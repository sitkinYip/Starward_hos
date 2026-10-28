#!/usr/bin/env python3
"""Build a public, sanitised state-to-source map from completed captures."""
import argparse
import datetime
import hashlib
import json
import math
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / 'artifacts'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--native-group', choices=('native-system-visual','native-https-visual'), default='native-system-visual')
args = parser.parse_args()
CRITERIA = 'arkui-system-v1'
IMMERSION_VERSION = 'edge-to-edge-v1'
FROZEN_WEB = '4b7d1a0a00051ac630e459b0fd6c074f821d7455'
FONT_HASH = hashlib.sha256((ROOT / 'entry/src/main/resources/rawfile/fonts/NotoSerifSC.ttf').read_bytes()).hexdigest()
NATIVE = ARTIFACTS / args.native_group


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_object(path):
    if not path.is_file() or path.is_symlink():
        return None
    try:
        value = json.loads(path.read_text())
    except (OSError, ValueError):
        return None
    return value if isinstance(value, dict) else None


policy = read_object(ARTIFACTS / 'visual-comparison/criteria.json')
if not policy or policy.get('id') != CRITERIA:
    raise SystemExit('Current visual-acceptance policy is missing or mismatched')

HAP_FILE = 'artifacts/validation/native-system-visual-hap.json'
expected_hap = read_object(ROOT / HAP_FILE)
expected_hap_source_sha = digest(ROOT / HAP_FILE) if expected_hap else None
expected_hap_sha = expected_hap.get('sha256') if expected_hap else None
if not isinstance(expected_hap_sha, str) or not re.fullmatch(r'[0-9a-f]{64}', expected_hap_sha):
    expected_hap_sha = None

RUNTIME_FILE = 'artifacts/validation/native-system-runtime.json'
runtime = read_object(ROOT / RUNTIME_FILE)
runtime_sha = digest(ROOT / RUNTIME_FILE) if runtime else None
def current_hap_provenance(data):
    if not isinstance(data, dict):
        return False
    hap = data.get('hap')
    return bool(expected_hap_sha and expected_hap.get('immersionVersion') == IMMERSION_VERSION
                and data.get('immersionVersion') == IMMERSION_VERSION and isinstance(hap, dict)
                and hap.get('immersionVersion') == IMMERSION_VERSION
                and hap.get('source') == HAP_FILE
                and hap.get('sourceSha256') == expected_hap_source_sha
                and hap.get('sha256') == expected_hap_sha)


interaction_file = 'artifacts/validation/device-system-ui.json'
interaction = read_object(ROOT / interaction_file)
interaction_checks = interaction.get('checks') if interaction else None
interaction_valid = bool(interaction and interaction.get('visualCriteria') == CRITERIA
                         and interaction.get('status') == 'passed' and current_hap_provenance(interaction)
                         and isinstance(interaction_checks, list) and interaction_checks
                         and interaction.get('count') == len(interaction_checks)
                         and all(isinstance(check, str) and check for check in interaction_checks))
material = runtime.get('material') if runtime else None
material_public = None
if (isinstance(material, dict) and isinstance(material.get('supported'), bool)
        and all(isinstance(material.get(key), int) and not isinstance(material[key], bool)
                for key in ('state', 'type', 'level'))):
    material_public = {key: material[key] for key in ('supported', 'state', 'type', 'level')}
system_bars_public = None
window_record = runtime.get('window') if runtime else None
if isinstance(window_record, dict) and window_record.get('systemBarPropertiesObserved') is True:
    color_keys = ('statusBarColor','navigationBarColor','statusBarContentColor','navigationBarContentColor')
    if all(isinstance(window_record.get(key),str) and re.fullmatch(r'#[0-9a-fA-F]{8}',window_record[key]) for key in color_keys):
        system_bars_public = {key:window_record[key] for key in color_keys}
        system_bars_public.update({'immersiveLayout':window_record.get('immersiveLayout'),'systemBarPropertiesObserved':True})

