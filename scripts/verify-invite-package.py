#!/usr/bin/env python3
"""Verify an invitation release against an existing distribution identity.

This tool does not sign, upload, install, or read private signing material.
Use a verified prior signed .app as the identity baseline.
"""

import argparse
from hashlib import sha256
from io import BytesIO
import json
from pathlib import Path, PurePosixPath
import subprocess
import tempfile
import time
from zipfile import BadZipFile, ZipFile


BUNDLE = 'com.sitkin.starward'
MODE = 'production-invite-push'
CAPABILITY = 'com.huawei.service.push.base_service'
SDK = Path('/Applications/DevEco-Studio.app/Contents')


class VerificationError(RuntimeError):
    pass


def require(condition, message):
    if not condition:
        raise VerificationError(message)


def strict_json(data):
    def unique_object(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, 'JSON contains a duplicate field.')
            result[key] = value
        return result

    def reject_constant(value):
        raise VerificationError('JSON contains a non-finite number.')

    return json.loads(data, object_pairs_hook=unique_object, parse_constant=reject_constant)


def entries(archive):
    names = archive.namelist()
    require(len(names) == len(set(names)), 'Archive has duplicate entries.')
    for item in archive.infolist():
        name = PurePosixPath(item.filename)
        require(not name.is_absolute() and '..' not in name.parts and '\\' not in item.filename,
                'Archive has an unsafe entry path.')
        require((item.external_attr >> 16) & 0o170000 != 0o120000, 'Archive has a symbolic link.')
    return names


def inspect_app(path, version_name, version_code):
    """Inspect all packaged HAP files; this does not assert a valid signature."""
    with ZipFile(path) as app:
        names = entries(app)
        require([name for name in names if name.endswith('.hap')] == ['entry-default.hap'],
                'App Pack must contain exactly the expected entry HAP.')
        hap_bytes = app.read('entry-default.hap')
    with ZipFile(BytesIO(hap_bytes)) as hap:
        names = entries(hap)
        module = strict_json(hap.read('module.json'))
        manifest = module['app']
        require(manifest['bundleName'] == BUNDLE, 'Unexpected application bundle.')
        require(manifest['versionName'] == version_name and manifest['versionCode'] == version_code,
                'Packaged version differs from the requested release.')
        require(manifest['debug'] is False and module['module']['name'] == 'entry',
                'Package must be a release entry module.')
        require(strict_json(hap.read('resources/rawfile/production-smoke.json')) == {'mode': MODE},
                'Package does not select production Push.')
        require(not any(PurePosixPath(name).name in ('integration.json', 'integration-ca.pem')
                        for name in names), 'Isolated HTTPS configuration is packaged.')
        require(not any(name.endswith(('.pem', '.p7b', '.p12', '.jks', '.key', '.log', '.ets', '.ts'))
                        for name in names), 'Package contains signing material, source, or debug artifacts.')
        actions = {action for ability in module['module']['abilities'] if ability['name'] == 'EntryAbility'
                   for skill in ability.get('skills', []) for action in skill.get('actions', [])}
        require({'action.ohos.push.listener', BUNDLE + '.action.PUSH_OPEN'} <= actions,
                'Push delivery or click action is missing.')
        require(not any(item.get('name') in ('appgallery_privacy_hosted',
                                            'appgallery_privacy_link_privacy_statement')
                        for item in module['module'].get('metadata', [])),
                'Sideload privacy debug metadata is packaged.')
        require(b'https://api.sitkin.top' in hap.read('ets/modules.abc'),
                'Production HTTPS endpoint is absent from compiled ArkTS.')
        # Signing blocks live outside ZIP entry content. Comparing every HAP
        # entry detects a resource or manifest replacement as well as code drift.
        contents = {name: sha256(hap.read(name)).hexdigest() for name in names if not name.endswith('/')}
        return {'entries': contents, 'compiledArkTSPayloadSHA256': contents['ets/modules.abc'],
                'module': module,
                'packInfo': strict_json(hap.read('pack.info')) if 'pack.info' in names else None}


def sdk_verify(arguments):
    command = [SDK / 'jbr/Contents/Home/bin/java', '-jar',
               SDK / 'sdk/default/openharmony/toolchains/lib/hap-sign-tool.jar', *arguments]
    result = subprocess.run(command, capture_output=True, check=False)
    require(result.returncode == 0, 'DevEco SDK signature verification failed; private output omitted.')


def verified_profile(path):
    with tempfile.TemporaryDirectory(prefix='starward-invite-verify-') as folder:
        folder = Path(folder)
        profile = folder / 'profile.p7b'
        result_file = folder / 'profile.json'
        sdk_verify(['verify-app', '-inFile', path, '-outProfile', profile,
                    '-outCertChain', folder / 'chain.cer'])
        sdk_verify(['verify-profile', '-inFile', profile, '-outFile', result_file])
        result = strict_json(result_file.read_bytes())
        require(str(result.get('verifiedPassed')).lower() == 'true', 'Profile signature was not verified.')
        content = result['content']
        return strict_json(content) if isinstance(content, str) else content


