#!/bin/sh
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if ! command -v python3 >/dev/null 2>&1; then
  printf '可选管理工具需要 Python 3.8 或更新版本；普通输入法安装不受影响。\n' >&2
  exit 1
fi
if ! python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)'; then
  printf '可选管理工具需要 Python 3.8 或更新版本。\n' >&2
  exit 1
fi
exec python3 -X utf8 "$script_dir/manage.py" "$@"
