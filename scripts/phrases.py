#!/usr/bin/env python3
"""本地管理 Rime custom_phrase.txt；不执行输入法部署。"""
import argparse
from contextlib import contextmanager
from datetime import datetime
import os
from pathlib import Path
import re
import stat
import sys
import tempfile


class PhraseError(ValueError):
    pass


class Parser(argparse.ArgumentParser):
    def error(self, message):
        # argparse 默认错误可能回显包含私人短语的参数。
        self.exit(2, "参数无效；使用 --help 查看用法。\n")


def default_user_dir():
    if sys.platform == "win32":
        try:
            import winreg
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Rime\Weasel") as key:
                directory, _ = winreg.QueryValueEx(key, "RimeUserDir")
            if directory:
                return Path(os.path.expandvars(directory))
        except OSError:
            pass
        if os.environ.get("APPDATA"):
            return Path(os.environ["APPDATA"]) / "Rime"
        raise PhraseError("无法定位小狼毫用户目录，请指定 --user-dir。")
    if sys.platform == "darwin":
        return Path.home() / "Library/Rime"
    raise PhraseError("请使用 --user-dir 指定 Rime 用户目录。")


def absolute(path):
    return Path(os.path.abspath(Path(path).expanduser()))


def resolve_user_dir(path=None):
    return absolute(path) if path else absolute(default_user_dir())


def reject_link(path):
    if path.is_symlink() or getattr(path, "is_junction", lambda: False)():
        raise PhraseError("为保护原文件，不操作符号链接或目录联接。")
    if os.name == "nt" and path.exists():
        attributes = getattr(path.lstat(), "st_file_attributes", 0)
        if attributes & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400):
            raise PhraseError("为保护原文件，不操作 Windows 重解析点。")


def directory(path, create=False):
    reject_link(path)
    if create:
        path.mkdir(parents=True, exist_ok=True, mode=0o700)
    if path.exists() and not path.is_dir():
        raise PhraseError("指定的用户目录或备份位置不是目录。")


def fingerprint(info):
    return (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns,
            info.st_ctime_ns, stat.S_IMODE(info.st_mode))


def snapshot(path):
    reject_link(path)
    try:
        if not stat.S_ISREG(path.lstat().st_mode):
            raise PhraseError("常用语或导入文件必须是普通文件。")
        descriptor = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
                             | getattr(os, "O_NONBLOCK", 0))
    except FileNotFoundError:
        return None, None
    with os.fdopen(descriptor, "rb") as source:
        before = os.fstat(source.fileno())
        if not stat.S_ISREG(before.st_mode):
            raise PhraseError("常用语或导入文件必须是普通文件。")
        data = source.read()
        after = os.fstat(source.fileno())
    if fingerprint(before) != fingerprint(after):
        raise PhraseError("文件正在被其他程序修改，请稍后重试。")
    return data, fingerprint(after)


def validate(text, code, weight):
    if text.startswith(("#", "\ufeff")):
        raise PhraseError("短语不能以注释符 # 或 BOM 字符开头。")
    if not text or text != text.strip() or any(ord(c) < 32 or ord(c) == 127
                                              or c in "\x85\u2028\u2029" for c in text):
        raise PhraseError("短语不可为空、首尾有空白或包含 Tab、换行等控制字符。")
    if not re.fullmatch(r"[a-z]+", code):
        raise PhraseError("编码只能使用完整小写英文字母。")
    if not 1 <= weight <= 2147483647:
        raise PhraseError("权重必须是 1 至 2147483647 的整数。")


