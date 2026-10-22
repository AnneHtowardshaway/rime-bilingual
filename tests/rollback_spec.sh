#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$project_root/.cache/test"
sandbox=$(mktemp -d "$project_root/.cache/test/rollback.XXXXXX")
backup="$sandbox/backups/qingjian-learning-test"
mkdir -p "$backup/previous"
printf 'default.custom.yaml\nnew-file.txt\nluna_pinyin.tech.dict.yaml\n' > "$backup/deployed-files.txt"
printf '%s\n' "$backup" > "$sandbox/backups/.rime-bilingual-last-backup"
printf 'before\n' > "$backup/previous/default.custom.yaml"
printf 'installed\n' > "$sandbox/default.custom.yaml"
printf 'new file\n' > "$sandbox/new-file.txt"
printf 'old private imports\n' > "$backup/previous/luna_pinyin.tech.dict.yaml"
printf 'private imports added later\n' > "$sandbox/luna_pinyin.tech.dict.yaml"

# 损坏的清单必须在开始移动文件前被完整拒绝。
printf '../outside\n' >> "$backup/deployed-files.txt"
if RIME_USER_DIR="$sandbox" RIME_SKIP_RELOAD=1 sh "$project_root/scripts/rollback.sh" > "$sandbox/rejected.log" 2>&1; then
  printf '损坏的回滚清单未被拒绝\n' >&2; exit 1
fi
test "$(cat "$sandbox/default.custom.yaml")" = installed
printf 'default.custom.yaml\nnew-file.txt\nluna_pinyin.tech.dict.yaml\n' > "$backup/deployed-files.txt"
RIME_USER_DIR="$sandbox" RIME_SKIP_RELOAD=1 sh "$project_root/scripts/rollback.sh" > "$sandbox/rollback.log"
test "$(cat "$sandbox/default.custom.yaml")" = before
test ! -e "$sandbox/new-file.txt"
test "$(cat "$sandbox/luna_pinyin.tech.dict.yaml")" = 'private imports added later'
printf 'after rollback\n' > "$sandbox/default.custom.yaml"
printf 'user new file\n' > "$sandbox/new-file.txt"
if RIME_USER_DIR="$sandbox" RIME_SKIP_RELOAD=1 sh "$project_root/scripts/rollback.sh" >> "$sandbox/rejected.log" 2>&1; then
  printf '重复回滚未被拒绝\n' >&2; exit 1
fi
test "$(cat "$sandbox/default.custom.yaml")" = 'after rollback'
test "$(cat "$sandbox/new-file.txt")" = 'user new file'
printf '回滚保护通过：损坏清单、旧版私人词库、重复回滚及回滚后新增文件\n'
