#!/usr/bin/env python3
"""Staged source-format phone checks after the main avatar acceptance passes.

begin --case ... --manifest <private> --receipt <private import receipt>
  -> root selects that exact imported source in the real system Picker
confirm --case ... --manifest <same private manifest>

No host upload exists here. Host requests only authenticate/read back the result
of the native multipart write. Main avatar reports/session files are untouched.
"""
import argparse
import datetime
import hashlib
import importlib.util
import io
import json
import math
import os
from pathlib import Path
import ssl
import shutil
import time
import urllib.parse
import urllib.request

from native_device_ui import ROOT, IsolationControl, SafeFailure
from isolated_snapshot import ReadonlySnapshot

SPEC = importlib.util.spec_from_file_location('avatar_source_ui', Path(__file__).with_name('device-profile-avatar.py'))
AVATAR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AVATAR)
OUT = ROOT / 'artifacts/validation/profile'
PRIVATE = ROOT / 'artifacts/private/avatar-source-device'
HAP = ROOT / 'entry/build/default/outputs/default/entry-default-signed.hap'
PROFILE = '/api/questions/v1/me/profile'
CHANGE = '/api/questions/v1/me/change-password'
TOKEN = '/api/files/token'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def private_write(path, value, binary=False):
    if path.is_symlink():
        raise SafeFailure('Private source-format output cannot be a symlink')
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd = os.open(path, os.O_WRONLY|os.O_CREAT|os.O_TRUNC|os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'wb' if binary else 'w') as output:
        output.write(value)
    path.chmod(0o600)


def within_private(path):
    resolved = path.resolve()
    if path.is_symlink() or not resolved.is_relative_to((ROOT/'artifacts/private').resolve()):
        raise SafeFailure('Source fixture inputs and receipts must remain private')
    return resolved


class SourceUI(AVATAR.AvatarUI):
    def __init__(self, state, density, directory):
        super().__init__(state, density)
        self.output = directory
        self.shots = directory


