# 固定工具链与官方工具接入

核验日期：2026-10-27。项目作用域 `/Users/sitkin/my_code/starward_hm`。

| 工具 | 本机精确版本 | 核验 |
| --- | --- | --- |
| DevEco Studio | 26.0.0.851 | `Contents/Resources/product-info.json` |
| SDK | HarmonyOS 26.0.0 Release / API 26 / 26.0.0.105 | `Contents/sdk/default/sdk-pkg.json` |
| Hvigor | 6.26.8 | 内置 `hvigorw.js --version` |
| ohpm | 26.0.0.630 | 内置 `tools/ohpm/package.json` |
| 构建 Node | 24.14.1 | 内置 `tools/node/bin/node --version` |
| DevEco CLI | 1.3.0-stable | `devecocli --version`，npm stable 标签再次核验 |

CLI 使用 `npm install -g @deveco/deveco-cli@1.3.0-stable` 安装。npm `latest=1.3.9` 是另一渠道，不将其当稳定版。工程构建使用 Studio 配套 Node，Shell Node 24.13.0 仅承担 CLI 启动。现有设备一台，预研已核验 API26；不在文档记录设备标识。

## MCP

项目 `.codex/config.toml` 配置两项：

- 官方远程知识：`https://connect-api.cloud.huawei.com/api/developerknowledge/mcp`，仅开放 `searchDocuments` / `getDocumentsById`。已实际通过 HTTP 执行 tools/list、搜索 API26 MVVM V2，再根据 parent 读取全文；成功取得官方 `arkts-mvvm-v2` 正文。
- 官方本地 LSP：`devecocli init --mcp --agent codex --project /Users/sitkin/my_code/starward_hm` 写入的 `deveco-mcp`，用于工程 ArkTS 语义检查。它不代替远程文档，也不代替完整编译。已通过官方服务实际执行 stdio initialize、tools/list 和 check；Index.ets 与 HttpsGameRepository.ets 均返回 no diagnostics（首次同步后等待11秒重试成功）。证据为 artifacts/validation/mcp-check.json。

`codex mcp get harmonyos_developer_knowledge --json` 已从本项目解析出正确的 HTTP 配置。当前聊天的工具目录不会因为写入配置自动证明热加载成功；后续新会话需检查 MCP 及 Skill 发现。当前会话通过真实 HTTP 读取官方文档、通过 CLI 执行工程工具，不将“已写配置”称为“当前会话已热加载”。

配置限于本项目，没有修改全局 Agent/MCP。Codex 仅加载受信任项目配置：[官方 MCP 配置说明](https://learn.chatgpt.com/docs/extend/mcp)。

## Skill

已审读安装包唯一内置 `SKILL.md`，执行：

```sh
devecocli init --skill --path /Users/sitkin/my_code/starward_hm/.agents/skills
```

真实输出 Success 1 / Failed 0；文件在 `.agents/skills/deveco-cli/SKILL.md`。采用官方 CLI 作为平台工具层；不安装未审计 Registry 技能。Skill 中自动更新、签名、卸载、模拟器等命令仍按实际任务范围使用，不因为文档列出就执行。来源：[CLI 快速入门](https://developer.huawei.com/consumer/cn/doc/doccenter-deveco-studio/ide-deveco-cli-install)、[命令说明](https://developer.huawei.com/consumer/cn/doc/doccenter-deveco-studio/ide-deveco-cli-options)。

## 调试签名接入与CLI限制

2026-10-27 本轮已分别完成 DevEco Studio 与 DevEco CLI 的华为开发者登录；两者会话独立，Studio登录成功不能推断CLI已经登录。官方CLI签名入口是 `devecocli signature generate --product default`，但本机 **1.3.0-stable** 在“云端设备列表为空、当前连接为USB真机”的条件下遇到前置检查缺陷：该分支只把loopback连接的模拟器视为可用目标，排除了已由HDC识别的USB真机，因此不能据此判定设备未连接或用户未登录。

本轮改用 **DevEco Studio → Project Structure → Signing Configs 的自动签名流程**。IDE已生成一项本机调试签名配置，所需签名材料文件存在。没有修改CLI包、使用私有接口、伪造loopback设备或以重装/重置凭据规避检查。以上限制来自本机该稳定版本的代码与实际行为核验，只适用于所述云端设备列表为空的分支，不泛化为所有CLI版本都无法为真机签名。

生成配置与完成签名安装是不同环节；实际signed HAP、安装、启动和UI结果以 [首切片验收记录](slice-01-validation.md) 为准，本节不提前标记设备验收通过。

根目录 `build-profile.json5` 含本机IDE签名配置，已加入 `.gitignore`，不得强制提交。版本管理保留无签名材料的 `build-profile.example.json5`。`scripts/hm.sh` 启动时若缺根配置，会从样例复制创建；不会覆盖现有本机配置。不要把签名文件、路径对应的私人材料、口令、设备标识或开发者登录会话写入示例、报告或日志。

项目脚本新增 `run` 子命令：

```sh
scripts/hm.sh run
```

它调用官方 `devecocli run --module entry --product default --build-mode debug`，在本机有效签名配置与目标设备可用时执行构建、安装和启动。多设备场景应先明确目标，再使用CLI的设备选择选项；不要根据旧记录猜测在线设备。无本机签名配置时，自动复制样例只提供无凭据的工程结构，不意味着已取得签名能力。

## 开始业务实现前的准备门槛

2026-10-27 已完成：工具版本核验、官方知识查询链路、本地官方 Skill 安装、项目级 MCP 配置、AGENTS.md、10 项 ADR、功能逐状态验收表。源码基线是冻结的本地 Web 候选，线上版本 GET 403，发行基线核验仍待完成。后续切片可在 mock 模式推进；不得因此声称生产协议/视觉/真机已经验收。
