# Rime 中英伴学

**用中文输入，顺便看英文释义；遇到常用英文，直接选词。**

适用于 macOS **鼠须管**和 Windows **小狼毫**，使用万象拼音。安装后保持中文输入模式即可使用，输入过程完全离线。

| 中文模式下输入 | 你会看到 | 怎么输入上屏 |
| --- | --- | --- |
| `kaifa` | 中文候选「开发」旁显示 `v. develop · v. exploit` | 像平常一样选「开发」 |
| `github` | 第二候选为 `GitHub` | 按数字 **2** |
| `docker` | 出现规范英文候选 `Docker` | 选择该候选 |

内置 **4240 个英文编码**：215 个互联网常用编码，以及 4025 个编程、AI、日常和设备编码（含别名）。覆盖 Go、Rust、JS、TS、Python、Java，以及 AI 工具、Agent 术语、日常交流和设备名称；英文候选和英文释义都可以单独关闭。

现已只保留万象作为日常方案。升级后，朙月不再出现在方案选单；已有朙月文件、私人词库和学习数据库不会被删除。

**直接跳到：** [安装](#安装) · [安装后怎么用](#安装后怎么用) · [编程英文怎么输](#编程英文怎么输) · [中文学习与私人短语](#中文学习与私人短语) · [本地管理](#本地管理菜单) · [备份迁移](#个人数据备份与迁移) · [字号与开关](#字号与开关) · [恢复原配置](#恢复原配置) · [常见问题](#常见问题)

## 安装

这是输入法的配置与扩展。**请先安装对应的 Rime 输入法，再安装本项目。**

| 你的系统 | 先安装输入法 | 然后跟着这节操作 |
| --- | --- | --- |
| macOS | [鼠须管 Squirrel](https://github.com/rime/squirrel/releases) | [macOS 安装](#macos-鼠须管) |
| Windows 10 / 11 x64 | [小狼毫 Weasel](https://github.com/rime/weasel/releases)，建议 0.17.4 或更新版本 | [Windows 安装](#windows-小狼毫) |

**安装前了解两件事：**

- 首次需联网下载约 **432 MiB** 的词库方案与语法模型；下载完成后，日常输入无需联网。
- 安装会替换方案列表、候选窗口样式和相关方案配置。**已有同名文件会先备份**，不合适可以[恢复原配置](#恢复原配置)。用户学习数据库、已有 `rime.lua` 和安装清单之外的私有词库会保留。

只需阅读自己系统对应的一节。

### macOS 鼠须管

1. 安装并启用鼠须管，确认能正常输入中文。
2. **[下载本项目 ZIP](https://github.com/AnneHtowardshaway/rime-bilingual/archive/refs/heads/main.zip)**，解压。打开后应能看到 `README.md` 和 `scripts` 文件夹。
3. 打开「终端」，输入 `cd `（后面有一个空格），把**解压后的项目文件夹**拖入终端，再按回车。
4. 复制下面这条命令，粘贴到终端并回车：

   ```sh
   ./scripts/deploy.sh
   ```

等待下载和重新部署完成，然后看[安装后怎么用](#安装后怎么用)。

<details>
<summary>可选：先预览要安装的文件</summary>

在正式安装前运行：

```sh
./scripts/deploy.sh --dry-run
```

这会列出将安装或替换的文件，不修改输入法目录；首次仍需下载资源。看完清单后，运行上面的正式安装命令即可。

</details>

### Windows 小狼毫

1. 安装并启用小狼毫，确认能正常输入中文。
2. **[下载本项目 ZIP](https://github.com/AnneHtowardshaway/rime-bilingual/archive/refs/heads/main.zip)**，解压。打开后应能看到 `README.md` 和 `scripts` 文件夹。
3. 在这个项目文件夹的**资源管理器地址栏**中输入 `powershell`，按回车，打开位于此目录的 PowerShell。
4. 复制下面这条命令，粘贴并回车：

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy.ps1
   ```

等待下载和重新部署完成，然后看[安装后怎么用](#安装后怎么用)。正常安装不需要 Python、Git Bash 或 WSL，也不需要管理员权限来写入自己的输入法用户目录。

如果提示**目录编码不兼容**，先查看[Windows 目录问题](#windows-提示目录编码不兼容怎么办)，不要反复重试安装。

<details>
<summary>可选：先预览要安装的文件</summary>

在正式安装前运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy.ps1 -Preview
```

这会列出将安装或替换的文件，不修改输入法目录；首次仍需下载资源。看完清单后，运行上面的正式安装命令即可。

命令中的 `-ExecutionPolicy Bypass` 仅对这次 PowerShell 进程有效，不修改系统执行策略。

</details>

## 安装后怎么用

1. 切换到鼠须管或小狼毫，保持**中文模式**。
2. 按 **F4**，或 **Control + 重音符键**（通常位于数字 1 左侧），打开方案选单。
3. 选择「**万象拼音**」。
4. 输入 `github`，确认第二候选为 **GitHub**，按 **2** 输出。
5. 再输入 `kaifa`，查看「开发」旁的英文释义。

**看到英文候选和英文释义，就可以正常使用了。** 不需要运行开发测试或继续调整配置。

英文词使用完整小写编码，例如 `github`、`chatgpt`；输入 `zai` 可选 `Z.ai`，输入 `mergerequest` 可选 `Merge Request`，编码中不加点号或空格。定制的第二候选规则只做精确匹配；万象自带英文联想和 `;` / `vv` 补全仍可使用。未命中的输入沿用原候选顺序。若原方案只有这个英文一个候选，则只保留一个规范英文候选。

也可以在同一次输入中接续中文和技术英文。例如输入 `woyonggithub`，先选择「我用」，再按 **2**，即可完整输出「我用GitHub」；`woyonggofmtprintf` 同样可以输出「我用fmt.Printf」。需要先选择前面的中文，末尾英文使用完整编码。

## 编程英文怎么输

**编程、AI、日常和设备词库统一接入万象。** 输入完整小写编码，通常按 **2** 选中英文；若原方案没有其他候选，则英文会单独显示。`go`、`js`、`ts` 也可直接选出语言名称。

| 语言 | 覆盖内容举例 | 输入编码 → 英文候选 |
| --- | --- | --- |
| Go | fmt、context、sync、net/http、Gin、GORM、Viper、Testify | `gofmtprintf` → `fmt.Printf`；`waitgroup` → `WaitGroup` |
| Rust | Vec、HashMap、Option、Result、Tokio、Serde、Reqwest、Rayon | `serdejson` → `serde_json`；`rustmapnew` → `HashMap::new` |
| JavaScript | Promise、Node.js、Axios、Lodash、RxJS、Vue/React API | `jsallsettled` → `Promise.allSettled`；`usestate` → `useState` |
| TypeScript | Partial、Record、Readonly、Awaited、TSConfig、Zod、类型工具 | `tsreadonlytype` → `Readonly`；`tsasconst` → `as const` |
| Python | pathlib、asyncio、collections、NumPy、pandas、Pydantic、pytest | `pygather` → `asyncio.gather`；`pyexecutor` → `concurrent.futures.ThreadPoolExecutor` |
| Java | 集合、Stream、并发、时间、JDBC、Jackson、Guava、Spring | `arraylist` → `ArrayList`；`javafuture` → `CompletableFuture` |

常用主题示例：`claudecode` → `Claude Code`、`toolcalling` → `tool calling`、`thankyou` → `thank you`、`macbook` → `MacBook`、`googleaistudio` → `Google AI Studio`。旧数字编码保留在专用词库，同时提供纯字母别名，如 `deepseekvthree` → `DeepSeek-V3`、`mfourmax` → `M4 Max`。

编码中不输入点号、下划线、冒号或空格，选中后会完整输出这些符号。较长的 API 提供简短别名，例如上面的 `pyexecutor`。`pythonsqlite` 可以输出带数字的 `sqlite3`。

**同名词用明确的语言编码区分大小写**：例如 `gomap` 输出 `map`，`jsmap` 输出 `Map`；`axios` 输出库名 `Axios`，`jsaxios` 输出模块名 `axios`。定制第二候选只匹配完整编码，输入一半不会提前插入该候选。

编程编码清单见 [programming-english.tsv](rime/data/programming-english.tsv)。万象同时提供 `;` / `vv` 英文入口及其前缀补全，例如 `;usesta` / `vvusesta` 补全为 `useState`，`;claudecode` 输出 `Claude Code`。这些入口也覆盖 AI、日常与设备词库。

<details>
<summary>词条来源与维护方法</summary>

语言词库位于 `rime/tech_english_*.dict.yaml`。本轮补充按官方资料核对库名、类型、模块与 API 符号，仅收录术语及名称，不复制文档正文：

- [Go 标准库](https://pkg.go.dev/std)、[Rust 标准库](https://doc.rust-lang.org/std/)
- [JavaScript 标准对象](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects)、[Node.js API](https://nodejs.org/api/)
- [TypeScript 工具类型](https://www.typescriptlang.org/docs/handbook/utility-types.html)、[TSConfig](https://www.typescriptlang.org/tsconfig/)
- [Python 标准库](https://docs.python.org/3/library/)、[Java 标准库](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/module-summary.html)
- [React](https://react.dev/reference/react)、[Vue](https://vuejs.org/api/reactivity-core.html)、[Axios](https://axios-http.com/docs/intro)、[Lodash](https://lodash.com/docs/)、[Zod](https://zod.dev/)

维护者修改语言词库后，运行以下命令更新供万象使用的词表：

```sh
python3 scripts/build-programming-vocabulary.py
```

生成器沿用编程码表权重选择同码候选，保留互联网与既有编程编码的规范拼写。新增主题词按日常、AI、Agent、设备的顺序补齐未占用编码，因此 `book` / `phone` 保留普通单词，设备名使用 `macbook` / `iphone`。普通中文入口只收录纯字母编码，单字母编码及含数字的编码不会自动加入。跨词表重复编码、生成结果不同步等问题会由自动检查拦截。安装者使用仓库内已生成的文件，无需额外安装 Python。

</details>

## 中文学习与私人短语

万象启用 **Rime 本地用户词库学习**。经常选择的中文词会参与词频调整；学习记录保存在输入法用户目录，不会上传到 GitHub。旧朙月的学习数据库会保留，但不会自动合并到万象。

### 缺少的词，先逐字组出来

例如要输入「岚栩」：先一次输入完整拼音 `lanxu`（也可以写成 `lan'xu`），没有整词时，在这次输入中依次选择「岚」「栩」，完成整个词的上屏。以后再输入完整拼音，就可以从用户词库中找回新词。

**先将一个字单独上屏，再重新输入下一个字，不能保证自动合成新词。** 自动学习也不保证一次使用就永久排第一。

### 万象：立即调整候选顺序

先输入拼音，用方向键或 Tab **高亮目标候选，暂不上屏**，再按快捷键：

| 快捷键 | 操作 |
| --- | --- |
| `Control + p` | 将高亮候选置顶 |
| `Control + j` | 向前移动一位 |
| `Control + k` | 向后移动一位 |
| `Control + l` | 清除该候选在当前编码下的手动排序 |

常用英文仍按本项目的规则出现在第二项，手动排序不会改变这个规则。

### 姓名、项目名：使用私人短语

在**输入法用户目录**新建 UTF-8 纯文本文件 `custom_phrase.txt`；万象使用此文件，完整编码命中时优先显示。不要将它放进下载的项目文件夹。

| 系统 | 文件位置 |
| --- | --- |
| macOS | `~/Library/Rime/custom_phrase.txt` |
| Windows | 小狼毫用户目录中的 `custom_phrase.txt`，通常为 `%APPDATA%\Rime\custom_phrase.txt` |

每行三列，顺序是 **词语、完整小写编码、权重**，使用真正的 **Tab** 分隔。例如（请替换为自己的短语）：

```text
星澜工作室	xinglangongzuoshi	1000
```

保存后，对输入法执行「重新部署」。同一编码有多条私人短语时，权重较大的优先。**固定短语也可通过下面的本地管理菜单维护；自动学习的词保存在用户学习数据库中。** 该文件不会被本项目安装或回滚覆盖，也已加入 Git 忽略规则；个人信息不要加入公开词表。格式参考 [Rime 官方短语示例](https://gist.github.com/lotem/5440677)。

### 本地管理菜单

不想手写 Tab，可以使用可选的本地管理工具。它需要 **Python 3.8 或更新版本**，只用标准库，无需安装第三方包；普通输入法安装仍无需 Python。

**macOS：** 双击项目中的 `scripts/manage.command`，或在终端运行：

```sh
./scripts/manage.sh
```

**Windows：** 在项目目录的 PowerShell 中运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\manage.ps1
```

菜单支持查看、搜索、新增、精准删除、导入和导出常用语；修改前会保存原文件备份。相同编码可以对应多条短语，重复导入不会重复添加；更新已有权重需要显式选择 `--update`。常用语修改后，选择菜单中的「应用更改」请求输入法重新部署。

也可以直接使用命令，例如：

```sh
./scripts/manage.sh phrases add "星澜工作室" xinglangongzuoshi
./scripts/manage.sh phrases search 工作室
./scripts/manage.sh phrases remove xinglangongzuoshi --text "星澜工作室"
./scripts/manage.sh apply
```

### 个人数据备份与迁移

管理菜单还支持生成本地 `.rime-personal.zip` 迁移包，包含常用语、两个平台的个人样式文件和 `user.yaml` 偏好。完整模式另包含当前万象的中文学习、手动排序、上下文调频及英文学习数据库的原生快照（存在时收录）。额外导入的私人 `.dict.yaml` 文件需要单独保管，不在此包中。

完整备份与恢复学习记录前，先切换到系统输入法并退出鼠须管／小狼毫服务；工具不会自动结束输入法进程，也不会复制运行中的数据库。只备份常用语和设置可以使用 `--settings-only`。恢复时会合并常用语与同名学习库，已有个人设置默认保留；显式加 `--replace-settings` 才会替换，并保留恢复前副本。

**macOS 示例：**

```sh
./scripts/manage.sh data backup
./scripts/manage.sh data backup --settings-only
./scripts/manage.sh data inspect "/path/to/backup.rime-personal.zip"
./scripts/manage.sh data restore "/path/to/backup.rime-personal.zip"
```

默认备份保存在输入法用户目录的 `backups` 下。换机时先安装本项目，再恢复个人数据，最后重新启动输入法并应用更改。迁移包包含私人内容，请自行保管。

Windows 的常用语和设置迁移同样可用：将菜单入口后加 `data backup --settings-only` 或 `data restore "备份包路径" --settings-only`。自动处理学习快照还需要兼容的 `rime_dict_manager`，可通过 `RIME_DICT_MANAGER` 指定已有程序；Windows 原生学习恢复仍需实机验证。

## 字号与开关

### 关闭英文候选或释义

在上面的方案选单中，找到对应选项并切换：

| 选项 | 控制什么 |
| --- | --- |
| 英文候选 / 关闭英文候选 | 是否插入本项目的常用英文候选 |
| 英文释义 / 关闭英文释义 | 是否在中文候选旁显示英文释义 |
| 伴学显示 / 简洁显示 | 伴学显示完整义项；简洁只显示一个义项，长释义以省略号收尾 |

关闭英文候选后，原方案自带的英文词条仍可能显示。万象的 `;github` / `vvgithub` 专用英文入口仍可使用。

从方案选单切换上述开关或显示档后，状态会保存在本机，重启输入法后继续沿用。默认使用伴学显示。

### 字太大，换成紧凑字号

默认候选字号为 **17pt**、释义为 **16pt**。笔记本或普通显示器可以改用紧凑字号：候选 **15pt**、释义 **12pt**。

回到项目目录，按你的系统运行一条命令。脚本会重新备份、安装并部署。

**macOS：**

```sh
RIME_FONT_PRESET=compact ./scripts/deploy.sh
```

**Windows：**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy.ps1 -FontPreset compact
```

想恢复大字号，重新运行对应系统的默认安装命令。浅色和深色主题会随系统外观切换。

### 保留自己的应用与外观设置

在输入法用户目录创建 `squirrel.personal.yaml`（macOS）或 `weasel.personal.yaml`（Windows），将个人的应用偏好、字号和样式写在其中。个人文件最后生效，安装和回滚都会保留它；不要放进下载的项目文件夹。

例如，macOS 希望 VS Code 初始使用中文，并调整释义字号：

```yaml
patch:
  app_options/com.microsoft.VSCode/ascii_mode: false
  style/comment_font_point: 12
```

Windows 的应用规则使用进程文件名，例如 `app_options/code.exe/ascii_mode: false`。保存后对输入法执行「重新部署」即可，不必重新安装整套词库。

原先直接写在 `squirrel.custom.yaml` 或 `weasel.custom.yaml` 的个人设置，需要将想保留的应用和样式项目手动移入个人文件；安装前的旧配置仍会备份。

## 恢复原配置

如果安装后的设置不合适，在**同一个项目目录**运行对应命令，恢复最近一次安装前的配置：

**macOS：**

```sh
./scripts/rollback.sh
```

**Windows：**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\rollback.ps1
```

等待输入法重新部署完成。回滚只处理本次安装清单中的文件，撤回的版本也会保留。

<details>
<summary>备份保存在哪里？</summary>

| 系统 | 默认备份位置 |
| --- | --- |
| macOS | `~/Library/Rime/backups/` |
| Windows | `%APPDATA%\Rime\backups\` |

如果小狼毫配置了自定义用户目录，备份保存在那个目录的 `backups` 文件夹。每次备份以 `qingjian-learning-` 开头，后面带时间戳；脚本会打印本次备份的完整位置。

已有 `luna_pinyin.tech.dict.yaml` 聚合词库会保留，也不纳入此次回滚。安装器会将其私人词库导入接到万象的 `;` / `vv` 英文入口，后续更新也会保留 `bilingual_english.dict.yaml` 中的额外导入；朙月中文主词库不会被带入。安装清单中的其他同名文件会先备份再替换；两个平台不会互相覆盖 `squirrel.custom.yaml` 和 `weasel.custom.yaml`。同一份备份只能回滚一次。

</details>

## 常见问题

### 会自动更新到 GitHub 新版吗？

不会。需要更新时，重新下载本项目并运行对应系统的安装命令。日常选词和组词会自动更新本机学习数据库，私人短语则由你手动维护；这些本地内容不会自动上传到 GitHub。

### 已经安装，为什么看不到英文？

先确认三件事：正在使用鼠须管或小狼毫的**中文模式**；选中的是「万象拼音」；输入的是完整小写编码 `github`，而不是 `githu`。再检查方案选单里的英文候选、英文释义是否被关闭。

如果还没有生效，等待重新部署结束后重试；若安装命令报错，先按错误信息处理，不要把“复制了文件”当作部署成功。

### 为什么输入 github，第一候选可能还是「Git湖北」？

原方案可能把英文拆成拼音，例如 `github` 被拆成 `git hu b`。本项目保留原有首选，并把精确匹配的 **GitHub 放到第二项**，按 **2** 即可输出。第一候选会受方案和用户学习影响，不同电脑可能不同。

### Windows 提示目录编码不兼容，怎么办？

小狼毫的 Lua 模块需要目录能被 Windows 的本地编码表示。例如，英文 Windows 的默认码页 1252 无法表示中文目录。

请先在小狼毫的安装设置中选择一个**纯英文用户目录**（例如 `D:\Rime`），再重新运行本项目的安装命令。脚本会自动读取小狼毫登记的目录，不会擅自修改系统区域设置、注册表或全局 UTF-8 选项。

**不要只给命令加 `-UserDir` 来绕过这个问题。** 小狼毫重新部署时使用的是它登记的目录，单独修改复制目标不能改变输入法实际使用的位置。

### Windows 找不到 WeaselDeployer.exe，怎么办？

先确认小狼毫已正常安装。如果自动检测不到安装位置，可指定实际安装文件夹；下面的路径只是示例，请换成你电脑上的位置：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy.ps1 -WeaselDir 'C:\Program Files\Rime\weasel-0.17.4'
```

### 下载失败或出现 SHA-256 mismatch，怎么办？

下载失败时，先确认能访问 GitHub，然后重试。校验失败说明下载文件与固定版本不一致，脚本会停止安装；不要删除校验逻辑。

如果错误指出某个缓存文件损坏，只删除错误信息中的那个缓存文件，再重试。若仍失败，请提交 Issue 并附上错误信息。上游删除固定资产时也会报错，项目不会自动改用未经确认的新模型。

## 进阶设置

不需要自定义词表或参与开发，可以跳过本节。

<details>
<summary>添加常用英文、调整释义数量</summary>

编辑 `rime/data/internet-english.tsv`，每行三列，使用真正的 **Tab** 分隔：

```text
github	GitHub	代码托管
docker	Docker	容器
```

三列分别为：**完整小写编码、规范英文、候选注释**。编码只使用小写英文字母，不重复；数字键用于选词，所以不使用 `k8s` 这样的编码。请勿将个人短语、手机号、账号或内部项目名称放进公开词表。

默认最多显示两个英文义项。需要调整时，在 `rime/wanxiang.custom.yaml` 的 `patch:` 下加入：

```yaml
  bilingual_gloss/max_senses: 1
```

支持 1–4 项，以词表实际内容为限。修改后重新运行对应系统的安装命令。

常用编程和 AI 中文词优先使用 `rime/data/technical-glossary-en.tsv` 的专业释义，例如「回调」显示 `n. callback`。未收录的词继续使用青简原始释义；调整专业释义时，保持中文词条唯一并按 UTF-8 字节顺序排序。

</details>

<details>
<summary>给开发者：检查与回归测试</summary>

普通用户不需要运行这些命令。静态检查只核对已安装文件、编译配置和模型校验值，不能代替真实候选测试。真实引擎回归会逐项检查整张英文词表，并验证专用入口补全与上屏、中文学习、私人短语和排序。

中文体验语料在 `tests/data/input-experience.tsv`，覆盖日常整句、工作消息、简拼和错序拼写；本地全拼纠错规则在 `rime/bilingual_algebra.yaml`。例如 `jintainkaihui` 可容错为「今天开会」。它只补充明确的字母换位，不默认启用模糊音。

**macOS：**

```sh
./scripts/verify.sh       # 检查已安装的编译产物
./scripts/test.sh --unit  # Lua 回归与脚本语法检查
./scripts/test.sh         # 隔离目录中的真实引擎、安装与回滚测试
```

完整测试需要已安装的鼠须管，以及 Xcode Command Line Tools 提供的 `clang++`。

**Windows：**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-windows.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-windows.ps1 -Engine
```

最后一条还需 Visual Studio C++ Build Tools 和可从命令行调用的 7-Zip。它只解压、校验官方小狼毫安装包，使用其 `rime.dll` 测试万象方案的候选和上屏，不运行安装程序、不注册输入法。

文件操作测试覆盖含空格、中文的目录；Windows 原生引擎测试覆盖系统码页可表示的非 ASCII 路径。

**隔离目录参数：** macOS 使用 `RIME_USER_DIR` 与 `RIME_SKIP_RELOAD=1`；Windows 使用 `-UserDir` 与 `-SkipDeploy`。自定义测试目录必须跳过正式输入法部署。Windows 脚本会拒绝符号链接或目录联接。

**验证范围：** macOS 本机为 macOS 26.5.2、鼠须管 1.1.2、librime 1.16.0；Windows CI 使用 Windows Server 2022 x64、小狼毫 0.17.4，覆盖 PowerShell 5.1 和 7；Linux CI 检查 Lua 与 Shell 脚本。最新结果见 [Actions](https://github.com/AnneHtowardshaway/rime-bilingual/actions)。

Windows 桌面应用、候选窗口外观与高 DPI 效果仍需实机验收；Windows ARM64 和 Linux 桌面输入法尚未验证。

</details>

<details>
<summary>给开发者：目录与依赖</summary>

| 路径 | 内容 |
| --- | --- |
| `rime/lua/` | 英文候选与释义过滤器 |
| `rime/data/` | 常用英文词表、青简释义表 |
| `rime/*.custom.yaml` | 输入方案与候选窗口配置 |
| `rime/*.dict.yaml` | 技术英文、AI、日常与电子领域词条 |
| `scripts/*.sh`、`scripts/*.ps1` | 两个平台的安装、检查、回滚与测试 |
| `tests/` | Lua 和真实 Rime 引擎测试 |
| `third_party/` | 第三方署名与许可证 |

安装目录默认是 macOS 的 `~/Library/Rime`，或小狼毫登记的用户目录（通常为 `%APPDATA%\Rime`）。Windows 从 `HKCU\Software\Rime\Weasel` 读取 `RimeUserDir`，安装目录自动检测，也可用 `-WeaselDir` 或 `RIME_WEASEL_DIR` 指定。

万象 Base 固定为 `v17.10.3`，语法模型使用固定 GitHub 资产 ID 和 SHA-256 校验，缓存放在 `.cache/wanxiang/`。具体版本及校验值见 [资源署名说明](third_party/wanxiang/ATTRIBUTION.md)。

不要将整个输入法用户目录上传到 GitHub。仓库忽略构建缓存、模型缓存、备份、同步数据、用户数据库和本机安装信息。

</details>

## 来源与许可

原创配置、脚本、Lua 扩展与自编词条采用 **GPL-3.0-or-later**，见 [LICENSE](LICENSE)。第三方资源保留各自的许可证。

| 资源 | 来源与说明 |
| --- | --- |
| 离线英文释义 | [青简 Qingjian](https://github.com/qingjian-team/qingjian)，仅改文件名；[署名与 GPL 许可](third_party/qingjian/ATTRIBUTION.md) |
| 拼音方案 | [万象拼音](https://github.com/amzxyz/rime-wanxiang)，固定版本；[资源与许可](third_party/wanxiang/ATTRIBUTION.md) |
| 语法模型 | [万象数据](https://github.com/amzxyz/rime-wanxiang-data)，按需下载，不纳入 Git |
| LangChain 专业词条 | 整理自官方 Docs 与 API Reference，只收录术语和 API 符号，不复制正文 |

英文释义由青简上游使用大语言模型离线生成，可能有误，适合作为学习提示。本项目不提供云端翻译、译词一键替换或学习计数功能，与 Rime、鼠须管及小狼毫上游没有官方隶属关系。

遇到问题或想补充词条，请[提交 Issue](https://github.com/AnneHtowardshaway/rime-bilingual/issues)，附上**操作系统、输入法版本、使用的方案、输入编码和期望结果**。只提交你有权公开的通用词条。
