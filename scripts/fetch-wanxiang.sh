#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cache_root="$project_root/.cache/wanxiang"
release_version='v17.10.3'
base_sha256='b01a9d62a0717c15b4669ea237226f13028ebe017bd2ed728cf92a2c0151bf1a'
model_sha256='e34500ab44626dc039a0641792ecba98ab63307646eb3d29186be56608ffe094'
model_asset_id='676604065'
base_url="https://github.com/amzxyz/rime-wanxiang/releases/download/$release_version/rime-wanxiang-base.zip"
model_url="https://api.github.com/repos/amzxyz/rime-wanxiang-data/releases/assets/$model_asset_id"
base_dir="$cache_root/$release_version"
model_dir="$cache_root/models/$model_asset_id"
base_archive="$base_dir/rime-wanxiang-base.zip"
model_file="$model_dir/wanxiang-lts-zh-hans.gram"
source_dir="$base_dir/source"

sha256_of() {
  shasum -a 256 "$1" | awk '{print $1}'
}

download() {
  url=$1
  destination=$2
  expected_sha256=$3
  label=$4

  if [ -f "$destination" ]; then
    actual_sha256=$(sha256_of "$destination")
    if [ "$actual_sha256" != "$expected_sha256" ]; then
      printf '错误：%s 缓存校验失败：%s\n' "$label" "$destination" >&2
      exit 1
    fi
    return
  fi

  temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/wanxiang-download.XXXXXX")
  temp_file="$temp_dir/$(basename -- "$destination")"

  if command -v aria2c >/dev/null 2>&1; then
    aria2c --max-tries=5 --retry-wait=2 --max-connection-per-server=4 \
      --header='Accept: application/octet-stream' \
      --split=4 --min-split-size=5M --dir="$temp_dir" \
      --out="$(basename -- "$destination")" "$url"
  else
    curl --http1.1 --retry 5 --retry-all-errors -H 'Accept: application/octet-stream' -fL "$url" -o "$temp_file"
  fi

  actual_sha256=$(sha256_of "$temp_file")
  if [ "$actual_sha256" != "$expected_sha256" ]; then
    printf '错误：%s 下载校验失败，期望 %s，实际 %s。\n' \
      "$label" "$expected_sha256" "$actual_sha256" >&2
    exit 1
  fi

  mkdir -p "$(dirname -- "$destination")"
  mv "$temp_file" "$destination"
  rmdir "$temp_dir"
}

mkdir -p "$base_dir" "$model_dir"
download "$base_url" "$base_archive" "$base_sha256" '万象 Base v17.10.3'
download "$model_url" "$model_file" "$model_sha256" '万象简体 LTS 语法模型'

if [ ! -f "$source_dir/wanxiang.schema.yaml" ]; then
  extract_dir=$(mktemp -d "${TMPDIR:-/tmp}/wanxiang-extract.XXXXXX")
  unzip -q "$base_archive" -d "$extract_dir"
  test -f "$extract_dir/wanxiang.schema.yaml"
  test -f "$extract_dir/lua/wanxiang/wanxiang.lua"
  test -f "$extract_dir/dicts/jichu.dict.yaml"
  mv "$extract_dir" "$source_dir"
fi

printf '万象资源已就绪：%s（Base %s + 简体 LTS 模型）\n' "$source_dir" "$release_version"
