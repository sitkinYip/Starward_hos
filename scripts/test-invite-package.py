#!/usr/bin/env python3
"""Release-boundary tests; synthetic ZIPs do not prove official signing."""

import importlib.util
from copy import deepcopy
from io import BytesIO
import json
from pathlib import Path
import tempfile
import subprocess
import unittest
from unittest.mock import patch
from zipfile import ZipFile


spec = importlib.util.spec_from_file_location('invite_verify', Path(__file__).with_name('verify-invite-package.py'))
verify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verify)
prepare_spec = importlib.util.spec_from_file_location('invite_prepare',
                                                     Path(__file__).with_name('prepare-invite-candidate.py'))
prepare = importlib.util.module_from_spec(prepare_spec)
prepare_spec.loader.exec_module(prepare)


def package(path, *, version='0.1.2', code=4, extra=None, image=b'original image', debug=False):
    module = {'app': {'bundleName': verify.BUNDLE, 'versionName': version, 'versionCode': code, 'debug': debug},
              'module': {'name': 'entry', 'abilities': [{'name': 'EntryAbility', 'skills': [
                  {'actions': ['action.ohos.push.listener', verify.BUNDLE + '.action.PUSH_OPEN']}]}]}}
    stream = BytesIO()
    with ZipFile(stream, 'w') as archive:
        archive.writestr('module.json', json.dumps(module))
        archive.writestr('resources/rawfile/production-smoke.json', json.dumps({'mode': verify.MODE}))
        archive.writestr('ets/modules.abc', b'compiled https://api.sitkin.top')
        archive.writestr('resources/image.png', image)
        for name, data in (extra or {}).items():
            archive.writestr(name, data)
    with ZipFile(path, 'w') as archive:
        archive.writestr('entry-default.hap', stream.getvalue())


def profile(identifier='same-app', certificate='same-certificate'):
    return {'type': 'release', 'bundle-info': {'bundle-name': verify.BUNDLE, 'app-identifier': identifier,
                                            'distribution-certificate': certificate},
            'app-services-capabilities': [verify.CAPABILITY],
            'validity': {'not-before': 0, 'not-after': 4102444800}}


class ReleaseBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.path = Path(self.folder.name) / 'candidate.app'

    def tearDown(self):
        self.folder.cleanup()

    def test_explicit_version_supports_current_and_previous_release(self):
        for version, code in [('0.1.1', 3), ('0.1.2', 4)]:
            with self.subTest(version=version):
                package(self.path, version=version, code=code)
                self.assertIn('ets/modules.abc', verify.inspect_app(self.path, version, code)['entries'])

    def test_stale_version_fails(self):
        package(self.path, version='0.1.1', code=3)
        with self.assertRaisesRegex(verify.VerificationError, 'version differs'):
            verify.inspect_app(self.path, '0.1.2', 4)

    def test_debug_build_cannot_pass_release(self):
        package(self.path, debug=True)
        with self.assertRaisesRegex(verify.VerificationError, 'release entry'):
            verify.inspect_app(self.path, '0.1.2', 4)

    def test_private_configuration_and_unsafe_paths_fail(self):
        for name in ['resources/rawfile/integration.json', 'resources/rawfile/signing.key', '../unexpected']:
            with self.subTest(name=name):
                package(self.path, extra={name: b'not production'})
                with self.assertRaises(verify.VerificationError):
                    verify.inspect_app(self.path, '0.1.2', 4)

    def test_resource_replacement_detected_even_when_arkts_matches(self):
        package(self.path)
        replacement = Path(self.folder.name) / 'replacement.app'
        package(replacement, image=b'replaced image')
        before = verify.inspect_app(self.path, '0.1.2', 4)
        after = verify.inspect_app(replacement, '0.1.2', 4)
        self.assertEqual(before['compiledArkTSPayloadSHA256'], after['compiledArkTSPayloadSHA256'])
        with patch.object(verify, 'verified_profile') as sdk:
            with self.assertRaisesRegex(verify.VerificationError, 'changed packaged HAP'):
                verify.verify(self.path, replacement, self.path, '0.1.2', 4)
            sdk.assert_not_called()

    def test_same_valid_profile_is_accepted_without_forcing_new_uuid(self):
        verify.compare_identity(profile(), profile())

    def cloud_payloads(self):
        before = {'entries': {'module.json': 'old-module', 'pack.info': 'old-pack',
                              'ets/modules.abc': 'same-code', 'image.png': 'same-image'},
                  'module': {'app': {'versionName': '0.1.2'}},
                  'packInfo': {'summary': {'app': {'version': {'code': 4}}}}}
        after = deepcopy(before)
        after['entries'].update({'module.json': 'new-module', 'pack.info': 'new-pack'})
        after['module']['app']['buildVersion'] = '1'
        after['packInfo']['summary']['app']['version']['build'] = '1'
        return before, after

    def test_cloud_build_additions_require_explicit_observed_number(self):
        before, after = self.cloud_payloads()
        with self.assertRaises(verify.VerificationError):
            verify.compare_payload(before, after)
        self.assertEqual(len(verify.compare_payload(before, after, '1')), 2)

    def test_cloud_build_exception_rejects_other_changes(self):
        for mutate in [lambda x: x['module']['app'].update({'versionName': '9.0'}),
                       lambda x: x['packInfo']['summary']['app']['version'].update({'code': 5}),
                       lambda x: x['entries'].update({'ets/modules.abc': 'changed-code'}),
                       lambda x: x['entries'].update({'image.png': 'changed-image'}),
                       lambda x: x['entries'].update({'new-resource': 'new'}),
                       lambda x: x['module']['app'].update({'buildVersion': '2'}),
                       lambda x: x['packInfo']['summary']['app']['version'].update({'build': 1})]:
            before, after = self.cloud_payloads()
            mutate(after)
            with self.subTest(after=after), self.assertRaises(verify.VerificationError):
                verify.compare_payload(before, after, '1')

    def test_cloud_build_exception_cannot_replace_existing_build(self):
        before, after = self.cloud_payloads()
        before['module']['app']['buildVersion'] = '0'
        with self.assertRaises(verify.VerificationError):
            verify.compare_payload(before, after, '1')

    def test_cloud_metadata_comparison_is_type_sensitive(self):
        before, after = self.cloud_payloads()
        before['module']['module'] = {'installationFree': False}
        after['module']['module'] = {'installationFree': 0}
        with self.assertRaisesRegex(verify.VerificationError, 'other manifest'):
            verify.compare_payload(before, after, '1')

    def test_json_duplicate_fields_and_nonfinite_numbers_fail(self):
        for text in ['{"debug":false,"debug":false}', '{"value":NaN}',
                     '{"value":Infinity}', '{"value":-Infinity}']:
            with self.subTest(text=text), self.assertRaises(verify.VerificationError):
                verify.strict_json(text)

    def test_app_identifier_and_certificate_changes_fail(self):
        for current in [profile(identifier='other-app'), profile(certificate='other-certificate')]:
            with self.subTest(current=current):
                with self.assertRaises(verify.VerificationError):
                    verify.compare_identity(current, profile())

    def test_missing_push_capability_fails(self):
        current = profile()
        current['app-services-capabilities'] = []
        with self.assertRaisesRegex(verify.VerificationError, 'lacks Push'):
            verify.compare_identity(current, profile())


