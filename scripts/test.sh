#!/bin/sh
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"
python3 tests/vocabulary_generator_spec.py
python3 tests/phrases_spec.py
python3 tests/rime_native_spec.py
python3 tests/personal_data_spec.py
python3 tests/manage_spec.py
python3 scripts/build-programming-vocabulary.py --check
python3 tests/run_lua.py
for script in scripts/*.sh; do sh -n "$script"; done
sh tests/rollback_spec.sh

if [ "${1:-}" = '--unit' ]; then exit 0; fi
if [ "$(uname -s)" != Darwin ]; then
  printf '真实引擎测试需要 macOS 鼠须管；其他平台使用 --unit。\n' >&2
  exit 1
fi
cache="$project_root/.cache/test"
mkdir -p "$cache"
header="$cache/rime_api.h"
expected='6eb5629162c44761e7b878f1b122f464de5c8685bd3cd5ac1e8519badc6d6424'
if [ ! -f "$header" ]; then
  curl -fL --retry 3 https://raw.githubusercontent.com/rime/librime/1.16.0/src/rime_api.h -o "$header"
fi
test "$(shasum -a 256 "$header" | awk '{print $1}')" = "$expected"
clang++ -std=c++17 -I "$cache" tests/rime_engine.cpp -o "$cache/rime-engine" \
  -Wl,-rpath,'/Library/Input Methods/Squirrel.app/Contents/Frameworks'
sandbox=$(mktemp -d "$cache/run.XXXXXX")
printf '原配置\n' > "$sandbox/default.custom.yaml"
printf '%s\n' '-- existing custom extension' > "$sandbox/rime.lua"
printf '星澜工作室\txinglangongzuoshi\t1000\n' > "$sandbox/custom_phrase.txt"
cat > "$sandbox/luna_pinyin.tech.dict.yaml" <<'EOF'
---
name: luna_pinyin.tech
import_tables:
  - luna_pinyin
  # existing private imports
  - private_user
...
EOF
cat > "$sandbox/private_user.dict.yaml" <<'EOF'
---
name: private_user
version: "1"
sort: by_weight
...
PRIVATE_SENTINEL	privateword	1000
EOF
mkdir -p "$sandbox/private.userdb"
printf 'private learning sentinel\n' > "$sandbox/private.userdb/sentinel"
RIME_USER_DIR="$sandbox" RIME_SKIP_RELOAD=1 RIME_FONT_PRESET=compact scripts/deploy.sh > "$sandbox/deploy.log"
cp tests/data/input-experience.tsv "$sandbox/data/input-experience.tsv"
printf '\n# private import added after installation\n' >> "$sandbox/luna_pinyin.tech.dict.yaml"
for schema in wanxiang; do
  "$cache/rime-engine" "$sandbox" "$schema" > "$sandbox/$schema.log" 2>&1 || {
    cat "$sandbox/$schema.log"; exit 1;
  }
  cat "$sandbox/$schema.log"
  "$cache/rime-engine" "$sandbox" "$schema" --check-learning
  "$cache/rime-engine" "$sandbox" "$schema" --check-options
done
RIME_USER_DIR="$sandbox" scripts/verify.sh
grep -Fq 'style/font_point: 15' "$sandbox/squirrel.custom.yaml"
grep -Fq -- '-- existing custom extension' "$sandbox/rime.lua"
grep -Fq -- '- private_user' "$sandbox/luna_pinyin.tech.dict.yaml"
grep -Fq -- '- private_user' "$sandbox/bilingual_english.dict.yaml"
! grep -Eq '^  - luna_pinyin$' "$sandbox/bilingual_english.dict.yaml"
grep -Fq -- '# private import added after installation' "$sandbox/luna_pinyin.tech.dict.yaml"
RIME_USER_DIR="$sandbox" RIME_SKIP_RELOAD=1 scripts/rollback.sh
test "$(cat "$sandbox/default.custom.yaml")" = '原配置'
test "$(cat "$sandbox/private.userdb/sentinel")" = 'private learning sentinel'
test "$(cat "$sandbox/custom_phrase.txt")" = "$(printf '星澜工作室\txinglangongzuoshi\t1000')"
test ! -e "$sandbox/lua/internet_english_filter.lua"
grep -Fq -- '- private_user' "$sandbox/luna_pinyin.tech.dict.yaml"
grep -Fq -- '# private import added after installation' "$sandbox/luna_pinyin.tech.dict.yaml"
grep -Fq -- '-- existing custom extension' "$sandbox/rime.lua"
printf '全部测试通过；真实引擎、部署与回滚记录：%s\n' "$sandbox"
sh tests/install_spec.sh