runtime_evidence = {
    'runtime': {'available': runtime is not None, 'file': RUNTIME_FILE, 'sha256': runtime_sha,
                'materialAsRecorded': material_public,'immersionVersion':runtime.get('immersionVersion') if runtime else None,
                'systemBarsAsRecorded':system_bars_public},
    'interaction': {'available': interaction_valid, 'file': interaction_file,
                    'sha256': digest(ROOT / interaction_file) if interaction else None,
                    'status': interaction.get('status') if interaction else 'missing',
                    'count': interaction.get('count', 0) if interaction else 0,
                    'verifiedCheckCount': len(interaction_checks) if interaction_valid else 0,
                    'currentHapVerified':current_hap_provenance(interaction)},
    'historicalInteraction':{'file':'artifacts/native-pre-edge-to-edge/device-system-ui.json','scope':'Pre-edge-to-edge 17 checks are archived and do not establish final immersion-version acceptance.'},
    'scope': 'One API26 physical phone. Independent interaction report and recorded material support/state; screenshot pairing is separate. No motion recording, reduced-motion, spoken-reader, fold/hover/split/window-change or forced material-fallback acceptance is implied.'
}


def current_capture_provenance(data):
    if not isinstance(data, dict):
        return False, False
    hap_valid = current_hap_provenance(data)
    window = data.get('window')
    records = runtime.get('records', []) if runtime else []
    keys = ('widthPx','heightPx','density','topInsetPx','bottomInsetPx')
    window_valid = False
    if isinstance(window, dict):
        index = window.get('sourceRecord')
        window_valid = bool(window.get('source') == RUNTIME_FILE
                            and window.get('sourceSha256') == runtime_sha
                            and isinstance(index, int) and not isinstance(index, bool)
                            and isinstance(records, list) and 0 <= index < len(records)
                            and isinstance(records[index], dict)
                            and all(isinstance(window.get(key),(int,float))
                                    and not isinstance(window[key],bool) and math.isfinite(window[key])
                                    and records[index].get(key) == window[key] for key in keys))
    return hap_valid, window_valid


def resume_provenance(data, depth=0):
    if depth > 8:
        return False, {'verified':False,'reason':'Resume provenance chain exceeds the bounded verification depth'}
    resumed = data.get('resumedFrom') if isinstance(data,dict) else None
    if resumed is None:
        return True, None
    if not isinstance(resumed,dict):
        return False, {'verified':False}
    source = resumed.get('source','')
    valid_path = isinstance(source,str) and re.fullmatch(r'artifacts/native-system-visual-attempt-[0-9]+/capture-summary\.json',source)
    path = ROOT / source if valid_path else None
    previous = read_object(path) if path else None
    retained = resumed.get('retained',[])
    count = resumed.get('retainedCount')
    new_count = resumed.get('newExpectedCount')
    valid = bool(previous and digest(path) == resumed.get('sha256')
                 and current_capture_provenance(previous) == (True,True)
                 and previous.get('status') == resumed.get('originalStatus')
                 and previous.get('count') == resumed.get('originalCount')
                 and isinstance(retained,list) and isinstance(count,int) and not isinstance(count,bool)
                 and isinstance(new_count,int) and not isinstance(new_count,bool)
                 and count == len(retained) and count > 0 and new_count > 0)
    previous_resume = None
    if valid:
        previous_valid, previous_resume = resume_provenance(previous, depth + 1)
        valid = valid and previous_valid
    if valid:
        for item in retained:
            if not isinstance(item,dict):
                valid = False
                break
            before = next((r for r in previous.get('states',[]) if isinstance(r,dict)
                           and r.get('state') == item.get('state') and r.get('theme') == item.get('theme')),None)
            current = next((r for r in data.get('states',[]) if isinstance(r,dict)
                            and r.get('state') == item.get('state') and r.get('theme') == item.get('theme')),None)
            if not before or not current or before.get('themeVerified') is not True or before.get('screenshotSha256') != item.get('screenshotSha256') or current.get('screenshotSha256') != item.get('screenshotSha256'):
                valid = False
                break
    if valid and data.get('status') == 'captured' and data.get('count') != count + new_count:
        valid = False
    public = {'verified':valid,'source':source if valid_path else None,'sha256':resumed.get('sha256'),
              'originalStatus':resumed.get('originalStatus'),'originalCount':resumed.get('originalCount'),
              'retainedCount':count,'newExpectedCount':new_count,'newCapturedCount':data.get('newCapturedCount'),
              'previousResume':previous_resume,
              'note':'Retained verified states plus new states; not one uninterrupted capture run.'}
    return valid, public


