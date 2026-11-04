import importlib.util
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


def load_module(name):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).resolve().parents[1] / f'{name}.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


sync = load_module('sync_upstream')
recovery = load_module('build_recovery')


class DataMergeTests(unittest.TestCase):
    def test_independent_translation_and_placeholder_changes_are_retained(self):
        base = {'title': 'Before', '@title': {'description': 'Old'}}
        ours = {**base, 'quickControls': 'Controls'}
        theirs = {'title': 'After', '@title': {'description': 'New'}, 'newKey': 'Upstream'}
        self.assertEqual(sync.merge_json(base, ours, theirs), {**theirs, 'quickControls': 'Controls'})

    def test_different_edits_to_the_same_translation_are_not_overwritten(self):
        with self.assertRaises(sync.MergeConflict):
            sync.merge_json({'title': 'Before'}, {'title': 'Ours'}, {'title': 'Theirs'})

    def test_deleted_keys_stay_deleted_when_the_other_side_did_not_edit(self):
        self.assertEqual(sync.merge_json({'key': 'Before'}, {}, {'key': 'Before'}), {})

    def test_upstream_toolchain_versions_are_validated(self):
        self.assertEqual(sync.version_pins("env:\n  FLUTTER_VERSION: '3.47.6'\n  GO_VERSION: '1.27.1'\n  NDK_VERSION: r28c\n"), {
            'flutter_version': '3.47.6', 'go_version': '1.27.1', 'ndk_version': 'r28c',
        })
        with self.assertRaises(ValueError):
            sync.version_pins("  FLUTTER_VERSION: '$(echo broken)'\n")

    def test_only_clear_infrastructure_failures_are_retried(self):
        for log in ['curl: (56) Connection reset', 'HTTP Error 503', 'Could not GET https://example.com: Read timed out']:
            self.assertTrue(recovery.is_transient_failure(log))
        for log in ['HTTP Error 403', 'HTTP Error 404', 'Unknown build failure', 'CONFLICT (content): Merge conflict; curl: (56)', 'lib/view.dart:12:7: Error: Type not found\nConnection reset']:
            self.assertFalse(recovery.is_transient_failure(log))


class GitMergeTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.previous = Path.cwd()
        os.chdir(self.directory.name)
        self.git('init', '-b', 'upstream-main')
        self.git('config', 'user.name', 'Merge test')
        self.git('config', 'user.email', 'merge-test@example.invalid')
        self.write('arb/intl_en.arb', {'base': 'Original'})
        self.write('lib/feature.dart', 'base\n')
        self.write('.github/workflows/build.yaml', 'upstream workflow\n')
        self.write('lib/providers/generated/example.g.dart', 'base generated\n')
        self.commit('base')
        self.git('checkout', '-b', 'vantage')
        self.write('arb/intl_en.arb', {'base': 'Original', 'vantage': 'Our feature'})
        self.write('.github/workflows/sync-build.yaml', 'our workflow\n')
        self.git('rm', '.github/workflows/build.yaml')
        self.write('lib/vantage.dart', 'our UI\n')
        self.write('lib/providers/generated/example.g.dart', 'our generated\n')
        self.commit('our feature')
        self.ours = self.git('rev-parse', 'HEAD')
        self.git('checkout', 'upstream-main')
        self.write('arb/intl_en.arb', {'base': 'Updated upstream', 'new': 'Upstream feature'})
        self.write('lib/new.dart', 'upstream feature\n')
        self.write('.github/workflows/build.yaml', 'changed upstream workflow\n')
        self.write('lib/providers/generated/example.g.dart', 'upstream generated\n')
        self.commit('upstream update')
        self.git('checkout', 'vantage')

    def tearDown(self):
        os.chdir(self.previous)
        self.directory.cleanup()

    def git(self, *args):
        return subprocess.check_output(['git', *args], stderr=subprocess.PIPE, text=True).strip()

    def write(self, name, content):
        path = Path(name)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(content) + '\n' if isinstance(content, dict) else content)

    def commit(self, message):
        self.git('add', '--all')
        self.git('commit', '-m', message)

    def test_real_merge_preserves_custom_features_workflows_and_translations(self):
        sync.merge_upstream('upstream-main')
        self.assertEqual(sync.conflicts(), [])
        self.assertTrue(Path('lib/vantage.dart').exists())
        self.assertTrue(Path('lib/new.dart').exists())
        self.assertFalse(Path('.github/workflows/build.yaml').exists())
        self.assertEqual(Path('.github/workflows/sync-build.yaml').read_text(), 'our workflow\n')
        self.assertEqual(json.loads(Path('arb/intl_en.arb').read_text()), {
            'base': 'Updated upstream', 'vantage': 'Our feature', 'new': 'Upstream feature',
        })
        self.assertEqual(Path('lib/providers/generated/example.g.dart').read_text(), 'our generated\n')

    def test_source_conflict_stops_without_publishing_a_commit(self):
        self.write('lib/feature.dart', 'our edit\n')
        self.commit('custom source change')
        expected_head = self.git('rev-parse', 'HEAD')
        self.git('checkout', 'upstream-main')
        self.write('lib/feature.dart', 'upstream edit\n')
        self.commit('upstream source change')
        self.git('checkout', 'vantage')
        with self.assertRaises(sync.MergeConflict):
            sync.merge_upstream('upstream-main')
        self.assertEqual(self.git('rev-parse', 'HEAD'), expected_head)
        self.assertIn('lib/feature.dart', sync.conflicts())

    def test_an_already_merged_upstream_does_not_change_the_checkout(self):
        sync.merge_upstream(self.ours)
        self.assertEqual(self.git('status', '--porcelain'), '')


if __name__ == '__main__':
    unittest.main()
