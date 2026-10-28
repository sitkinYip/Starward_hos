#!/usr/bin/env python3
"""Refresh minimal public replay provenance from validated capture metadata."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile

ROOT=Path(__file__).resolve().parents[1]
GROUPS=('web-isolated-content','web-isolated-forced','web-isolated-waiting','web-isolated-expired','web-isolated-locked','web-isolated-error')
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--groups',choices=GROUPS,nargs='+',default=['web-isolated-content','web-isolated-forced'])
args=parser.parse_args()
for group in args.groups:
    directory=ROOT/'artifacts'/group
    if directory.is_symlink():raise SystemExit('Replay directory symlinks are not supported')
    summary=directory/'capture-summary.json';raw=summary.read_bytes();data=json.loads(raw)
    if data.get('browserUsesRealBackend') is not False or data.get('pageErrors'):
        raise SystemExit('Replay metadata is not a clean intercepted browser capture')
    source=data.get('snapshotInput',{});sha=source.get('sha256','')
    if not re.fullmatch('[0-9a-f]{64}',sha):raise SystemExit('Snapshot SHA is missing')
    path=Path(source.get('file',''));path=path if path.is_absolute() else ROOT/path
    resolved=path.resolve()
    if not resolved.is_relative_to((ROOT/'artifacts/private/https-isolation').resolve()) or path.is_symlink() or hashlib.sha256(path.read_bytes()).hexdigest()!=sha:
        raise SystemExit('Frozen replay snapshot no longer matches its metadata')
    archive=ROOT/'artifacts/private/web-visual-inputs'/(sha+'.json')
    if archive.is_symlink() or hashlib.sha256(archive.read_bytes()).hexdigest()!=sha:
        raise SystemExit('Immutable snapshot archive no longer matches')
    counts=data.get('responseSourceCounts',{})
    actual={'actual_snapshot_player':'player','actual_snapshot_assignments':'assignments','actual_snapshot_assignment':'assignment'}
    value={'snapshotSha256':sha,'captureSummarySha256':hashlib.sha256(raw).hexdigest(),
           'snapshotArchive':'artifacts/private/web-visual-inputs/'+sha+'.json',
           'sourceResolution':'Same capture-time snapshot bytes; originalFile in capture-summary records any immutable-copy relocation.',
           'responseSourceCounts':counts,'browserUsesRealBackend':False,'requestedStates':data.get('requestedStates',[]),
           'consumedActualSnapshotDTOs':[name for key,name in actual.items() if counts.get(key,0)>0],
           'renderDrivers':'Authentication and any password reply are synthetic browser rendering drivers; no browser backend write occurs.',
           'auxiliaryEmptyResponsesObserved':counts.get('fixed_empty_auxiliary_outside_slice',0),
           'auxiliaryAPIs':'Any fixed empty notification/reward response is outside this slice and is not actual snapshot data or migrated capability.',
           'scope':'Browser content reference only. Native HTTPS and final HAP/window verification have separate evidence.'}
    with tempfile.NamedTemporaryFile(mode='w',encoding='utf-8',dir=directory,prefix='.provenance-',delete=False) as f:
        json.dump(value,f,ensure_ascii=False,indent=2);f.write('\n');temporary=Path(f.name)
    os.replace(temporary,directory/'provenance.json')
    print(json.dumps({'group':group,'snapshotSha256':sha,'captureSummarySha256':value['captureSummarySha256'],'browserUsesRealBackend':False}))
