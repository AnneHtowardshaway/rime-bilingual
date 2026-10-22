#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
rime_dir=${RIME_USER_DIR:-"$HOME/Library/Rime"}
dry_run=0
case "${1:-}" in
  '') ;;
  --dry-run) dry_run=1 ;;
  *) printf '用法：%s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac
font_preset=${RIME_FONT_PRESET:-large}
case "$font_preset" in
  large|compact) ;;
  *) printf '错误：RIME_FONT_PRESET 只能是 large 或 compact。\n' >&2; exit 2 ;;
esac
squirrel_bin='/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel'
if [ "$dry_run" = '0' ] && [ "${RIME_SKIP_RELOAD:-0}" != '1' ] && [ ! -x "$squirrel_bin" ]; then
  printf '错误：请先安装 macOS 鼠须管。\n' >&2
  exit 1
fi
wanxiang_version='v17.10.3'
wanxiang_source="$project_root/.cache/wanxiang/$wanxiang_version/source"
wanxiang_model="$project_root/.cache/wanxiang/LTS/wanxiang-lts-zh-hans.gram"
backup_stamp="$(date '+%Y%m%d-%H%M%S')-$$"
backup_dir="$rime_dir/backups/qingjian-learning-$backup_stamp"
manifest="$backup_dir/deployed-files.txt"
manifest_source=$(mktemp "${TMPDIR:-/tmp}/rime-deploy-manifest.XXXXXX")

cleanup() {
  rm -f "$manifest_source"
}
trap cleanup EXIT HUP INT TERM

"$project_root/scripts/fetch-wanxiang.sh"

for relative_path in \
  default.yaml \
  wanxiang.schema.yaml \
  wanxiang.dict.yaml \
  wanxiang_algebra.yaml \
  wanxiang_symbols.yaml \
  wanxiang_mixedcode.schema.yaml \
  wanxiang_mixedcode.dict.yaml \
  wanxiang_reverse.schema.yaml \
  wanxiang_reverse.dict.yaml \
  wanxiang_english.schema.yaml \
  wanxiang_english.dict.yaml \
  version.txt
do
  test -f "$wanxiang_source/$relative_path"
  printf '%s\n' "$relative_path" >> "$manifest_source"
done

find "$wanxiang_source/lua" "$wanxiang_source/dicts" -type f -print \
  | sed "s#^$wanxiang_source/##" >> "$manifest_source"
printf '%s\n' 'wanxiang-lts-zh-hans.gram' >> "$manifest_source"

find "$project_root/rime" -type f ! -name rime.lua -print \
  | sed "s#^$project_root/rime/##" >> "$manifest_source"

printf '目标目录：%s\n字号：%s\n以下文件会被安装或替换（已有文件会先备份）：\n' "$rime_dir" "$font_preset"
LC_ALL=C sort -u "$manifest_source"
if [ "$dry_run" = '1' ]; then
  printf '预览结束，未修改输入法目录。下载缓存可能已更新。\n'
  exit 0
fi

mkdir -p "$backup_dir"
LC_ALL=C sort -u "$manifest_source" > "$manifest"

# 只备份本次要覆盖的文件；用户词库和其他方案不在变更范围内。
while IFS= read -r relative_path; do
  if [ -f "$rime_dir/$relative_path" ]; then
    mkdir -p "$backup_dir/previous/$(dirname -- "$relative_path")"
    cp -p "$rime_dir/$relative_path" "$backup_dir/previous/$relative_path"
  fi
done < "$manifest"

while IFS= read -r relative_path; do
  mkdir -p "$rime_dir/$(dirname -- "$relative_path")"
  cp -p "$wanxiang_source/$relative_path" "$rime_dir/$relative_path"
done <<'EOF'
default.yaml
wanxiang.schema.yaml
wanxiang.dict.yaml
wanxiang_algebra.yaml
wanxiang_symbols.yaml
wanxiang_mixedcode.schema.yaml
wanxiang_mixedcode.dict.yaml
wanxiang_reverse.schema.yaml
wanxiang_reverse.dict.yaml
wanxiang_english.schema.yaml
wanxiang_english.dict.yaml
version.txt
EOF

for directory in lua dicts; do
  find "$wanxiang_source/$directory" -type f -print | while IFS= read -r source_file; do
    relative_path=${source_file#"$wanxiang_source/"}
    mkdir -p "$rime_dir/$(dirname -- "$relative_path")"
    cp -p "$source_file" "$rime_dir/$relative_path"
  done
done

cp -p "$wanxiang_model" "$rime_dir/wanxiang-lts-zh-hans.gram"

while IFS= read -r relative_path; do
  mkdir -p "$rime_dir/$(dirname -- "$relative_path")"
  # 已有聚合词库可能包含用户私有 import_tables，保持其原有内容。
  if [ "$relative_path" = 'luna_pinyin.tech.dict.yaml' ] && [ -f "$rime_dir/$relative_path" ]; then
    continue
  fi
  cp -p "$project_root/rime/$relative_path" "$rime_dir/$relative_path"
done <<EOF
$(find "$project_root/rime" -type f ! -name rime.lua -print | sed "s#^$project_root/rime/##")
EOF

if [ "$font_preset" = 'compact' ]; then
  sed -e 's#style/font_point: 17#style/font_point: 15#' \
      -e 's#style/comment_font_point: 16#style/comment_font_point: 12#' \
      -e 's#style/line_spacing: 5#style/line_spacing: 3#' \
      "$project_root/rime/squirrel.custom.yaml" > "$rime_dir/squirrel.custom.yaml"
fi

printf '%s\n' "$backup_dir" > "$rime_dir/backups/.rime-bilingual-last-backup"

if [ "${RIME_SKIP_RELOAD:-0}" != '1' ]; then
  "$squirrel_bin" --reload
fi

printf '部署完成：万象 Base %s + 简体 LTS 语法模型。\n备份目录：%s\n' \
  "$wanxiang_version" "$backup_dir"