def parse(data):
    try:
        content = (data or b"").decode("utf-8-sig")
    except UnicodeDecodeError:
        raise PhraseError("文件必须使用 UTF-8 编码。") from None
    rows, seen = [], {}
    for number, line in enumerate(content.splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            rows.append(line)
            continue
        fields = line.split("\t")
        if len(fields) != 3:
            raise PhraseError(f"第 {number} 行应为短语、编码、权重三列，以真正的 Tab 分隔。")
        try:
            if not re.fullmatch(r"[0-9]+", fields[2]):
                raise ValueError
            text, code, weight = fields[0], fields[1], int(fields[2])
            validate(text, code, weight)
        except ValueError:
            raise PhraseError(f"第 {number} 行的短语、编码或权重无效。") from None
        key = (text, code)
        if key in seen:
            if seen[key] != weight:
                raise PhraseError(f"第 {number} 行的重复词条存在权重冲突。")
            continue
        seen[key] = weight
        rows.append((text, code, weight))
    return rows


def entries(rows):
    return [row for row in rows if isinstance(row, tuple)]


def encode(rows):
    lines = [row if isinstance(row, str) else "\t".join(map(str, row)) for row in rows]
    return ("\n".join(lines) + ("\n" if lines else "")).encode("utf-8")


@contextmanager
def lock(user_dir):
    path = user_dir / ".custom_phrase.lock"
    try:
        descriptor = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except FileExistsError:
        raise PhraseError("另一个常用语管理操作尚未结束；确认没有运行后可删除 .custom_phrase.lock。") from None
    try:
        os.close(descriptor)
        yield
    finally:
        path.unlink()


def write_backup(user_dir, data):
    backup_dir = user_dir / "backups"
    directory(backup_dir, create=True)
    prefix = "phrases-" + datetime.now().strftime("%Y%m%d-%H%M%S-")
    descriptor, filename = tempfile.mkstemp(prefix=prefix, suffix=".txt", dir=backup_dir)
    try:
        with os.fdopen(descriptor, "wb") as backup:
            backup.write(data)
            backup.flush()
            os.fsync(backup.fileno())
    except OSError:
        Path(filename).unlink(missing_ok=True)
        raise
    return Path(filename)


def atomic_write(path, data, expected):
    directory(path.parent)
    mode = expected[1][-1] if expected[1] is not None else 0o600
    descriptor, filename = tempfile.mkstemp(prefix=".custom-phrase-", dir=path.parent)
    temporary = Path(filename)
    try:
        with os.fdopen(descriptor, "wb") as target:
            target.write(data)
            target.flush()
            os.fsync(target.fileno())
        os.chmod(temporary, mode)
        if snapshot(path) != expected:
            raise PhraseError("检测到其他程序修改文件，本次操作已停止；请重新查看后重试。")
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def merge(rows, additions, update):
    locations = {(row[0], row[1]): i for i, row in enumerate(rows) if isinstance(row, tuple)}
    changed = 0
    for row in additions:
        key = row[:2]
        if key not in locations:
            locations[key] = len(rows)
            rows.append(row)
            changed += 1
        elif update and rows[locations[key]] != row:
            rows[locations[key]] = row
            changed += 1
    return changed


def mutate(user_dir, operation):
    directory(user_dir, create=True)
    with lock(user_dir):
        target = user_dir / "custom_phrase.txt"
        original = snapshot(target)
        rows = parse(original[0])
        changed = operation(rows)
        if not changed:
            print("没有需要写入的变更。")
            return
        backup = write_backup(user_dir, original[0]) if original[0] is not None else None
        atomic_write(target, encode(rows), original)
    print(f"已更新常用语，共 {changed} 条变更。")
    if backup:
        print(f"原文件备份：{backup}")
    print("请通过输入法菜单重新部署后使用。")


def build_parser():
    parser = Parser(description=__doc__, epilog="私人短语仅保存在指定用户目录；同码可有多个短语。")
    parser.add_argument("--user-dir", help="Rime 用户目录；默认自动定位鼠须管/小狼毫")
    commands = parser.add_subparsers(dest="command", required=True, parser_class=Parser)
    commands.add_parser("list", help="显示全部常用语（三列 Tab）")
    commands.add_parser("search", help="按短语或编码包含匹配").add_argument("query")
    add = commands.add_parser("add", help="新增短语；更新已有权重需 --update")
    add.add_argument("text", help="短语内容，含空格时加引号")
    add.add_argument("code", help="完整小写编码")
    add.add_argument("--weight", type=int, help="权重，新增默认 1000；更新时必填")
    add.add_argument("--update", action="store_true", help="显式更新已有词条的权重")
    remove = commands.add_parser("remove", help="删除编码下全部短语；--text 可指定一条")
    remove.add_argument("code")
    remove.add_argument("--text", help="只删除与此短语及编码同时匹配的词条")
    incoming = commands.add_parser("import", help="合并 UTF-8 三列 Tab 文件")
    incoming.add_argument("file")
    incoming.add_argument("--update", action="store_true", help="显式更新重复词条的权重")
    outgoing = commands.add_parser("export", help="导出 UTF-8 三列 Tab 文件")
    outgoing.add_argument("file")
    outgoing.add_argument("--force", action="store_true", help="允许替换已有导出文件")
    return parser


def run(args):
    user_dir = resolve_user_dir(args.user_dir)
    directory(user_dir)
    target = user_dir / "custom_phrase.txt"
    if args.command in ("list", "search", "export"):
        rows = parse(snapshot(target)[0])
        if args.command == "export":
            destination = absolute(args.file)
            if destination == target or (destination.exists() and target.exists()
                                         and os.path.samefile(destination, target)):
                raise PhraseError("导出目标不能是正在使用的常用语文件。")
            existing = snapshot(destination)
            if existing[0] is not None and not args.force:
                raise PhraseError("导出目标已存在；需要替换时使用 --force。")
            atomic_write(destination, encode(rows), existing)
            print("常用语已导出。")
        else:
            for row in entries(rows):
                if args.command == "list" or args.query.casefold() in "\t".join(row[:2]).casefold():
                    print("\t".join(map(str, row)))
        return
    if args.command == "add":
        if args.update and args.weight is None:
            raise PhraseError("更新已有词条时，请通过 --weight 明确指定权重。")
        weight = args.weight if args.weight is not None else 1000
        validate(args.text, args.code, weight)
        mutate(user_dir, lambda rows: merge(rows, [(args.text, args.code, weight)], args.update))
    elif args.command == "import":
        incoming = snapshot(absolute(args.file))[0]
        if incoming is None:
            raise PhraseError("导入文件不存在。")
        additions = entries(parse(incoming))
        mutate(user_dir, lambda rows: merge(rows, additions, args.update))
    elif args.command == "remove":
        validate(args.text if args.text is not None else "删除", args.code, 1)
        def remove(rows):
            before = len(rows)
            rows[:] = [row for row in rows if not (isinstance(row, tuple) and row[1] == args.code
                       and (args.text is None or row[0] == args.text))]
            return before - len(rows)
        mutate(user_dir, remove)


def main(argv=None):
    try:
        args = build_parser().parse_args(argv)
        run(args)
        return 0
    except SystemExit as error:
        return int(error.code or 0)
    except (PhraseError, OSError):
        # 不输出异常中的用户内容、导入原行或系统路径。
        error = sys.exc_info()[1]
        print("错误：" + (str(error) if isinstance(error, PhraseError) else "文件操作失败，请检查目录、权限及文件占用。"), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
