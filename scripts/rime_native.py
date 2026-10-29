"""Offline, checked Rime user-dictionary snapshots using an installed native CLI.

Use backup/restore rather than export/import: native snapshots retain frequency,
logical versions and deletion tombstones. Normal input-method installation does
not depend on this optional Python module.
"""
from __future__ import annotations

from contextlib import contextmanager
from dataclasses import dataclass
import csv
import io
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


DATABASES = ("wanxiang", "sequence", "context_reorder", "en", "zc")
_SQUIRREL = Path("/Library/Input Methods/Squirrel.app/Contents/MacOS")
_TAIL = re.compile(r"c=(-?\d+) d=([+\-0-9.eE]+) t=(\d+)")


class NativeRimeError(RuntimeError):
    """A checked native operation failed; messages never contain dictionary rows."""

    def __init__(self, message: str, *, recovery_path: Path | None = None,
                 rollback_complete: bool = True):
        super().__init__(message)
        self.recovery_path = recovery_path
        self.rollback_complete = rollback_complete


@dataclass
class _Snapshot:
    name: str
    path: Path
    commits: dict[tuple[str, str], int]


def _root(directory: Path) -> Path:
    directory = Path(directory).expanduser().resolve()
    if directory == Path(directory.anchor):
        raise NativeRimeError("请使用独立的 Rime 用户目录。")
    if directory.exists() and not directory.is_dir():
        raise NativeRimeError(f"用户目录不是文件夹：{directory}")
    return directory


def _registered_directory() -> Path | None:
    if sys.platform == "darwin":
        return (Path.home() / "Library/Rime").resolve()
    if sys.platform == "win32":
        import winreg
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Rime\Weasel") as key:
                value, _ = winreg.QueryValueEx(key, "RimeUserDir")
            return Path(os.path.expandvars(value)).resolve()
        except FileNotFoundError:
            appdata = os.environ.get("APPDATA")
            return (Path(appdata) / "Rime").resolve() if appdata else None
    return None


def _input_method_running() -> bool:
    try:
        if sys.platform == "darwin":
            result = subprocess.run(["pgrep", "-x", "Squirrel"], capture_output=True,
                                    timeout=10, check=False)
            if result.returncode not in (0, 1):
                raise NativeRimeError("无法确认鼠须管是否已退出。")
            return result.returncode == 0
        if sys.platform == "win32":
            result = subprocess.run(["tasklist", "/FO", "CSV", "/NH"],
                                    capture_output=True, text=True, errors="replace",
                                    timeout=15, check=False)
            if result.returncode:
                raise NativeRimeError("无法确认小狼毫是否已退出。")
            names = {row[0].casefold() for row in csv.reader(io.StringIO(result.stdout)) if row}
            return bool(names & {"weaselserver.exe", "weaseldeployer.exe"})
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise NativeRimeError("无法检查输入法进程，请退出输入法后重试。") from exc
    return False


def _databases(user_dir: Path) -> list[str]:
    found = []
    for name in DATABASES:
        path = user_dir / f"{name}.userdb"
        if path.is_symlink() or (path.exists() and not path.is_dir()):
            raise NativeRimeError(f"用户数据库不是普通目录：{path}")
        if path.is_dir():
            found.append(name)
    return found


