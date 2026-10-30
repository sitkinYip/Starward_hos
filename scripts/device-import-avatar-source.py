#!/usr/bin/env python3
"""Official, exact-file import/readback/cleanup for own private source fixtures.

Importing this Python module, --help, py_compile and cleanup-plan do not touch devices. Actual
import requires one connected target, an existing album from an earlier verified
receipt, query0 and no destination file. Cleanup re-exports/SHA-verifies the exact
recorded URI before deleting it. Never handles all, folders or personal media.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import secrets
import shlex
import subprocess
import time
from urllib.parse import urlparse

ROOT=Path(__file__).resolve().parents[1]
PRIVATE=ROOT/'artifacts/private'
BASE=PRIVATE/'avatar-source-import'
NAME=re.compile(r'starward-source-[a-f0-9]{32}\.(jpg|webp)')


class SafeFailure(RuntimeError):pass


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def private_path(path):
    resolved=path.resolve()
    if path.is_symlink() or not resolved.is_relative_to(PRIVATE.resolve()):
        raise SafeFailure('All source/receipt/output paths must remain in project private artifacts')
    return resolved


def save(path,value):
    path=private_path(path)
    path.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
    descriptor=os.open(path,os.O_WRONLY|os.O_CREAT|os.O_TRUNC|os.O_NOFOLLOW,0o600)
    with os.fdopen(descriptor,'w') as out:
        json.dump(value,out,ensure_ascii=False,indent=2);out.write('\n')
    path.chmod(0o600)


def valid_uri(uri,display_name):
    parsed=urlparse(uri)
    parts=PurePosixPath(parsed.path).parts
    return (parsed.scheme=='file' and parsed.netloc=='media' and not parsed.query and not parsed.fragment and
            len(parts)>=4 and parts[1]=='Photo' and parts[2].isdigit() and int(parts[2])>0 and parts[-1]==display_name)


def load_receipt(path):
    path=private_path(path)
    value=json.loads(path.read_text())
    name=value.get('displayName','')
    if not NAME.fullmatch(name) or value.get('ownedTool')!='device-import-avatar-source.py':
        raise SafeFailure('Only a uniquely named source fixture owned by this tool may be handled')
    if not re.fullmatch(r'[a-f0-9]{64}',value.get('fixtureSha256','')):
        raise SafeFailure('The source fixture SHA is missing')
    device_path=PurePosixPath(value.get('devicePath',''))
    if not re.fullmatch(r'/mnt/data/[0-9]+/media_fuse/Photo/[^/]+/'+re.escape(name),str(device_path)):
        raise SafeFailure('The recorded exact media_fuse destination is invalid')
    if value.get('mediaUri') and not valid_uri(value['mediaUri'],name):
        raise SafeFailure('The recorded exact media URI is invalid')
    return path,value


class Device:
    def __init__(self,directory):
        self.directory=private_path(directory)
        self.directory.mkdir(parents=True,exist_ok=True,mode=0o700)
        self.directory.chmod(0o700)
        self.serial=0
        try:result=subprocess.run(['hdc','list','targets'],capture_output=True,text=True,timeout=20,cwd=ROOT)
        except subprocess.TimeoutExpired:raise SafeFailure('Connected-target query timed out; identifiers omitted') from None
        if result.returncode:raise SafeFailure('Connected-target query failed; identifiers omitted')
        devices=[line.strip() for line in result.stdout.splitlines() if line.strip() and '[Empty]' not in line]
        save(self.directory/'connected-target-count.json',{'connectedCount':len(devices),'identifiersPersisted':False})
        if len(devices)!=1:
            raise SafeFailure('Exactly one connected target is required; identifiers omitted')

    def run(self,args,label,allow_one=False,timeout=45):
        self.serial+=1
        try:result=subprocess.run(args,capture_output=True,text=True,timeout=timeout,cwd=ROOT)
        except subprocess.TimeoutExpired:raise SafeFailure('Official command timed out: '+label) from None
        record={'label':label,'returncode':result.returncode,'stdout':result.stdout,'stderr':result.stderr}
        save(self.directory/(str(self.serial).zfill(3)+'-'+label+'.json'),record)
        if result.returncode!=0 and not (allow_one and result.returncode==1):
            raise SafeFailure('Official command failed: '+label+'; raw output remains private')
        if not allow_one and re.search(r'\[fail\]|\[error\]|error:|permission denied|not connected',result.stdout+'\n'+result.stderr,re.I):
            raise SafeFailure('Official command reported failure: '+label+'; raw output remains private')
        return result.stdout

    def test(self,flag,path,expected,label):
        # Shell quoting is for the remote shell only; no local shell is used.
        command='test '+flag+' '+shlex.quote(str(path))
        if not expected:command='test ! '+flag+' '+shlex.quote(str(path))
        self.run(['hdc','shell',command],label)

    def query(self,name,label):
        if not NAME.fullmatch(name):raise SafeFailure('Refusing a non-owned display name')
        output=self.run(['hdc','shell',shlex.join(['mediatool','query',name,'-u'])],label)
        counts=re.findall(r'\bfind\s+(\d+)\s+result\b',output,re.I)
        uris=re.findall(r'"(file://media/Photo/[^"\r\n]+)"',output)
        if len(counts)!=1 or 'format is not correct' in output:
            raise SafeFailure('Official exact-name query did not report one parseable result count')
        count=int(counts[0])
        if count!=len(uris) or any(not valid_uri(uri,name) for uri in uris):
            raise SafeFailure('Exact-name query count and URI rows did not agree')
        return count,uris

    def readback(self,value,label):
        if not valid_uri(value['mediaUri'],value['displayName']):raise SafeFailure('Exact owned URI is required before export')
        extension=PurePosixPath(value['displayName']).suffix
        unique='starward-source-export-'+secrets.token_hex(16)+extension
        temporary='/data/local/tmp/'+unique
        target=self.directory/unique
        self.test('-e',temporary,False,label+'-temp-absent')
        # Journal the exact temporary path before creating it, for safe recovery.
        value.setdefault('ownedTemporaryExports',[]).append({'path':temporary,'shaVerified':False})
        self.run(['hdc','shell',shlex.join(['mediatool','recv',value['mediaUri'],temporary])],label+'-media-recv')
        self.run(['hdc','file','recv',temporary,str(target)],label+'-hdc-recv')
        target.chmod(0o600)
        digest=sha(target)
        if digest!=value['fixtureSha256']:
            raise SafeFailure('Exported source bytes differ from the exact owned fixture SHA')
        value['ownedTemporaryExports'][-1].update({'shaVerified':True,'sha256':digest})
        value.update({'temporaryExport':temporary,'readbackSha256':digest,'readbackBytes':target.stat().st_size,
                      'shaVerified':True})
        return target


def source_case(manifest_path,case):
    manifest_path=private_path(manifest_path)
    data=json.loads(manifest_path.read_text())
    entries=[x for x in data.get('cases',[]) if x.get('case')==case]
    if data.get('status')!='prepared_not_device_tested' or len(entries)!=1:
        raise SafeFailure('A unique prepared source fixture is required')
    entry=entries[0]['source']
    source=private_path(ROOT/entry['file'])
    if sha(source)!=entry['sha256'] or source.stat().st_size!=entry['bytes']:
        raise SafeFailure('The prepared source bytes no longer match the private manifest')
    return source,entry,sha(manifest_path)


def new_import(args):
    source,entry,manifest_sha=source_case(args.manifest,args.case)
    observed=json.loads(private_path(args.album_receipt).read_text())
    if (observed.get('shaVerified') is not True or observed.get('fixtureSha256')!=observed.get('readbackSha256') or
            not observed.get('devicePath') or not observed.get('mediaUri')):
        raise SafeFailure('An earlier exact-file, SHA-verified observed-album receipt is required')
    album=PurePosixPath(observed['devicePath']).parent
    if not re.fullmatch(r'/mnt/data/[0-9]+/media_fuse/Photo/[^/]+',str(album)) or album.name in ('.','..'):
        raise SafeFailure('The earlier receipt does not identify one observed existing album')
    stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    directory=BASE/('import-'+args.case+'-'+stamp)
    directory.mkdir(parents=True,exist_ok=False,mode=0o700)
    directory.chmod(0o700)
    extension='.jpg' if args.case=='jpeg-exif6' else '.webp'
    display_name='starward-source-'+secrets.token_hex(16)+extension
    local=directory/display_name
    descriptor=os.open(local,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600)
    with os.fdopen(descriptor,'wb') as output:output.write(source.read_bytes())
    if sha(local)!=entry['sha256']:raise SafeFailure('The private import copy changed before any device operation')
    receipt=directory/'receipt.json'
    value={'ownedTool':'device-import-avatar-source.py','case':args.case,'status':'prepared_not_sent',
           'fixtureSha256':entry['sha256'],'sourceBytes':entry['bytes'],'sourceManifestSha256':manifest_sha,
           'displayName':display_name,'devicePath':str(album/display_name),'localCopy':str(local.relative_to(ROOT)),
           'importedVia':'Official hdc media_fuse import API21+; no directory creation',
           'albumReceiptSha256':sha(args.album_receipt),'importSent':False,'shaVerified':False,
           'createdAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'ownedTemporaryExports':[]}
    save(receipt,value)
    device=Device(directory/'commands')
    device.test('-d',album,True,'observed-album-still-exists')
    count,_=device.query(display_name,'query-before-import')
    if count!=0:raise SafeFailure('The unique exact source name already exists; nothing was overwritten')
    device.test('-e',value['devicePath'],False,'exact-destination-absent')
    value['queryBeforeCount']=0;save(receipt,value)
    value['sendAttempted']=True;save(receipt,value)
    device.run(['hdc','file','send',str(local),value['devicePath']],'official-hdc-exact-file-send')
    value.update({'importSent':True,'status':'sent_not_verified'});save(receipt,value)
    verify_import(receipt,value,device)
    return receipt,value


def verify_import(receipt,value,device):
    if not (value.get('importSent') or value.get('sendAttempted')):raise SafeFailure('This tool has not recorded an import attempt for this receipt')
    deadline=time.monotonic()+30
    while time.monotonic()<deadline:
        count,uris=device.query(value['displayName'],'query-exact-import')
        if count==1:break
        if count>1:raise SafeFailure('The exact own display name is ambiguous; no asset was deleted')
        time.sleep(.25)
    else:raise SafeFailure('The imported source did not become an exact single media query result')
    if value.get('mediaUri') and value['mediaUri']!=uris[0]:
        raise SafeFailure('The source query URI changed from the recorded asset')
    value['mediaUri']=uris[0];value['queryAfterCount']=1;value['importSent']=True;save(receipt,value)
    try:device.readback(value,'source-readback')
    finally:save(receipt,value)
    value['status']='imported_sha_verified';save(receipt,value)


def cleanup_plan(receipt,value):
    if not value.get('shaVerified') or value.get('fixtureSha256')!=value.get('readbackSha256') or not value.get('mediaUri'):
        raise SafeFailure('Only a fully SHA-verified own source receipt has a cleanup plan')
    plan={'status':'plan_only_not_executed','receiptSha256':sha(receipt),
          'guards':['exact query URI must still match','fresh mediatool recv + local SHA must match before deletion',
                    'temporary exports are removed only after matching SHA; no wildcard, directory or all command'],
          'deleteExactVerifiedUri':['hdc','shell','mediatool','delete',value['mediaUri']],
          'verifyExactNameAbsent':['hdc','shell','mediatool','query',value['displayName'],'-u'],
          'ownedTemporaryExports':[x['path'] for x in value.get('ownedTemporaryExports',[])],
          'execution':'Use this script cleanup --receipt <this private receipt>; it performs fresh guards first'}
    target=receipt.parent/'cleanup-plan.json';save(target,plan);return target


def cleanup(receipt,value):
    if value.get('status')=='cleaned':return
    if not value.get('shaVerified') or value.get('readbackSha256')!=value['fixtureSha256']:
        raise SafeFailure('Cleanup refuses an unverified imported source')
    device=Device(receipt.parent/('cleanup-'+datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')))
    count,uris=device.query(value['displayName'],'cleanup-query-exact')
    if count!=1 or uris[0]!=value.get('mediaUri'):
        raise SafeFailure('Cleanup exact name/URI no longer matches; no media was deleted')
    try:device.readback(value,'cleanup-fresh-sha-check')
    finally:save(receipt,value)
    acknowledgement=device.run(['hdc','shell',shlex.join(['mediatool','delete',value['mediaUri']])],'delete-only-sha-verified-own-uri')
    if 'delete success' not in acknowledgement.lower():
        raise SafeFailure('The official exact-file delete did not acknowledge success')
    count,_=device.query(value['displayName'],'cleanup-query-absent')
    if count!=0:raise SafeFailure('The exact owned source is still indexed after cleanup')
    value['mediaDeleted']=True;save(receipt,value)
    # Every temporary file is an exact random path created by this tool, with a
    # previously verified fixture SHA. Re-read it again before its own rm.
    for index,item in enumerate(value.get('ownedTemporaryExports',[])):
        temporary=item.get('path','')
        if not re.fullmatch(r'/data/local/tmp/starward-source-export-[a-f0-9]{32}\.(jpg|webp)',temporary):
            raise SafeFailure('Cleanup refuses an unrecognised temporary export path')
        if item.get('removed'):continue
        if not item.get('shaVerified') or item.get('sha256')!=value['fixtureSha256']:
            raise SafeFailure('An incomplete temporary export requires explicit verification before removal')
        local=device.directory/('tmp-check-'+str(index)+PurePosixPath(temporary).suffix)
        device.run(['hdc','file','recv',temporary,str(local)],'cleanup-temp-readback-'+str(index))
        local.chmod(0o600)
        if sha(local)!=value['fixtureSha256']:
            raise SafeFailure('Temporary export changed; it was not removed')
        device.run(['hdc','shell',shlex.join(['rm',temporary])],'remove-only-own-temp-'+str(index))
        item['removed']=True;save(receipt,value)
    value.update({'status':'cleaned','cleanupQueryCount':0,'cleanupCompletedAt':datetime.datetime.now(datetime.timezone.utc).isoformat()})
    save(receipt,value)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    sub=parser.add_subparsers(dest='action',required=True)
    p=sub.add_parser('import')
    p.add_argument('--case',required=True,choices=['jpeg-exif6','webp-rgb'])
    p.add_argument('--manifest',type=Path,required=True)
    p.add_argument('--album-receipt',type=Path,default=ROOT/'artifacts/private/profile-device/avatar-import-receipt.json')
    for action in ('verify','cleanup-plan','cleanup'):
        p=sub.add_parser(action);p.add_argument('--receipt',type=Path,required=True)
    args=parser.parse_args()
    try:
        if args.action=='import':receipt,value=new_import(args)
        else:
            receipt,value=load_receipt(args.receipt)
            if args.action=='verify':verify_import(receipt,value,Device(receipt.parent/('verify-'+datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'))))
            elif args.action=='cleanup-plan':
                plan=cleanup_plan(receipt,value)
                print(json.dumps({'status':'plan_only_not_executed','privatePlan':str(plan.relative_to(ROOT))}));return 0
            else:cleanup(receipt,value)
        print(json.dumps({'status':value['status'],'receipt':str(receipt.relative_to(ROOT)),
                          'shaVerified':value.get('shaVerified',False),'sensitiveAddresses':'private receipt only'}))
        return 0
    except Exception as error:
        message=str(error) if isinstance(error,SafeFailure) else 'Owned source-media operation stopped; inspect the private receipt and command records'
        print(json.dumps({'status':'incomplete','error':message}));return 1


if __name__=='__main__':raise SystemExit(main())
