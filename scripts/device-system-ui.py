#!/usr/bin/env python3
"""Actual API26 official ArkUI regressions on this task's disposable HTTPS player."""
import datetime
import json
import time
from native_device_ui import ROOT, DeviceUI, IsolationControl, SafeFailure
from native_system_visual import runtime_hap, runtime_window

OUT = ROOT / 'artifacts/validation/native-system'
SHOTS = ROOT / 'artifacts/native-system-visual'
REPORT = ROOT / 'artifacts/validation/device-system-ui.json'
LIST = '/api/questions/v1/assignments'
AUTH = '/api/collections/game_players/auth-with-password'
ui = DeviceUI(OUT, SHOTS)
control = IsolationControl()
HAP = runtime_hap('edge-to-edge-v1')
WINDOW = runtime_window()
checks, geometry = [], []
cleanup = {'singleReadyRestored': False, 'loggedOut': False}

def report(status, error=None):
    result = {'status': status, 'visualCriteria': 'arkui-system-v1', 'immersionVersion':'edge-to-edge-v1', 'hap':HAP, 'window':WINDOW, 'count': len(checks),
              'checks': checks, 'geometry': geometry, 'cleanup': cleanup,
              'environment': 'real isolated PocketBase over verified USB HTTPS',
              'updatedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'limitations': ['One API26 physical phone; no foldable hardware, spoken reader or motion recording',
                              'Injected 503 is a resilience test, not an observed production failure']}
    if error: result['error'] = error
    REPORT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')

def check(value, label):
    if not value: raise SafeFailure('System UI expectation failed: ' + label)
    checks.append(label); report('running')
    print(json.dumps({'passed': label, 'count': len(checks)}, ensure_ascii=False), flush=True)

def request(number, status=200, fault=False):
    deadline=time.monotonic()+25
    while time.monotonic()<deadline:
        rows=[x for x in control.requests() if x.get('path')==LIST and x.get('method')=='GET']
        if len(rows)>=number and rows[number-1].get('status'):
            if rows[number-1]['status']!=status or rows[number-1].get('fault')!=fault:
                raise SafeFailure('This new list request had an unexpected status/origin')
            return
        time.sleep(.15)
    raise SafeFailure('New HTTPS list request did not finish')

def pull():
    ui.capture(); r=ui.find('current-scroll')['bounds']
    x=(r[0]+r[2])//2
    ui.run('devecocli','ui','swipe',x,int(r[1]+(r[3]-r[1])*.14),x,int(r[1]+(r[3]-r[1])*.72),'--speed',1000)

def top():
    # The current native Scroll exclusively owns these bounded gestures.
    for _ in range(7):
        ui.capture()
        first=ui.find('assignment-state-'+control.state['assignmentId'])
        if first and first['bounds'][1] > ui.find('current-scroll')['bounds'][1]+40: return
        ui.swipe('up')
    raise SafeFailure('Current list did not reach its beginning')

def shot(name):
    ui.capture(name); ui.screenshot(name)

