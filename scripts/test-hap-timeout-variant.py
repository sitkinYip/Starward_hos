#!/usr/bin/env python3
"""Offline tooling checks against original signed HAP bytes; no device/service.

All deliberate changes are dictionaries of uncompressed bytes in this process.
Neither signed input HAP is rewritten, re-signed, installed, or executed.
"""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import zipfile

from hap_timeout_variant import CONFIG_ENTRY, SYMBOL_ENTRY, VariantMismatch, validate_timeout_entries

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/validation/profile'
SOURCE_URL = ('https://github.com/openharmony/arkcompiler_ets_frontend/blob/'
              '3271e689443900dbce3ad766c881f397a38e2c76/es2panda/util/symbolTable.cpp#L72')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def entries(path):
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)) or any(i.file_size > 30 * 1024 * 1024 for i in archive.infolist()):
            raise RuntimeError('Original HAP entry structure is invalid')
        return {n: archive.read(n) for n in names if not n.endswith('/')}


def replace(data, name, value):
    return {**data, name: value}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base-manifest', type=Path, default=OUT / 'base-hap.json')
    parser.add_argument('--variant-hap', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=OUT / 'hap-timeout-variant-host.json')
    args = parser.parse_args()
    manifest = args.base_manifest.resolve()
    variant_path = args.variant_hap.resolve()
    output = args.output.absolute()
    if (not manifest.is_relative_to(OUT) or not variant_path.is_relative_to(ROOT / 'artifacts/private') or
            not output.resolve().is_relative_to(OUT) or output.exists() or output.is_symlink()):
        raise RuntimeError('Use original project evidence paths and a new profile report')
    base_meta = json.loads(manifest.read_text())
    base_path = (ROOT / base_meta['privateArchive']).resolve()
    if not base_path.is_relative_to(ROOT / 'artifacts/private') or sha(base_path) != base_meta['hapSha256']:
        raise RuntimeError('Original frozen base archive does not match its manifest')
    base, variant = entries(base_path), entries(variant_path)
    comparison = validate_timeout_entries(base, variant)
    checks = []

    def require(label, condition):
        checks.append({'check': label, 'passed': bool(condition)})

    def rejected(label, candidate_base, candidate_variant):
        try:
            validate_timeout_entries(candidate_base, candidate_variant)
        except VariantMismatch:
            require(label, True)
        else:
            require(label, False)

    require('actual original signed-HAP pair accepts only declared configuration and mapping-order changes', True)
    require('all frozen ArkTS source files still match original manifest',
            all(sha(ROOT / row['file']) == row['sha256'] for row in base_meta['sourceFiles']))
    require('all runtime ABC bytes are exactly identical and match the frozen base manifest',
            {row['file']: row['sha256'] for row in base_meta['arktsBytecode']} ==
            {name: hashlib.sha256(data).hexdigest() for name, data in base.items() if name.endswith('.abc')} and
            all(variant[name] == data for name, data in base.items() if name.endswith('.abc')))
    require('original CA bytes remain exactly identical',
            base['resources/rawfile/integration-ca.pem'] == variant['resources/rawfile/integration-ca.pem'])
    require('real mapping comparison preserves every complete record and unique symbol key',
            comparison['symbolMap']['completeRecordMultisetIdentical'] and comparison['symbolMap']['uniqueRecordKeys'])
    # A future deterministic compiler may leave the map byte-identical.
    same_map = replace(variant, SYMBOL_ENTRY, base[SYMBOL_ENTRY])
    require('byte-identical symbol map remains accepted',
            validate_timeout_entries(base, same_map)['symbolMap']['bytesIdentical'])
    lines = base[SYMBOL_ENTRY].split(b'\n')[:-1]
    reversed_map = b'\n'.join(reversed(lines)) + b'\n'
    require('arbitrary order of complete unique original records remains accepted',
            validate_timeout_entries(base, replace(variant, SYMBOL_ENTRY, reversed_map))['symbolMap']['completeRecordMultisetIdentical'])
    changed_line = list(lines)
    module_index = next(i for i, line in enumerate(changed_line) if b'|' not in line)
    first = changed_line[module_index].split(b';')
    first[1] = str(int(first[1]) ^ 1).encode()
    changed_line[module_index] = b';'.join(first)
    rejected('one valid-format symbol hash change is rejected', base,
             replace(variant, SYMBOL_ENTRY, b'\n'.join(changed_line) + b'\n'))
    rejected('one removed symbol record is rejected', base,
             replace(variant, SYMBOL_ENTRY, b'\n'.join(lines[1:]) + b'\n'))
    rejected('one duplicate symbol record/key is rejected', base,
             replace(variant, SYMBOL_ENTRY, variant[SYMBOL_ENTRY] + lines[0] + b'\n'))
    malformed = replace(variant, SYMBOL_ENTRY, variant[SYMBOL_ENTRY] + b'not-a-record\n')
    rejected('unknown record grammar is rejected', base, malformed)
    rejected('even matching malformed maps cannot bypass format validation',
             replace(base, SYMBOL_ENTRY, malformed[SYMBOL_ENTRY]), malformed)
    rejected('blank map record is rejected', base,
             replace(variant, SYMBOL_ENTRY, variant[SYMBOL_ENTRY] + b'\n'))
    rejected('map CRLF normalization is not accepted as record reordering', base,
             replace(variant, SYMBOL_ENTRY, variant[SYMBOL_ENTRY].replace(b'\n', b'\r\n')))
    abc = next(name for name in base if name.endswith('.abc'))
    rejected('one runtime bytecode byte change is rejected', base, replace(variant, abc, variant[abc] + b'!'))
    ca = 'resources/rawfile/integration-ca.pem'
    rejected('one authority byte change is rejected', base, replace(variant, ca, variant[ca] + b'!'))
    other = next(name for name in base if name not in (CONFIG_ENTRY, SYMBOL_ENTRY, abc, ca))
    rejected('one unrelated packaged-entry byte change is rejected', base, replace(variant, other, variant[other] + b'!'))
    rejected('an extra packaged entry is rejected', base, replace(variant, 'unexpected.txt', b'extra'))
    rejected('a removed packaged entry is rejected', base, {n: v for n, v in variant.items() if n != other})
    cfg = json.loads(variant[CONFIG_ENTRY])
    rejected('another timeout is rejected', base, replace(variant, CONFIG_ENTRY, json.dumps({**cfg, 'timeoutMs': 30000}).encode()))
    rejected('another configuration field is rejected', base, replace(variant, CONFIG_ENTRY, json.dumps({**cfg, 'extra': True}).encode()))
    rejected('duplicate JSON configuration keys are rejected', base, replace(variant, CONFIG_ENTRY,
             variant[CONFIG_ENTRY].rstrip()[:-1] + b',"timeoutMs":15000}'))
    rejected('unchanged base configuration is rejected as a timeout variant', base, base)
    report = {'status': 'passed' if all(row['passed'] for row in checks) else 'failed',
        'scope': 'Offline HAP provenance tooling only; no native, service, signature-validity or business acceptance',
        'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'baseHapSha256': sha(base_path), 'variantHapSha256': sha(variant_path),
        'baseManifestSha256': sha(manifest), 'helperSha256': sha(Path(__file__).with_name('hap_timeout_variant.py')),
        'testDriverSha256': sha(Path(__file__)), 'comparison': comparison,
        'formatEvidence': {'officialSource': SOURCE_URL,
            'fixedSdkObservedFormat': '34 module and1139 three-field function records, all with unique self-contained keys',
            'scopeLimit': 'OpenHarmony reader explains record-key semantics; it is not asserted to be the exact commercial SDK source revision'},
        'checkCount': len(checks), 'checks': checks, 'originalSignedHapsRewritten': False,
        'deviceOrServiceCommandsExecuted': False}
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open('x') as stream:
        stream.write(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'status': report['status'], 'checks': len(checks), 'report': str(output.relative_to(ROOT))}))
    return 0 if report['status'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())