class Acceptance:
    def __init__(self, args):
        self.args = args
        self.control = IsolationControl()
        self.state = self.control.state
        self.hap = sha(HAP)
        self.runtime_path = args.runtime_report.resolve()
        if not self.runtime_path.is_relative_to(OUT.resolve()):
            raise SafeFailure('Source-format runtime report must remain in profile validation')
        self.runtime_sha = sha(self.runtime_path)
        runtime = json.loads(self.runtime_path.read_text())
        density = runtime.get('window',{}).get('density')
        if (runtime.get('status') != 'passed' or runtime.get('installedHapSha256') != self.hap or
                not isinstance(density,(int,float)) or isinstance(density,bool) or not math.isfinite(density) or density <= 0):
            raise SafeFailure('Source-format runtime must match the current actual HAP and density')
        config = json.loads((ROOT/'entry/src/main/resources/rawfile/integration.json').read_text())
        if config.get('isolated') is not True or config.get('endpoint') != self.state['tls']['base'] or not self.state['account'].startswith('hm_'):
            raise SafeFailure('Only this packaged dedicated HTTPS player is supported')
        self.inputs = {'runtime':self.runtime_path,'core':OUT/'device-profile-acceptance.json',
                       's2':OUT/'device-profile-password-uncertain.json','mainAvatar':OUT/'device-profile-avatar.json'}
        self.input_shas = {key:sha(path) for key,path in self.inputs.items()}
        core = json.loads(self.inputs['core'].read_text())
        s2 = json.loads(self.inputs['s2'].read_text())
        main_avatar = json.loads(self.inputs['mainAvatar'].read_text())
        for label,value in (('core',core),('S2',s2),('main avatar',main_avatar)):
            if (value.get('status') != 'passed' or value.get('hap',{}).get('packagedSha256') != self.hap or
                    value.get('runtime',{}).get('sha256') != self.runtime_sha):
                raise SafeFailure('Complete matching '+label+' acceptance before source-format phone checks')
        if (s2.get('corePrerequisite',{}).get('sha256') != self.input_shas['core'] or
                main_avatar.get('corePrerequisite',{}).get('sha256') != self.input_shas['core'] or
                main_avatar.get('securityPrerequisiteSha256') != self.input_shas['s2'] or
                not all(s2.get('cleanup',{}).get(k) is True for k in ('loggedOut','faultNeutralised'))):
            raise SafeFailure('Source-format prerequisites do not share one completed account epoch')
        self.password_key = s2.get('finalPasswordKey')
        if self.password_key not in ('initialPassword','newPassword'):
            raise SafeFailure('A verified S2 password key is required')
        self.manifest_path = within_private(args.manifest)
        self.manifest_sha = sha(self.manifest_path)
        manifest = json.loads(self.manifest_path.read_text())
        cases = [x for x in manifest.get('cases',[]) if x.get('case') == args.case]
        if manifest.get('status') != 'prepared_not_device_tested' or len(cases) != 1:
            raise SafeFailure('A unique prepared source-format fixture case is required')
        self.fixture = cases[0]
        self.fixture_paths = {}
        for key,record in (('source',self.fixture['source']),('expected',self.fixture['expectedLosslessPng']),
                           ('wrong',self.fixture['wrongHypothesis'])):
            path = within_private(ROOT/record['file'])
            if sha(path) != record['sha256']:
                raise SafeFailure('A prepared source-format fixture/reference changed')
            self.fixture_paths[key] = path
        if self.fixture_paths['source'].stat().st_size > 50*1024*1024:
            raise SafeFailure('This source-format case unexpectedly exceeds the raw image limit')
        self.owner = hashlib.sha256((self.state['account']+self.state['playerId']+self.state['controlBase']).encode()).hexdigest()
        self.session_path = PRIVATE/(args.case+'-session.json')
        self.report_path = OUT/('avatar-source-'+args.case+'.json')
        if args.action == 'begin':
            if self.session_path.exists():
                if not args.new_attempt:
                    raise SafeFailure('This source case already has a session; use --new-attempt for an intentional evidence-preserving retry')
                stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
                archived=PRIVATE/(args.case+'-session-'+stamp+'.json')
                shutil.copyfile(self.session_path,archived)
                archived.chmod(0o600)
                if self.report_path.exists():
                    attempts=OUT/'attempts'
                    attempts.mkdir(exist_ok=True)
                    shutil.copyfile(self.report_path,attempts/('avatar-source-'+args.case+'-'+stamp+'.json'))
            self.directory = PRIVATE/('capture-'+args.case+'-'+datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'))
            self.directory.mkdir(parents=True,exist_ok=False,mode=0o700)
            self.directory.chmod(0o700)
            self.session = {'case':args.case,'ownerSha256':self.owner,'hapSha256':self.hap,
                'inputShas':self.input_shas,'manifestSha256':self.manifest_sha,
                'directory':str(self.directory.relative_to(ROOT)),'startedAt':now(),
                'checks':[],'phases':[],'privateScreenshots':[],'requestLedger':[],
                'cleanup':{'loggedOut':False,'emptyLoginInputs':False},'finalPasswordKey':self.password_key}
        else:
            self.session = json.loads(self.session_path.read_text())
            if (self.session.get('ownerSha256') != self.owner or self.session.get('hapSha256') != self.hap or
                    self.session.get('inputShas') != self.input_shas or self.session.get('manifestSha256') != self.manifest_sha or
                    'picker-open' not in self.session.get('phases',[])):
                raise SafeFailure('The source-format session belongs to another build, fixture or account epoch')
            self.directory = within_private(ROOT/self.session['directory'])
        self.ui = SourceUI(self.state,density,self.directory)
        self.ui.private_screenshots = self.session['privateScreenshots']
        self.ready = False

    def immutable(self):
        if sha(HAP) != self.hap or sha(self.manifest_path) != self.manifest_sha or any(sha(path) != self.input_shas[key] for key,path in self.inputs.items()):
            raise SafeFailure('A source-format HAP, fixture or prerequisite report changed')
        for key,record in (('source',self.fixture['source']),('expected',self.fixture['expectedLosslessPng']),('wrong',self.fixture['wrongHypothesis'])):
            if sha(self.fixture_paths[key]) != record['sha256']:
                raise SafeFailure('A prepared source-format fixture/reference changed during acceptance')

    def save(self,status='awaiting_next_stage',error=None):
        self.immutable()
        self.session['updatedAt'] = now()
        private_write(self.session_path,json.dumps(self.session,ensure_ascii=False,indent=2)+'\n')
        source = self.fixture['source']
        public = {'status':status,'scope':'Actual native source-format system Picker/crop/upload/readback',
            'case':self.args.case,'environment':'Dedicated disposable PocketBase over strict USB HTTPS',
            'startedAt':self.session['startedAt'],'updatedAt':self.session['updatedAt'],
            'hap':{'packagedSha256':self.hap},'runtime':{'file':str(self.runtime_path.relative_to(ROOT)),'sha256':self.runtime_sha},
            'prerequisiteSha256':self.input_shas,'fixtureManifestSha256':self.manifest_sha,
            'source':{key:source.get(key) for key in ('sha256','bytes','format','rawDimensions','exifOrientation')},
            'expectedNormalization':self.fixture['normalization'],'expectedOutputDimensions':[512,512],
            'expectedQuadrantOrder':self.fixture['quadrantOrder'],
            'count':len(self.session['checks']),'checks':self.session['checks'],'phases':self.session['phases'],
            'output':self.session.get('output'),'privateScreenshots':self.ui.private_screenshots,
            'requestLedger':self.session['requestLedger'],'cleanup':self.session['cleanup'],
            'finalPasswordKey':self.password_key,
            'hostTraffic':'Strict HTTPS authentication/file-token/readback only; native UI sends the sole profile multipart write',
            'notExecuted':['Over50MiB source and alpha WebP behaviour are outside these two small-format cases',
                           'Foldable and other cross-device checks remain deferred']}
        if error:public['error']=self.ui.redact(error)
        self.report_path.write_text(json.dumps(public,ensure_ascii=False,indent=2)+'\n')

    def check(self,condition,label):
        if not condition:raise SafeFailure('Source-format expectation did not hold: '+label)
        self.session['checks'].append({'label':label,'case':self.args.case})
        self.save()
        print(json.dumps({'count':len(self.session['checks']),'passed':label},ensure_ascii=False),flush=True)

    def rows(self,path,method):
        return [r for r in self.control.requests() if r.get('path')==path and r.get('method')==method]

    def await_rows(self,path,method,before,status=200):
        deadline=time.monotonic()+30
        while time.monotonic()<deadline:
            rows=self.rows(path,method)[before:]
            if rows and rows[0].get('status'):
                if rows[0]['status']!=status or rows[0].get('fault'):
                    raise SafeFailure('The expected new source-format request did not complete normally')
                return rows
            time.sleep(.15)
        raise SafeFailure('The expected new source-format request did not complete')

    def checkpoint(self,label):
        keys=('method','path','status','fault','authenticated','bearer','bodyKind','avatarPartPresent','requestBytes','fileTokenProvided')
        rows=[]
        for row in self.control.requests():
            item={k:row[k] for k in keys if k in row}
            if str(item.get('path','')).startswith('/api/files/game_players/'):
                item['path']='/api/files/game_players/[owner]/[avatar]'
            rows.append(item)
        self.session['requestLedger'].append({'phase':label,'requests':rows})

    def login(self):
        self.ui.fill('account',self.state['account'])
        self.ui.fill('password',self.state[self.password_key])
        self.ui.tap('primary-action')
        self.ui.wait(lambda u:u.find('current-tab') is not None,'source-format authenticated home')
        self.ui.tap('nav-profile')
        self.ui.wait(lambda u:u.find('profile-scroll') is not None,'source-format profile Scroll')
        self.ui.seek('profile-avatar-pick')

    def begin(self):
        if not self.args.receipt:raise SafeFailure('A private source import/readback receipt is required')
        receipt_path=within_private(self.args.receipt)
        receipt=json.loads(receipt_path.read_text())
        expected=self.fixture['source']['sha256']
        if (receipt.get('fixtureSha256')!=expected or receipt.get('readbackSha256')!=expected or
                not isinstance(receipt.get('mediaUri'),str) or not receipt['mediaUri']):
            raise SafeFailure('The precise source fixture must have a matching official import/readback SHA')
        self.session['importReceipt']={'file':str(receipt_path.relative_to(ROOT)),'sha256':sha(receipt_path)}
        self.ui.launch()
        self.ui.wait(lambda u:u.find('account') is not None,'pre-existing blank login before source Picker')
        if not self.ui.input_empty('account') or not self.ui.input_empty('password'):
            raise SafeFailure('Finish the previous phone phase at empty login before source acceptance')
        self.ready=True
        self.session['beforePatch']=len(self.rows(PROFILE,'PATCH'))
        self.session['beforePassword']=len(self.rows(CHANGE,'POST'))
        self.login()
        self.ui.private_shot(self.args.case+'-profile-before-picker')
        self.check(True,'The dedicated phone reaches the native profile before opening a real system Picker')
        self.ui.tap('profile-avatar-pick')
        self.session['phases'].append('picker-open')
        self.save('awaiting_system_selection')
        print('System Picker opened. Root must select the exact imported source, then run confirm for this same case.',flush=True)

    def owned_readback(self):
        snapshot=ReadonlySnapshot(self.state)
        snapshot.login(self.state[self.password_key])
        player=snapshot.request('/api/questions/v1/me')
        if player.get('id')!=self.state['playerId'] or not player.get('avatar'):
            raise SafeFailure('Native source upload did not retain a file on the owned player')
        path='/api/files/game_players/'+urllib.parse.quote(self.state['playerId'],safe='')+'/'+urllib.parse.quote(player['avatar'],safe='')
        # Before Host file-token/GET, require the native automatic protected read.
        deadline=time.monotonic()+30
        while time.monotonic()<deadline:
            new_rows=self.control.requests()[self.session['beforeSaveLedger']:]
            native_files=[r for r in new_rows if r.get('path')==path and r.get('method')=='GET']
            native_tokens=[r for r in new_rows if r.get('path')==TOKEN and r.get('method')=='POST']
            if any(r.get('status')==200 and not r.get('fault') for r in native_files):
                break
            if any(r.get('status') and r.get('status')!=200 for r in native_files):
                raise SafeFailure('The new native source-avatar protected read did not succeed')
            time.sleep(.15)
        else:raise SafeFailure('The new native source-avatar protected read did not complete')
        self.check(any(r.get('status')==200 and not r.get('fault') and r.get('fileTokenProvided') for r in native_files) and
                   any(r.get('status')==200 and not r.get('fault') for r in native_tokens),
                   'After native source save, a new native file-token and protected-file GET200 finish before Host readback')
        ctx=ssl.create_default_context(cafile=self.state['tls']['caPath'])
        request=urllib.request.Request(self.state['tls']['hostBase']+TOKEN,data=b'{}',method='POST',
            headers={'Authorization':snapshot.token,'Content-Type':'application/json'})
        try:
            with urllib.request.urlopen(request,context=ctx,timeout=25) as response:file_token=json.load(response)['token']
            request=urllib.request.Request(self.state['tls']['hostBase']+path+'?token='+urllib.parse.quote(file_token,safe=''))
            with urllib.request.urlopen(request,context=ctx,timeout=25) as response:
                body=response.read(2*1024*1024+1)
                content_type=response.headers.get_content_type()
        except Exception:raise SafeFailure('Source-result protected readback failed; URL and token omitted') from None
        private_write(self.directory/'native-uploaded-result.jpg',body,True)
        from PIL import Image,ImageChops,ImageStat
        with Image.open(io.BytesIO(body)) as image:
            image.load()
            output=image.convert('RGB')
            self.check(image.format=='JPEG' and image.size==(512,512) and content_type=='image/jpeg' and len(body)<=200*1024,
                       'The actual native upload is a512px square JPEG within200KiB')
            self.check(not dict(image.getexif()),'Native source normalization/upload removes source EXIF fields')
        with Image.open(self.fixture_paths['expected']) as image:expected=image.convert('RGB')
        with Image.open(self.fixture_paths['wrong']) as image:wrong=image.convert('RGB')
        def mae(reference):return sum(ImageStat.Stat(ImageChops.difference(output,reference)).mean)/3
        correct_mae,wrong_mae=mae(expected),mae(wrong)
        self.session['output']={'sha256':hashlib.sha256(body).hexdigest(),'bytes':len(body),'format':'JPEG','dimensions':[512,512],
            'correctCenteredOrientationMae':round(correct_mae,6),'wrongHypothesisMae':round(wrong_mae,6),
            'wrongHypothesis':self.fixture['wrongHypothesis']['description'],
            'wrongUnrotatedComparisonApplicable':self.fixture['wrongUnrotatedComparisonApplicable'],
            'thresholds':{'maxCorrectMae':8,'minWrongMinusCorrectMae':5,'minWrongToCorrectRatio':1.6},
            'expectedReferenceSha256':self.fixture['expectedLosslessPng']['sha256']}
        self.check(correct_mae<=8 and wrong_mae>=correct_mae+5 and wrong_mae>=correct_mae*1.6,
                   'The entire real native output matches the correctly oriented centered crop and rejects the specified wrong hypothesis')
        for sample in self.fixture['quadrantSamples']:
            x,y=sample['position']
            rgb=output.getpixel((int(x*512),int(y*512)))
            if max(abs(rgb[i]-sample['expectedRGB'][i]) for i in range(3))>36:
                raise SafeFailure('The real source output did not preserve the expected oriented quadrant order')
        self.check(True,'Real output quadrant order matches the independently normalized source fixture')

    def confirm(self):
        receipt=self.session['importReceipt']
        if sha(within_private(ROOT/receipt['file']))!=receipt['sha256']:
            raise SafeFailure('The source import receipt changed between Picker stages')
        self.ui.wait(lambda u:u.find('avatar-crop-preview') is not None,'prepared native source crop')
        self.ready=True
        self.ui.seek('avatar-crop-preview')
        self.ui.private_shot(self.args.case+'-default-crop')
        self.ui.tap('avatar-crop-confirm')
        self.ui.wait(lambda u:u.find('avatar-crop-preview') is None,'source crop confirmation')
        self.ui.seek('profile-avatar-pending')
        self.check(len(self.rows(PROFILE,'PATCH'))==self.session['beforePatch'],
                   'Source crop confirmation leaves an unsaved local draft and sends no profile write')
        self.ui.private_shot(self.args.case+'-pending')
        before=len(self.rows(PROFILE,'PATCH'))
        self.session['beforeSaveLedger']=len(self.control.requests())
        self.ui.tap('profile-save')
        rows=self.await_rows(PROFILE,'PATCH',before)
        row=rows[0]
        self.ui.seek('profile-saved')
        self.check(row.get('bodyKind')=='multipart' and row.get('avatarPartPresent') is True and
                   row.get('authenticated') is True and row.get('bearer') is False and len(self.rows(PROFILE,'PATCH'))==before+1,
                   'One explicit native source save sends one authenticated multipart avatar PATCH200')
        self.owned_readback()
        self.ui.seek('profile-avatar-pick')
        self.ui.private_shot(self.args.case+'-saved')
        self.session['phases'].append('native-source-verified')
        self.checkpoint('native-source-format-orientation-upload-readback')

    def logout(self):
        self.ui.capture()
        if any(self.ui.find(x) is not None for x in ('avatar-crop-preview','avatar-crop-loading','avatar-crop-error')):
            self.ui.back()
            self.ui.wait(lambda u:u.find('profile-scroll') is not None,'source crop dismissed before logout')
        if self.ui.find('account') is None:
            menu_open=any(self.ui.find(x) is not None for x in ('menu-home','menu-profile','menu-rewards','menu-notifications','logout')) or self.ui.has_text('冒险者菜单')
            if not menu_open:self.ui.tap('account-menu')
            self.ui.seek('logout')
            self.ui.tap('logout')
            self.ui.wait(lambda u:u.find('account') is not None,'source-format explicit logout')
        self.ui.back()
        self.ui.launch()
        self.ui.wait(lambda u:u.find('account') is not None,'source-format Back/Ability logout boundary')
        self.session['cleanup']={'loggedOut':True,'emptyLoginInputs':self.ui.input_empty('account') and self.ui.input_empty('password')}
        if not self.session['cleanup']['emptyLoginInputs']:raise SafeFailure('Source-format logout did not clear login fields')

    def run(self):
        failure=None
        try:getattr(self,self.args.action)()
        except Exception as error:
            failure=str(error) if isinstance(error,SafeFailure) else 'Source-format helper stopped before this stage completed'
            private_write(self.directory/'failure.json',json.dumps({'type':type(error).__name__,'message':str(error)},ensure_ascii=False)+'\n')
        if self.args.action=='confirm' or failure:
            if self.ready:
                try:self.logout()
                except Exception:failure=failure or 'Source-format explicit logout cleanup did not complete'
            if not failure and (len(self.rows(PROFILE,'PATCH'))!=self.session['beforePatch']+1 or
                    len(self.rows(CHANGE,'POST'))!=self.session['beforePassword']):
                failure='Source-format checks observed an unexpected number of profile/password writes'
            if not failure:self.session['phases'].append('logged-out')
            self.save('incomplete' if failure else 'passed',failure)
        print(json.dumps({'status':'incomplete' if failure else 'awaiting_system_selection' if self.args.action=='begin' else 'passed',
            'case':self.args.case,'count':len(self.session['checks']),'report':str(self.report_path.relative_to(ROOT))},ensure_ascii=False))
        return 1 if failure else 0


def main():
    parser=argparse.ArgumentParser(description=__doc__,formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('action',choices=['begin','confirm'])
    parser.add_argument('--case',required=True,choices=['jpeg-exif6','webp-rgb'])
    parser.add_argument('--manifest',required=True,type=Path)
    parser.add_argument('--receipt',type=Path)
    parser.add_argument('--runtime-report',type=Path,default=OUT/'runtime.json')
    parser.add_argument('--new-attempt',action='store_true')
    args=parser.parse_args()
    try:return Acceptance(args).run()
    except Exception as error:
        text=str(error) if isinstance(error,SafeFailure) else 'Source-format setup stopped before phone acceptance began'
        print(json.dumps({'status':'incomplete','error':text},ensure_ascii=False))
        return 1


if __name__=='__main__':raise SystemExit(main())
