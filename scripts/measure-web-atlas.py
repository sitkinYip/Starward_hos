#!/usr/bin/env python3
"""Measure frozen Web atlas layout without screenshots or backend requests."""
import sys,json,hashlib,subprocess,re
from pathlib import Path
from urllib.parse import quote
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'artifacts/private/python-playwright'))
from playwright.sync_api import sync_playwright
web=ROOT.parent/'questions-web'
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=web,text=True).strip()=='4b7d1a0a00051ac630e459b0fd6c074f821d7455'
assert not subprocess.check_output(['git','status','--porcelain'],cwd=web,text=True).strip()
font=(ROOT/'entry/src/main/resources/rawfile/fonts/NotoSerifSC.ttf').read_bytes()
fixtures={}
for name,literal in re.findall(r'export const (WEB_\w+): string = (".*?");',(ROOT/'entry/src/test/fixtures/WebFixture.ets').read_text()):
 fixtures[name]=json.loads(json.loads(literal))
result={'sourceCommit':'4b7d1a0a00051ac630e459b0fd6c074f821d7455','method':'Read-only headless Chrome DOM and SVG getBBox/getScreenCTM; frozen E2E fixture replay; no screenshot, no browser backend requests','fontSha256':hashlib.sha256(font).hexdigest(),'runs':[]}
selectors={'story':'.game-auth__story','storyCopy':'.game-auth__story-copy','atlas':'.game-auth__story > .celestial-atlas','outer':'.game-auth__story .celestial-atlas__orbit--outer','middle':'.game-auth__story .celestial-atlas__orbit--middle','inner':'.game-auth__story .celestial-atlas__orbit--inner','star':'.game-auth__story .celestial-atlas__star','svg':'.game-auth__story .celestial-atlas__star svg','north':'.game-auth__story .celestial-atlas__north','south':'.game-auth__story .celestial-atlas__south'}
selectors.update({'homeIntro':'.game-lobby__intro','homeAtlas':'.game-lobby__intro > .celestial-atlas','homeStar':'.game-lobby__intro .celestial-atlas__star','brief':'.assignment-brief','briefArt':'.assignment-brief__art','briefAtlas':'.assignment-brief__art .celestial-atlas','briefStar':'.assignment-brief__art .celestial-atlas__star'})
measure_js='''selectors=>{
 const r={};const rect=b=>({x:b.x,y:b.y,width:b.width,height:b.height,centerX:b.x+b.width/2,centerY:b.y+b.height/2});
 for(const [key,selector] of Object.entries(selectors)){const e=document.querySelector(selector);if(!e)continue;const s=getComputedStyle(e);r[key]={...rect(e.getBoundingClientRect()),position:s.position,top:s.top,right:s.right,left:s.left,transform:s.transform,opacity:s.opacity};}
 r.svgShapes=[...document.querySelectorAll('.celestial-atlas__star svg path,.celestial-atlas__star svg polygon')].map(e=>{const q=e.getBBox(),m=e.getScreenCTM(),a=new DOMPoint(q.x,q.y).matrixTransform(m),b=new DOMPoint(q.x+q.width,q.y+q.height).matrixTransform(m),s=getComputedStyle(e);return{tag:e.tagName,bbox:{x:q.x,y:q.y,width:q.width,height:q.height},screenBbox:{x:a.x,y:a.y,width:b.x-a.x,height:b.y-a.y,centerX:(a.x+b.x)/2,centerY:(a.y+b.y)/2},stroke:s.stroke,strokeWidth:s.strokeWidth,fill:s.fill}});
 const atlas=document.querySelector('.game-auth__story > .celestial-atlas,.game-lobby__intro > .celestial-atlas,.assignment-brief__art .celestial-atlas');
 if(atlas){const a=atlas.getBoundingClientRect();r.orbitMarkers=[...atlas.querySelectorAll('.celestial-atlas__orbit')].flatMap(orbit=>{const o=orbit.getBoundingClientRect(),s=getComputedStyle(orbit);return [...orbit.querySelectorAll('i')].map((e,i)=>{const b=e.getBoundingClientRect(),c=getComputedStyle(e);return{orbit:orbit.className,index:i+1,orbitRect:rect(o),orbitStyle:{border:s.border,padding:s.padding,opacity:s.opacity},viewportRect:rect(b),relativeToAtlas:{x:b.x-a.x,y:b.y-a.y,width:b.width,height:b.height},style:{top:c.top,left:c.left,border:c.border,boxSizing:c.boxSizing,background:c.backgroundColor}}})})}
 return r;
}'''
with sync_playwright() as p:
 b=p.chromium.launch(headless=True,executable_path='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')
 result['browser']=b.version
 for width,height in [(390,844),(391,777)]:
  for controlled in [False,True]:
   c=b.new_context(viewport={'width':width,'height':height},device_scale_factor=1,color_scheme='light',reduced_motion='reduce',locale='zh-CN',timezone_id='Asia/Shanghai')
   page=c.new_page()
   player=json.loads(json.dumps(fixtures['WEB_PLAYER_JSON']))
   assignment=fixtures['WEB_ASSIGNMENT_JSON']
   def intercept(route):
    from urllib.parse import urlparse
    u=urlparse(route.request.url)
    if u.path=='/__measure__/font.ttf':route.fulfill(status=200,content_type='font/ttf',body=font)
    elif u.path.startswith('/api/'):
     if u.path=='/api/collections/game_players/auth-with-password':body={'token':'atlas-fixture-token','record':{'id':player['id']}}
     elif u.path=='/api/questions/v1/me':body=player
     elif u.path=='/api/questions/v1/me/change-password':
      player['mustChangePassword']=False;body={'token':'atlas-rotated-fixture-token','player':player}
     elif u.path=='/api/questions/v1/assignments':body=fixtures['WEB_ASSIGNMENTS_JSON']
     elif u.path=='/api/questions/v1/assignments/'+quote(assignment['id'],safe=''):body=assignment
     else:route.abort();return
     route.fulfill(status=200,content_type='application/json',body=json.dumps(body,ensure_ascii=False))
    elif u.netloc=='127.0.0.1:5178':route.continue_()
    else:route.abort()
   page.route('**/*',intercept)
   page.goto('http://127.0.0.1:5178/login?theme=light');page.wait_for_load_state('networkidle')
   if controlled:
    page.add_style_tag(content='@font-face{font-family:StarwardControlledSerif;src:url("http://127.0.0.1:5178/__measure__/font.ttf") format("truetype");font-weight:100 900;font-style:normal;font-display:block}:root{--font-display:StarwardControlledSerif,serif!important}')
    page.evaluate('document.fonts.load("34px StarwardControlledSerif")')
   page.evaluate('document.fonts.ready')
   measured=page.evaluate(measure_js,selectors)
   page.get_by_label('登录账号',exact=True).fill(player['account'])
   page.get_by_label('密码',exact=True).fill('AtlasFixture123')
   page.get_by_role('button',name='进入冒险',exact=True).click()
   page.get_by_role('heading',name='首次登录，请先修改密码',exact=True).wait_for()
   page.get_by_label('当前密码',exact=True).fill('AtlasFixture123')
   page.get_by_label('新密码',exact=True).fill('NewAtlasFixture123')
   page.get_by_label('确认新密码',exact=True).fill('NewAtlasFixture123')
   page.get_by_role('button',name='保存新密码',exact=True).click()
   page.get_by_role('heading',name='下一段故事，等你落笔。',exact=True).wait_for();page.wait_for_load_state('networkidle')
   home_measured=page.evaluate(measure_js,selectors)
   page.locator('a[href="/play/'+quote(assignment['id'],safe='')+'"]').click()
   page.get_by_role('button',name='开始本场冒险',exact=True).wait_for();page.wait_for_load_state('networkidle')
   detail_measured=page.evaluate(measure_js,selectors)
   result['runs'].append({'viewport':{'width':width,'height':height},'font':'same-native-NotoSerifSC' if controlled else 'original-system-font','measurements':measured,'homeMeasurements':home_measured,'detailMeasurements':detail_measured})
   c.close()
 b.close()
out=ROOT/'artifacts/validation/web-atlas-layout.json';out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
for run in result['runs']:
 print(run['viewport'],run['font'],json.dumps({'authAtlas':run['measurements']['atlas'],'home':run['homeMeasurements'],'detail':run['detailMeasurements']},ensure_ascii=False))
