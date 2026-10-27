"""公开词表生成器回归，不读取输入法用户目录。"""
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("vocabulary_builder", ROOT / "scripts/build-programming-vocabulary.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class VocabularyGeneratorSpec(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.rime = Path(self.temporary.name)
        builder.RIME = self.rime
        (self.rime / "data").mkdir()
        (self.rime / "data/internet-english.tsv").write_text("github\tGitHub\t代码托管\n", encoding="utf-8")
        for name in builder.SUPPLEMENTS:
            self.dictionary(name, "")

    def tearDown(self):
        self.temporary.cleanup()

    def dictionary(self, name, body, imports=()):
        header = f"---\nname: {name}\n"
        if imports:
            header += "import_tables:\n" + "".join(f"  - {item}\n" for item in imports)
        (self.rime / (name + ".dict.yaml")).write_text(header + "...\n" + body, encoding="utf-8")

    def test_import_comments_weights_and_internet_priority(self):
        self.dictionary("tech_english_table", "Parent\tshared\t100\nwrong\tgithub\t10000\n", ["tech_english_go # standard library"])
        self.dictionary("tech_english_go", "Child\tshared\t200\nAlpha\talpha\t100\n")
        result = builder.render()
        self.assertIn("shared\tChild\tGo · 库与 API", result)
        self.assertNotIn("github\t", result)
        self.assertLess(result.index("alpha\t"), result.index("shared\t"))

    def test_short_codes_and_numeric_selection_keys(self):
        self.dictionary("tech_english_table", "Go\tgo\t100\nJavaScript\tjs\t100\nTypeScript\tts\t100\nC\tc\t100\nif\tif\t100\nKubernetes\tk8s\t100\nsqlite3\tpythonsqlite\t100\n")
        result = builder.render()
        for code in ("go", "js", "ts", "pythonsqlite"):
            self.assertIn("\n" + code + "\t", result)
        for code in ("c", "if", "k8s"):
            self.assertNotIn("\n" + code + "\t", result)

    def test_import_cycle_is_rejected(self):
        self.dictionary("tech_english_table", "", ["tech_english_go"])
        self.dictionary("tech_english_go", "", ["tech_english_table"])
        with self.assertRaisesRegex(ValueError, "循环"):
            builder.render()

    def test_supplements_preserve_programming_and_daily_words(self):
        self.dictionary("tech_english_table", "UPDATE\tupdate\t100\nOk\tok\t9999\n")
        self.dictionary("daily_english", "book\tbook\t100\nupdate\tupdate\t100\nhi\thi\t100\nok\tok\t100\n")
        self.dictionary("electronics_english", "MacBook\tbook\t9999\nMacBook\tmacbook\t9999\n")
        self.dictionary("ai_english", "DALL·E\tdalle\t100\n")
        result = builder.render()
        self.assertIn("update\tUPDATE\t", result)
        self.assertIn("book\tbook\t日常英语", result)
        self.assertIn("macbook\tMacBook\t设备", result)
        self.assertIn("dalle\tDALL·E\tAI", result)
        self.assertIn("hi\thi\t日常英语", result)
        self.assertIn("ok\tok\t日常英语", result)
        self.assertNotIn("\nbook\tMacBook\t", result)

    def test_private_path_import_is_rejected(self):
        self.dictionary("tech_english_table", "", ["../private"])
        with self.assertRaisesRegex(ValueError, "非法"):
            builder.render()

    def test_malformed_row_is_rejected(self):
        self.dictionary("tech_english_table", "broken\trow\n")
        with self.assertRaisesRegex(ValueError, "格式错误"):
            builder.render()


if __name__ == "__main__":
    unittest.main()
