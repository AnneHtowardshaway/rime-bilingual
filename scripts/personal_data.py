#!/usr/bin/env python3
"""本地导出、检查和恢复 Rime 个人迁移包；不上传数据、不部署输入法。"""
import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import sys
import tempfile
import zipfile
import zlib

import phrases

FORMAT = "rime-bilingual-personal-data"
VERSION = 1
SETTINGS = ("custom_phrase.txt", "squirrel.personal.yaml", "weasel.personal.yaml", "user.yaml")
DATABASES = ("wanxiang", "sequence", "context_reorder", "en", "zc")
MAX_FILE = 32 * 1024 * 1024
MAX_TOTAL = 128 * 1024 * 1024
MAX_MANIFEST = 64 * 1024
MAX_ENTRIES = len(SETTINGS) + len(DATABASES) + 1


class MigrationError(ValueError):
    pass


class Parser(argparse.ArgumentParser):
    def error(self, message):
        self.exit(2, "参数无效；使用 --help 查看用法。\n")


def native():
    try:
        import rime_native
        return rime_native
    except ImportError:
        raise MigrationError("原生数据库工具不可用；可先使用 --settings-only。") from None


def reject_link(path):
    if path.is_symlink() or getattr(path, "is_junction", lambda: False)():
        raise MigrationError("不操作符号链接或目录联接。")


def user_directory(path):
    path = Path(os.path.abspath(Path(path).expanduser()))
    reject_link(path)
    if path.exists() and not path.is_dir():
        raise MigrationError("用户目录不是目录。")
    return path


def safe_child(root, relative):
    path = root / relative
    for parent in (path, *path.parents):
        reject_link(parent)
        if parent == root:
            return path
    raise MigrationError("个人数据路径越界。")


def fingerprint(info):
    return (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns,
            info.st_ctime_ns, stat.S_IMODE(info.st_mode))


def read_file(path, limit=MAX_FILE):
    reject_link(path)
    try:
        info = path.lstat()
        if not stat.S_ISREG(info.st_mode) or info.st_size > limit:
            raise MigrationError("个人数据必须为大小受限的普通文件。")
        fd = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
                     | getattr(os, "O_NONBLOCK", 0))
    except FileNotFoundError:
        return None, None
    with os.fdopen(fd, "rb") as source:
        before = os.fstat(source.fileno())
        if not stat.S_ISREG(before.st_mode):
            raise MigrationError("个人数据必须是普通文件。")
        data = source.read(limit + 1)
        after = os.fstat(source.fileno())
    if len(data) > limit or fingerprint(before) != fingerprint(after):
        raise MigrationError("个人数据过大或正在修改；本次操作已停止。")
    return data, fingerprint(after)


def atomic_write(path, data, expected):
    reject_link(path.parent)
    descriptor, filename = tempfile.mkstemp(prefix=".personal-data-", dir=path.parent)
    temporary = Path(filename)
    try:
        with os.fdopen(descriptor, "wb") as output:
            output.write(data)
            output.flush()
            os.fsync(output.fileno())
        os.chmod(temporary, expected[1][-1] if expected[1] else 0o600)
        if read_file(path, max(MAX_FILE, len(data))) != expected:
            raise MigrationError("检测到其他程序修改目标；未覆盖该文件。")
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


@contextmanager
def migration_lock(root):
    path = safe_child(root, ".personal-data.lock")
    try:
        fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except FileExistsError:
        raise MigrationError("另一个个人数据迁移尚未结束；请先确认其状态。") from None
    try:
        os.close(fd)
        yield
    finally:
        path.unlink(missing_ok=True)


def archive_kind(name):
    if name in {"settings/" + item for item in SETTINGS}:
        return "phrases" if name.endswith("/custom_phrase.txt") else "settings"
    if name in {"databases/" + item + ".userdb.txt" for item in DATABASES}:
        return "database"
    raise MigrationError("迁移包包含不支持的条目。")


def validate_name(name):
    if (not isinstance(name, str) or not name or "\\" in name or ":" in name
            or "\0" in name or name.startswith("/")
            or any(part in ("", ".", "..") for part in name.split("/"))
            or str(PurePosixPath(name)) != name):
        raise MigrationError("迁移包包含不安全路径。")
    if name != "manifest.json":
        archive_kind(name)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise MigrationError("迁移清单存在重复字段。")
        result[key] = value
    return result