try:
    report('running')
    control.call('/scenario', {'status':'assigned'})
    control.call('/scenario', {'singleAssignment':True})
    ui.launch(cold=True)
    ui.wait(lambda u:u.find('account') is not None,'system login')
    check(ui.has_text('隔离测试环境'), 'Native title retains the isolated environment label')
    runtime = json.loads((ROOT/'artifacts/validation/native-system-runtime.json').read_text())
    appearance = runtime['window']
    transparent = lambda color: isinstance(color,str) and len(color)==9 and color[1:3]=='00'
    check(appearance['immersiveLayout']=='enabled' and appearance['systemBarPropertiesObserved'] and
          transparent(appearance['statusBarColor']) and transparent(appearance['navigationBarColor']),
          'Actual main window is immersive and both system bar backgrounds are transparent')
    themes=runtime['systemBarThemeRecords']
    check(themes['0']['statusBarContentColor']=='#FFFFFFFF' and themes['1']['statusBarContentColor']=='#FF000000',
          'Actual dark and light app themes use legible white and black system bar content')
    picker=ui.find('theme-picker')['bounds']
    check(picker[1]>=appearance['topInsetPx']+8,
          'Title actions avoid the real status bar and cutout while their material paints behind it')
    geometry.append({'control':'safe-title-picker','bounds':picker,'safeTopPx':appearance['topInsetPx']})
    before=control.count(LIST,'GET')
    ui.fill('account',control.state['account']);ui.fill('password',control.state['newPassword']);ui.tap('primary-action')
    request(before+1)
    ui.wait(lambda u:u.find('current-tab') is not None,'official home')
    check(any(n.get('type')=='TitleBar' for n in ui.flat) and sum(n.get('type')=='Tabs' for n in ui.flat)>=2,
          'Home uses native Navigation title and nested native Tabs')
    ui.tap('account-menu')
    ui.wait(lambda u:u.find('logout') is not None,'first avatar tap opens official sheet')
    check(ui.has_text('冒险者护照') and ui.has_text('远航者'), 'First avatar click opens the official account Sheet')
    shot('system-sheet')
    ui.back();ui.wait(lambda u:u.find('logout') is None and u.find('current-tab') is not None,'sheet system Back')
    check(True,'System Back dismisses Sheet without leaving home')
    ui.tap('history-tab');ui.wait(lambda u:u.has_text('故事的第一页，还空着。'),'native category history')
    check(ui.has_text('完成一场冒险，就会在这里留下你的足迹。'),'Native category Tabs show the distinct history empty state')
    ui.tap('current-tab');ui.wait(lambda u:u.find('current-scroll') is not None,'current category')
    ui.tap('nav-rewards');ui.wait(lambda u:u.find('current-scroll') is not None,'deferred native destination stays on home')
    check(ui.find('assignment-'+control.state['assignmentId']) is not None,'Deferred bottom destination cannot enter an empty page')
    # A multi-card real projection must be scrollable beneath the floating bar.
    control.call('/scenario',{'singleAssignment':False})
    before=control.count(LIST,'GET');pull();request(before+1)
    check(control.count(LIST,'GET')==before+1,'Official Refresh gesture makes one new successful list GET')
    ui.capture()
    scroll=ui.find('current-scroll')['bounds'];bar=ui.find('nav-home')['bounds']
    geometry.append({'control':'floating-overlap','scroll':scroll,'barItem':bar})
    bar_path=ui.path_to('nav-home')
    whole_bar=next(n['bounds'] for n in reversed(bar_path) if n.get('type')=='TabBar')
    check(whole_bar[3]<=appearance['heightPx']-appearance['bottomInsetPx'],
          'The native floating bar keeps its interactive surface above the actual gesture safe area')
    check(scroll[3]==appearance['heightPx'],
          'Scrolling content extends to the physical bottom behind the transparent gesture region')
    check(scroll[3]>bar[3] and scroll[1]<bar[1], 'List viewport extends behind the floating native bottom bar')
    check(ui.find('refresh-assignments') is None,'The fixed synchronization refresh block has been removed')
    # Seek the actual sentence text in the final scroll item, not its padded box.
    footer=None
    for _ in range(14):
        ui.capture()
        note=ui.find('assignment-sync-note')
        text=next((n for n in ui.flat if n.get('id')=='assignment-sync-note-text'),None)
        if note and text:
            tabs=[n['bounds'] for n in ui.flat if n.get('type')=='TabBar' and n.get('bounds') and n['bounds'][1]>2000]
            bar_top=min(r[1] for r in tabs) if tabs else ui.find('nav-home')['bounds'][1]
            if text['bounds'][3]<=bar_top-8 and text['bounds'][1]>=ui.find('current-scroll')['bounds'][1]+8:
                footer=text;geometry.append({'control':'sync-sentence','text':text['bounds'],'floatingBarTop':bar_top,'lastItem':note['bounds']});break
        ui.swipe('down')
    check(footer is not None and footer.get('text')=='场次与进度会自动同步，放心去探索。',
          'The unchanged sync sentence is the final scrolling item and is fully above the floating bar at the end')
    shot('system-home-scroll-end')
    top();time.sleep(.3)
    before=control.count(LIST,'GET')
    control.call('/fault',{'path':LIST,'method':'GET','status':503,'body':{'error':{'code':'TEST_FAULT','message':'隔离网络故障注入'}}})
    pull();request(before+1,503,True)
    ui.wait(lambda u:u.find('request-retry') is not None,'refresh failure retained UI')
    check(ui.find('assignment-'+control.state['assignmentId']) is not None,'Refresh 503 keeps the previously loaded list and exposes retry')
    before=control.count(LIST,'GET');ui.tap('request-retry');request(before+1)
    ui.wait(lambda u:u.find('request-retry') is None,'successful refresh retry clears error')
    check(True,'Refresh failure recovers through one new real HTTPS GET')
    ui.tap('assignment-'+control.state['assignmentId']);ui.wait(lambda u:u.find('start-assignment') is not None,'native detail')
    check(any(n.get('type')=='NavDestination' for n in ui.flat) and any(n.get('type')=='TitleBar' for n in ui.flat),
          'Read-only detail uses native NavDestination and title')
    ui.seek('start-assignment');check(not ui.find('start-assignment').get('clickable'),'Start remains unavailable after native container migration')
    shot('system-detail')
    ui.edge_back();ui.wait(lambda u:u.find('current-tab') is not None,'native detail edge Back')
    check(True,'System edge Back returns from detail to home')
    ui.tap('account-menu');ui.tap('logout');ui.wait(lambda u:u.find('account') is not None,'native Sheet logout')
    check(ui.input_empty('account') and ui.input_empty('password'),'Official Sheet logout clears credentials and protected content')
    ui.back();ui.launch();ui.wait(lambda u:u.find('account') is not None,'logout Back gate')
    check(not ui.has_text('远航者'),'Back after logout cannot reveal the account or protected home')
    report('passed')
except Exception as e:
    report('failed',str(e) if isinstance(e,SafeFailure) else 'Native system UI helper failed');raise
finally:
    try:
        control.call('/fault',{'path':'/__neutralised_system_test__','method':'GET','status':503,'body':{}})
        control.call('/scenario',{'status':'assigned'});control.call('/scenario',{'singleAssignment':True});cleanup['singleReadyRestored']=True
        ui.launch(cold=True);ui.wait(lambda u:u.find('account') is not None,'system cleanup login')
        cleanup['loggedOut']=ui.input_empty('account') and ui.input_empty('password')
    finally:
        status=json.loads(REPORT.read_text()).get('status','failed');error=json.loads(REPORT.read_text()).get('error');report(status,error)
