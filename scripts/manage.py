#!/usr/bin/env python3
"""本地管理菜单；所有数据操作由独立的常用语和迁移模块完成。"""
import os
from pathlib import Path
import subprocess
import sys

if sys.version_info < (3, 8):
    print("可选管理工具需要 Python 3.8 或更新版本。", file=sys.stderr)
    raise SystemExit(2)

import phrases
import personal_data


def apply_configuration(user_dir):
    target = phrases.resolve_user_dir(user_dir)
    registered = phrases.resolve_user_dir()
    if target != registered:
        raise ValueError("只能为输入法登记的用户目录请求重新部署；隔离目录请使用测试工具")
    if sys.platform == "darwin":
        binary = Path("/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel")
        arguments = [str(binary), "--reload"]
    elif os.name == "nt":
        import winreg
        directories = []
        if os.environ.get("RIME_WEASEL_DIR"):
            directories.append(Path(os.environ["RIME_WEASEL_DIR"]))
        for hive, key in ((winreg.HKEY_CURRENT_USER, r"Software\Rime\Weasel"),
                          (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Rime\Weasel"),
                          (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\WOW6432Node\Rime\Weasel")):
            try:
                with winreg.OpenKey(hive, key) as setting:
                    directories.append(Path(winreg.QueryValueEx(setting, "InstallDir")[0]))
            except OSError:
                pass
        binary = next((folder / "WeaselDeployer.exe" for folder in directories
                       if (folder / "WeaselDeployer.exe").is_file()), None)
        arguments = [str(binary), "/deploy"]
    else:
        raise ValueError("自动重新部署支持 macOS 鼠须管和 Windows 小狼毫")
    if binary is None or not binary.is_file():
        raise ValueError("未找到输入法程序，请先安装鼠须管或小狼毫")
    result = subprocess.run(arguments, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            text=True, timeout=120)
    if result.returncode:
        raise ValueError("输入法拒绝重新部署；常用语文件仍已保留，请从输入法菜单重试")
    print("已请求重新部署。请等待输入法完成编译后，再试输入新增短语。")
    return 0


def dispatch(command, arguments, user_dir):
    prefix = ["--user-dir", str(user_dir)] if user_dir else []
    if command == "phrases":
        return phrases.main(prefix + arguments)
    if command == "data":
        return personal_data.main(prefix + arguments)
    if command == "apply":
        if arguments:
            raise ValueError("apply 不接受额外参数")
        return apply_configuration(user_dir)
    raise ValueError("未知管理命令，运行 --help 查看用法")


def ask(label, required=True):
    value = input(label).strip()
    if required and not value:
        raise ValueError("输入不能为空")
    return value


def menu(user_dir):
    print("Rime 中英伴学 · 本地管理")
    print("用户目录：" + str(phrases.resolve_user_dir(user_dir)))
    while True:
        print("\n1 查看常用语    2 搜索常用语    3 添加常用语    4 删除一条常用语")
        print("5 导入常用语    6 导出常用语    7 备份个人数据  8 恢复个人数据")
        print("9 应用更改      0 退出")
        try:
            choice = input("选择操作：").strip()
            if choice == "0":
                return 0
            command, arguments = "phrases", []
            if choice == "1":
                arguments = ["list"]
            elif choice == "2":
                arguments = ["search", ask("关键词：")]
            elif choice == "3":
                text, code = ask("短语内容："), ask("小写输入编码：")
                weight = ask("权重（回车使用 1000）：", False) or "1000"
                arguments = ["add", text, code, "--weight", weight]
            elif choice == "4":
                arguments = ["remove", ask("输入编码："), "--text", ask("要删除的完整短语：")]
            elif choice in ("5", "6"):
                arguments = ["import" if choice == "5" else "export", ask("文件路径：")]
            elif choice == "7":
                command = "data"
                path = ask("备份路径（回车使用用户目录 backups）：", False)
                mode = ask("备份范围：1 常用语与设置；2 同时包含学习与排序：")
                if mode not in ("1", "2"):
                    raise ValueError("请选择 1 或 2")
                arguments = ["backup"] + ([path] if path else [])
                if mode == "1":
                    arguments.append("--settings-only")
                else:
                    print("包含学习记录时，请先退出输入法；工具不会自动结束输入法进程。")
            elif choice == "8":
                command = "data"
                path = ask("备份包路径：")
                mode = ask("恢复范围：1 常用语与设置；2 同时合并学习与排序：")
                if mode not in ("1", "2"):
                    raise ValueError("请选择 1 或 2")
                arguments = ["restore", path]
                if mode == "1":
                    arguments.append("--settings-only")
                print("恢复会合并常用语，保留已有个人设置；请先退出输入法。")
            elif choice == "9":
                command = "apply"
            else:
                raise ValueError("请选择菜单中的操作编号")
            dispatch(command, arguments, user_dir)
        except (ValueError, OSError) as error:
            print("操作未完成：" + str(error), file=sys.stderr)
        except (EOFError, KeyboardInterrupt):
            print()
            return 0


def main(argv=None):
    parser = phrases.Parser(description="管理本机常用语、个人数据和配置生效")
    parser.add_argument("--user-dir", help="指定 Rime 用户目录；默认读取本机目录")
    parser.add_argument("command", nargs="?", choices=("phrases", "data", "apply"),
                        help="不填时打开交互菜单；子命令加 --help 查看详情")
    try:
        arguments = list(sys.argv[1:] if argv is None else argv)
        # 子命令的 --help、--weight 等交给对应模块，避免根菜单抢先解析。
        split = 0
        while split < len(arguments):
            if arguments[split] == "--user-dir":
                split += 2
            elif arguments[split].startswith("--user-dir="):
                split += 1
            else:
                break
        split = min(split, len(arguments))
        leading = arguments[:split + 1] if split < len(arguments) else arguments
        options = parser.parse_args(leading)
        if options.command:
            return dispatch(options.command, arguments[split + 1:], options.user_dir)
        return menu(options.user_dir)
    except SystemExit as error:
        return error.code
    except (ValueError, OSError, subprocess.TimeoutExpired) as error:
        print("操作未完成：" + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
