# Windows 小狼毫使用教程

适用于 **Windows 10 / 11 x64**。本项目提供万象拼音配置、中英伴学词库和可选管理工具，输入法程序需要先安装小狼毫。

安装本项目配置无需 Python、Git Bash 或 WSL，也不需要用管理员 PowerShell 向自己的输入法用户目录写文件。下面的命令都在**已经解压的项目根目录**运行。

## 先安装并启用小狼毫

1. 打开 [Rime 官方小狼毫下载页](https://github.com/rime/weasel/releases)，选择稳定版的安装程序。本项目已验证的版本为 **0.17.4**；该版文件名为 `weasel-0.17.4.0-installer.exe`，不要下载成 Source code。
2. 运行官方安装程序，按提示完成安装；如果安装器要求注销或重启，先完成这一步。
3. 按 **Win + 空格**，选择「小狼毫」，打开记事本，先确认原始方案可以输入中文。

如 Windows 输入法列表中没有小狼毫，先完成小狼毫自身的安装与启用，再继续。本项目不能代替输入法程序的安装。

## 下载项目并安装配置

1. [下载本项目 ZIP](https://github.com/AnneHtowardshaway/rime-bilingual/archive/refs/heads/main.zip)，右键选择「全部解压缩」。**不要在 ZIP 预览窗口中运行脚本。**
2. 打开解压后的项目文件夹；这一层应该同时看见 `README.md`、`rime` 和 `scripts`，不要停在它的上一级或进入 `scripts`。
3. 在资源管理器的地址栏输入 `powershell` 并回车，打开位于此处的 PowerShell。
4. 可以先预览安装清单，再正式安装：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy.ps1 -Preview
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy.ps1
```

预览不修改输入法目录，但首次仍可能下载资源。正式安装会备份同名文件、安装词库并请求重新部署；等待命令结束，不要在编译过程中反复重装。

脚本会打印实际的 `Target` 用户目录和 `Backup` 备份位置。它优先使用小狼毫登记的用户目录，未自定义时通常为 `%APPDATA%\Rime`；不是把项目文件夹当成用户目录。

若提示找不到 `WeaselDeployer.exe`，用**实际安装目录**重试，例如：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy.ps1 -WeaselDir 'C:\Program Files\Rime\weasel-0.17.4'
```

`-ExecutionPolicy Bypass` 只对本次 PowerShell 进程生效，不会修改系统的全局执行策略。

## 安装成功的三项验收

保持小狼毫的**中文模式**，在记事本中检查：

1. 按 **F4** 或 **Ctrl + 重音符键**（通常在数字 1 左边），确认方案列表仅含「万象拼音」，不再列出朙月。
2. 输入完整小写 `github`，第二候选为 **GitHub**，按 **2** 可完整上屏。
3. 输入 `kaifa`，「开发」旁边显示 `develop` 等英文释义，选中后仍上屏中文「开发」。

有些笔记本需要按 `Fn + F4` 才会发送 F4。若没有英文，先检查选中的方案、中文模式和英文开关，再处理安装命令报告的错误。

## 日常输入怎么用

| 需求 | 操作与结果 |
| --- | --- |
| 输入规范英文 | `docker` → 选择 `Docker`；`claudecode` → `Claude Code` |
| 输出 API 符号 | `gofmtprintf` → `fmt.Printf`；编码中不输入点号 |
| 在同次输入中接续中文和英文 | 输入 `woyonggithub`，先选择「我用」，再按 **2**，输出「我用GitHub」 |
| 专用英文入口及补全 | `;usesta` 或 `vvusesta` → `useState`；`;claudecode` → `Claude Code` |
| 减少候选旁的文字 | F4 选单切到「简洁显示」，仅保留一个义项，长释义省略 |
| 暂时隐藏英文候选或释义 | F4 选单切换「英文候选」「英文释义」对应开关 |

定制英文通常放在第二项；如果只剩这一个候选，会单独显示。普通入口只精确匹配完整英文编码，输入一半时可改用 `;` / `vv` 补全。

分段混输需要先选择前面的中文，剩余英文才按上述规则选择；并不承诺任意中英混合整句都自动成为首选。开关和显示档从方案选单设置后会在本机记住。

### 中文学习与候选排序

缺少人名或新词时，在**同一次输入**中输入完整拼音，例如 `lanxu`，依次选择「岚」「栩」，完成整个词上屏；之后再输 `lanxu` 可找回这个新词。分两次分别上屏单字，不能保证合成新词。

想马上调整顺序，先用方向键或 Tab 高亮候选，**暂时不要上屏**：

| 快捷键 | 效果 |
| --- | --- |
| Ctrl + P | 置顶当前候选 |
| Ctrl + J / Ctrl + K | 向前 / 向后移一位 |
| Ctrl + L | 清除该候选在当前编码下的手动排序 |

常用英文的固定第二项规则仍然有效。学习记录与固定常用语是两种数据，不要把用户数据库文件当成普通文本编辑。

## 可选安装 Python 并打开管理菜单

只在需要管理常用语或迁移包时安装；日常输入与正常配置安装不需要它。管理工具最低要求 **Python 3.8**，建议从 [Python 官方 Windows 下载页](https://www.python.org/downloads/windows/) 安装当前稳定版，参考 [官方安装说明](https://docs.python.org/zh-cn/3/using/windows.html)，无需安装第三方 Python 包。

安装后重新打开项目根目录的 PowerShell，先确认：

```powershell
py -3 --version
```

应显示 Python 3.8 或更高版本。随后打开菜单：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\manage.ps1
```

如果 `py -3 --version` 已正常显示版本，但此脚本仍报找不到 Python，可直接运行：

```powershell
py -3 -X utf8 .\scripts\manage.py
```

当前包装脚本会跳过 `WindowsApps` 路径，而官方 Python Install Manager 的合法命令也可能在该目录；直接入口用于绕过此限制，不必为此卸载合法 Python 或关闭全局别名。下面的管理示例都采用这个直接入口。

### 新增、查找、删除和导出常用语

把示例短语换成自己的内容；编码只能是完整小写字母，相同编码可以对应多条短语。

```powershell
py -3 -X utf8 .\scripts\manage.py phrases add "星澜工作室" xinglangongzuoshi
py -3 -X utf8 .\scripts\manage.py phrases search "工作室"
py -3 -X utf8 .\scripts\manage.py phrases add "星澜工作室" xinglangongzuoshi --weight 1500 --update
py -3 -X utf8 .\scripts\manage.py phrases export ".\my-phrases.tsv"
py -3 -X utf8 .\scripts\manage.py phrases import ".\my-phrases.tsv"
py -3 -X utf8 .\scripts\manage.py phrases remove xinglangongzuoshi --text "星澜工作室"
py -3 -X utf8 .\scripts\manage.py apply
```

最后一条请求重新部署，等待结束后试输入新词。删除时加 `--text` 只删指定短语；不加会删除该编码下全部短语。重复导入不会重复添加，默认保留已有权重；导出目标已存在时会拒绝覆盖，需要替换才加 `--force`。

工具会在修改前备份原文件。如果小狼毫登记了自定义目录，工具会自动读取；确需指定时，`--user-dir` 放在 `phrases` / `data` 之前，例如：

```powershell
py -3 -X utf8 .\scripts\manage.py --user-dir 'D:\Rime' phrases search "工作室"
```

这里的目录必须是你实际使用的用户目录；它不能改变小狼毫的登记位置。使用手工文本编辑时，固定短语文件是该目录下的 `custom_phrase.txt`，三列以真正的 Tab 分隔。

## 保存个人字号与按应用设置

从小狼毫菜单或开始菜单的「用户文件夹」打开**实际用户目录**，在其中新建 `weasel.personal.yaml`；不要放进下载的项目目录。

用记事本等纯文本编辑器保存为 **UTF-8**。另存为时选择「所有文件」，文件名可填 `"weasel.personal.yaml"`；在资源管理器启用「文件扩展名」，确认实际名字不是 `weasel.personal.yaml.txt`。YAML 缩进使用空格，不用 Tab。

以下内容可作为自己的设置起点：

```yaml
patch:
  style/font_point: 16
  style/comment_font_point: 12
  app_options/code.exe/ascii_mode: false
  app_options/windowsterminal.exe/ascii_mode: true
```

这会调整字号，并将 VS Code 的初始状态设为中文、Windows Terminal 的初始状态设为英文；使用时仍可手动切换。Windows 规则使用进程文件名；其他应用请在任务管理器「详细信息」中核对实际 `.exe` 名称，不要复制 macOS 的 `com.microsoft.VSCode` 标识。

保存后，从小狼毫菜单执行「重新部署」，或运行上面的 `manage.py apply`。个人文件最后生效，安装与回滚都会保留它；它的字号设置也会优先于安装器的字号预设。

只想使用项目预置的紧凑字号，且个人文件没有覆盖字号时，也可运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy.ps1 -FontPreset compact
```

## 更新与回滚

更新时重新下载并解压新 ZIP，在新项目根目录运行 `deploy.ps1`。学习库、`custom_phrase.txt`、`weasel.personal.yaml` 会保留；原来直接写在 `weasel.custom.yaml` 的个人设置，请先迁入个人文件。

想撤回最近一次项目安装，运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\rollback.ps1
```

回滚只处理该次安装清单中的文件，用户学习与个人文件保留；同一份安装备份只能回滚一次。实际备份在用户目录的 `backups` 下，脚本会打印位置。**安装回滚不是个人学习记录的历史恢复。**

## 备份与换机迁移

Windows 普通用户先用**常用语与设置迁移**。它包含 `custom_phrase.txt`、个人样式文件与 `user.yaml` 偏好，不含中文学习、手动排序、上下文调频或英文学习数据库；额外私人 `.dict.yaml` 也需另行保管。

在项目根目录的 PowerShell 中，为迁移包选择一个尚不存在的文件名：

```powershell
$backupFile = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'my-rime.rime-personal.zip'
py -3 -X utf8 .\scripts\manage.py data backup "$backupFile" --settings-only
py -3 -X utf8 .\scripts\manage.py data inspect "$backupFile"
```

仅备份文本设置可以在输入法运行时进行；`inspect` 只校验迁移包并显示文件类型，不输出私人词条。把这个迁移包自行传到新电脑，先安装小狼毫与本项目，再恢复。

**任何恢复，包括 `--settings-only`，都必须先退出小狼毫服务。** 单切换到英文、换到微软拼音或关闭设置面板，都不等于 `WeaselServer.exe` 已退出。

先用 Win + 空格切到系统输入法，等待正在进行的部署完成；然后在实际小狼毫安装目录请求退出算法服务。以下路径是示例，需换成自己的：

```powershell
& 'C:\Program Files\Rime\weasel-0.17.4\WeaselServer.exe' /quit
Get-Process WeaselServer, WeaselDeployer -ErrorAction SilentlyContinue
```

确认检查命令不再列出这两个进程；若部署器仍在运行，先等待它结束，不要在编译中强行恢复。然后在项目根目录执行：

```powershell
$backupFile = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'my-rime.rime-personal.zip'
py -3 -X utf8 .\scripts\manage.py data restore "$backupFile" --settings-only
```

恢复会合并常用语，已有个人设置发生冲突时默认保留目标文件。只有明确需要替换目标偏好时，才使用下面这一条；两种方式都会保留恢复前副本：

```powershell
py -3 -X utf8 .\scripts\manage.py data restore "$backupFile" --settings-only --replace-settings
```

完成后从开始菜单启动「小狼毫算法服务」，再运行 `py -3 -X utf8 .\scripts\manage.py apply`，等待部署结束并重新做三项输入验收。迁移包包含私人内容，不要提交到公开仓库。

完整学习迁移需要兼容的原生词库管理 CLI。**Windows 默认没有本项目可直接调用的该 CLI，不能承诺一键全量迁移。** `RIME_DICT_MANAGER` 仅供已有可信、兼容程序的高级用户指定；`WeaselDeployer.exe` 是部署器，不能替代它。该高级路径尚未在原生 Windows 实机验证，不要直接复制运行中的 `.userdb` 目录。

## 常见问题

| 现象 | 处理 |
| --- | --- |
| 提示脚本不存在 | 确认已解压 ZIP，并在同时有 `README.md` 和 `scripts` 的根目录打开 PowerShell |
| 目录编码不兼容 | 在小狼毫安装设置中选可由本机编码表示的纯英文用户目录，例如 `D:\Rime`，再安装项目；只传 `-UserDir` 不能改变登记目录 |
| 下载失败或 SHA-256 不匹配 | 确认能访问 GitHub 后重试；按错误提示只处理对应坏缓存，保留校验逻辑 |
| 个人设置无效 | 确认位于实际用户目录、UTF-8、真实 `.yaml` 扩展名且缩进正确，然后重新部署 |
| 恢复提示输入法仍运行 | 检查 `WeaselServer` / `WeaselDeployer`，退出服务后再恢复，不能用 `--settings-only` 绕过运行检查 |

目录问题不需要关闭安全软件、改系统全局 UTF-8 或绕过路径保护。桌面候选外观、高 DPI 与各应用交互仍需 Windows 实机验收；本教程不把脚本检查当成全部桌面体验已验证。
