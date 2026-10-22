#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
rime_dir=${RIME_USER_DIR:-"$HOME/Library/Rime"}
backup_file="$rime_dir/backups/.rime-bilingual-last-backup"
if [ ! -f "$backup_file" ]; then
  backup_file="$project_root/.last-backup"
fi

if [ ! -f "$backup_file" ]; then
  printf '错误：没有找到最近一次部署的备份记录。\n' >&2
  exit 1
fi

backup_dir=$(sed -n '1p' "$backup_file")
case "$backup_dir" in
  "$rime_dir"/backups/qingjian-learning-*) ;;
  *)
    printf '错误：备份路径不在允许范围内：%s\n' "$backup_dir" >&2
    exit 1
    ;;
esac

manifest="$backup_dir/deployed-files.txt"
if [ ! -f "$manifest" ]; then
  printf '错误：备份缺少部署清单：%s\n' "$manifest" >&2
  exit 1
fi

# 回滚前一次性校验整张清单，避免恢复到一半才发现路径非法。
while IFS= read -r relative_path; do
  case "$relative_path" in
    ''|/*|..|*/..|*../*|../*)
      printf '错误：部署清单包含非法路径：%s\n' "$relative_path" >&2
      exit 1 ;;
  esac
done < "$manifest"

# 先保留当前安装文件，再恢复部署前版本；回滚本身仍可追溯。
rollback_stamp=$(date '+%Y%m%d-%H%M%S')
installed_dir="$backup_dir/rolled-back-$rollback_stamp"

while IFS= read -r relative_path; do
  case "$relative_path" in
    ''|/*|*../*|../*)
      printf '错误：部署清单包含非法路径：%s\n' "$relative_path" >&2
      exit 1
      ;;
  esac

  if [ -f "$rime_dir/$relative_path" ]; then
    mkdir -p "$installed_dir/$(dirname -- "$relative_path")"
    mv "$rime_dir/$relative_path" "$installed_dir/$relative_path"
  fi
  if [ -f "$backup_dir/previous/$relative_path" ]; then
    mkdir -p "$rime_dir/$(dirname -- "$relative_path")"
    cp -p "$backup_dir/previous/$relative_path" "$rime_dir/$relative_path"
  fi
done < "$manifest"

if [ "${RIME_SKIP_RELOAD:-0}" != '1' ]; then
  squirrel_bin='/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel'
  if [ ! -x "$squirrel_bin" ]; then
    printf '错误：找不到鼠须管命令：%s\n' "$squirrel_bin" >&2
    exit 1
  fi
  "$squirrel_bin" --reload
fi

printf '已恢复部署前备份：%s\n被撤回的当前文件保留在：%s\n' \
  "$backup_dir" "$installed_dir"