def read_archive(path):
    reject_link(path)
    try:
        info = path.stat()
        if not stat.S_ISREG(info.st_mode) or info.st_size > MAX_TOTAL:
            raise MigrationError("迁移包必须是大小受限的普通 ZIP 文件。")
        with zipfile.ZipFile(path) as package:
            infos = package.infolist()
            if not 1 <= len(infos) <= MAX_ENTRIES:
                raise MigrationError("迁移包条目数量无效。")
            contents, names, total = {}, set(), 0
            for info in infos:
                validate_name(info.filename)
                folded = info.filename.casefold()
                if folded in names:
                    raise MigrationError("迁移包包含重复条目。")
                names.add(folded)
                mode = info.external_attr >> 16
                if ((stat.S_IFMT(mode) not in (0, stat.S_IFREG)) or info.is_dir()
                        or info.flag_bits & 1
                        or info.compress_type not in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED)):
                    raise MigrationError("迁移包包含链接、目录或不支持的压缩条目。")
                limit = MAX_MANIFEST if info.filename == "manifest.json" else MAX_FILE
                total += info.file_size
                if (info.file_size > limit or total > MAX_TOTAL
                        or (info.file_size > 1024 * 1024
                            and info.file_size > max(1, info.compress_size) * 2000)):
                    raise MigrationError("迁移包展开大小超出限制。")
                with package.open(info) as source:
                    data = source.read(limit + 1)
                if len(data) != info.file_size or len(data) > limit:
                    raise MigrationError("迁移包条目大小不匹配。")
                contents[info.filename] = data
            raw_manifest = contents.pop("manifest.json", None)
            if raw_manifest is None:
                raise MigrationError("迁移包缺少清单。")
            manifest = json.loads(raw_manifest.decode("utf-8"), object_pairs_hook=unique_object)
            if (not isinstance(manifest, dict) or manifest.get("format") != FORMAT
                    or type(manifest.get("version")) is not int or manifest["version"] != VERSION
                    or not isinstance(manifest.get("files"), list)):
                raise MigrationError("迁移包格式或版本不受支持。")
            declared = set()
            for item in manifest["files"]:
                if not isinstance(item, dict) or not isinstance(item.get("path"), str):
                    raise MigrationError("迁移清单条目无效。")
                name = item["path"]
                validate_name(name)
                if name == "manifest.json" or name in declared or name not in contents:
                    raise MigrationError("迁移清单与实际文件不一致。")
                data = contents[name]
                if (item.get("type") != archive_kind(name)
                        or type(item.get("size")) is not int or item["size"] != len(data)
                        or not isinstance(item.get("sha256"), str)
                        or not re.fullmatch(r"[0-9a-f]{64}", item["sha256"])
                        or hashlib.sha256(data).hexdigest() != item["sha256"]):
                    raise MigrationError("迁移包文件校验失败。")
                declared.add(name)
            if declared != set(contents):
                raise MigrationError("迁移清单与实际文件不一致。")
            return manifest, contents
    except (OSError, zipfile.BadZipFile, UnicodeError, json.JSONDecodeError,
            NotImplementedError, RuntimeError, TypeError, KeyError, EOFError, zlib.error):
        raise MigrationError("无法读取或校验迁移包。") from None


