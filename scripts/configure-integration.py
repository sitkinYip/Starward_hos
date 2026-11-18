#!/usr/bin/env python3
"""Select a packaged isolated endpoint; trust additions affect this App only."""
import argparse
import json
from pathlib import Path
import shutil
from urllib.parse import urlparse

parser = argparse.ArgumentParser()
parser.add_argument('--endpoint')
parser.add_argument('--ca', type=Path)
parser.add_argument('--timeout-ms', type=int, default=15000)
parser.add_argument('--probe-tls', action='store_true')
parser.add_argument('--push-test', action='store_true',
                    help='Enable Push and the hosted privacy gate in a dedicated isolated build.')
parser.add_argument('--font-scale', type=float, default=1)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
target = root / 'entry/src/main/resources/rawfile/integration.json'
ca_target = target.parent / 'integration-ca.pem'
if not args.endpoint:
    if args.push_test:
        parser.error('--push-test requires an isolated HTTPS endpoint.')
    target.unlink(missing_ok=True)
    ca_target.unlink(missing_ok=True)
    print('Prepared default in-memory demo build configuration.')
    raise SystemExit(0)
parsed = urlparse(args.endpoint)
cloud = parsed.hostname and parsed.hostname.endswith('.trycloudflare.com') and not parsed.port
loopback = parsed.hostname == '127.0.0.1' and parsed.port == 18443
if parsed.scheme != 'https' or not (cloud or loopback) or parsed.username or parsed.password or parsed.path or parsed.query or parsed.fragment:
    parser.error('Expected a temporary Cloudflare HTTPS origin or the isolated https://127.0.0.1:18443 origin.')
if not 1 <= args.font_scale <= 1.6:
    parser.error('Test font scale must be between 1 and 1.6.')
if not 1000 <= args.timeout_ms <= 15000:
    parser.error('Test timeout must be between 1000 and 15000 ms.')
if loopback:
    if not args.ca:
        parser.error('Loopback HTTPS requires the explicit isolated certificate authority.')
    pem = args.ca.read_text()
    if '-----BEGIN CERTIFICATE-----' not in pem or 'PRIVATE KEY' in pem:
        parser.error('Only the public CA certificate may be packaged.')
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(args.ca, ca_target)
else:
    ca_target.unlink(missing_ok=True)
config = {'isolated': True, 'endpoint': args.endpoint, 'timeoutMs': args.timeout_ms,
          'probeTls': args.probe_tls, 'fontScale': args.font_scale}
if args.push_test:
    config.update(hostedPrivacy=True, pushEnabled=True)
target.write_text(json.dumps(config) + '\n')
print('Prepared isolated HTTPS build configuration; no credentials embedded and certificate validation stays enabled.')
