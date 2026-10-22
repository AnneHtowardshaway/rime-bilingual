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