def backup(root, destination=None, settings_only=False):
    if not root.is_dir():
        raise MigrationError("用户目录不存在。")
    if not settings_only:
        try:
            native().assert_restore_ready(root)
        except RuntimeError:
            raise MigrationError("请先关闭输入法后导出学习数据；也可使用 --settings-only。") from None
    contents = {}
    for name in SETTINGS:
        data, _ = read_file(safe_child(root, name))
        if data is not None:
            contents["settings/" + name] = data
    with tempfile.TemporaryDirectory(prefix="rime-personal-export-") as work:
        output_dir = Path(work).resolve() / "databases"
        output_dir.mkdir(mode=0o700)
        if not settings_only:
            try:
                snapshots = native().backup_databases(root, output_dir)
            except RuntimeError:
                raise MigrationError("原生学习数据导出失败；请关闭输入法，或使用 --settings-only。") from None
            for snapshot in snapshots:
                snapshot = Path(snapshot)
                name = "databases/" + snapshot.name
                if snapshot.parent.resolve() != output_dir.resolve():
                    raise MigrationError("原生快照输出路径无效。")
                archive_kind(name)
                data, _ = read_file(snapshot)
                if data is None or name in contents:
                    raise MigrationError("原生快照输出无效。")
                contents[name] = data
        if sum(map(len, contents.values())) > MAX_TOTAL - MAX_MANIFEST:
            raise MigrationError("个人数据总大小超出迁移包限制。")
        manifest = {"format": FORMAT, "version": VERSION,
                    "created_at": datetime.now(timezone.utc).isoformat(),
                    "source_platform": sys.platform, "settings_only": settings_only,
                    "files": [{"path": name, "type": archive_kind(name), "size": len(data),
                               "sha256": hashlib.sha256(data).hexdigest()}
                              for name, data in sorted(contents.items())]}
        if destination is None:
            backups = safe_child(root, "backups")
            backups.mkdir(mode=0o700, exist_ok=True)
            destination = backups / ("personal-data-" + datetime.now().strftime("%Y%m%d-%H%M%S-%f") + ".rime-personal.zip")
        destination = Path(os.path.abspath(Path(destination).expanduser()))
        reject_link(destination.parent)
        if destination.exists() or destination.is_symlink():
            raise MigrationError("迁移包目标已存在；请使用新的文件名。")
        fd, filename = tempfile.mkstemp(prefix=".rime-personal-", suffix=".zip", dir=destination.parent)
        temporary = Path(filename)
        os.close(fd)
        try:
            with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED) as package:
                for name, data in {"manifest.json": json.dumps(manifest, ensure_ascii=False).encode("utf-8"), **contents}.items():
                    info = zipfile.ZipInfo(name)
                    info.create_system = 3
                    info.external_attr = (stat.S_IFREG | 0o600) << 16
                    info.compress_type = zipfile.ZIP_DEFLATED
                    package.writestr(info, data)
            read_archive(temporary)
            os.chmod(temporary, 0o600)
            if destination.exists():
                raise MigrationError("迁移包目标已被其他程序创建。")
            os.replace(temporary, destination)
        finally:
            temporary.unlink(missing_ok=True)
    return destination


def restore(root, archive, settings_only=False, replace_settings=False):
    _, contents = read_archive(archive)
    plans, conflicts = [], []
    for name in SETTINGS:
        data = contents.get("settings/" + name)
        if data is None:
            continue
        path = safe_child(root, name)
        original = read_file(path)
        if name == "custom_phrase.txt":
            rows = phrases.parse(original[0])
            changed = phrases.merge(rows, phrases.entries(phrases.parse(data)), False)
            if original[0] is not None and not changed:
                continue
            data = phrases.encode(rows)
        elif original[0] is not None and original[0] != data and not replace_settings:
            conflicts.append(name)
            continue
        if original[0] != data:
            plans.append((name, data, original))
    incoming = {name: data for name, data in contents.items()
                if name.startswith("databases/") and not settings_only}
    try:
        native().assert_restore_ready(root)
    except RuntimeError:
        raise MigrationError("请先关闭输入法再恢复个人数据；本次未写入。") from None
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    with migration_lock(root), phrases.lock(root):
        # 在创建恢复目录前再次核对全部目标，保证冲突不会造成部分写入。
        for name, _, original in plans:
            if read_file(safe_child(root, name)) != original:
                raise MigrationError("目标文件正在修改；本次未写入。")
        backups = safe_child(root, "backups")
        backups.mkdir(mode=0o700, exist_ok=True)
        recovery = Path(tempfile.mkdtemp(prefix="personal-restore-", dir=backups))
        previous = recovery / "settings"
        previous.mkdir(mode=0o700)
        for name, _, original in plans:
            if original[0] is not None:
                (previous / name).write_bytes(original[0])
        (recovery / "recovery.json").write_text(json.dumps({"version": 1, "files": [
            {"path": name, "existed": original[0] is not None} for name, _, original in plans]}, ensure_ascii=False), encoding="utf-8")
        applied = []
        native_recovery = None
        try:
            snapshots = []
            if incoming:
                (recovery / "database-snapshots").mkdir(mode=0o700)
                native().backup_databases(root, recovery / "database-snapshots")
                incoming_dir = recovery / "incoming-databases"
                incoming_dir.mkdir(mode=0o700)
                for name, data in incoming.items():
                    snapshot = incoming_dir / Path(name).name
                    snapshot.write_bytes(data)
                    snapshots.append(snapshot)
            native().assert_restore_ready(root)
            for name, data, original in plans:
                atomic_write(safe_child(root, name), data, original)
                applied.append((name, data, original))
            # 适配器在独立目录完成全部原生合并后才换入，并负责数据库目录回滚。
            if snapshots:
                native_recovery = native().restore_databases(root, snapshots)
        except Exception as error:
            rollback_ok = True
            for name, data, original in reversed(applied):
                try:
                    path = safe_child(root, name)
                    now = read_file(path)
                    if now[0] != data:
                        raise MigrationError("恢复期间文件被其他程序修改。")
                    if original[0] is None:
                        path.unlink()
                    else:
                        atomic_write(path, original[0], now)
                except (OSError, MigrationError):
                    rollback_ok = False
            status = "文本变更已回滚" if rollback_ok else "文本回滚未全部完成，请人工恢复"
            if not getattr(error, "rollback_complete", True):
                status += "；学习数据库回滚未全部完成"
            message = f"个人数据恢复失败，{status}。恢复材料：{recovery}"
            if isinstance(error, getattr(native(), "NativeRimeError", ())):
                message += f"；原生工具提示：{error}"
            native_recovery = getattr(error, "recovery_path", None)
            if native_recovery is not None:
                message += f"；原生数据库恢复材料：{native_recovery}"
            raise MigrationError(message) from None
    return {"changed": len(plans), "databases": len(incoming), "conflicts": conflicts,
            "recovery": recovery, "native_recovery": native_recovery}


