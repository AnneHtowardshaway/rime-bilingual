#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# 使用已校验的缓存，在隔离目录验证安装冲突及中断恢复。
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sandbox=$(mktemp -d "$project_root/.cache/test/interrupted.XXXXXX")
mkdir -p "$sandbox/conflict/default.custom.yaml" "$sandbox/bin" "$sandbox/target"
if RIME_USER_DIR="$sandbox/conflict" RIME_SKIP_RELOAD=1 sh "$project_root/scripts/deploy.sh" --dry-run > "$sandbox/preview.log" 2>&1; then
  printf '安装预览未发现文件与目录冲突\n' >&2; exit 1
fi
if RIME_USER_DIR="$sandbox/conflict" RIME_SKIP_RELOAD=1 sh "$project_root/scripts/deploy.sh" > "$sandbox/conflict.log" 2>&1; then
  printf '安装未拒绝文件与目录冲突\n' >&2; exit 1
fi
test ! -e "$sandbox/conflict/default.yaml"
test ! -e "$sandbox/conflict/backups/.rime-bilingual-last-backup"

cat > "$sandbox/bin/cp" <<'EOF'
#!/bin/sh
for argument do destination=$argument; done
if [ "$destination" = "$RIME_USER_DIR/wanxiang.schema.yaml" ]; then exit 1; fi
exec /bin/cp "$@"
EOF
chmod +x "$sandbox/bin/cp"
printf 'original configuration\n' > "$sandbox/target/default.custom.yaml"
if PATH="$sandbox/bin:$PATH" RIME_USER_DIR="$sandbox/target" RIME_SKIP_RELOAD=1 sh "$project_root/scripts/deploy.sh" > "$sandbox/interrupted.log" 2>&1; then
  printf '中断模拟未生效\n' >&2; exit 1
fi
test -f "$sandbox/target/default.yaml"
test -f "$sandbox/target/backups/.rime-bilingual-last-backup"
RIME_USER_DIR="$sandbox/target" RIME_SKIP_RELOAD=1 sh "$project_root/scripts/rollback.sh" > "$sandbox/recovered.log"
test ! -e "$sandbox/target/default.yaml"
test "$(cat "$sandbox/target/default.custom.yaml")" = 'original configuration'
printf '安装恢复通过：同名目录冲突、中途复制失败与恢复入口\n'

# 使用微型安装源验证个人文件边界，不为文件操作测试复制整套词库与模型。
personal_project="$sandbox/personal-project"
personal_target="$sandbox/personal-target"
personal_source="$personal_project/.cache/wanxiang/v17.10.3/source"
mkdir -p "$personal_project/scripts" "$personal_project/rime" "$personal_target" \
  "$personal_source/lua" "$personal_source/dicts" "$personal_project/.cache/wanxiang/models/676604065"
cp "$project_root/scripts/deploy.sh" "$project_root/scripts/rollback.sh" "$personal_project/scripts/"
printf '#!/bin/sh\nexit 0\n' > "$personal_project/scripts/fetch-wanxiang.sh"
chmod +x "$personal_project/scripts/fetch-wanxiang.sh"
for relative_path in default.yaml wanxiang.schema.yaml wanxiang.dict.yaml wanxiang_algebra.yaml \
  wanxiang_symbols.yaml wanxiang_mixedcode.schema.yaml wanxiang_mixedcode.dict.yaml \
  wanxiang_reverse.schema.yaml wanxiang_reverse.dict.yaml wanxiang_english.schema.yaml \
  wanxiang_english.dict.yaml version.txt; do
  printf 'fixture\n' > "$personal_source/$relative_path"
done
printf 'fixture\n' > "$personal_source/lua/fixture.lua"
printf 'fixture\n' > "$personal_source/dicts/fixture.dict.yaml"
printf 'fixture\n' > "$personal_project/.cache/wanxiang/models/676604065/wanxiang-lts-zh-hans.gram"
printf 'patch: {}\n' > "$personal_project/rime/default.custom.yaml"
printf 'patch: {}\n' > "$personal_project/rime/squirrel.custom.yaml"
cat > "$personal_project/rime/bilingual_english.dict.yaml" <<'EOF'
---
name: bilingual_english
import_tables:
  - tech_english_table
...
EOF
# 即使本地安装源意外带有同名个人文件，也不能安装或覆盖。
for personal_file in squirrel.personal.yaml weasel.personal.yaml; do
  printf 'must never install\n' > "$personal_project/rime/$personal_file"
done
printf 'patch:\n  style/font_point: 14\n' > "$personal_target/squirrel.personal.yaml"
printf '# original custom app rules\n' > "$personal_target/squirrel.custom.yaml"
RIME_USER_DIR="$personal_target" RIME_SKIP_RELOAD=1 sh "$personal_project/scripts/deploy.sh" > "$sandbox/personal-first.log"
test "$(cat "$personal_target/squirrel.personal.yaml")" = "$(printf 'patch:\n  style/font_point: 14')"
test ! -e "$personal_target/weasel.personal.yaml"
personal_backup=$(sed -n '1p' "$personal_target/backups/.rime-bilingual-last-backup")
! grep -Fq '.personal.yaml' "$personal_backup/deployed-files.txt"
test "$(cat "$personal_backup/previous/squirrel.custom.yaml")" = '# original custom app rules'
grep -Fq "$personal_backup/previous/squirrel.custom.yaml" "$sandbox/personal-first.log"

printf '# edited between updates\n' >> "$personal_target/squirrel.personal.yaml"
printf 'patch:\n  style/font_point: 13\n' > "$personal_target/weasel.personal.yaml"
RIME_USER_DIR="$personal_target" RIME_SKIP_RELOAD=1 sh "$personal_project/scripts/deploy.sh" > "$sandbox/personal-update.log"
personal_backup=$(sed -n '1p' "$personal_target/backups/.rime-bilingual-last-backup")
! grep -Fq '.personal.yaml' "$personal_backup/deployed-files.txt"
for personal_file in squirrel.personal.yaml weasel.personal.yaml; do
  test ! -e "$personal_backup/previous/$personal_file"
  printf '# edited after update\n' >> "$personal_target/$personal_file"
done
RIME_USER_DIR="$personal_target" RIME_SKIP_RELOAD=1 sh "$personal_project/scripts/rollback.sh" > "$sandbox/personal-rollback.log"
test "$(cat "$personal_target/squirrel.personal.yaml")" = "$(printf 'patch:\n  style/font_point: 14\n# edited between updates\n# edited after update')"
test "$(cat "$personal_target/weasel.personal.yaml")" = "$(printf 'patch:\n  style/font_point: 13\n# edited after update')"
printf '个人配置保护通过：安装源排除、重复更新、回滚保留及旧配置迁移入口\n'
