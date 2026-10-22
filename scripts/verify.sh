#!/bin/sh
set -eu

rime_dir=${RIME_USER_DIR:-"$HOME/Library/Rime"}
built_wanxiang="$rime_dir/build/wanxiang.schema.yaml"
built_luna="$rime_dir/build/luna_pinyin_simp.schema.yaml"
built_theme="$rime_dir/build/squirrel.yaml"
model="$rime_dir/wanxiang-lts-zh-hans.gram"
expected_model_sha256='9eedac1d836f3fdafb61b162035c8937253aedc106be40b2b957d9ab64e9ed89'
legacy_model_sha256='8f1b2d3ed2b2755fdd445f6ab103eff613052080b62a0c049f4b166043a16ac4'

for path in \
  "$rime_dir/default.custom.yaml" \
  "$rime_dir/wanxiang.schema.yaml" \
  "$rime_dir/wanxiang.custom.yaml" \
  "$rime_dir/wanxiang.dict.yaml" \
  "$rime_dir/lua/wanxiang/wanxiang.lua" \
  "$rime_dir/dicts/jichu.dict.yaml" \
  "$rime_dir/lua/qingjian_gloss_filter.lua" \
  "$rime_dir/lua/internet_english_filter.lua" \
  "$rime_dir/data/internet-english.tsv" \
  "$rime_dir/data/programming-english.tsv" \
  "$rime_dir/data/qingjian-glossary-en.tsv" \
  "$rime_dir/langchain_agent.dict.yaml" \
  "$rime_dir/langchain_agent.schema.yaml" \
  "$model" \
  "$built_wanxiang" \
  "$built_luna" \
  "$built_theme"
do
  test -f "$path"
done

actual_model_sha256=$(shasum -a 256 "$model" | awk '{print $1}')
test "$actual_model_sha256" = "$expected_model_sha256" || test "$actual_model_sha256" = "$legacy_model_sha256"

grep -Fq 'schema_id: wanxiang' "$built_wanxiang"
grep -Eq 'language: "?wanxiang-lts-zh-hans"?' "$built_wanxiang"
grep -Fq 'dictionary: wanxiang' "$built_wanxiang"
grep -Fq 'page_size: 6' "$built_wanxiang"
grep -Fq 'lua_filter@*qingjian_gloss_filter' "$built_wanxiang"
grep -Fq 'lua_filter@*internet_english_filter' "$built_wanxiang"
awk '
  /lua_filter@\*wanxiang.super_sequence\*F/ { sequence = NR }
  /lua_filter@\*qingjian_gloss_filter/ { gloss = NR }
  /lua_filter@\*internet_english_filter/ { english = NR }
  /- uniquifier/ { unique = NR }
  END { exit !(sequence < gloss && gloss < english && english < unique) }
' "$built_wanxiang"

grep -Fq 'lua_filter@*qingjian_gloss_filter' "$built_luna"
grep -Fq 'lua_filter@*internet_english_filter' "$built_luna"
grep -Fq 'states: ["中文", "英文"]' "$built_luna"
grep -Fq 'qingjian_learning_light' "$built_theme"
grep -Fq 'qingjian_learning_dark' "$built_theme"

grep -Fq -- '- schema: wanxiang' "$rime_dir/default.custom.yaml"
grep -Fq -- '- schema: luna_pinyin_simp' "$rime_dir/default.custom.yaml"

for term in Overview LangChain LangGraph LangSmith 'Deep Agents' 'Managed Deep Agents' OpenWiki Integrations Learn Reference Contribute StateGraph ToolNode create_agent checkpointer ToolRuntime; do
  grep -Fq "${term}$(printf '\t')" "$rime_dir/langchain_agent.dict.yaml"
done

for word in 开发 编程 架构 计算机; do
  grep -Fq "${word}$(printf '\t')" "$rime_dir/data/qingjian-glossary-en.tsv"
done

printf '静态部署检查通过：方案编译产物、模型校验值与双语过滤链匹配；候选排序需运行真实引擎测试。\n'