def native_report(filename, required_states):
    path = NATIVE / filename
    data = read_object(path)
    records = data.get('states',[]) if data else []
    if not isinstance(records, list) or not all(isinstance(item, dict) for item in records):
        records = []
    actual = {(item.get('state'),item.get('theme')) for item in records}
    expected = {(state,theme) for state in required_states for theme in ('light','dark')}
    hap_valid, window_valid = current_capture_provenance(data)
    resume_valid, resume_public = resume_provenance(data)
    valid = bool(resume_valid and hap_valid and window_valid and data and data.get('visualCriteria') == CRITERIA and data.get('status') == 'captured'
                 and data.get('count') == len(records) and len(actual) == len(records)
                 and expected.issubset(actual))
    return data if valid else None, {'file':str(path.relative_to(ROOT)), 'complete':valid,
            'status':data.get('status') if data else 'missing', 'count':data.get('count',0) if data else 0,
            'visualCriteria':data.get('visualCriteria') if data else None, 'currentHapVerified':hap_valid,
            'currentRuntimeVerified':window_valid,'resume':resume_public, 'immersionVersion':data.get('immersionVersion') if data else None, 'requiredStatesPresent':expected.issubset(actual),
            'sha256':digest(path) if data else None, 'capturedAt':data.get('capturedAt') if data else None}


auth, auth_public = native_report('auth-capture-summary.json', ('login','forced-password'))
visual, visual_public = native_report('capture-summary.json', ('home','detail','history','logout','login-keyboard','detail-waiting','detail-expired','detail-locked','detail-404-fault'))
web_cache = {}


def web_source(group, state, theme, fault=False):
    if group not in web_cache:
        directory = ARTIFACTS / group
        metadata = read_object(directory / 'capture-summary.json')
        reason = None
        if not metadata:
            reason = 'Web capture summary is missing'
        elif metadata.get('sourceCommit') != FROZEN_WEB or metadata.get('viewport') != {'width':391,'height':777}:
            reason = 'Web revision or content viewport does not match'
        elif metadata.get('pageErrors') or metadata.get('browserUsesRealBackend') is not False:
            reason = 'Web capture is not a clean local response replay'
        elif metadata.get('fontControl', {}).get('sha256') != FONT_HASH:
            reason = 'Display-font control bytes do not match the native font'
        else:
            source = metadata.get('snapshotInput', {})
            sha = source.get('sha256', '')
            if not re.fullmatch(r'[0-9a-f]{64}', sha):
                reason = 'This group has no actual response-snapshot SHA-256'
            else:
                archive = ROOT / 'artifacts/private/web-visual-inputs' / (sha + '.json')
                supplied = Path(source.get('file',''))
                supplied = (supplied if supplied.is_absolute() else ROOT / supplied).resolve()
                if not supplied.is_relative_to((ROOT / 'artifacts/private/https-isolation').resolve()):
                    reason = 'Unexpected source-snapshot location'
                elif not archive.is_file() or archive.is_symlink() or digest(archive) != sha:
                    reason = 'Immutable private snapshot archive is missing or changed'
                elif not supplied.is_file() or digest(supplied) != sha:
                    reason = 'The current snapshot was changed after this capture; recapture required'
        web_cache[group] = metadata, reason
    metadata, reason = web_cache[group]
    public = {'available':False,'directory':group,'file':f'{state}-{theme}.png','reason':reason}
    if reason:
        return public
    expected = f'{state}-{theme}.png'
    item = next((i for i in metadata.get('states', []) if i.get('state') == state and i.get('theme') == theme and i.get('screenshot') == expected), None)
    path = ARTIFACTS / group / expected
    measurement = path.with_suffix('.json')
    if not item or not path.is_file() or path.is_symlink() or not measurement.is_file():
        public['reason'] = 'The selected Web state has not been captured'
        return public
    if item.get('screenshotSha256') != digest(path):
        public['reason'] = 'The Web PNG does not match its capture-time SHA-256'
        return public
    if fault and not metadata.get('errorReplay'):
        public['reason'] = 'Fault origin was not explicitly labelled'
        return public
    public.update({'available':True,'reason':None,'sha256':digest(path),'measurement':measurement.name,
                   'shaScope':'capture-time PNG SHA-256 validated against current bytes',
                   'snapshotSha256':metadata['snapshotInput']['sha256'],'browserUsesRealBackend':False,
                   'dataConsumption':{'login':'空登录表单，不消费玩家/场次DTO','logout':'退出后的空登录表单，不显示玩家/场次DTO','forced-password':'仅消费真实改密前player','home':'真实player与assignments快照','detail':'真实player与assignment快照','history':'真实player与assignments快照','error':'真实player前置与显式合成错误响应'}.get(state,'逐请求来源见capture-summary'),
                   'errorReplay':metadata.get('errorReplay') if fault else None})
    return public


