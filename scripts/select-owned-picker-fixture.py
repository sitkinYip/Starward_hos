#!/usr/bin/env python3
"""Select one SHA-verified owned fixture visible in the actual system Photo Picker.

Uses its observed CachedImage asset identity, never thumbnail order or host upload.
Does not scroll, inspect image pixels, or select any other library asset.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PRIVATE = ROOT / 'artifacts/private'
OUT = ROOT / 'artifacts/validation/profile/picker-selections.json'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(args):
    result = subprocess.run(args, cwd=ROOT, capture_output=True, text=True, timeout=30)
    if result.returncode or '[Fail]' in result.stdout:
        raise RuntimeError('Official Picker command failed; details omitted')
    return result.stdout


def nodes(value):
    if isinstance(value, list):
        for item in value:
            yield from nodes(item)
    elif isinstance(value, dict):
        if isinstance(value.get('attributes'), dict):
            yield value['attributes']
        for item in value.get('children', []):
            yield from nodes(item)


def bounds(value):
    match = re.fullmatch(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', value or '')
    if not match:
        raise RuntimeError('Actual Picker bounds are unavailable')
    return [int(item) for item in match.groups()]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--receipt', required=True, type=Path)
    parser.add_argument('--fixture', required=True, type=Path)
    args = parser.parse_args()
    receipt_path, fixture = args.receipt.resolve(), args.fixture.resolve()
    if not receipt_path.is_relative_to(PRIVATE.resolve()) or not fixture.is_relative_to(ROOT):
        raise RuntimeError('Only this project private import receipt and fixture are supported')
    receipt = json.loads(receipt_path.read_text())
    digest = sha(fixture)
    uri = receipt.get('mediaUri')
    if (receipt.get('fixtureSha256') != digest or receipt.get('readbackSha256') != digest or
            not isinstance(uri, str) or not uri.startswith('file://media/Photo/') or '?' in uri):
        raise RuntimeError('Exact owned fixture import and readback SHA are required')
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    directory = PRIVATE / 'profile-picker' / ('selection-' + stamp)
    directory.mkdir(parents=True, mode=0o700)
    target = directory / 'raw.json'
    remote = '/data/local/tmp/starward-owned-picker-' + stamp + '.json'
    try:
        run(['hdc', 'shell', 'uitest', 'dumpLayout', '-b', 'com.sitkin.starward', '-p', remote])
        run(['hdc', 'file', 'recv', remote, str(target)])
        target.chmod(0o600)
    finally:
        run(['hdc', 'shell', 'rm', remote])
    rows = list(nodes(json.loads(target.read_text())))
    grids = [row for row in rows if row.get('id') == 'ThirdSelectAlbum_Gird' and row.get('visible') == 'true']
    if len(grids) != 1:
        raise RuntimeError('The actually observed system Photo Picker grid is not foreground')
    identity = re.compile(r'^ThirdSelectAlbumGridBase_GridItem' + re.escape(uri) + r'(?:\?|$)')
    matches = [row for row in rows if row.get('type') == 'CachedImage' and identity.search(row.get('id', ''))]
    if len(matches) != 1 or any(matches[0].get(key) != 'true' for key in ('visible', 'enabled')):
        raise RuntimeError('The exact owned image is not uniquely visible and enabled; no other asset selected')
    rect, grid = bounds(matches[0].get('bounds')), bounds(grids[0].get('bounds'))
    if (rect[2]-rect[0] < 100 or abs((rect[2]-rect[0])-(rect[3]-rect[1])) > 3 or
            not (grid[0] <= rect[0] < rect[2] <= grid[2] and grid[1] <= rect[1] < rect[3] <= grid[3])):
        raise RuntimeError('The owned image is clipped; no other asset selected')
    point = [(rect[0]+rect[2])//2, (rect[1]+rect[3])//2]
    private = {'fixtureSha256': digest, 'importReceiptSha256': sha(receipt_path),
               'mediaUri': uri, 'rawSha256': sha(target), 'bounds': rect, 'clickPx': point}
    private_path = directory / 'selection.json'
    descriptor = os.open(private_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, 'w') as output:
        json.dump(private, output, indent=2)
    run(['hdc', 'shell', 'uitest', 'uiInput', 'click', *map(str, point)])
    public = json.loads(OUT.read_text()) if OUT.exists() else {'scope': 'Exact owned system Picker selection only; crop/upload are separate', 'selections': []}
    public['selections'].append({'status': 'selection_sent', 'at': stamp, 'fixtureSha256': digest,
                                'rawSha256': sha(target), 'importReceiptSha256': sha(receipt_path),
                                'clickPx': point, 'privateEvidence': str(directory.relative_to(ROOT)),
                                'driverSha256': sha(Path(__file__))})
    OUT.write_text(json.dumps(public, indent=2) + '\n')
    print(json.dumps({'status': 'selection_sent', 'fixtureSha256': digest,
                      'evidence': str(OUT.relative_to(ROOT)), 'acceptance': 'Selection command only; verify actual crop next'}))


if __name__ == '__main__':
    try:
        main()
    except Exception:
        print(json.dumps({'status': 'not_selected', 'error': 'Owned Picker identity/command check failed; no fallback selection attempted'}))
        raise SystemExit(1)
