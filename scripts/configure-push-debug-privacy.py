#!/usr/bin/env python3
"""Enable Huawei's supported privacy simulation in a disposable Push build copy."""
import argparse
import json
from pathlib import Path
from urllib.parse import urlsplit


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('isolated_project', type=Path)
parser.add_argument('approved_policy_url')
args = parser.parse_args()

workspace = Path(__file__).resolve().parents[1]
private = (workspace / 'artifacts/private').resolve()
project = args.isolated_project.resolve()
if private not in project.parents or (project / '.git').exists():
    parser.error('Use a disposable project copy inside this workspace’s artifacts/private directory.')

url = urlsplit(args.approved_policy_url)
if (url.scheme != 'https' or not url.hostname or url.username or url.password or url.fragment or
        any(char.isspace() or ord(char) < 32 for char in args.approved_policy_url)):
    parser.error('Use the approved public HTTPS privacy policy URL.')

source = project / 'entry/src/main'
integration = (source / 'resources/rawfile/integration.json').resolve()
manifest = (source / 'module.json5').resolve()
if project not in integration.parents or project not in manifest.parents:
    parser.error('The test configuration and manifest must both live inside the disposable copy.')

try:
    config = json.loads(integration.read_text())
    module_file = json.loads(manifest.read_text())
except (OSError, ValueError):
    parser.error('Prepare the isolated Push integration configuration before adding debug privacy metadata.')
if not all(config.get(key) is True for key in ('isolated', 'pushEnabled', 'hostedPrivacy')):
    parser.error('Debug privacy metadata requires an explicitly configured isolated Push test build.')

module = module_file['module']
metadata = module.setdefault('metadata', [])
debug_fields = {
    'appgallery_privacy_hosted': '1',
    'appgallery_privacy_link_privacy_statement': args.approved_policy_url,
}
# An optional user agreement is a separate document; don't replace it with the policy URL.
module['metadata'] = [item for item in metadata if item.get('name') not in debug_fields]
module['metadata'].extend({'name': name, 'value': value} for name, value in debug_fields.items())
manifest.write_text(json.dumps(module_file, ensure_ascii=False, indent=2) + '\n')
print('Configured official privacy simulation in the isolated copy; build it in debug mode.')
