# 万象拼音与万象语法模型

- 万象拼音：[amzxyz/rime-wanxiang](https://github.com/amzxyz/rime-wanxiang)
- 固定版本：Base `v17.10.3`
- Base 发布包 SHA-256：`b01a9d62a0717c15b4669ea237226f13028ebe017bd2ed728cf92a2c0151bf1a`
- 万象语法模型：[amzxyz/RIME-LMDG](https://github.com/amzxyz/RIME-LMDG)
- 模型：`wanxiang-lts-zh-hans.gram`（LTS，2026-09-15 发布资产）
- 模型 SHA-256：`8f1b2d3ed2b2755fdd445f6ab103eff613052080b62a0c049f4b166043a16ac4`
- 许可证：CC BY 4.0，完整文本见本目录 `LICENSE`。

项目不将 400 MiB 语法模型纳入 Git；`scripts/fetch-wanxiang.sh` 会从上述官方 Release 获取固定资产、校验 SHA-256，再放入 `.cache/wanxiang/`。
