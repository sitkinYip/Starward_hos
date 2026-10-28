#!/usr/bin/env python3
"""Check the public comparison controls in headless Chrome without device access."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'artifacts/private/python-playwright'))
from playwright.sync_api import sync_playwright
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--port',type=int,default=5179)
args=parser.parse_args()
if not 1<=args.port<=65535:parser.error('Expected a running loopback viewer port')
manifest_path=ROOT/'artifacts/visual-comparison/pairs.json'
manifest_bytes=manifest_path.read_bytes()
manifest=json.loads(manifest_bytes)
first=next((key for key in manifest['order'] if manifest['states'][key]['native']['available']),manifest['order'][0])
expected=manifest['states'][first]['native']
errors=[];csp=[];responses=[];state_images=[]
with sync_playwright() as p:
    browser=p.chromium.launch(channel='chrome',headless=True)
    try:
        page=browser.new_page(viewport={'width':1200,'height':1000})
        page.on('pageerror',lambda e:errors.append(str(e)))
        page.on('console',lambda m:csp.append(m.text) if m.type=='error' and 'Content Security Policy' in m.text else None)
        page.on('response',lambda r:responses.append({'path':r.url.split(':'+str(args.port))[-1],'status':r.status}) if r.status>=400 else None)
        page.goto(f'http://127.0.0.1:{args.port}/visual-comparison/index.html');page.wait_for_load_state('networkidle')
        buttons=page.locator('#states button')
        if buttons.count()!=len(manifest['order']):raise RuntimeError('Viewer state index is incomplete')
        for i,key in enumerate(manifest['order']):
            buttons.nth(i).click()
            selected=manifest['states'][key]
            checked={'state':key}
            for surface in ('native','web'):
                source=selected[surface]
                target=page.locator('#'+surface)
                if source['available']:
                    suffix='/'+source['directory']+'/'+source['file']
                    page.wait_for_function('([id,suffix])=>{const img=document.getElementById(id);return !img.hidden && img.complete && img.naturalWidth>0 && img.src.endsWith(suffix)}',arg=[surface,suffix])
                    pixels=target.evaluate('(img)=>[img.naturalWidth,img.naturalHeight]')
                    if surface=='native' and pixels!=source['pixels']:
                        raise RuntimeError('Rendered native dimensions differ from the verified source: '+key)
                    if surface=='web' and pixels!=manifest['viewport']['webReferenceCssPx']:
                        raise RuntimeError('Rendered Web dimensions differ from the frozen viewport: '+key)
                    checked[surface]={'loaded':True,'pixels':pixels}
                elif not target.is_hidden():
                    raise RuntimeError('An unavailable source was displayed: '+key+'/'+surface)
                else:
                    checked[surface]={'loaded':False,'expectedUnavailable':True}
            state_images.append(checked)
        buttons.nth(manifest['order'].index(first)).click();page.wait_for_load_state('networkidle')
        if expected['available']:
            page.wait_for_function('(suffix)=>{const img=document.getElementById("native");return !img.hidden && img.complete && img.naturalWidth>0 && img.src.endsWith(suffix)}',arg=expected['file'])
        if page.locator('#area').input_value() != 'full':
            raise RuntimeError('The default view hides the system immersion areas')
        if manifest.get('visualReview',{}).get('available'):
            visible_notes=page.locator('#knownDifferences').inner_text()
            if not all(item['description'] in visible_notes for item in manifest['visualReview']['knownNonPlatformDifferences']):
                raise RuntimeError('The documented non-platform visual differences are not visible')
        current={'title':page.title(),'states':buttons.count(),'counts':page.locator('#pairStatus').inner_text(),
                 'selectedState':first,'nativeHidden':page.locator('#native').is_hidden(),
                 'areaDisabled':page.locator('#area').is_disabled(),'defaultNativeArea':'full',
                 'runtime':page.locator('#runtimeStatus').inner_text(),
                 'window':page.locator('#viewportNote').inner_text()}
        if current['nativeHidden']==expected['available']:
            raise RuntimeError('Displayed native availability differs from verified provenance')
        if expected['available']:
            if not page.locator('#native').evaluate('(img)=>img.complete && img.naturalWidth>0'):
                raise RuntimeError('Verified native image failed to load')
            page.locator('#area').select_option('content')
            if not page.locator('#nativeFrame').evaluate('(frame)=>frame.classList.contains("content")'):
                raise RuntimeError('Optional content-alignment view did not activate')
            page.locator('#area').select_option('full')
        elif not current['areaDisabled']:
            raise RuntimeError('Viewport conversion was enabled without verified current evidence')
        buttons.nth(manifest['order'].index('login-light')).click()
        page.locator('#run').select_option('initial');page.wait_for_load_state('networkidle')
        page.wait_for_function('()=>{const img=document.getElementById("native");return !img.hidden && img.complete && img.naturalWidth>0 && img.src.includes("native-before-visual")}')
        legacy=page.locator('#native').evaluate('(img)=>img.complete && img.naturalWidth>0 && img.src.includes("native-before-visual")')
        if not legacy:raise RuntimeError('Historical image failed to load')
        page.locator('#run').select_option('final');page.wait_for_load_state('networkidle')
        page.screenshot(path=str(ROOT/'artifacts/validation/visual-report-framework.png'),full_page=True)
    finally:browser.close()
result={'visualCriteria':manifest['visualCriteria'],'immersionVersion':manifest['expectedHap']['immersionVersion'],
        'expectedHap':manifest['expectedHap'],
        'pairManifest':{'file':str(manifest_path.relative_to(ROOT)),'sha256':hashlib.sha256(manifest_bytes).hexdigest()},
        'checkedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'scope':'Viewer framework only. Screenshot/source pairing and native product acceptance are separate conclusions.',
        'browser':current,'stateImages':state_images,'legacyImageLoaded':legacy,'pageErrors':errors,'cspErrors':csp,
        'httpErrors':responses,'expectedUnservedFaviconOnly':all(r['path']=='/favicon.ico' for r in responses)}
(ROOT/'artifacts/validation/visual-report-server-browser-checks.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'states':current['states'],'verifiedAvailabilityMatches':True,'verifiedStateImages':len(state_images),'legacyLoaded':legacy,
                  'pageErrors':len(errors),'cspErrors':len(csp),
                  'unexpectedHttpErrors':sum(r['path']!='/favicon.ico' for r in responses)}))
if errors or csp or any(r['path']!='/favicon.ico' for r in responses):raise SystemExit(1)
