#!/usr/bin/env python3
"""Checked offline native snapshots; all dictionaries are synthetic fixtures."""
from pathlib import Path
import json
import os
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import rime_native as native


def write_snapshot(directory, name="wanxiang", rows=None):
    path = directory / f"{name}.userdb.txt"
    if rows is None:
        rows = [("lan xu ", "合成审计词", 6), ("shan chu ", "合成删除词", -9)]
    path.write_text(
        "# Rime user dictionary\n"
        f"#@/db_name\t{name}\n#@/db_type\tuserdb\n"
        "#@/rime_version\t1.16.0\n#@/user_id\tfixture-source\n#@/tick\t42\n"
        + "".join(f"{code}\t{word}\tc={commits} d=0 t=42\n" for code, word, commits in rows),
        encoding="utf-8")
    return path


def write_installation(directory, identity):
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "installation.yaml").write_text(
        f"installation_id: {identity}\nsync_dir: {json.dumps(str(directory / 'native sync'))}\n",
        encoding="utf-8")


class NativeBoundarySpec(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="rime-native-unit-")
        self.root = Path(self.temporary.name).resolve()

    def tearDown(self):
        self.temporary.cleanup()

    def test_readiness_allows_new_isolated_directory_without_manager(self):
        target = self.root / "not-created"
        with mock.patch.object(native, "_registered_directory", return_value=self.root / "registered"), \
                mock.patch.object(native, "_input_method_running") as running:
            native.assert_restore_ready(target)
        running.assert_not_called()
        self.assertFalse(target.exists())

    def test_running_registered_input_method_is_rejected(self):
        with mock.patch.object(native, "_registered_directory", return_value=self.root), \
                mock.patch.object(native, "_input_method_running", return_value=True):
            with self.assertRaisesRegex(native.NativeRimeError, "先退出"):
                native.assert_restore_ready(self.root)

    def test_windows_requires_explicit_native_cli(self):
        with mock.patch.object(native.sys, "platform", "win32"), mock.patch.dict(os.environ, {}, clear=True):
            with self.assertRaisesRegex(native.NativeRimeError, "仅设置"):
                native._manager()

    def test_invalid_snapshot_is_rejected_before_target_creation(self):
        source = write_snapshot(self.root)
        source.write_text(source.read_text().replace("#@/db_name\twanxiang", "#@/db_name\t../escape"))
        target = self.root / "new-target"
        with self.assertRaises(native.NativeRimeError):
            native.restore_databases(target, [source])
        self.assertFalse(target.exists())

    def test_partial_or_duplicate_rows_are_rejected(self):
        source = write_snapshot(self.root)
        source.write_text(source.read_text() + "invalid\n")
        with self.assertRaises(native.NativeRimeError):
            native._snapshot(source)
        source = write_snapshot(self.root)
        source.write_text(source.read_text() + "lan xu \t合成审计词\tc=1 d=0 t=1\n")
        with self.assertRaises(native.NativeRimeError):
            native._snapshot(source)

    def test_native_exit_zero_without_fresh_snapshot_is_failure(self):
        (self.root / "wanxiang.userdb").mkdir()
        write_installation(self.root, "fixture-source")
        with mock.patch.object(native, "_manager", return_value=Path(sys.executable)), \
                mock.patch.object(native, "_run"):
            with self.assertRaisesRegex(native.NativeRimeError, "新快照"):
                native.backup_databases(self.root, self.root / "outputs")

    def test_stale_snapshot_cannot_be_reported_as_current_backup(self):
        (self.root / "wanxiang.userdb").mkdir()
        sync = self.root / "sync/unknown"
        sync.mkdir(parents=True)
        write_snapshot(sync)
        with mock.patch.object(native, "_manager", return_value=Path(sys.executable)), \
                mock.patch.object(native, "_run"):
            with self.assertRaisesRegex(native.NativeRimeError, "新快照"):
                native.backup_databases(self.root, self.root / "outputs")

    def test_native_stderr_is_not_echoed_into_errors(self):
        result = subprocess.CompletedProcess([], 1, b"private rows", b"private rows")
        with mock.patch.object(native.subprocess, "run", return_value=result):
            with self.assertRaises(native.NativeRimeError) as caught:
                native._run(Path(sys.executable), self.root, "--backup", "wanxiang")
        self.assertNotIn("private rows", str(caught.exception))

    def test_only_default_database_names_are_selected(self):
        for name in ("wanxiang", "en", "unrelated"):
            (self.root / f"{name}.userdb").mkdir()
        self.assertEqual(native._databases(self.root), ["wanxiang", "en"])

    def test_installation_scalars_support_quoted_paths_and_reject_complex_yaml(self):
        write_installation(self.root, "fixture-source")
        self.assertEqual(native._installation(self.root),
                         ("fixture-source", self.root / "native sync/fixture-source"))
        (self.root / "installation.yaml").write_text("sync_dir: |\n  /some/path\n")
        with self.assertRaises(native.NativeRimeError):
            native._installation(self.root)


try:
    NATIVE_MANAGER = native._manager()
except native.NativeRimeError:
    NATIVE_MANAGER = None