class SnapshotBoundaryTests(unittest.TestCase):
    def test_new_source_is_frozen_but_ignored_signing_material_stays_out(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            subprocess.run(['git', 'init', '-q', root], check=True, capture_output=True)
            (root / '.gitignore').write_text('/build-profile.json5\n*.key\n/artifacts/private/\n')
            (root / 'build-profile.example.json5').write_text('{"app":{"signingConfigs":[]}}')
            (root / 'build-profile.json5').write_text('private signing configuration')
            (root / 'secret.key').write_text('never copied')
            (root / 'AppScope').mkdir()
            app = {'app': {'bundleName': verify.BUNDLE, 'versionName': '0.1.0', 'versionCode': 1}}
            (root / 'AppScope/app.json5').write_text(json.dumps(app))
            (root / 'entry/src/main/resources/rawfile').mkdir(parents=True)
            (root / 'new-source.ets').write_text('newly implemented source')
            private = root / 'artifacts/private'
            private.mkdir(mode=0o700, parents=True)
            original_git = prepare.git

            def git(*arguments):
                if arguments == ('rev-parse', 'HEAD'):
                    return b'synthetic-test-head\n'
                return original_git(*arguments)

            with patch.object(prepare, 'ROOT', root), patch.object(prepare, 'git', side_effect=git):
                stage = prepare.prepare('0.1.2', 4)
            project = stage / 'project'
            self.assertEqual((project / 'new-source.ets').read_text(), 'newly implemented source')
            self.assertFalse((project / 'secret.key').exists())
            self.assertEqual(json.loads((project / 'build-profile.json5').read_text())['app']['signingConfigs'], [])
            self.assertEqual(json.loads((project / 'AppScope/app.json5').read_text())['app']['versionCode'], 4)
            self.assertEqual(json.loads((root / 'AppScope/app.json5').read_text()), app)
            receipt = json.loads((stage / 'source-snapshot.json').read_text())
            self.assertFalse(receipt['signingMaterialCopied'])
            self.assertFalse(receipt['buildExecuted'])
            self.assertNotIn('secret.key', receipt['sourceSHA256'])


if __name__ == '__main__':
    unittest.main()
