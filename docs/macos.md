# macOS 鼠须管使用教程

本项目为鼠须管安装万象拼音、中英候选与离线英文释义。先完成安装和首次验收，再按需要设置常用语、字号或迁移数据。返回[项目首页](../README.md)。

**普通安装不需要 Python。** 只有后面的可选管理菜单需要 Python 3.8 或更新版本。

## 1. 安装并启用鼠须管

1. 从[鼠须管官方发布页](https://github.com/rime/squirrel/releases)下载适配你系统的正式安装包，按安装向导完成安装。系统要求以该版本说明为准。
2. 打开「系统设置 → 键盘 → 文字输入 → 编辑」。如果列表中没有鼠须管，点「+」，找到并添加「鼠须管」或 Squirrel。
3. 在菜单栏输入法菜单中选择鼠须管，打开「文本编辑」等普通文字输入窗口，先确认能输入中文。
4. 首次安装后，如果部分应用不能输入，保存工作后注销并重新登录，再试一次；这是[鼠须管官方说明](https://github.com/rime/squirrel#安裝輸入法)中的处理建议。

macOS 不同版本的设置名称可能略有不同。添加和切换输入法可参照 [Apple 官方指南](https://support.apple.com/zh-cn/guide/mac-help/mchlp1406/mac)。菜单栏选择输入源最直观，系统默认也支持 `Control + 空格` 切换。

## 2. 下载项目并进入目录

1. [下载本项目 ZIP](https://github.com/AnneHtowardshaway/rime-bilingual/archive/refs/heads/main.zip)，解压到方便保留的位置。
2. 打开解压后的文件夹，确认其中直接包含 `README.md`、`rime` 和 `scripts`。
3. 打开「终端」，输入 `cd `，注意后面有一个空格；把上面的项目文件夹拖进终端，再按回车。

也可以输入带引号的路径。下面只是示例，请换成你的实际项目目录：

```sh
cd "$HOME/Downloads/rime-bilingual-main"
```

**本文所有后续命令都从项目根目录运行。** 文件路径含空格时要加引号，例如 `"$HOME/Documents/Rime Backups/个人备份.zip"`。不要把示例中的 `/path/to/` 原样当成自己的路径。

## 3. 安装项目配置

可选：先预览将安装或替换哪些文件：

```sh
./scripts/deploy.sh --dry-run
```

预览不会写入输入法用户目录，但首次仍可能下载资源。确认后正式安装：

```sh
./scripts/deploy.sh
```

首次需联网下载约 432 MiB 的方案与语法模型，完成后日常输入完全离线。等待脚本结束和输入法重新部署完成；出现错误时按提示处理，不要把复制了文件当成部署成功。

安装目标为 `~/Library/Rime`。同名项目文件会先备份；已有学习数据库、私人短语和安装清单外的私有词库会保留。安装将更新方案列表与候选窗口样式，日常只保留万象，旧朙月学习记录不会自动合并进万象。

脚本和安装说明分别见 [deploy.sh](../scripts/deploy.sh)、[项目首页](../README.md#安装)。

## 4. 首次成功验收

1. 切到鼠须管，保持**中文模式**，把光标放进普通文本框。
2. 按 `F4` 打开方案选单，选择「万象拼音」。如果选项折叠，展开后再找。
3. 输入 `github`，第二候选应为 `GitHub`，按 **2** 输出。
4. 输入 `kaifa`，应看到「开发」旁的英文释义；正常选词即可输出中文。
5. 输入 `;usesta`，应能补全为 `useState`，选择后完整输出。

如果 F4 打开了系统功能，可用 `Fn + F4`，或 `Control + 重音符键`（通常是数字 1 左侧的 `` ` `` 键）。功能键行为见 [Apple 官方说明](https://support.apple.com/zh-cn/102439)。

这几项通过即可日常使用，不需要运行开发测试。若只有英文原样上屏，先检查是否处于西文模式；若没有本项目英文候选，检查是否选中了万象以及相关开关。

## 5. 日常输入

### 中文、英文与同次输入接续

中文按全拼输入，整句、简拼和常见错序拼写沿用万象能力。例如 `jintiankaihui` 可输入「今天开会」；本地额外补充 `jintainkaihui` 这类 `ian → ain` 换位容错，不默认放宽模糊音。

常用英文使用完整小写编码，例如 `docker`、`chatgpt`、`claudecode`。通常按 **2** 选择规范英文；若只有这个英文候选，则直接选它。`githu` 不会触发本项目的完整 `github` 匹配规则。

同一次输入中接续英文：输入 `woyonggithub`，先从候选中选择「我用」，再按 **2**，完整输出「我用GitHub」。`woyonggofmtprintf` 同样可输出「我用fmt.Printf」。前面的中文可能需要翻页寻找；必须先选中文，末尾英文使用完整编码。这不是任意中英整句自动分词。

### `;` / `vv` 专用英文入口

输入 `;github` 或 `vvgithub` 可选 `GitHub`；`;usesta` 或 `vvusesta` 可补全 `useState`。带空格和符号的候选会完整输出，例如 `;claudecode` 输出 `Claude Code`。

普通中文入口只做定制英文精确匹配；专用入口允许前缀补全。更多编码示例见[编程英文说明](../README.md#编程英文怎么输)。

### 切换显示与候选开关

在 F4 / `Control + 重音符键` 的方案选单中切换：

| 选项 | 作用 |
| --- | --- |
| 伴学显示 / 简洁显示 | 伴学通常显示两个义项；简洁只显示一个，长释义截短并加省略号 |
| 英文释义 / 关闭英文释义 | 控制中文候选旁的英文释义 |
| 英文候选 / 关闭英文候选 | 控制本项目插入的常用英文候选 |

从选单切换后会保存到本机，下次会话和重启后继续使用。关闭定制英文候选不等于关闭万象自带英文或 `;` / `vv` 入口。

### 学习新词与手动排序

缺少「岚栩」时，一次输入完整拼音 `lanxu` 或 `lan'xu`，在同次输入中依次选择「岚」「栩」，完成整词上屏。分成两次独立输入单字，不能保证自动合成词；自动学习也不保证使用一次就永久排第一。

要立即调整中文排序，先用方向键或 Tab **高亮候选，暂不上屏**：`Control + p` 置顶，`Control + j` 前移，`Control + k` 后移，`Control + l` 清除当前编码下的手动排序。定制英文仍遵循固定第二候选规则。

## 6. 可选：管理私人常用语

固定姓名、地址或项目名保存在 `~/Library/Rime/custom_phrase.txt`，自动学习词则在用户数据库中。不要将这些私人文件放进项目仓库。

先在终端检查可用版本：

```sh
python3 --version
```

若没有 Python，或版本低于 3.8，从 [Python 官方 macOS 下载页](https://www.python.org/downloads/macos/)安装当前稳定的 Python 3，完成后重新打开终端并再次检查。最低支持 3.8 不代表需要专门安装旧版；无需为本工具安装 pip 包或创建虚拟环境。安装细节可参照 [Python 官方 macOS 指南](https://docs.python.org/zh-cn/3/using/mac.html)。

确认 Python 3.8+ 可用后，可双击 [manage.command](../scripts/manage.command)，或从项目根目录启动菜单：

```sh
./scripts/manage.sh
```

菜单支持查看、搜索、添加、精准删除、导入、导出和应用更改。以下是独立命令示例，请按需单独运行：

```sh
./scripts/manage.sh phrases add "星澜工作室" xinglangongzuoshi
./scripts/manage.sh phrases search 工作室
./scripts/manage.sh phrases add "星澜工作室" xinglangongzuoshi --update --weight 1200
./scripts/manage.sh phrases remove xinglangongzuoshi --text "星澜工作室"
./scripts/manage.sh phrases import "$HOME/Documents/常用语 备份.txt"
./scripts/manage.sh phrases export "$HOME/Documents/常用语 导出.txt"
./scripts/manage.sh apply
```

请把示例短语换成自己的内容。同码可有多条短语；重复词条默认保留既有权重，显式 `--update` 才会更新。`remove 编码` 会删除该编码下全部短语，精准删除要带 `--text`。导入更新权重也可加 `--update`；导出文件已存在时，确认要替换再加 `--force`。

修改前会在用户目录 `backups` 保存原文件副本。`apply` 只是请求重新部署，等待编译完成后再试新增编码；也可通过输入法菜单「重新部署」生效。

不安装 Python 也能手工维护：用 UTF-8 纯文本编辑 `custom_phrase.txt`，每行按「短语、完整小写编码、整数权重」三列，用**真正的 Tab** 分隔，保存后重新部署。格式和[详细用法](../README.md#姓名项目名使用私人短语)见首页。

使用「文本编辑」维护 `.txt` 或 `.yaml` 时，先选「格式 → 制作纯文本」，不要保存为富文本 RTF；确认实际文件名没有多出的 `.txt` 扩展名。

## 7. 设置个人字号和应用偏好

在输入法用户目录新建 **`~/Library/Rime/squirrel.personal.yaml`**，使用 UTF-8 纯文本；文件名不要变成 `.yaml.txt`。例如：

```yaml
patch:
  style/font_point: 15
  style/comment_font_point: 12
  app_options/com.microsoft.VSCode/ascii_mode: false
```

保存后从输入法菜单「重新部署」，或运行 `./scripts/manage.sh apply`。个人补丁最后生效，安装更新与回滚不会删除这个文件；不要直接改项目管理的 `squirrel.custom.yaml`，否则下次安装会替换。

如果只想使用项目预设的紧凑字号，也可重新安装：

```sh
RIME_FONT_PRESET=compact ./scripts/deploy.sh
```

默认预设为候选 17pt / 释义 16pt，紧凑为 15pt / 12pt。已有个人字号会优先覆盖预设。浅色和深色主题随系统外观切换。

## 8. 备份、换机与恢复

**完整学习备份，以及任何恢复操作（包括 `--settings-only` 恢复），都要先退出 Squirrel。切换输入源不等于退出进程。**

1. 完成当前输入并保存工作，在输入法菜单切到系统「ABC」或系统拼音。
2. 打开「活动监视器」，搜索 `Squirrel`，选择对应进程，点停止按钮后选择「退出」。参见 [Apple 的退出进程说明](https://support.apple.com/zh-cn/guide/activity-monitor/actmntr1002/mac)。
3. 确认 `Squirrel` 已消失，再执行完整备份或恢复。若它重新出现，保持系统输入法并先解决进程仍在运行的问题；不要删除数据库锁来绕过检查。

从项目根目录按需选择以下命令。迁移包默认放在 `~/Library/Rime/backups`，命令会显示具体路径：

```sh
./scripts/manage.sh data backup
./scripts/manage.sh data backup --settings-only
./scripts/manage.sh data inspect "$HOME/Documents/Rime Backups/个人迁移.rime-personal.zip"
./scripts/manage.sh data restore "$HOME/Documents/Rime Backups/个人迁移.rime-personal.zip"
```

只备份常用语和设置可用 `--settings-only`，不必为这种备份退出输入法。完整备份另含存在的中文学习、排序、上下文和英文学习库。额外私人 `.dict.yaml` 及其导入配置须另行保存，迁移包不包含它们。

换机顺序：在新 Mac 安装鼠须管和本项目 → 切系统输入法并退出 Squirrel → 恢复迁移包 → 重新选择鼠须管并重新部署。若重新选择后仍不可用，注销重登再试。迁移包会合并常用语与学习记录，冲突的个人设置默认保留目标版本；只有明确需要替换时才加 `--replace-settings`。恢复前的副本路径会打印出来。

迁移包包含私人内容，请自行妥善保管。`inspect` 只核对文件类型和校验值，不证明它适合你的个人设置。

## 9. 更新和回滚

项目不会自动更新。重新下载 ZIP，解压到一个新目录，从新项目根目录运行 `./scripts/deploy.sh`。私人短语、学习数据库与个人样式文件会保留；不必把旧项目的受管理配置整套覆盖回来。

要撤回最近一次项目安装，从项目根目录运行：

```sh
./scripts/rollback.sh
```

它恢复最近一次安装前的受管理文件，每份备份只可回滚一次；不会删除私人短语、个人样式和学习库。安装自动备份不是完整个人数据迁移包，也不是卸载鼠须管。

## 10. 常见问题与验证范围

- **`No such file or directory`**：确认终端位于直接含 `scripts` 的项目根目录；含空格的路径加引号。
- **提示需要 Python**：仅管理菜单需要 Python；可继续正常安装，或手工编辑私人短语。管理入口不自动安装依赖。
- **下载失败 / SHA-256 不匹配**：检查 GitHub 连接，按错误提示重试；只清除提示中损坏的那个缓存文件，不跳过校验。当前资源说明见[依赖署名](../third_party/wanxiang/ATTRIBUTION.md)。
- **修改没有生效**：确认文件位于 `~/Library/Rime`，为 UTF-8 纯文本，已保存并完成重新部署；私人字号会覆盖项目预设。
- **迁移提示输入法仍在运行**：按第 8 节真正退出 Squirrel，不能只切换输入法。原生学习迁移需要鼠须管携带的兼容词库管理工具；不要用直接复制运行中数据库代替。
- **仍有问题**：记录 macOS / 鼠须管版本、输入编码、操作步骤和错误信息；分享前遮去私人短语、姓名、路径和账号。

项目的真实引擎回归覆盖英文候选、接续提交、释义、学习、排序、开关持久化及隔离安装/回滚；这不等于逐个 Mac 应用、键盘布局和显示器均做过界面验收。当前环境与 CI 范围见首页[进阶设置中的验证说明](../README.md#进阶设置)，普通使用无需运行测试脚本。

## 计算机专业英语选词

新增 300 个术语、600 个英文／拼音编码。例如 `algorithm` 或 `suanfa` 可选 algorithm，`datastructure` 或 `shujujiegou` 可选 data structure。普通模式完整编码通常按 2 选英文；只有一个候选时按 1。技术入口 `;authenticat` / `vvauthenticat` 支持补全。

完整示例与词库链接见 [计算机专业英语](../README.md#计算机专业英语300-个术语)。更新源码后按本教程的脚本安装步骤重新部署；此前生成的离线安装包不包含本轮新增词。