def native_source(state, theme):
    report = auth if state in ('login','forced-password') else visual
    name = f'{state}-{theme}.png'
    source = {'available':False,'directory':args.native_group,'file':name,'reason':'The final edge-to-edge capture is incomplete or does not match the expected HAP/runtime provenance'}
    if not report:
        return source
    item = next((i for i in report['states'] if i.get('state') == state and i.get('theme') == theme and i.get('screenshot') == name), None)
    path = NATIVE / name
    if not item or item.get('themeVerified') is not True or not path.is_file() or path.is_symlink():
        source['reason'] = 'Native state/theme lacks a verified original PNG'
        return source
    with path.open('rb') as image:
        header = image.read(24)
    if len(header) != 24 or header[:8] != b'\x89PNG\r\n\x1a\n' or header[12:16] != b'IHDR' or item.get('pixels') != list(struct.unpack('>II',header[16:24])):
        source['reason'] = 'Native PNG dimensions do not match the capture report'
        return source
    if state in ('login','forced-password') and item.get('visibleInputsEmpty') is not True:
        source['reason'] = 'The blank native auth-input prerequisite is not confirmed'
        return source
    if state == 'detail-404-fault' and item.get('injectedResilience') is not True:
        source['reason'] = 'The native fault origin is not explicitly labelled'
        return source
    if state == 'login-keyboard' and (item.get('keyboard') is not True or item.get('keyboardFocus') != 'account' or item.get('visibleInputsEmpty') is not True):
        source['reason'] = 'The blank ordinary-account keyboard prerequisite is not confirmed'
        return source
    current_hash = digest(path)
    recorded_hash = item.get('screenshotSha256')
    if recorded_hash is not None and recorded_hash != current_hash:
        source['reason'] = 'Native PNG differs from its capture-time hash'
        return source
    window = report.get('window')
    if isinstance(window,dict):
        keys = ('widthPx','heightPx','density','topInsetPx','bottomInsetPx')
        if not all(isinstance(window.get(key),(int,float)) and not isinstance(window.get(key),bool) and math.isfinite(window[key]) for key in keys) or min(window['widthPx'],window['density']) <= 0 or min(window['topInsetPx'],window['bottomInsetPx']) < 0 or window['heightPx'] <= window['topInsetPx'] + window['bottomInsetPx'] or item.get('pixels') != [window['widthPx'],window['heightPx']]:
            source['reason'] = 'The new window metadata does not match the screenshot pixels'
            return source
        clean_window = {key:window[key] for key in keys}
        source_keys = ('source', 'sourceRecord', 'sourceSha256')
        if any(key in window for key in source_keys):
            index = window.get('sourceRecord')
            records = runtime.get('records', []) if runtime else []
            if (window.get('source') != RUNTIME_FILE or window.get('sourceSha256') != runtime_sha
                    or not isinstance(index, int) or isinstance(index, bool)
                    or not isinstance(records, list) or not 0 <= index < len(records)
                    or not isinstance(records[index], dict)
                    or any(records[index].get(key) != window[key] for key in keys)):
                source['reason'] = 'Native window source record/hash does not match the measured runtime file'
                return source
            clean_window.update({key: window[key] for key in source_keys})
        window = clean_window
    else:
        window = None
    source.update({'available':True,'reason':None,'sha256':current_hash,'themeVerified':True,
                   'shaScope':'capture-time PNG SHA-256 validated against current bytes' if recorded_hash else 'pair-generation current PNG bytes; native report has no capture-time PNG hash',
                   'captureSource':'auth-system' if state in ('login','forced-password') else 'main-system',
                   'window':window,'geometryStatus':'new-report-window-recorded' if window else 'new-window-metrics-missing-full-image-only',
                   'contentViewportVp':[window['widthPx']/window['density'],(window['heightPx']-window['topInsetPx']-window['bottomInsetPx'])/window['density']] if window else None,
                   'pixels':item.get('pixels'),'keyboardFocus':item.get('keyboardFocus') if state == 'login-keyboard' else None,
                   'keyboardScope':'Ordinary blank account focus only; device IME keeps its own theme. No password secure-IME image or simultaneous visibility of every field/CTA is implied.' if state == 'login-keyboard' else None,
                   'injectedResilience':item.get('injectedResilience',False)})
    return source


