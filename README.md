# 鼠须管 / 小狼毫中英伴学 · Rime Bilingual

输入中文，在候选词旁看到英文释义；输入常用英文，直接选择规范英文候选。

支持 macOS [鼠须管 Squirrel](https://github.com/rime/squirrel) 与 Windows [小狼毫 Weasel](https://github.com/rime/weasel)，适配万象拼音与朙月拼音·简化字。英文释义使用青简的离线词表，运行时无需联网。

```text
中文模式输入 github：
1. Git湖北
2. GitHub     代码托管
3. Git
```

以上为朙月拼音的真实引擎示例。第一个候选由原方案及用户学习决定；精确命中的英文固定插入第二项。若原方案只有该英文一个候选，则保留一个规范英文候选。

## 功能

- 中文候选旁显示英文词性与释义，默认最多两项。
- 内置 196 个常用英文编码，包含 GitHub、GitLab、Docker、ChatGPT、JavaScript、VS Code 等。
- 完整小写编码精确匹配，不做英文前缀联想；未命中的输入沿用原候选顺序。
- 支持关闭英文候选、关闭英文释义。
- 自动适配系统浅色与深色外观，提供大字号与紧凑字号。
- 保留朙月拼音的 `;github` / `vvgithub` 技术英文入口及现有专业词典。
- 安装前预览、覆盖前备份、按文件清单回滚；不收集输入内容。

这是 Rime 配置与 Lua 扩展，不是独立输入法。Windows 安装脚本面向 Windows 10/11、小狼毫 0.17.4 及以上，兼容系统自带 Windows PowerShell 5.1 与 PowerShell 7。Windows ARM64、Linux 桌面平台尚未验证。没有云端翻译、译词一键替换或学习计数功能。

2026-10-22 本机验证环境：macOS 26.5.2、鼠须管 1.1.2、librime 1.16.0。Windows CI 在 Windows Server 2022 x64 上，使用官方小狼毫 0.17.4 的 `rime.dll` 持续验证 PowerShell 5.1/7 安装、真实引擎候选、数字键上屏与回滚，结果见 [Actions](https://github.com/AnneHtowardshaway/rime-bilingual/actions)。原生候选窗口外观、Windows 桌面应用和 ARM64 仍需实机验收。

## 安装

### macOS 鼠须管

先安装并启用[鼠须管](https://github.com/rime/squirrel/releases)，然后克隆仓库：

```sh
git clone https://github.com/AnneHtowardshaway/rime-bilingual.git
cd rime-bilingual

# 预览安装文件；首次仍会下载并校验上游资源
./scripts/deploy.sh --dry-run

# 安装、备份并通知鼠须管重新部署
./scripts/deploy.sh
```

默认安装到 `$HOME/Library/Rime`。首次需要联网下载约 34 MiB 万象 Base 发布包和约 380 MiB 语法模型，随后运行完全离线。下载使用固定版本、模型资产 ID 与 SHA-256 校验；校验失败或上游删除资产时会终止，不跟随可变的 LTS 下载地址，也不使用未知版本替代。

部署后等待鼠须管部署完成，按 **Control + grave**（重音符键）或 **F4** 打开方案选单，选择“万象拼音”或“朙月拼音·简化字”。输入 `github`，按数字 **2** 应输出 `GitHub`。

笔记本或普通显示器可安装紧凑字号：

```sh
RIME_FONT_PRESET=compact ./scripts/deploy.sh
```

默认 `large` 使用候选 17pt / 注释 16pt；`compact` 使用候选 15pt / 注释 12pt。

**覆盖范围：** 脚本会安装仓库配置、通用专业词库及固定版本万象资源；包括替换方案列表、候选样式及两个中文方案的补丁。请先看 `--dry-run` 输出。已有 `rime.lua`、用户学习数据库和安装清单之外的私有词库文件不会被覆盖；已有 `luna_pinyin.tech.dict.yaml` 聚合词库也会保留，以免丢失私有导入。其余同名文件会先备份再替换。

### Windows 小狼毫

先安装并启用[官方小狼毫](https://github.com/rime/weasel/releases)，然后克隆仓库，或在 GitHub 选择 **Code → Download ZIP** 并解压。在项目目录打开 PowerShell：

```powershell
# 安装预览；首次会下载约 34 MiB Base 包与约 380 MiB 模型
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy.ps1 -Preview

# 备份、安装并调用小狼毫重新部署
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy.ps1

# 笔记本紧凑字号（候选 15pt、注释 12pt）
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy.ps1 -FontPreset compact
```

这里的执行策略参数仅对当前 PowerShell 进程有效，不修改系统策略。不需要安装 Python、Git Bash 或 WSL；也不需要管理员权限来写入自己的输入法用户目录。

脚本优先读取小狼毫在 `HKCU\Software\Rime\Weasel` 登记的 `RimeUserDir`，未自定义时使用 `%APPDATA%\Rime`。小狼毫安装路径从注册表检测；检测不到时可显式指定：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy.ps1 -WeaselDir 'C:\Program Files\Rime\weasel-0.17.4'
```

只调用现有 `WeaselDeployer.exe /deploy`，不修改输入法注册表、系统输入源或执行策略。Windows 安装 `weasel.custom.yaml`，macOS 安装 `squirrel.custom.yaml`；两边不会覆盖另一平台的主题。用户数据库、已有 `rime.lua` 和聚合词库的保护规则与 macOS 相同。

等待重新部署完成，切换到小狼毫中文模式，在方案选单选择“万象拼音”或“朙月拼音·简化字”。输入 `github`，第二候选应为 `GitHub`，按 `2` 上屏。英文释义使用 Segoe UI，中文使用系统自带微软雅黑，支持浅色与深色主题。

**路径限制：** 小狼毫携带的 [Lua 模块使用 Windows 本地编码路径](https://github.com/hchunhui/librime-lua/blob/master/src/modules.cc)。目录必须能被系统 ANSI 码页无损表示，例如英文 Windows 默认码页 1252 无法表示中文目录。正式安装会在覆盖文件前检测并拒绝不兼容路径；可在小狼毫安装设置中选择纯英文用户目录后重试。脚本不修改系统区域、注册表或全局 UTF-8 选项。PowerShell 的文件复制支持中文目录，不代表原生引擎也支持该路径。

检查和回滚：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\rollback.ps1
```

备份保存在用户目录的 `backups\qingjian-learning-时间戳\`，回滚只恢复清单中的文件，并保留撤回版本。Windows 和 macOS 的最近备份记录各自独立。

如需准备隔离目录，可使用 `-UserDir 'D:\Rime Test' -SkipDeploy`；三个 Windows 脚本均支持 `-UserDir` 或 `RIME_USER_DIR`。**小狼毫的 `/deploy` 始终针对注册目录**，所以自定义测试目录必须加 `-SkipDeploy`，避免误部署正在使用的输入法。脚本会拒绝符号链接或目录联接，以免安装、回滚越过目标目录。

## 使用与自定义

在方案选单里切换“英文候选 / 关闭英文候选”和“英文释义 / 关闭英文释义”。英文候选开关只控制本项目插入的候选，原方案自带的英文词条仍可显示。

在 `rime/data/internet-english.tsv` 中添加英文词，每行用真正的 Tab 分隔：

```text
github	GitHub	代码托管
docker	Docker	容器
```

编码使用完整小写英文字母。中文模式下数字键用于选词，因此不使用 `k8s` 这样的带数字编码。重复编码只保留一条；不要把个人短语、手机号、账号或内部项目名称放入公开词表。

修改后重新运行安装脚本。要调整释义数量，可在对应的 `rime/wanxiang.custom.yaml` 或 `rime/luna_pinyin_simp.custom.yaml` 的 `patch:` 下加入：

```yaml
  bilingual_gloss/max_senses: 1
```

支持 1–4 项，以词表实际提供的义项为限。默认 2 项。

## 验证与回滚

```sh
# 核对安装文件、编译后的过滤链与语法模型校验值
./scripts/verify.sh

# Lua 回归与脚本语法检查
./scripts/test.sh --unit

# macOS 真实引擎测试：在隔离目录安装、编译、选词并回滚
./scripts/test.sh

# 回滚最近一次安装，随后等待鼠须管重新部署
./scripts/rollback.sh
```

以上为 macOS 命令。完整测试使用已安装鼠须管的 librime、Lua 与语法模型插件，并需要 Xcode Command Line Tools 的 `clang++`。首次额外下载固定版本的 Rime API 头文件并校验。测试不会写入正在使用的输入法目录。Linux CI 运行 Lua 与脚本检查。

Windows 开发测试（文件操作覆盖空格与中文；真实引擎覆盖系统码页可表示的非 ASCII 路径）：

```powershell
# 脚本解析、真实资源校验、安装预览、备份、回滚及目录保护
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-windows.ps1

# 同时编译 C++ 测试程序，使用真实 Windows rime.dll 验证候选及上屏
# 需要 Visual Studio C++ Build Tools 和 7-Zip，CI 已提供
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-windows.ps1 -Engine
```

引擎测试只解压、校验官方小狼毫安装包，不运行安装程序，不注册输入法，不触发正式输入法部署。自动测试不能代替 Windows 10/11 中记事本、浏览器及不同 DPI 下的候选窗口验收。

备份位于 `$HOME/Library/Rime/backups/qingjian-learning-时间戳/`。回滚只恢复安装清单涉及的文件，被撤回的版本也会保留。备份记录按目标目录存储，测试安装不会改写真实输入法的回滚记录。

可用 `RIME_USER_DIR=/你的测试目录` 指定隔离目录，配合 `RIME_SKIP_RELOAD=1` 禁止通知正在使用的鼠须管。`verify.sh` 通过只代表静态产物匹配，真实候选与提交行为由完整引擎测试验证。

## 文件结构

- `rime/lua/internet_english_filter.lua`：精确英文第二候选与去重。
- `rime/data/internet-english.tsv`：常用互联网英文词表。
- `rime/lua/qingjian_gloss_filter.lua`：中文候选英文释义。
- `rime/data/qingjian-glossary-en.tsv`：上游青简离线释义数据。
- `rime/*.custom.yaml`：方案与候选窗口配置。
- `rime/*.dict.yaml`：技术英文、AI、日常与电子领域词条。
- `scripts/*.sh`：macOS 下载、安装、检查、回滚及测试。
- `scripts/*.ps1`：Windows 安装、路径检测、校验、回滚及测试。
- `tests/`：Lua 回归与真实 librime 测试。
- `third_party/`：第三方来源与原始许可证。

不要将整个 `~/Library/Rime` 上传到 GitHub。仓库忽略构建缓存、语法模型缓存、备份、同步数据、用户数据库和本机安装信息。

## 来源与许可

本项目原创配置、脚本、Lua 扩展与自编词条以 **GPL-3.0-or-later** 发布，见 [LICENSE](LICENSE)。第三方资源保留各自原始许可证，不重新授权。

- 英文释义表来自 [qingjian-team/qingjian](https://github.com/qingjian-team/qingjian)，固定提交 `1cb7696da86e4822f5056af4d9635f2bb6628da4`，按原数据内容分发，仅改变文件名。许可与署名见 [third_party/qingjian](third_party/qingjian/ATTRIBUTION.md)。释义由上游使用大语言模型离线生成，可能存在错误，适合作为学习提示。
- 万象 Base `v17.10.3` 来自 [amzxyz/rime-wanxiang](https://github.com/amzxyz/rime-wanxiang)；简体 LTS 语法模型来自 [amzxyz/RIME-LMDG](https://github.com/amzxyz/RIME-LMDG)。仅按需下载，不提交大模型文件；固定资源信息见 [third_party/wanxiang](third_party/wanxiang/ATTRIBUTION.md)。
- Rime 与鼠须管由其原项目维护，本项目与上游项目无官方隶属关系。
- LangChain 专业词条整理自官方 Docs 与 API Reference，仅收录术语和 API 符号，不复制文档正文。

提交词表修正时，请附上输入编码、期望候选、所用方案与鼠须管版本。提交内容应为你有权公开的通用词条。