@contextmanager
def _check_lock(database: Path):
    lock = database / "LOCK"
    if lock.is_symlink():
        raise NativeRimeError(f"数据库锁文件不能是符号链接：{lock}")
    if not lock.exists():
        yield
        return
    try:
        with lock.open("r+b") as handle:
            if sys.platform == "win32":
                import msvcrt
                msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
                try:
                    yield
                finally:
                    handle.seek(0)
                    msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                import fcntl
                fcntl.lockf(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                try:
                    yield
                finally:
                    fcntl.lockf(handle.fileno(), fcntl.LOCK_UN)
    except OSError as exc:
        raise NativeRimeError(f"数据库正在使用或无法锁定，请先退出输入法：{database}") from exc


def assert_restore_ready(user_dir: Path) -> None:
    """Check the registered app and existing database locks; never create files.

    Empty test/new-machine directories are allowed. A real running input method
    blocks changes only to its registered directory, not to isolated fixtures.
    This check does not require rime_dict_manager (settings-only restores use it).
    """
    user_dir = _root(user_dir)
    if user_dir == _registered_directory() and _input_method_running():
        raise NativeRimeError("输入法仍在运行，请先退出鼠须管或小狼毫后重试。")
    for name in _databases(user_dir):
        with _check_lock(user_dir / f"{name}.userdb"):
            pass


def _manager() -> Path:
    configured = os.environ.get("RIME_DICT_MANAGER")
    if configured:
        candidate = Path(os.path.expandvars(configured)).expanduser()
        if not candidate.is_absolute():
            found = shutil.which(str(candidate))
            candidate = Path(found) if found else candidate.absolute()
    elif sys.platform == "darwin":
        candidate = _SQUIRREL / "rime_dict_manager"
    else:
        raise NativeRimeError("没有可用的原生词库管理 CLI；可使用仅设置迁移，或用 RIME_DICT_MANAGER 指定已安装的可信工具。")
    if not candidate.is_file() or (sys.platform != "win32" and not os.access(candidate, os.X_OK)):
        raise NativeRimeError(f"找不到可执行的 rime_dict_manager：{candidate}")
    return candidate.resolve()


def _run(manager: Path, user_dir: Path, *args: str) -> None:
    try:
        result = subprocess.run([str(manager), *map(str, args)], cwd=user_dir,
                                capture_output=True, timeout=120, check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise NativeRimeError(f"原生词库操作未完成（{args[0]}）：{user_dir}") from exc
    if result.returncode:
        raise NativeRimeError(f"原生词库操作失败（{args[0]}，退出码 {result.returncode}）：{user_dir}")


def _scalar(value: str) -> str:
    """Decode only installation.yaml scalar fields; reject complex YAML."""
    value = value.strip()
    if value.startswith('"'):
        try:
            parsed, end = json.JSONDecoder().raw_decode(value)
        except (ValueError, json.JSONDecodeError) as exc:
            raise NativeRimeError("installation.yaml 包含不支持的字符串格式。") from exc
        rest = value[end:].strip()
        if not isinstance(parsed, str) or (rest and not rest.startswith("#")):
            raise NativeRimeError("installation.yaml 的字段必须是单行字符串。")
        return parsed
    if value.startswith("'"):
        match = re.fullmatch(r"'((?:[^']|'')*)'\s*(?:#.*)?", value)
        if not match:
            raise NativeRimeError("installation.yaml 包含不支持的字符串格式。")
        return match[1].replace("''", "'")
    value = re.split(r"\s+#", value, maxsplit=1)[0].strip()
    if not value or value in ("null", "~"):
        return ""
    if value[0] in "[{}]&*!|>@`%?" or re.search(r":\s", value):
        raise NativeRimeError("installation.yaml 的安装 ID 和同步目录必须使用单行字符串。")
    return value


def _installation(user_dir: Path) -> tuple[str, Path]:
    values = {}
    path = user_dir / "installation.yaml"
    if path.is_file():
        try:
            lines = path.read_text(encoding="utf-8-sig").splitlines()
        except (OSError, UnicodeError) as exc:
            raise NativeRimeError(f"无法读取安装信息：{path}") from exc
        for line in lines:
            match = re.match(r"^(installation_id|sync_dir):\s*(.*)$", line)
            if match:
                if match[1] in values:
                    raise NativeRimeError(f"安装信息中有重复字段：{path}")
                values[match[1]] = _scalar(match[2])
    identity = values.get("installation_id") or "unknown"
    if identity in (".", "..") or any(char in identity for char in "/\\:\x00\r\n"):
        raise NativeRimeError(f"安装 ID 不能用作安全的同步子目录：{path}")
    sync_dir = Path(values.get("sync_dir") or "sync")
    if not sync_dir.is_absolute():
        sync_dir = user_dir / sync_dir
    return identity, sync_dir.resolve() / identity


def _snapshot(path: Path, expected: str | None = None) -> _Snapshot:
    if path.is_symlink() or not path.is_file():
        raise NativeRimeError(f"原生快照缺失或不是普通文件：{path}")
    try:
        text = path.read_text(encoding="utf-8-sig")
    except (OSError, UnicodeError) as exc:
        raise NativeRimeError(f"无法读取 UTF-8 原生快照：{path}") from exc
    metadata = {}
    records = {}
    for number, line in enumerate(text.split("\n"), 1):
        if line.endswith("\r"):
            line = line[:-1]
        if not line:
            continue
        if line.startswith("#@"):
            fields = line[2:].split("\t")
            if len(fields) != 2 or fields[0] in metadata:
                raise NativeRimeError(f"快照元数据格式不正确：{path}（第 {number} 行）")
            metadata[fields[0]] = fields[1]
            continue
        if line.startswith("#") and "\t" not in line:
            continue
        fields = line.split("\t")
        tail = _TAIL.fullmatch(fields[2]) if len(fields) == 3 else None
        if (not tail or not fields[0].endswith(" ") or not fields[0].strip()
                or not fields[1] or "\x00" in line or "\r" in line):
            raise NativeRimeError(f"快照记录格式不正确：{path}（第 {number} 行）")
        try:
            commits, dee, tick = int(tail[1]), float(tail[2]), int(tail[3])
        except ValueError as exc:
            raise NativeRimeError(f"快照记录数值不正确：{path}（第 {number} 行）") from exc
        if not -2147483648 <= commits <= 2147483647 or not math.isfinite(dee) or tick > 4294967295:
            raise NativeRimeError(f"快照记录超出可移植范围：{path}（第 {number} 行）")
        key = fields[0], fields[1]
        if key in records:
            raise NativeRimeError(f"快照包含重复记录：{path}（第 {number} 行）")
        records[key] = commits
    name = metadata.get("/db_name", "")
    if name.endswith(".userdb"):
        name = name[:-7]
    if (name not in DATABASES or metadata.get("/db_type") != "userdb"
            or not metadata.get("/rime_version") or (expected and name != expected)):
        raise NativeRimeError(f"快照的数据库名或类型不符合迁移范围：{path}")
    return _Snapshot(name, path, records)


def _signature(path: Path) -> tuple[int, int, int] | None:
    if not path.exists():
        return None
    if path.is_symlink() or not path.is_file():
        raise NativeRimeError(f"快照输出路径不是普通文件：{path}")
    stat = path.stat()
    return stat.st_mtime_ns, stat.st_ctime_ns, stat.st_size


def _backup_selected(user_dir: Path, output_dir: Path, names: list[str], manager: Path) -> list[Path]:
    _, sync_dir = _installation(user_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    outputs = []
    for name in names:
        native_output = sync_dir / f"{name}.userdb.txt"
        before = _signature(native_output)
        _run(manager, user_dir, "--backup", name)
        after = _signature(native_output)
        if after is None or after == before:
            raise NativeRimeError(f"原生工具未产生本次的新快照：{native_output}")
        _snapshot(native_output, name)
        destination = output_dir / native_output.name
        if destination.exists() or destination.is_symlink():
            raise NativeRimeError(f"快照目标已存在：{destination}")
        try:
            with tempfile.NamedTemporaryFile(dir=output_dir, prefix=".snapshot-", delete=False) as handle:
                temporary = Path(handle.name)
                handle.write(native_output.read_bytes())
                handle.flush()
                os.fsync(handle.fileno())
            temporary.replace(destination)
        except OSError as exc:
            if "temporary" in locals():
                temporary.unlink(missing_ok=True)
            raise NativeRimeError(f"无法写入备份快照：{destination}") from exc
        outputs.append(destination)
    return outputs


def backup_databases(user_dir: Path, output_dir: Path) -> list[Path]:
    """Create freshly verified native text snapshots for existing default DBs."""
    user_dir = _root(user_dir)
    assert_restore_ready(user_dir)
    names = _databases(user_dir)
    if not names:
        return []
    return _backup_selected(user_dir, Path(output_dir).resolve(), names, _manager())


def _database_signature(path: Path) -> tuple:
    if not path.exists():
        return ()
    result = []
    for child in sorted(path.rglob("*")):
        if child.is_symlink():
            raise NativeRimeError(f"数据库内部存在符号链接：{child}")
        stat = child.stat()
        result.append((str(child.relative_to(path)), stat.st_mtime_ns, stat.st_size))
    return tuple(result)


def restore_databases(user_dir: Path, snapshots: list[Path]) -> Path | None:
    """Merge validated snapshots in isolation, then swap all closed databases.

    No target database is replaced until all merges are re-backed-up and checked.
    Replacement errors are rolled back in reverse order, including newly created
    DBs. If filesystem errors prevent rollback, NativeRimeError exposes the
    retained recovery_path and rollback_complete=False; never delete that folder.
    """
    user_dir = _root(user_dir)
    assert_restore_ready(user_dir)
    incoming = [_snapshot(Path(path)) for path in snapshots]
    names = [item.name for item in incoming]
    if len(names) != len(set(names)):
        raise NativeRimeError("恢复材料包含重复的数据库快照。")
    if not names:
        return
    manager = _manager()
    user_dir.mkdir(parents=True, exist_ok=True)
    backups = user_dir / "backups"
    if backups.is_symlink() or (backups.exists() and not backups.is_dir()):
        raise NativeRimeError("数据库恢复备份位置必须是普通目录。")
    backups.mkdir(mode=0o700, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix="native-restore-", dir=backups))
    retain = False
    swapped = []
    withdrawn = []
    try:
        work = stage / "work"
        work.mkdir()
        identity, _ = _installation(user_dir)
        (work / "installation.yaml").write_text(
            "installation_id: " + json.dumps(identity, ensure_ascii=False)
            + "\nsync_dir: " + json.dumps(str(work / "sync"), ensure_ascii=False) + "\n",
            encoding="utf-8")
        existing = [name for name in names if (user_dir / f"{name}.userdb").is_dir()]
        originals = _backup_selected(user_dir, stage / "before", existing, manager)
        signatures = {name: _database_signature(user_dir / f"{name}.userdb") for name in names}
        expected = {name: {} for name in names}
        for source in [*originals, *[item.path for item in incoming]]:
            parsed = _snapshot(source)
            for key, commits in parsed.commits.items():
                old = expected[parsed.name].get(key, 0)
                expected[parsed.name][key] = commits if abs(commits) > abs(old) else old
            _run(manager, work, "--restore", str(source.resolve()))
        checked = _backup_selected(work, stage / "checked", names, manager)
        for source in checked:
            actual = _snapshot(source)
            if actual.commits != expected[actual.name]:
                raise NativeRimeError(f"原生合并结果未通过完整性检查：{actual.name}")
        assert_restore_ready(user_dir)
        if any(_database_signature(user_dir / f"{name}.userdb") != signatures[name] for name in names):
            raise NativeRimeError("恢复期间目标数据库发生变化，请退出其他词库工具后重试。")
        (stage / "withdrawn").mkdir()
        for name in names:
            destination = user_dir / f"{name}.userdb"
            if destination.exists():
                destination.replace(stage / "withdrawn" / destination.name)
                withdrawn.append(name)
            (work / destination.name).replace(destination)
            swapped.append(name)
        # 保留关闭中的原数据库；原生文本合并无法精确撤销新增记录。
        retain = True
        return stage
    except Exception as exc:
        rollback_errors = []
        for name in reversed(names):
            destination = user_dir / f"{name}.userdb"
            try:
                if name in swapped:
                    destination.replace(stage / "work" / destination.name)
                if name in withdrawn:
                    (stage / "withdrawn" / destination.name).replace(destination)
            except OSError:
                rollback_errors.append(name)
        if rollback_errors:
            retain = True
            raise NativeRimeError(f"数据库恢复失败，部分撤回未完成；请保留恢复目录：{stage}",
                                  recovery_path=stage, rollback_complete=False) from exc
        if isinstance(exc, NativeRimeError):
            raise
        raise NativeRimeError("数据库恢复未完成，目标数据库已撤回。") from exc
    finally:
        if not retain:
            shutil.rmtree(stage, ignore_errors=True)