mapping = [
    ('login','登录','web-isolated-content','login','primary'),
    ('forced-password','首次改密','web-isolated-forced','forced-password','primary'),
    ('home','主页','web-isolated-content','home','primary'),
    ('detail','详情','web-isolated-content','detail','primary'),
    ('history','历史空状态','web-isolated-content','history','primary'),
    ('logout','退出后登录','web-isolated-content','logout','primary'),
    ('detail-waiting','等待详情','web-isolated-waiting','detail','primary'),
    ('detail-expired','过期详情','web-isolated-expired','detail','primary'),
    ('detail-locked','等级锁定详情','web-isolated-locked','detail','primary'),
    ('detail-404-fault','404故障详情','web-isolated-error','error','fault'),
    ('login-keyboard','原生登录键盘',None,None,'native-only'),
]
result = {'generatedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'visualCriteria':CRITERIA,'sourceCommit':FROZEN_WEB,
          'criteriaFile':'criteria.json','expectedHap':{'file':HAP_FILE,'sourceSha256':expected_hap_source_sha,'sha256':expected_hap_sha,'immersionVersion':IMMERSION_VERSION},'approvedPlatformDifferences':policy['approvedPlatformDifferences'],
          'viewport':{'webReferenceCssPx':[391,777],'nativeWindow':'Per-state new report window when provided; legacy density/insets are not inherited'},
          'meaning':'Compare brand, copy, business states and information layout. Official ArkUI materials, motion and approved home floating layout are intentional platform differences. Pair counts do not establish runtime API, interaction or adaptive-device acceptance.',
          'nativeReports':{'auth':auth_public,'visual':visual_public},
          'nativeComposition':'New arkui-system-v1 completed auth and main reports only. Superseded legacy captures are historical reference and never satisfy current acceptance.',
          'platformVerification':'Independent runtime and interaction evidence is listed separately; component selection or screenshot availability alone does not verify all platform behaviour.',
          'runtimeEvidence':runtime_evidence,
          'expected':{'primaryPairs':18,'faultPairs':2,'nativeOnlyKeyboard':2},
          'counts':{'primaryPairs':0,'faultPairs':0,'nativeOnlyKeyboard':0},'order':[],'states':{}}
for native_state,label,web_group,web_state,kind in mapping:
    for theme,theme_label in (('light','浅'),('dark','深')):
        key = f'{native_state}-{theme}'
        native = native_source(native_state,theme)
        web = web_source(web_group,web_state,theme,kind == 'fault') if web_group else {'available':False,'reason':'HarmonyOS IME is native platform evidence; no simulated browser keyboard is manufactured.'}
        paired = bool(native['available'] and web['available'])
        if paired:
            result['counts']['faultPairs' if kind == 'fault' else 'primaryPairs'] += 1
        elif kind == 'native-only' and native['available']:
            result['counts']['nativeOnlyKeyboard'] += 1
        result['order'].append(key)
        result['states'][key] = {'label':label+'·'+theme_label,'kind':kind,'paired':paired,'native':native,'web':web}