@unittest.skipUnless(NATIVE_MANAGER, "No installed native dictionary manager; fixtures were not run")
class NativeRoundTripSpec(unittest.TestCase):
    def setUp(self):
        cache = ROOT / ".cache/test"
        cache.mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(prefix="rime-native-fixture-", dir=cache)
        self.root = Path(self.temporary.name)
        self.source = self.root / "source"
        self.target = self.root / "target"
        self.seeds = self.root / "seeds"
        self.seeds.mkdir()
        write_installation(self.source, "fixture-source")
        write_installation(self.target, "fixture-target")

    def tearDown(self):
        self.temporary.cleanup()

    def seed(self, user_dir, name="wanxiang", rows=None):
        snapshot = write_snapshot(self.seeds, name, rows)
        native._run(NATIVE_MANAGER, user_dir, "--restore", str(snapshot))
        return snapshot

    def test_native_roundtrip_all_default_databases_retains_tombstones_and_merges(self):
        for name in native.DATABASES:
            self.seed(self.source, name)
        self.seed(self.target, rows=[("target only ", "目标自有词", 3)])
        snapshots = native.backup_databases(self.source, self.root / "backup")
        self.assertEqual({path.name for path in snapshots},
                         {f"{name}.userdb.txt" for name in native.DATABASES})
        self.assertIn("c=-9 d=0 t=42", snapshots[0].read_text())
        recovery = native.restore_databases(self.target, snapshots)
        original = native.backup_databases(recovery / "withdrawn", self.root / "before-check")
        self.assertEqual(native._snapshot(original[0]).commits,
                         {("target only ", "目标自有词"): 3})
        restored = native.backup_databases(self.target, self.root / "restored")
        for path in restored:
            parsed = native._snapshot(path)
            self.assertEqual(parsed.commits[("shan chu ", "合成删除词")], -9)
            self.assertEqual(parsed.commits[("lan xu ", "合成审计词")], 6)
            if parsed.name == "wanxiang":
                self.assertEqual(parsed.commits[("target only ", "目标自有词")], 3)
        self.assertFalse(list(self.target.glob(".rime-native-restore-*")))

    def test_live_database_lock_fails_without_native_force(self):
        if sys.platform == "win32":
            self.skipTest("The POSIX lock holder fixture is not portable to Windows")
        self.seed(self.source)
        code = ("import fcntl,sys; h=open(sys.argv[1],'r+b'); "
                "fcntl.lockf(h,fcntl.LOCK_EX); print('ready',flush=True); sys.stdin.read()")
        holder = subprocess.Popen([sys.executable, "-c", code,
                                   str(self.source / "wanxiang.userdb/LOCK")],
                                  stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        try:
            self.assertEqual(holder.stdout.readline().strip(), "ready")
            with self.assertRaisesRegex(native.NativeRimeError, "正在使用|锁定"):
                native.backup_databases(self.source, self.root / "locked")
        finally:
            holder.stdin.close()
            holder.wait(timeout=10)
            holder.stdout.close()

    def test_personal_archive_roundtrip_merges_native_data_and_private_phrases(self):
        import personal_data
        self.seed(self.source)
        self.seed(self.target, rows=[("target only ", "目标自有词", 3)])
        (self.source / "custom_phrase.txt").write_text("测试工作室\tceshi\t1000\n", encoding="utf-8")
        (self.target / "custom_phrase.txt").write_text("原有短语\tyuanyou\t900\n", encoding="utf-8")
        (self.source / "user.yaml").write_bytes(b"source options\n")
        (self.target / "user.yaml").write_bytes(b"target options\n")
        package = personal_data.backup(self.source, self.root / "portable.rime-personal.zip")
        result = personal_data.restore(self.target, package)
        self.assertEqual(result["databases"], 1)
        self.assertEqual(result["conflicts"], ["user.yaml"])
        self.assertTrue(result["native_recovery"].is_dir())
        self.assertEqual((self.target / "user.yaml").read_bytes(), b"target options\n")
        self.assertIn("原有短语", (self.target / "custom_phrase.txt").read_text(encoding="utf-8"))
        self.assertIn("测试工作室", (self.target / "custom_phrase.txt").read_text(encoding="utf-8"))
        exported = native.backup_databases(self.target, self.root / "after-archive")
        merged = native._snapshot(exported[0]).commits
        self.assertEqual(merged[("target only ", "目标自有词")], 3)
        self.assertEqual(merged[("shan chu ", "合成删除词")], -9)

    def test_swap_failure_restores_existing_database_and_removes_new_database(self):
        new = self.seed(self.source, "en")
        sequence = self.seed(self.source, "sequence")
        self.seed(self.target, "sequence", [("before ", "目标原有词", 4)])
        original_replace = Path.replace

        def injected_failure(path, destination):
            if path.name == "sequence.userdb" and path.parent.name == "work":
                raise OSError("synthetic directory replacement failure")
            return original_replace(path, destination)

        with mock.patch.object(Path, "replace", injected_failure):
            with self.assertRaises(native.NativeRimeError) as caught:
                native.restore_databases(self.target, [new, sequence])
        self.assertTrue(caught.exception.rollback_complete)
        self.assertFalse((self.target / "en.userdb").exists())
        remaining = native.backup_databases(self.target, self.root / "after-rollback")
        self.assertEqual(native._snapshot(remaining[0]).commits, {("before ", "目标原有词"): 4})


if __name__ == "__main__":
    unittest.main(verbosity=2)
