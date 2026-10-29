"""本地管理入口回归，不读取私人词条、不启动真实输入法。"""
from contextlib import redirect_stderr, redirect_stdout
import io
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import manage


class ManageSpec(unittest.TestCase):
    def run_main(self, args):
        output, errors = io.StringIO(), io.StringIO()
        with redirect_stdout(output), redirect_stderr(errors):
            status = manage.main(args)
        return status, output.getvalue() + errors.getvalue()

    def test_global_user_dir_named_like_command_and_unicode_arguments(self):
        with patch.object(manage.phrases, "main", return_value=0) as delegate:
            self.assertEqual(self.run_main(["--user-dir", "data", "phrases", "add",
                                            "项目名称", "xiangmu", "--weight", "900"])[0], 0)
            delegate.assert_called_once_with(["--user-dir", "data", "add", "项目名称",
                                              "xiangmu", "--weight", "900"])

    def test_subcommand_help_and_flags_are_delegated(self):
        with patch.object(manage.personal_data, "main", return_value=0) as delegate:
            self.assertEqual(self.run_main(["data", "--help"])[0], 0)
            delegate.assert_called_once_with(["--help"])
        with patch.object(manage.personal_data, "main", return_value=1) as delegate:
            self.assertEqual(self.run_main(["--user-dir=/tmp/隔离", "data", "restore",
                                            "archive.zip", "--settings-only"])[0], 1)
            delegate.assert_called_once_with(["--user-dir", "/tmp/隔离", "restore",
                                              "archive.zip", "--settings-only"])

    def test_help_and_parameter_errors_have_no_data_side_effects(self):
        with patch.object(manage.phrases, "snapshot", side_effect=AssertionError("must not read")), \
                patch.object(manage.subprocess, "run", side_effect=AssertionError("must not launch")):
            self.assertEqual(self.run_main(["--help"])[0], 0)
            status, output = self.run_main(["私有参数不得回显"])
            self.assertEqual(status, 2)
            self.assertNotIn("私有参数不得回显", output)

    def test_menu_remove_is_precise_and_eof_is_safe(self):
        with patch.object(manage, "dispatch", return_value=0) as delegate, \
                patch.object(manage.phrases, "resolve_user_dir", return_value=Path("/tmp/isolated")), \
                patch("builtins.input", side_effect=["4", "code", "只删除这一条", "0"]):
            self.assertEqual(self.run_main([])[0], 0)
            delegate.assert_called_once_with("phrases", ["remove", "code", "--text", "只删除这一条"], None)
        with patch("builtins.input", side_effect=EOFError), \
                patch.object(manage.phrases, "resolve_user_dir", return_value=Path("/tmp/isolated")):
            self.assertEqual(self.run_main([])[0], 0)

    def test_apply_rejects_isolated_directory_before_native_launch(self):
        with patch.object(manage.phrases, "resolve_user_dir", side_effect=[Path("/isolated"), Path("/registered")]), \
                patch.object(manage.subprocess, "run") as native:
            self.assertEqual(self.run_main(["--user-dir", "/isolated", "apply"])[0], 1)
            native.assert_not_called()


if __name__ == "__main__":
    unittest.main()
