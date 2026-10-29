# 万象拼音与万象语法模型

- 万象拼音：[amzxyz/rime-wanxiang](https://github.com/amzxyz/rime-wanxiang)
- 固定版本：Base `v17.10.3`
- Base 发布包 SHA-256：`b01a9d62a0717c15b4669ea237226f13028ebe017bd2ed728cf92a2c0151bf1a`
- 万象语法模型：[amzxyz/rime-wanxiang-data](https://github.com/amzxyz/rime-wanxiang-data)（原 RIME-LMDG）
- 模型：`wanxiang-lts-zh-hans.gram`（LTS，2026-10-26 发布资产）
- 固定 GitHub Asset ID：`676604065`，下载使用资产 API 与 `Accept: application/octet-stream`，不跟随可变的 LTS 文件地址。
- 模型 SHA-256：`e34500ab44626dc039a0641792ecba98ab63307646eb3d29186be56608ffe094`
- 模型大小：418,078,764 字节，约 399 MiB。
- 前一版已安装模型的 SHA-256：`9eedac1d836f3fdafb61b162035c8937253aedc106be40b2b957d9ab64e9ed89`。
- 更早版本已安装模型的 SHA-256：`8f1b2d3ed2b2755fdd445f6ab103eff613052080b62a0c049f4b166043a16ac4`；两个平台的检查脚本继续识别上述旧模型，不强制改写现有安装。
- 许可证：CC BY 4.0，完整文本见本目录 `LICENSE`。

`v17.10.3` 属于 `rime-wanxiang` 的 Base 方案包，模型则来自 `rime-wanxiang-data` 的 `LTS` 发布；手动下载请用[官方 LTS 模型链接](https://github.com/amzxyz/rime-wanxiang-data/releases/download/LTS/wanxiang-lts-zh-hans.gram)，不要套用方案包版本号。该 LTS 地址内容可能更新，自动安装仍获取上述固定资产并校验 SHA-256，缓存到 `.cache/wanxiang/models/676604065/`，不将模型纳入 Git；若固定资产被删除则报错，不自动切换模型或跳过校验。
