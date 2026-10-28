#!/usr/bin/env python3
"""Collect only this App's public geometry/material/TLS metrics from official hilog.

Cold-launches the owned Ability; never reads credentials or changes system settings.
Keep the final visual runtime file immutable after its captures begin.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import time

from native_device_ui import ROOT, DeviceUI, SafeFailure

parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--font-scale', type=float)
parser.add_argument('--require-tls', action='store_true')
parser.add_argument('--themes', action='store_true')
args = parser.parse_args()
output = (ROOT / args.output).resolve() if not args.output.is_absolute() else args.output.resolve()
if not output.is_relative_to((ROOT / 'artifacts/validation').resolve()):
    parser.error('Evidence output must remain in this project validation directory')
if output.name == 'native-system-runtime.json' and output.exists():
    parser.error('The captured visual runtime is frozen; choose a separate evidence file')
output.parent.mkdir(parents=True, exist_ok=True)
raw = ROOT / 'artifacts/private/https-isolation' / (output.stem + '-hilog.log')
raw.parent.mkdir(parents=True, exist_ok=True)
ui = DeviceUI(output.parent / 'window-evidence', output.parent / 'window-evidence')
with raw.open('w') as sink:
    process = subprocess.Popen(['hdc', 'shell', 'hilog', '-T',
                                'StarwardMetrics,StarwardMaterial,StarwardTlsProbe'],
                               stdout=sink, stderr=subprocess.STDOUT)
    try:
        ui.launch(cold=True)
        time.sleep(5)
        ui.capture()
        if args.themes:
            if not ui.input_empty('account') or not ui.input_empty('password'):
                raise SafeFailure('Theme evidence requires the empty login page')
            for theme in ('dark','light'):
                ui.tap('theme-'+theme)
                ui.wait(lambda value:value.find('theme-'+theme) is not None, 'theme control remains available')
                time.sleep(.5)
    finally:
        process.terminate()
        process.wait(timeout=5)
raw.chmod(0o600)
rows = []
for line in raw.read_text().splitlines():
    match = re.search(r'(\{.*\})', line)
    if match:
        try:
            value = json.loads(match.group(1))
            if isinstance(value, dict) and any(key in value for key in ('density','supported','customCaAccepted')):
                rows.append(value)
        except ValueError:
            pass
window = next((row for row in reversed(rows) if 'density' in row), None)
material = next((row for row in reversed(rows) if 'supported' in row), None)
tls = next((row for row in reversed(rows) if 'customCaAccepted' in row), None)
checks = {}
checks['actualWindowReported'] = window is not None
checks['actualImmersiveWindow'] = bool(window and window.get('immersiveLayout') == 'enabled')
checks['transparentSystemBars'] = bool(window and window.get('systemBarPropertiesObserved') and
    all(isinstance(window.get(key),str) and len(window[key])==9 and window[key][1:3]=='00'
        for key in ('statusBarColor','navigationBarColor')))
if args.font_scale is not None:
    scale = window.get('fontScale') if window else None
    checks['requestedFontScaleReported'] = isinstance(scale,(int,float)) and math.isfinite(scale) and abs(scale-args.font_scale)<=.001
if args.require_tls:
    checks['threeIndependentTlsCases'] = bool(tls and tls.get('customCaAccepted') and tls.get('untrustedCaRejected') and
        tls.get('wrongHostnameRejected') and tls.get('untrustedFailureCode')=='TLS_ERROR' and tls.get('wrongHostnameFailureCode')=='TLS_ERROR')
themes = {str(row['appColorMode']): row for row in rows if 'density' in row and 'appColorMode' in row}
if args.themes:
    checks['actualLightAndDarkBarContent'] = bool(themes.get('0',{}).get('statusBarContentColor')=='#FFFFFFFF' and themes.get('1',{}).get('statusBarContentColor')=='#FF000000')
hap = ROOT / 'entry/build/default/outputs/default/entry-default-signed.hap'
result = {'status': 'passed' if all(checks.values()) else 'failed', 'immersionVersion':'edge-to-edge-v1',
          'source':'Official hilog capture began before cold launch of the owned Ability',
          'installedHapSha256':hashlib.sha256(hap.read_bytes()).hexdigest(),
          'checks':checks,'systemBarThemeRecords':themes,'window':window,'material':material,'tls':tls,
          'records':[row for row in (window,material,tls) if row is not None]}
output.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'status':result['status'],'checks':checks,'output':str(output.relative_to(ROOT))}))
raise SystemExit(0 if result['status']=='passed' else 1)