def build_parser():
    parser = Parser(description=__doc__)
    parser.add_argument("--user-dir", help="Rime 用户目录；默认自动定位")
    commands = parser.add_subparsers(dest="command", required=True, parser_class=Parser)
    exporting = commands.add_parser("backup", help="生成本地个人迁移 ZIP")
    exporting.add_argument("output", nargs="?", help="新迁移包路径；默认放在用户目录 backups 下")
    exporting.add_argument("--settings-only", action="store_true", help="仅文本设置与常用语，不导出学习数据库")
    commands.add_parser("inspect", help="校验迁移包并显示条目类型").add_argument("archive")
    importing = commands.add_parser("restore", help="合并常用语和学习记录，保留已有冲突设置")
    importing.add_argument("archive")
    importing.add_argument("--settings-only", action="store_true", help="仅恢复文本设置与常用语")
    importing.add_argument("--replace-settings", action="store_true", help="备份后替换冲突个人设置；常用语仍采用合并")
    return parser


def main(argv=None):
    try:
        args = build_parser().parse_args(argv)
    except SystemExit as error:
        return int(error.code or 0)
    try:
        if args.command == "inspect":
            manifest, contents = read_archive(Path(args.archive).expanduser())
            print(f"迁移包校验通过，格式版本 {manifest['version']}，共 {len(contents)} 个条目。")
            for name in sorted(contents):
                print(f"{archive_kind(name)}\t{name}\t{len(contents[name])} bytes")
            return 0
        root = user_directory(args.user_dir if args.user_dir else phrases.default_user_dir())
        if args.command == "backup":
            destination = backup(root, args.output, args.settings_only)
            print(f"个人迁移包已生成：{destination}")
            print("迁移包包含私人数据，请自行妥善保管；本工具不会上传。")
        else:
            result = restore(root, Path(args.archive).expanduser(), args.settings_only, args.replace_settings)
            print(f"已恢复 {result['changed']} 个文本文件、{result['databases']} 个学习数据库。")
            if result["conflicts"]:
                print("已保留目标现有设置：" + "、".join(result["conflicts"]))
                print("需要替换时可明确使用 --replace-settings。")
            print(f"恢复前备份：{result['recovery']}")
            if result["native_recovery"]:
                print(f"原数据库保留在：{result['native_recovery']}")
            print("请重新启动并部署输入法后使用。")
        return 0
    except (MigrationError, phrases.PhraseError, OSError):
        # OSError 的路径或原生异常输出可能包含个人信息，不直接回显。
        error = sys.exc_info()[1]
        print(str(error) if isinstance(error, (MigrationError, phrases.PhraseError))
              else "文件操作失败；请检查路径、权限和可用空间。", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
