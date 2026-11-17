#!/usr/bin/env python3
"""Build a production debug candidate without changing preview settings (read-only by default)."""

import argparse
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
from zipfile import BadZipFile, ZipFile


ROOT = Path(__file__).resolve().parents[1]
PRIVATE = ROOT / 'artifacts/private'
RAW = ROOT / 'entry/src/main/resources/rawfile'
MARKER = RAW / 'production-smoke.json'
ISOLATION_NAMES = ('integration.json', 'integration-ca.pem')
HAP = ROOT / 'entry/build/default/outputs/default/entry-default-signed.hap'
READ_ONLY_MODE = 'production-readonly'
WRITE_MODE = 'production-write'
CANDIDATE_LABELS = {READ_ONLY_MODE: 'production-smoke', WRITE_MODE: 'production-write-candidate'}


class BuildError(RuntimeError):
    pass


def existing_file(path):
    if not os.path.lexists(path):
        return False
    if path.is_symlink() or not path.is_file():
        raise BuildError(f'Expected a regular file at {path.name}.')
    return True


@contextmanager
def production_resources(backup, mode):
    if os.path.lexists(MARKER):
        raise BuildError('Production marker already exists. Check the existing build before proceeding.')
    present = [RAW / name for name in ISOLATION_NAMES if existing_file(RAW / name)]
    staged = []
    marker_identity = None
    try:
        with MARKER.open('xb') as marker:
            identity = os.fstat(marker.fileno())
            marker_identity = (identity.st_dev, identity.st_ino)
            marker.write((json.dumps({'mode': mode}, separators=(',', ':')) + '\n').encode('utf-8'))
        for source in present:
            staged_path = backup / source.name
            source.rename(staged_path)
            staged.append((staged_path, source))
        yield
    finally:
        conflicts = []
        if marker_identity is not None:
            try:
                current = MARKER.lstat()
                if (current.st_dev, current.st_ino) != marker_identity:
                    conflicts.append(MARKER.name)
                else:
                    MARKER.unlink()
            except FileNotFoundError:
                # The file is already absent and will not be packaged by the preview build.
                pass
            except OSError:
                conflicts.append(MARKER.name)
        for staged_path, original in reversed(staged):
            try:
                # Restore the exact original file without replacing a concurrent change.
                os.link(staged_path, original, follow_symlinks=False)
                staged_path.unlink()
            except OSError:
                conflicts.append(original.name)
        if conflicts:
            raise BuildError('Resource cleanup needs attention. The original files are retained in the private staging directory.')


def run_hm(arguments, log_path):
    with log_path.open('xb') as log:
        os.fchmod(log.fileno(), 0o600)
        result = subprocess.run([ROOT / 'scripts/hm.sh', *arguments], cwd=ROOT, stdout=log,
                                stderr=subprocess.STDOUT, check=False)
    if result.returncode:
        raise BuildError(f'DevEco command failed. See the private {log_path.name}.')


def verify_package(path, mode):
    if not existing_file(path):
        raise BuildError('Build did not produce a new signed HAP.')
    with ZipFile(path) as archive:
        names = archive.namelist()
        markers = [name for name in names if name.rsplit('/', 1)[-1] == MARKER.name]
        if len(names) != len(set(names)) or markers != ['resources/rawfile/production-smoke.json']:
            raise BuildError('The signed HAP does not contain the expected production marker.')
        if any(name.rsplit('/', 1)[-1] in ISOLATION_NAMES for name in names):
            raise BuildError('The signed HAP contains isolated configuration or a test CA.')
        if json.loads(archive.read(markers[0])) != {'mode': mode}:
            raise BuildError('The signed HAP contains an unexpected production configuration.')
        manifest = json.loads(archive.read('module.json'))
        if (manifest['app']['bundleName'] != 'com.sitkin.starward' or manifest['app']['debug'] is not True or
                manifest['module']['name'] != 'entry'):
            raise BuildError('The signed HAP has an unexpected bundle, module or build mode.')


def digest(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def build_candidate(output, mode):
    backup = output / 'staged-preview'
    backup.mkdir(mode=0o700)
    previous = backup / HAP.name
    moved_hap = False
    started_build = False
    try:
        with production_resources(backup, mode):
            if existing_file(HAP):
                HAP.rename(previous)
                moved_hap = True
            started_build = True
            run_hm(['build'], output / 'build.log')
        verify_package(HAP, mode)
        candidate = output / f'starward-{CANDIDATE_LABELS[mode]}-signed.hap'
        with HAP.open('rb') as source, candidate.open('xb') as archive:
            os.fchmod(archive.fileno(), 0o600)
            shutil.copyfileobj(source, archive)
        sha256 = digest(candidate)
        if digest(HAP) != sha256:
            raise BuildError('The signed HAP changed while being archived.')
    except BaseException:
        if started_build and existing_file(HAP):
            HAP.rename(output / 'unverified-local.hap')
        if moved_hap:
            os.link(previous, HAP, follow_symlinks=False)
            previous.unlink()
        raise
    if moved_hap:
        previous.unlink()
    backup.rmdir()
    return candidate, sha256


def on_terminate(_signal, _frame):
    raise KeyboardInterrupt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true', help='Build a production-write debug HAP.')
    parser.add_argument('--install', action='store_true', help='Install the verified debug HAP through DevEco.')
    args = parser.parse_args()
    mode = WRITE_MODE if args.write else READ_ONLY_MODE
    signal.signal(signal.SIGTERM, on_terminate)
    if os.path.lexists(MARKER):
        print('Production marker already exists. Check the existing build before proceeding.', file=sys.stderr)
        return 1
    output = None
    try:
        PRIVATE.mkdir(mode=0o700, parents=True, exist_ok=True)
        if PRIVATE.resolve() != PRIVATE:
            raise BuildError('The private artifact directory must stay inside this checkout.')
        output = Path(tempfile.mkdtemp(prefix=f'{CANDIDATE_LABELS[mode]}-', dir=PRIVATE))
        candidate, sha256 = build_candidate(output, mode)
        result = {'mode': mode, 'signedHapSha256': sha256, 'archive': candidate.name, 'packageVerified': True,
                  'isolatedResourcesRestored': True, 'deploymentCommandSucceeded': False if args.install else None}
        receipt = output / 'candidate.json'
        receipt.write_text(json.dumps(result, indent=2) + '\n')
        if args.install:
            if digest(HAP) != sha256:
                raise BuildError('The local HAP changed after verification. Build a fresh candidate before installing.')
            run_hm(['run', '--skip-build'], output / 'install.log')
            if digest(HAP) != sha256:
                raise BuildError('DevEco changed the local artifact during deployment.')
            result['deploymentCommandSucceeded'] = True
            receipt.write_text(json.dumps(result, indent=2) + '\n')
        print(json.dumps({'output': str(output.relative_to(ROOT)), **result}, ensure_ascii=False))
        return 0
    except KeyboardInterrupt:
        print('The candidate command was interrupted.', file=sys.stderr)
    except BuildError as error:
        print(str(error), file=sys.stderr)
    except (OSError, ValueError, KeyError, TypeError, BadZipFile):
        print('Could not complete the candidate archive, resource handling or package check.', file=sys.stderr)
    if output is not None:
        print(f'Private build output: {output.relative_to(ROOT)}', file=sys.stderr)
    return 1


if __name__ == '__main__':
    sys.exit(main())
