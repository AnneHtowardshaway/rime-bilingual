"""个人迁移包回归：全部使用临时目录与可控的原生数据库适配器。"""
import contextlib
import hashlib
import io
import json
from pathlib import Path
import stat
import sys
import tempfile
import unittest
from unittest import mock
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import personal_data as migration


class NativeFixture:
    def __init__(self):
        self.busy = False
        self.fail_restore = False
        self.calls = []

    def assert_restore_ready(self, directory):
        self.calls.append(("ready", Path(directory)))
        if self.busy:
            raise RuntimeError("engine is running")

    def backup_databases(self, directory, output):
        self.calls.append(("backup", Path(directory)))
        output.mkdir(parents=True, exist_ok=True)
        result = []
        for name in migration.DATABASES:
            source = directory / (name + ".userdb") / "records"
            if source.exists():
                target = output / (name + ".userdb.txt")
                target.write_bytes(source.read_bytes())
                result.append(target)
        return result

    def restore_databases(self, directory, snapshots):
        self.calls.append(("restore", Path(directory)))
        if self.fail_restore:
            # 真实适配器会在隔离目录处理失败，换入前不更改目标。
            raise RuntimeError("simulated staged database restore failure")
        for source in snapshots:
            target = directory / (source.name[:-len(".userdb.txt")] + ".userdb")
            target.mkdir(exist_ok=True)
            rows = set((target / "records").read_bytes().splitlines()) if (target / "records").exists() else set()
            rows.update(source.read_bytes().splitlines())
            (target / "records").write_bytes(b"\n".join(sorted(rows)) + b"\n")


class PersonalDataTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.base = Path(self.temporary.name).resolve()
        self.source = self.base / "source"
        self.target = self.base / "target"
        self.source.mkdir()
        self.target.mkdir()
        self.native = NativeFixture()
        self.native_patch = mock.patch.object(migration, "native", return_value=self.native)
        self.native_patch.start()
        self.addCleanup(self.native_patch.stop)
        self.addCleanup(self.temporary.cleanup)

    def package(self, payload, filename="input.zip", records=None, extra=None):
        entries = [{"path": name, "type": migration.archive_kind(name), "size": len(data),
                    "sha256": hashlib.sha256(data).hexdigest()} for name, data in payload.items()]
        manifest = {"format": migration.FORMAT, "version": 1, "files": entries if records is None else records}
        path = self.base / filename
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr("manifest.json", json.dumps(manifest).encode())
            for name, data in payload.items():
                archive.writestr(name, data)
            if extra:
                extra(archive)
        return path

    def test_settings_backup_preserves_bytes_and_does_not_call_native(self):
        expected = {"custom_phrase.txt": "# note\r\n词条\tword\t1000\r\n".encode(),
                    "squirrel.personal.yaml": b"patch: {}\n", "weasel.personal.yaml": b"# Windows\n",
                    "user.yaml": b"var:\n  option:\n    bilingual_compact: true\n"}
        for name, data in expected.items():
            (self.source / name).write_bytes(data)
        (self.source / "installation.yaml").write_text("must stay on source")
        (self.source / "build").mkdir()
        (self.source / "build/cache").write_text("ignored")
        package = migration.backup(self.source, settings_only=True)
        manifest, payload = migration.read_archive(package)
        self.assertTrue(package.name.endswith(".rime-personal.zip"))
        self.assertTrue(manifest["settings_only"])
        self.assertEqual(payload, {"settings/" + name: data for name, data in expected.items()})
        self.assertEqual(self.native.calls, [])

    def test_full_backup_selects_only_known_native_snapshots(self):
        for name in ("wanxiang", "sequence", "en", "private"):
            directory = self.source / (name + ".userdb")
            directory.mkdir()
            (directory / "records").write_bytes((name + " data\n").encode())
        package = migration.backup(self.source, self.base / "full.zip")
        _, payload = migration.read_archive(package)
        self.assertEqual(set(payload), {"databases/" + name + ".userdb.txt"
                                        for name in ("wanxiang", "sequence", "en")})
        self.assertEqual([item[0] for item in self.native.calls], ["ready", "backup"])

    def test_merge_phrases_keep_existing_weights_and_settings(self):
        (self.target / "custom_phrase.txt").write_text("# keep\n旧词\toldword\t900\n", encoding="utf-8")
        (self.target / "user.yaml").write_bytes(b"target bytes\n")
        archive = self.package({"settings/custom_phrase.txt": "旧词\toldword\t1000\n新词\tnewword\t1000\n".encode(),
                                "settings/user.yaml": b"source bytes\n",
                                "settings/squirrel.personal.yaml": b"patch: {}\n"})
        result = migration.restore(self.target, archive, settings_only=True)
        self.assertEqual(result["conflicts"], ["user.yaml"])
        self.assertEqual(result["changed"], 2)
        self.assertEqual((self.target / "custom_phrase.txt").read_text(), "# keep\n旧词\toldword\t900\n新词\tnewword\t1000\n")
        self.assertEqual((self.target / "user.yaml").read_bytes(), b"target bytes\n")
        self.assertEqual((result["recovery"] / "settings/custom_phrase.txt").read_text(), "# keep\n旧词\toldword\t900\n")

    def test_replace_settings_requires_explicit_flag_and_keeps_raw_backup(self):
        original = b"var:\r\n  x: 1\r\n"
        incoming = b"var:\n  x: 2\n"
        (self.target / "user.yaml").write_bytes(original)
        archive = self.package({"settings/user.yaml": incoming})
        result = migration.restore(self.target, archive, settings_only=True, replace_settings=True)
        self.assertEqual((self.target / "user.yaml").read_bytes(), incoming)
        self.assertEqual((result["recovery"] / "settings/user.yaml").read_bytes(), original)

    def test_full_restore_is_last_and_retains_native_backup(self):
        database = self.target / "wanxiang.userdb"
        database.mkdir()
        (database / "records").write_bytes(b"old\n")
        archive = self.package({"databases/wanxiang.userdb.txt": b"new\n"})
        result = migration.restore(self.target, archive)
        self.assertEqual((database / "records").read_bytes(), b"new\nold\n")
        self.assertEqual((result["recovery"] / "database-snapshots/wanxiang.userdb.txt").read_bytes(), b"old\n")
        restore_calls = [p for action, p in self.native.calls if action == "restore"]
        self.assertEqual(len(restore_calls), 1)
        self.assertEqual(restore_calls[0], self.target)

    def test_partial_native_failure_never_changes_target(self):
        database = self.target / "sequence.userdb"
        database.mkdir()
        (database / "records").write_bytes(b"old\n")
        (self.target / "user.yaml").write_bytes(b"old setting")
        archive = self.package({"databases/sequence.userdb.txt": b"new\n", "settings/user.yaml": b"new setting"})
        self.native.fail_restore = True
        with self.assertRaisesRegex(migration.MigrationError, "恢复材料"):
            migration.restore(self.target, archive, replace_settings=True)
        self.assertEqual((database / "records").read_bytes(), b"old\n")
        self.assertEqual((self.target / "user.yaml").read_bytes(), b"old setting")

    def test_file_write_failure_restores_already_written_settings(self):
        archive = self.package({"settings/custom_phrase.txt": "词条\tword\t1000\n".encode(),
                                "settings/user.yaml": b"new settings"})
        real_write = migration.atomic_write
        def fail_second(path, data, expected):
            if path.name == "user.yaml":
                raise OSError("no space")
            return real_write(path, data, expected)
        with mock.patch.object(migration, "atomic_write", side_effect=fail_second):
            with self.assertRaisesRegex(migration.MigrationError, "文本变更已回滚"):
                migration.restore(self.target, archive, settings_only=True)
        self.assertFalse((self.target / "custom_phrase.txt").exists())
        self.assertFalse((self.target / "user.yaml").exists())

    def test_busy_target_refuses_before_writing(self):
        archive = self.package({"settings/user.yaml": b"new"})
        self.native.busy = True
        with self.assertRaisesRegex(migration.MigrationError, "关闭输入法"):
            migration.restore(self.target, archive, settings_only=True)
        self.assertEqual(list(self.target.iterdir()), [])

    def test_bad_hash_fails_before_native_or_any_target_write(self):
        data = b"new"
        record = {"path": "settings/user.yaml", "type": "settings", "size": len(data), "sha256": "0" * 64}
        archive = self.package({"settings/user.yaml": data}, records=[record])
        with self.assertRaises(migration.MigrationError):
            migration.restore(self.target, archive)
        self.assertEqual(self.native.calls, [])
        self.assertEqual(list(self.target.iterdir()), [])

    def test_rejects_unsafe_zip_names_duplicates_and_symlinks(self):
        unsafe = ("../user.yaml", "/user.yaml", "settings\\user.yaml", "C:/user.yaml",
                  "settings/../user.yaml", "settings//user.yaml", "settings/./user.yaml")
        for i, name in enumerate(unsafe):
            archive = self.package({}, filename=f"unsafe-{i}.zip", extra=lambda z, name=name: z.writestr(name, b"bad"))
            with self.subTest(name=name), self.assertRaises(migration.MigrationError):
                migration.read_archive(archive)
        with contextlib.redirect_stderr(io.StringIO()):
            archive = self.package({"settings/user.yaml": b"ok"}, filename="duplicate.zip",
                                   extra=lambda z: z.writestr("settings/user.yaml", b"bad"))
        with self.assertRaises(migration.MigrationError):
            migration.read_archive(archive)
        info = zipfile.ZipInfo("settings/user.yaml")
        info.create_system = 3
        info.external_attr = (stat.S_IFLNK | 0o777) << 16
        archive = self.package({}, filename="link.zip", extra=lambda z: z.writestr(info, b"/outside"))
        with self.assertRaises(migration.MigrationError):
            migration.read_archive(archive)

    def test_rejects_missing_manifest_entries_and_size_limits(self):
        archive = self.package({"settings/user.yaml": b"long content"}, records=[])
        with self.assertRaises(migration.MigrationError):
            migration.read_archive(archive)
        archive = self.package({"settings/user.yaml": b"long content"}, filename="big.zip")
        with mock.patch.object(migration, "MAX_FILE", 5):
            with self.assertRaises(migration.MigrationError):
                migration.read_archive(archive)

    def test_rejects_symlink_target_and_source(self):
        outside = self.base / "outside"
        outside.write_bytes(b"outside")
        try:
            (self.target / "user.yaml").symlink_to(outside)
        except OSError:
            self.skipTest("symlink not available")
        archive = self.package({"settings/user.yaml": b"incoming"})
        with self.assertRaises(migration.MigrationError):
            migration.restore(self.target, archive, settings_only=True, replace_settings=True)
        self.assertEqual(outside.read_bytes(), b"outside")
        (self.source / "custom_phrase.txt").symlink_to(outside)
        with self.assertRaises(migration.MigrationError):
            migration.backup(self.source, settings_only=True)

    def test_help_has_no_side_effects_and_inspect_does_not_print_contents(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(migration.main(["--help"]), 0)
        self.assertEqual(self.native.calls, [])
        secret = b"PRIVATE_SENTINEL_DO_NOT_PRINT"
        archive = self.package({"settings/user.yaml": secret})
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            self.assertEqual(migration.main(["inspect", str(archive)]), 0)
        self.assertNotIn(secret.decode(), output.getvalue())
        self.assertIn("settings/user.yaml", output.getvalue())
        self.assertEqual(self.native.calls, [])


    def test_settings_only_validates_but_skips_database_payload(self):
        archive = self.package({"databases/wanxiang.userdb.txt": b"snapshot",
                                "settings/user.yaml": b"options"})
        result = migration.restore(self.target, archive, settings_only=True)
        self.assertEqual(result["databases"], 0)
        self.assertFalse((self.target / "wanxiang.userdb").exists())
        self.assertTrue(all(action == "ready" for action, _ in self.native.calls))

    def test_zip_compression_bomb_and_manifest_version_are_rejected(self):
        archive = self.package({"settings/user.yaml": b"content"})
        with mock.patch.object(migration, "MAX_TOTAL", 5):
            with self.assertRaises(migration.MigrationError):
                migration.read_archive(archive)
        archive = self.base / "ratio.zip"
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as package:
            package.writestr("settings/user.yaml", b"x" * (2 * 1024 * 1024))
            package.writestr("manifest.json", b"{}")
        # 压缩比及总展开大小两种独立上界，任一超限都会拒绝。
        with mock.patch.object(migration, "MAX_FILE", 1024):
            with self.assertRaises(migration.MigrationError):
                migration.read_archive(archive)
        archive = self.base / "version.zip"
        with zipfile.ZipFile(archive, "w") as package:
            package.writestr("manifest.json", json.dumps({"format": migration.FORMAT,
                                                         "version": 2, "files": []}))
        with self.assertRaises(migration.MigrationError):
            migration.read_archive(archive)

    def test_native_incomplete_rollback_has_recovery_path_and_text_rollback(self):
        archive = self.package({"settings/user.yaml": b"new", "databases/en.userdb.txt": b"incoming"})
        (self.target / "user.yaml").write_bytes(b"old")
        error = RuntimeError("PRIVATE_ERROR_OUTPUT")
        error.rollback_complete = False
        error.recovery_path = self.base / "native-recovery"
        with mock.patch.object(self.native, "restore_databases", side_effect=error):
            with self.assertRaises(migration.MigrationError) as caught:
                migration.restore(self.target, archive, replace_settings=True)
        message = str(caught.exception)
        self.assertIn("学习数据库回滚未全部完成", message)
        self.assertIn(str(error.recovery_path), message)
        self.assertNotIn("PRIVATE_ERROR_OUTPUT", message)
        self.assertEqual((self.target / "user.yaml").read_bytes(), b"old")

    def test_parser_returns_two_without_echoing_private_argument(self):
        output = io.StringIO()
        with contextlib.redirect_stderr(output):
            self.assertEqual(migration.main(["PRIVATE_ARGUMENT"]), 2)
        self.assertNotIn("PRIVATE_ARGUMENT", output.getvalue())


if __name__ == "__main__":
    unittest.main()