def compare_identity(current, baseline):
    require(current['type'] == 'release' and baseline['type'] == 'release',
            'Identity comparison requires release Profiles.')
    expected = baseline['bundle-info']
    actual = current['bundle-info']
    require(expected['bundle-name'] == BUNDLE and actual['bundle-name'] == BUNDLE,
            'Distribution bundle differs from the original application.')
    require(bool(actual['app-identifier']) and actual['app-identifier'] == expected['app-identifier'],
            'Application identifier differs from the existing distribution.')
    require(bool(actual['distribution-certificate']) and
            actual['distribution-certificate'] == expected['distribution-certificate'],
            'Distribution certificate differs from the existing distribution.')
    require(CAPABILITY in current.get('app-services-capabilities', []), 'Release Profile lacks Push capability.')
    validity = current['validity']
    require(validity['not-before'] <= int(time.time()) < validity['not-after'],
            'Release Profile is not currently valid.')
    # Reusing a valid Profile is supported. A new UUID is not a release requirement.


def compare_payload(before, after, cloud_build_version=None):
    if before['entries'] == after['entries']:
        return []
    # DevEco's AGC upload adds the same cloud build number to these two
    # manifests and serializes them again. Only accept an explicitly observed
    # number, added to previously absent fields; every other JSON value and
    # every other resource/code byte must remain identical.
    require(isinstance(cloud_build_version, str) and cloud_build_version.isdecimal()
            and 0 < len(cloud_build_version) <= 20,
            'Signing changed packaged HAP content.')
    left, right = dict(before['entries']), dict(after['entries'])
    for key, field in [('module', ('app', 'buildVersion')),
                       ('packInfo', ('summary', 'app', 'version', 'build'))]:
        original = json.loads(json.dumps(before[key]))
        current = json.loads(json.dumps(after[key]))
        require(isinstance(original, dict) and isinstance(current, dict),
                'Cloud build metadata lacks a manifest.')
        a, b = original, current
        for part in field[:-1]:
            require(isinstance(a.get(part), dict) and isinstance(b.get(part), dict),
                    'Cloud build metadata has an unexpected structure.')
            a, b = a[part], b[part]
        require(field[-1] not in a and b.get(field[-1]) == cloud_build_version,
                'Cloud build number differs from the observed upload.')
        del b[field[-1]]
        require(json.dumps(original, sort_keys=True, allow_nan=False) ==
                json.dumps(current, sort_keys=True, allow_nan=False),
                'Signing changed other manifest content.')
        filename = 'module.json' if key == 'module' else 'pack.info'
        left.pop(filename)
        right.pop(filename)
    require(left == right, 'Signing changed packaged HAP content.')
    return ['module.json:app.buildVersion', 'pack.info:summary.app.version.build']


def verify(unsigned, signed, baseline, version_name, version_code, cloud_build_version=None):
    before = inspect_app(unsigned, version_name, version_code)
    after = inspect_app(signed, version_name, version_code)
    changes = compare_payload(before, after, cloud_build_version)
    compare_identity(verified_profile(signed), verified_profile(baseline))
    return {'bundleName': BUNDLE, 'versionName': version_name, 'versionCode': version_code,
            'productionMode': MODE, 'signedAppSHA256': sha256(signed.read_bytes()).hexdigest(),
            'unsignedAppSHA256': sha256(unsigned.read_bytes()).hexdigest(),
            'compiledArkTSPayloadSHA256': after['compiledArkTSPayloadSHA256'],
            'allHAPEntriesMatchUnsigned': before['entries'] == after['entries'],
            'cloudBuildNumber': cloud_build_version if changes else None,
            'verifiedCloudMetadataAdditions': changes,
            'allOtherHAPContentMatchesUnsigned': True, 'sdkOuterAppSignatureVerified': True,
            'sdkEmbeddedProfileVerified': True, 'sameDistributionIdentity': True,
            'releaseProfileCurrentlyValid': True, 'releaseProfilePushCapability': True,
            'isolatedResourcesPackaged': False, 'debugPrivacyMetadataPackaged': False,
            'uploadVerified': False, 'invitationSubmittedByThisTool': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--unsigned-app', required=True, type=Path)
    parser.add_argument('--signed-app', required=True, type=Path)
    parser.add_argument('--baseline-app', required=True, type=Path)
    parser.add_argument('--version-name', required=True)
    parser.add_argument('--version-code', required=True, type=int)
    parser.add_argument('--cloud-build-version', help='Explicit build number observed in the AGC upload.')
    parser.add_argument('--output', type=Path, help='Write non-secret verification evidence; must not exist.')
    args = parser.parse_args()
    try:
        require(args.version_code > 0, 'Version code must be positive.')
        result = verify(args.unsigned_app, args.signed_app, args.baseline_app,
                        args.version_name, args.version_code, args.cloud_build_version)
        formatted = json.dumps(result, indent=2) + '\n'
        if args.output:
            with args.output.open('x') as output:
                output.write(formatted)
        print(formatted, end='')
        return 0
    except VerificationError as error:
        parser.exit(1, str(error) + '\n')
    except (OSError, BadZipFile, ValueError, KeyError, TypeError):
        parser.exit(1, 'Could not verify the package, Profile, or output; private data omitted.\n')


if __name__ == '__main__':
    raise SystemExit(main())
