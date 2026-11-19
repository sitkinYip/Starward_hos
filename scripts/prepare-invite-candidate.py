#!/usr/bin/env python3
"""Freeze current non-ignored source in a private unsigned release project.

No build, signing, upload, installation, or production write is performed.
Ignored local credentials, test endpoints, CAs, and signing config are excluded.
"""

import argparse
from hashlib import sha256
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]


def git(*arguments):
    return subprocess.run(['git', *arguments], cwd=ROOT, check=True, capture_output=True).stdout


def prepare(version_name, version_code):
    if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', version_name) or version_code <= 0:
        raise ValueError('Use a three-part numeric version and a positive version code.')
    source_files = sorted(set(os.fsdecode(item) for item in
                              git('ls-files', '--cached', '--others', '--exclude-standard', '-z').split(b'\0')
                              if item))
    inputs = {}
    for name in source_files:
        relative = Path(name)
        if relative.is_absolute() or '..' in relative.parts:
            raise ValueError('Git returned an unsafe source path.')
        source = ROOT / relative
        if source.is_symlink():
            raise ValueError('Source snapshot does not accept symbolic links.')
        if not source.exists():
            continue  # A tracked deletion is also a deletion in the snapshot.
        if not source.is_file():
            raise ValueError('Source snapshot only accepts regular files.')
        if source.suffix.lower() in ('.p12', '.p7b', '.cer', '.csr', '.key', '.jks', '.pem'):
            raise ValueError('Signing or TLS material must not enter a release source snapshot.')
        if source.name == 'build-profile.json5' and relative.parent == Path('.'):
            raise ValueError('Local signing configuration must remain ignored.')
        inputs[name] = sha256(source.read_bytes()).hexdigest()
    private = ROOT / 'artifacts/private'
    if private.is_symlink() or not private.is_dir() or private.resolve() != private:
        raise ValueError('The existing private artifact directory must be a real directory.')
    if private.stat().st_mode & 0o077:
        raise ValueError('Private artifact parent must not be accessible to other users.')
    stage = Path(tempfile.mkdtemp(prefix=f'invite-candidate-{version_name}-', dir=private))
    project = stage / 'project'
    project.mkdir(mode=0o700)
    for name, expected in inputs.items():
        source = ROOT / name
        destination = project / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination, follow_symlinks=False)
        if destination.is_symlink() or sha256(destination.read_bytes()).hexdigest() != expected:
            raise ValueError('Source changed during the snapshot; discard this stage and prepare again.')
    # Check after copying as well: a parallel source edit must not silently become
    # a release payload different from the recorded snapshot.
    for name, expected in inputs.items():
        if sha256((ROOT / name).read_bytes()).hexdigest() != expected:
            raise ValueError('Source changed during the snapshot; discard this stage and prepare again.')
    if source_files != sorted(set(os.fsdecode(item) for item in
                                  git('ls-files', '--cached', '--others', '--exclude-standard', '-z').split(b'\0')
                                  if item)):
        raise ValueError('Source file list changed during the snapshot; prepare again after edits finish.')
    manifest_path = project / 'AppScope/app.json5'
    manifest = json.loads(manifest_path.read_bytes())
    if manifest['app']['bundleName'] != 'com.sitkin.starward':
        raise ValueError('Source application bundle does not match the registered app.')
    manifest['app']['versionName'] = version_name
    manifest['app']['versionCode'] = version_code
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    shutil.copy2(project / 'build-profile.example.json5', project / 'build-profile.json5')
    raw = project / 'entry/src/main/resources/rawfile'
    raw.mkdir(parents=True, exist_ok=True)
    for name in ('integration.json', 'integration-ca.pem', 'production-smoke.json'):
        if (raw / name).exists():
            raise ValueError('Source snapshot unexpectedly includes an environment override.')
    (raw / 'production-smoke.json').write_text('{"mode":"production-invite-push"}\n')
    receipt = {'sourceHead': git('rev-parse', 'HEAD').decode().strip(),
               'sourceDirty': bool(git('status', '--porcelain')), 'sourceSHA256': inputs,
               'bundleName': 'com.sitkin.starward', 'versionName': version_name,
               'versionCode': version_code, 'productionMode': 'production-invite-push',
               'signingMaterialCopied': False, 'buildExecuted': False,
               'signed': False, 'uploaded': False, 'invitationSubmitted': False}
    (stage / 'source-snapshot.json').write_text(json.dumps(receipt, indent=2) + '\n')
    return stage


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--version-name', required=True)
    parser.add_argument('--version-code', required=True, type=int)
    args = parser.parse_args()
    try:
        stage = prepare(args.version_name, args.version_code)
        print(json.dumps({'privateStage': str(stage), 'project': str(stage / 'project'),
                          'versionName': args.version_name, 'versionCode': args.version_code,
                          'buildExecuted': False, 'signingMaterialCopied': False}))
        return 0
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError):
        parser.exit(1, 'Could not freeze release source. Check for concurrent edits or unexpected local material.\n')


if __name__ == '__main__':
    raise SystemExit(main())