result['extraNativeEvidence'] = []
if visual:
    for observed in visual.get('observations', []):
        if (not isinstance(observed, dict) or observed.get('extraEvidence') is not True
                or observed.get('countsTowardMain18') is not False or observed.get('status') != 'captured'
                or observed.get('screenshot') != 'system-home-behind-bar.png'
                or observed.get('visibleInputsEmpty') is not True or observed.get('keyboard') is not False
                or observed.get('themeVerified') is not True):
            continue
        path = NATIVE / observed['screenshot']
        if not path.is_file() or path.is_symlink() or observed.get('screenshotSha256') != digest(path):
            continue
        with path.open('rb') as source:
            header = source.read(24)
        if (len(header) != 24 or header[:8] != b'\x89PNG\r\n\x1a\n'
                or header[12:16] != b'IHDR' or observed.get('pixels') != list(struct.unpack('>II',header[16:24]))
                or observed.get('pixels') != [visual['window']['widthPx'],visual['window']['heightPx']]):
            continue
        result['extraNativeEvidence'].append({'kind':'multi-card content behind the official floating bar',
            'label':'四场次内容与官方悬浮底栏（额外原图，不计18项）',
            'directory':args.native_group,'file':observed['screenshot'],
            'sha256':observed['screenshotSha256'],'shaScope':'capture-time PNG SHA-256 validated against current bytes',
            'countsTowardMain18':False,'theme':observed.get('theme'),'pixels':observed['pixels'],
            'scrollBounds':observed.get('scrollBounds'),'floatingBarBounds':observed.get('floatingBarBounds')})

review_path = ARTIFACTS / 'visual-comparison/visual-review.json'
review = read_object(review_path)
review_rows = review.get('states', []) if review else []
review_valid = bool(review and review.get('status') == 'reviewed_with_known_non_platform_differences'
                    and review.get('hapSha256') == expected_hap_sha
                    and review.get('hapSourceSha256') == expected_hap_source_sha
                    and review.get('visualCriteria') == CRITERIA
                    and review.get('immersionVersion') == IMMERSION_VERSION
                    and review.get('nativeReviewedCount') == len(result['order'])
                    and isinstance(review_rows, list) and len(review_rows) == len(result['order'])
                    and {row.get('state') for row in review_rows if isinstance(row, dict)} == set(result['order'])
                    and all(review.get('sourceReports', {}).get(key, {}).get('sha256') == result['nativeReports'][key]['sha256']
                            and result['nativeReports'][key]['complete'] for key in ('auth', 'visual')))
if review_valid:
    for row in review_rows:
        mapped = result['states'][row['state']]
        if (row.get('reviewed') is not True or mapped['native'].get('available') is not True
                or row.get('nativeSha256') != mapped['native'].get('sha256')
                or row.get('webSha256') != mapped['web'].get('sha256')):
            review_valid = False
            break
known_differences = review.get('knownNonPlatformDifferences', []) if review_valid else []
if not (isinstance(known_differences, list) and all(isinstance(item, dict)
        and item.get('status') == 'pending_adjustment' and isinstance(item.get('description'), str)
        and isinstance(item.get('states'), list) and set(item['states']).issubset(result['order'])
        for item in known_differences)):
    review_valid = False
    known_differences = []
result['visualReview'] = {'available':review_valid, 'status':review.get('status') if review_valid else 'not_verified',
    'sha256':digest(review_path) if review_valid else None,
    'nativeReviewedCount':review.get('nativeReviewedCount') if review_valid else 0,
    'knownNonPlatformDifferences':known_differences,
    'scope':'Manual visual findings for these exact capture/image bytes only. Pair counts are source coverage; documented non-platform differences remain pending adjustment.'}

manifest = ARTIFACTS / 'visual-comparison/pairs.json'
manifest.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
html = ARTIFACTS / 'visual-comparison/index.html'
source = html.read_text()
replacement = '// BEGIN GENERATED PAIRS\nconst finalPairs = ' + json.dumps(result,ensure_ascii=False,separators=(',',':')).replace('<','\\u003c') + ';\n// END GENERATED PAIRS'
source,count = re.subn(r'// BEGIN GENERATED PAIRS[\s\S]*?// END GENERATED PAIRS',lambda _:replacement,source)
if count != 1:
    raise SystemExit('The HTML pairing placeholder is missing or duplicated')
html.write_text(source)
print(json.dumps({'visualCriteria':CRITERIA,'counts':result['counts'],'expected':result['expected'],'nativeReports':{k:v['complete'] for k,v in result['nativeReports'].items()},'manifest':str(manifest.relative_to(ROOT))},ensure_ascii=False))
