# 002 计算机专业英语选词优化：交付复盘

- 日期：2026-10-29（Asia/Shanghai）
- 状态：用户确认后完成源码实现与 macOS 隔离真实引擎验证；未部署日用输入法，Windows 实机未验证。

## 1. 解决的问题与结果

普通中文模式的专业英语精确词表缺少算法、类型、操作系统、网络安全、数据库/分布式及工程测试等基础概念。本轮新增 300 个独立术语，每词提供英文连写与中文拼音两种编码，共 600 个编码；别名未重复计数。相对原精确词表，300/300 术语为新增；并非声称上游词库或旧专用入口从未收录这些词。

例如 algorithm / suanfa → algorithm；datastructure / shujujiegou → data structure；authentication / shenfenrenzheng → authentication。hashmap → HashMap 等旧 API 编码保持；通用 hash map 通过 cshashmap / haxiyingshe 输入。精确英文总数由 4240 增至 4840，专业释义由 49 增至 102（新增 53）。

前期曾把旧拼音词库未进入普通精确 TSV 误写成未接入聚合；实际 bilingual_english 已将旧词用于 ; / vv 专用入口，实施前已纠正。未全量导入旧表或改其可疑编码。

## 2. 文件与核心逻辑

- rime/tech_english_computer.dict.yaml：新增 300 术语及 600 编码，UTF-8、三列 text/code/weight、中文概念注释。权重为 80，冲突码使用明确的 cs 前缀。
- rime/tech_english_table.dict.yaml 与 bilingual_english.dict.yaml：分别接入普通模式生成链和 Rime 直接聚合编译链。
- scripts/build-programming-vocabulary.py：新增计算机词库标签；排序、同码权重和既有主题词优先逻辑保持。
- rime/data/programming-english.tsv：生成器更新，4625 编程/主题编码，加互联网 215 编码共 4840。
- rime/data/technical-glossary-en.tsv：补 53 条专业释义，保持 UTF-8 字节排序、中文词条唯一。
- tests/vocabulary_generator_spec.py：检查 300/600 数量、精确链完整接入、直接聚合导入和已有 API/日常码保护。
- tests/vocabulary_spec.h、tests/rime_engine.cpp：新增 20 个独立术语的 30 个逐键/数字键用例、60 个专用入口、2 个前缀补全；增加英文/拼音两种中文前段接续测试。
- scripts/verify.sh、verify.ps1：检查新增词库已安装。现有 deploy.sh 与 Windows Get-PayloadFiles 均递归收集公开 rime 文件，不需改其安装/回滚机制。
- README.md、docs/macos.md、docs/windows.md：更新总数、词表链接及实际可用示例，明确旧离线包未包含本轮词库。

没有修改 Lua 过滤器、用户词频、模型或中文排序。既有离线安装包改动保持，未改打包器、未创建新发布。

## 3. 实际验证

最终完整命令：`./scripts/test.sh > .cache/computer-english/acceptance.log 2>&1`，退出码 0。

| 检查 | 实际结果 |
| --- | --- |
| vocabulary_generator_spec.py | 7/7 passed |
| phrases_spec.py | 8/8 passed |
| rime_native_spec.py | 14/14 passed |
| personal_data_spec.py | 17/17 passed |
| manage_spec.py | 5/5 passed |
| release_spec.py（已有安装包任务测试） | 11 passed / 13 discovered，2 skipped：未指定 RIME_RELEASE_PAYLOAD；不算作通过 |
| Python 合计 | 62 passed，2 skipped，无失败 |
| 生成器 --check | 4625 编码同步通过 |
| Lua 回归 | 4840 编码、102 专业释义，以及去重/范围/开关通过；未虚构断言总数 |
| 原编码前后比较 | 4240/4240 原输出保留，新增 600 |
| 新词统计/格式 | 300/300 独立新术语，600/600 合法编码 |
| 真实 Rime 全量候选 | 4840/4840 排序及去重通过 |
| 中文原体验语料 | 50/50 passed |
| 新专业英语逐键与数字提交 | 30/30 passed，涉及 20 个独立术语 |
| 专业入口 ; / vv | 60/60 完整选词上屏通过 |
| 专业前缀补全 | 2/2 passed |
| 混输 | 原 4 例及新增 woyongalgorithm / woyongsuanfa 均完整提交 |
| 学习、开关与重启 | 既有真实引擎回归通过 |
| 安装、验证与回滚 | 私人词库哨兵、个人配置、中途失败恢复和回滚保护通过 |
| Python 语法 | python3 -m py_compile scripts/build-programming-vocabulary.py tests/vocabulary_generator_spec.py，退出码 0 |
| 格式门禁 | git diff --check，退出码 0 |

脚本实际使用 clang++ 编译测试器，并在 `.cache/test/run.iBp2Sr` 编译 Rime 方案、验证模型与双语过滤链，最后回滚隔离安装。最终日志：`.cache/computer-english/acceptance.log`。先前两次回归也通过，但交付以上述最终版本结果为准。

文件大小：新计算机字典 24,850 bytes；生成的 programming-english.tsv 202,844 bytes；technical-glossary-en.tsv 2,896 bytes。未重打 PKG/EXE，因此没有新的安装包体积或附件；不以旧包充作本轮产物。

## 4. 来源与术语复核

名称参考 [NIST DADS](https://xlinux.nist.gov/dads/terms.html)、[Oracle Java Glossary](https://www.oracle.com/java/technologies/glossary.html)、[PostgreSQL Glossary](https://www.postgresql.org/docs/current/glossary.html)、[NIST CSRC Glossary](https://csrc.nist.gov/glossary)。只整理通用术语名称，中文概念与拼音为本项目整理，没有复制定义正文。代码回归确认编码映射和上屏，不等于外部语言专家逐条审定。

## 5. 人工验收、限制与回滚

本轮已完成 macOS 真实 librime 隔离输入验收；没有在用户日用应用中手动输入，没有改正式 Rime 用户目录。Windows/PowerShell 当前未发现可用运行环境，Windows 脚本及桌面效果未执行验收；两平台共享词库、直接导入和安装遍历已做代码检查，不能替代实机结果。

源码修改保持未暂存、未提交、未推送。用户之后可按平台教程用脚本安装并重新部署；已有离线包需要另行重建才会包含这次新增词。源码回滚只撤回本轮词库、聚合、生成表、释义及测试/说明增量，不能整文件覆盖共享文档或撤销既有打包工作。部署后的恢复沿用现有安装前备份和回滚脚本。
