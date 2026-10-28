#!/usr/bin/env python3
"""Bounded HTTP isolation checks for the loopback-only visual report viewer."""
import argparse
import datetime
import hashlib
import http.client
import json
import importlib.util
import os
from pathlib import Path
import tempfile
import threading

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--port',type=int,default=5179)
args=parser.parse_args()
if not 1<=args.port<=65535:parser.error('Expected a running loopback viewer port')
checks=[]
manifest_path=ROOT/'artifacts/visual-comparison/pairs.json'
manifest_sha256=hashlib.sha256(manifest_path.read_bytes()).hexdigest()

def get(path,host=None,port=None):
    port = port or args.port
    connection=http.client.HTTPConnection('127.0.0.1',port,timeout=5)
    try:
        connection.request('GET',path,headers={'Host':host or f'127.0.0.1:{port}'})
        response=connection.getresponse()
        return response.status,dict(response.getheaders()),response.read()
    finally:connection.close()

def check(name,path,status,host=None,validate=None,port=None):
    observed,headers,body=get(path,host,port)
    if observed!=status or (validate and not validate(headers,body)):
        raise RuntimeError('Visual report HTTP isolation check failed: '+name)
    checks.append({'name':name,'status':observed,'target':'isolated same-handler fixture' if port else 'live viewer'})

check('public report','/visual-comparison/index.html',200,validate=lambda h,b:b'arkui-system-v1' in b and "connect-src 'none'" in h.get('Content-Security-Policy',''))
check('public manifest','/visual-comparison/pairs.json',200,validate=lambda h,b:json.loads(b).get('visualCriteria')=='arkui-system-v1' and hashlib.sha256(b).hexdigest()==manifest_sha256)
check('verified auth PNG','/native-system-visual/login-dark.png',200,validate=lambda h,b:b.startswith(b'\x89PNG\r\n\x1a\n') and h.get('Content-Type')=='image/png')
check('historical reference','/visual-comparison/legacy-index.html',200)
check('private blocked','/private/https-isolation/state.json',404)
check('raw UI input tree blocked','/native-system-visual/ui-login-dark.json',404)
check('unknown report blocked','/visual-comparison/unknown.html',404)
check('directory listing blocked','/native-system-visual/',404)
check('encoded traversal blocked','/visual-comparison/%2e%2e/private',404)
check('double encoded traversal blocked','/visual-comparison/%252e%252e',404)
check('backslash path blocked','/visual-comparison/%5cprivate',404)
check('foreign Host blocked','/visual-comparison/index.html',404,host='example.invalid')
file_link=ROOT/'artifacts/native-system-visual/qa-file-symlink.png'
if file_link.exists() or file_link.is_symlink():raise RuntimeError('Own file-link fixture path is occupied')
try:
    file_link.symlink_to(ROOT/'artifacts/private/https-isolation/state.json')
    check('file symlink blocked','/native-system-visual/qa-file-symlink.png',404)
finally:file_link.unlink(missing_ok=True)
# Probe a directory symlink in a private fixture tree through the identical
# handler. All real report groups may already exist; do not rename or replace
# final capture directories merely to test this edge case.
spec=importlib.util.spec_from_file_location('starward_visual_server',ROOT/'scripts/serve-visual-report.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
with tempfile.TemporaryDirectory(prefix='viewer-isolation-',dir=ROOT/'artifacts/private') as private:
    private=Path(private);fixture=private/'public';fixture.mkdir()
    outside=private/'private';outside.mkdir()
    (outside/'capture-summary.json').write_text('{"privateTestFixture":true}\n')
    (fixture/'web-isolated-error').symlink_to(outside,target_is_directory=True)
    server=module.ReportServer(0)
    os.close(server.artifacts_fd)
    server.artifacts_fd=os.open(fixture,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
    thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
    try:
        check('directory symlink blocked','/web-isolated-error/capture-summary.json',404,port=server.server_address[1])
    finally:
        server.shutdown();thread.join(timeout=5);server.server_close()
result={'status':'passed','count':len(checks),'checks':checks,'viewerBind':'127.0.0.1','privateFilesServed':False,
        'pairManifest':{'file':str(manifest_path.relative_to(ROOT)),'sha256':manifest_sha256},
        'checkedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'scope':'13 live viewer requests and one isolated identical-handler directory-symlink probe; not native device, screenshot comparison or product acceptance.'}
(ROOT/'artifacts/validation/visual-report-server-http-checks.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'status':result['status'],'count':result['count'],'scope':result['scope']}))
