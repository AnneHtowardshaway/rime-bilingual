"""常用语管理回归；仅在隔离临时目录中读写，不读取本机私人内容。"""
from contextlib import redirect_stderr, redirect_stdout
import importlib.util
import io
import os
from pathlib import Path
import stat
import sys
import tempfile
import unittest
from unittest.mock import patch
from unittest.mock import MagicMock

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("phrases", ROOT / "scripts/phrases.py")
phrases = importlib.util.module_from_spec(spec)
spec.loader.exec_module(phrases)


class PhrasesSpec(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name).resolve()
        self.user = self.root / "用户 目录"
        self.user.mkdir()
        self.target = self.user / "custom_phrase.txt"

    def tearDown(self):
        self.temporary.cleanup()

    def cli(self, *arguments):
        output, errors = io.StringIO(), io.StringIO()
        with redirect_stdout(output), redirect_stderr(errors):
            status = phrases.main(["--user-dir", str(self.user), *arguments])
        return status, output.getvalue(), errors.getvalue()

    def backups(self):
        return list((self.user / "backups").glob("phrases-*.txt"))

    def test_same_code_multiple_phrases_duplicate_and_explicit_update(self):
        original = b"# existing comment\r\n"
        self.target.write_bytes(original)
        self.assertEqual(self.cli("add", "项目甲", "xiangmu")[0], 0)
        self.assertEqual(self.backups()[0].read_bytes(), original)
        self.assertEqual(self.cli("add", "项目乙", "xiangmu", "--weight", "800")[0], 0)
        unchanged = self.target.read_bytes()
        backup_count = len(self.backups())
        self.assertEqual(self.cli("add", "项目甲", "xiangmu", "--weight", "900")[0], 0)
        self.assertEqual(self.target.read_bytes(), unchanged)
        self.assertEqual(len(self.backups()), backup_count)
        self.assertEqual(self.cli("add", "项目甲", "xiangmu", "--update")[0], 1)
        self.assertEqual(self.target.read_bytes(), unchanged)
        self.assertEqual(self.cli("add", "项目甲", "xiangmu", "--update", "--weight", "900")[0], 0)
        self.assertEqual(self.cli("search", "项目")[1], "项目甲\txiangmu\t900\n项目乙\txiangmu\t800\n")
        self.assertEqual(self.cli("remove", "xiangmu", "--text", "项目甲")[0], 0)
        self.assertEqual(self.cli("list")[1], "项目乙\txiangmu\t800\n")
        self.assertEqual(self.cli("remove", "xiangmu")[0], 0)
        self.assertEqual(self.cli("list")[1], "")
        self.assertIn(b"# existing comment", self.target.read_bytes())

    def test_import_bom_crlf_idempotent_and_export_roundtrip(self):
        self.target.write_bytes("\ufeff原短语\tyuan\t100\r\n".encode())
        incoming = self.root / "incoming.txt"
        incoming.write_bytes("\ufeff原短语\tyuan\t999\r\n新短语\txin\t200\r\n新短语\txin\t200\r\n".encode())
        self.assertEqual(self.cli("import", str(incoming))[0], 0)
        self.assertEqual(self.cli("list")[1], "原短语\tyuan\t100\n新短语\txin\t200\n")
        unchanged = self.target.read_bytes()
        self.assertEqual(self.cli("import", str(incoming))[0], 0)
        self.assertEqual(self.target.read_bytes(), unchanged)
        self.assertEqual(self.cli("import", str(incoming), "--update")[0], 0)
        exported = self.root / "export.txt"
        self.assertEqual(self.cli("export", str(exported))[0], 0)
        self.assertEqual(exported.read_text(encoding="utf-8"), "原短语\tyuan\t999\n新短语\txin\t200\n")
        exported.write_text("keep this output")
        self.assertEqual(self.cli("export", str(exported))[0], 1)
        self.assertEqual(exported.read_text(), "keep this output")
        self.assertEqual(self.cli("export", str(exported), "--force")[0], 0)
        self.assertEqual(self.cli("export", str(self.target), "--force")[0], 1)

    def test_invalid_input_preserves_original_and_avoids_private_error_output(self):
        secret = "私有内容不得回显"
        original = (secret + "\tprivate\t100\n").encode()
        self.target.write_bytes(original)
        cases = [("add", secret, "INVALID"), ("add", secret + "\n下一行", "valid"),
                 ("add", "中\u2028间", "valid"), ("add", "#不应成为注释", "valid"),
                 ("add", "\ufeff隐藏字符", "valid"), ("add", secret, "valid", "--weight", "0")]
        for args in cases:
            with self.subTest(args=args[0]):
                status, out, err = self.cli(*args)
                self.assertEqual(status, 1)
                self.assertNotIn(secret, out + err)
                self.assertEqual(self.target.read_bytes(), original)
        for payload in [b"\xff", (secret + " not tabs").encode(),
                        (secret + "\tvalid\tnot a number\n").encode(),
                        b"first\tone\t1\nfirst\tone\t2\n"]:
            source = self.root / "invalid.txt"
            source.write_bytes(payload)
            status, out, err = self.cli("import", str(source))
            self.assertEqual(status, 1)
            self.assertNotIn(secret, out + err)
            self.assertEqual(self.target.read_bytes(), original)
        self.assertEqual(self.backups(), [])
        status, out, err = self.cli("add", secret, "valid", "--weight", secret)
        self.assertEqual(status, 2)
        self.assertNotIn(secret, out + err)
        self.target.write_bytes((secret + " bad existing format").encode())
        invalid_original = self.target.read_bytes()
        self.assertEqual(self.cli("add", "合法", "valid")[0], 1)
        self.assertEqual(self.target.read_bytes(), invalid_original)

    def test_detects_external_edit_before_replacement(self):
        original = b"old\told\t100\n"
        externally_changed = b"changed by editor\tedit\t200\n"
        self.target.write_bytes(original)
        backup = phrases.write_backup

        def concurrent_edit(user, data):
            result = backup(user, data)
            self.target.write_bytes(externally_changed)
            return result

        with patch.object(phrases, "write_backup", side_effect=concurrent_edit):
            self.assertEqual(self.cli("add", "new", "new")[0], 1)
        self.assertEqual(self.target.read_bytes(), externally_changed)
        self.assertEqual(self.backups()[0].read_bytes(), original)
        self.assertEqual(list(self.user.glob(".custom-phrase-*")), [])
        self.assertFalse((self.user / ".custom_phrase.lock").exists())

    def test_existing_lock_and_atomic_failure_leave_original_intact(self):
        original = b"old\told\t100\n"
        self.target.write_bytes(original)
        lock = self.user / ".custom_phrase.lock"
        lock.write_text("")
        self.assertEqual(self.cli("remove", "old")[0], 1)
        self.assertEqual(self.backups(), [])
        lock.unlink()
        with patch.object(phrases.os, "replace", side_effect=PermissionError("private failure")):
            status, out, err = self.cli("add", "new", "new")
        self.assertEqual(status, 1)
        self.assertNotIn("private failure", out + err)
        self.assertEqual(self.target.read_bytes(), original)
        self.assertEqual(self.backups()[0].read_bytes(), original)
        self.assertEqual(list(self.user.glob(".custom-phrase-*")), [])

    def test_symlink_targets_and_backup_directory_are_rejected(self):
        outside = self.root / "outside.txt"
        original = b"outside\toutside\t100\n"
        outside.write_bytes(original)
        try:
            self.target.symlink_to(outside)
        except OSError:
            self.skipTest("platform does not permit symlinks")
        self.assertEqual(self.cli("add", "new", "new")[0], 1)
        self.assertEqual(self.cli("list")[0], 1)
        self.assertEqual(outside.read_bytes(), original)
        self.target.unlink()
        self.target.write_bytes(original)
        backup_target = self.root / "external-backups"
        backup_target.mkdir()
        (self.user / "backups").symlink_to(backup_target, target_is_directory=True)
        self.assertEqual(self.cli("add", "new", "new")[0], 1)
        self.assertEqual(self.target.read_bytes(), original)
        self.assertEqual(list(backup_target.iterdir()), [])
        output_link = self.root / "output-link"
        output_link.symlink_to(outside)
        self.assertEqual(self.cli("export", str(output_link), "--force")[0], 1)

    @unittest.skipIf(os.name == "nt", "POSIX permissions")
    def test_new_files_private_and_existing_permissions_preserved(self):
        self.assertEqual(self.cli("add", "你好", "nihao")[0], 0)
        self.assertEqual(stat.S_IMODE(self.target.stat().st_mode), 0o600)
        self.target.chmod(0o640)
        self.assertEqual(self.cli("add", "再见", "zaijian")[0], 0)
        self.assertEqual(stat.S_IMODE(self.target.stat().st_mode), 0o640)
        self.assertEqual(stat.S_IMODE(self.backups()[0].stat().st_mode), 0o600)

    def test_registry_path_precedes_appdata_and_help_does_not_read_private_file(self):
        with patch.object(phrases, "snapshot", side_effect=AssertionError("must not read")):
            with redirect_stdout(io.StringIO()):
                self.assertEqual(phrases.main(["--help"]), 0)
        with patch.object(phrases.sys, "platform", "darwin"), patch.object(phrases.Path, "home", return_value=self.root):
            self.assertEqual(phrases.default_user_dir(), self.root / "Library/Rime")
        registry = MagicMock()
        registry.QueryValueEx.return_value = (str(self.root / "registered"), 1)
        with patch.object(phrases.sys, "platform", "win32"), patch.dict(sys.modules, {"winreg": registry}), \
                patch.dict(os.environ, {"APPDATA": str(self.root / "appdata")}):
            self.assertEqual(phrases.resolve_user_dir(), self.root / "registered")
            registry.OpenKey.side_effect = FileNotFoundError
            self.assertEqual(phrases.resolve_user_dir(), self.root / "appdata/Rime")
            self.assertEqual(phrases.resolve_user_dir(self.user), self.user)


if __name__ == "__main__":
    unittest.main()
