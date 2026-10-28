# Starward 鸿蒙原生应用前置调研

调研日期：2026 年 10 月 27 日。目标是把现有 `questions-web` 的正式业务、视觉和交互用 ArkTS 与原生 ArkUI 重写，后续支持桌面服务卡片和 Push。源项目位于 `/Users/sitkin/my_code/questions-web`，新项目位于 `/Users/sitkin/my_code/starward_hm`。

当前建议采用：**官方鸿蒙开发者知识 MCP、DevEco CLI 及少量官方 Skills、项目专属迁移规则、已有代码审查能力**。不需要先安装庞大的架构技能包，也不需要先搭建向量数据库或自建全量鸿蒙 RAG。

用户已明确要求 DevEco Studio 和配套工具采用最新版本，并授权更新。执行时优先选择官方最新稳定版本，记录精确版本及配套关系；工程创建后固定版本，后续升级通过独立任务验证。应用业务代码尚未开始。

## 环境与升级状态

### 升级前实测

| 项目 | 本机结果 |
| --- | --- |
| Mac 架构 | Apple Silicon arm64，应选择 Mac ARM 安装包 |
| DevEco Studio | 6.0.2.650 |
| 内置 SDK | HarmonyOS 6.0.2 Release，API 22，SDK 6.0.2.130 |
| Hvigor | 内置 6.22.4 |
| ohpm | 内置 6.0.1 |
| DevEco 内置 Node | 18.20.1 |
| Shell 中的 Node | 24.13.0，与 IDE 内置 Node 不同 |
| hdc | 3.2.0c，已在 PATH |
| 测试工具 | DevEco Testing for App 实际版本 6.1.0.211，SDK 含 Hypium |
| 已连接设备 | 1 台，API 26，软件版本 7.0.0.111 |

核验依据为 IDE 的 `product-info.json`、SDK 的 `sdk-pkg.json`、工具自身的包元数据和 hdc 的只读版本查询。设备标识和签名凭据不应写入项目文档。

### 升级进度

已完成更新。2026 年 10 月 27 日官方下载中心的最新稳定版为 **DevEco Studio 26.0.0 Release，Build 26.0.0.851，发布日期 2026 年 9 月 23 日**。Studio 与 Testing 均从官网 Mac ARM 包安装，原路径保持不变。[官方下载中心](https://developer.huawei.com/consumer/cn/download/)

| 升级后项目 | 实际验证结果 |
| --- | --- |
| DevEco Studio | 26.0.0.851，已正常进入欢迎界面，原有最近项目仍在 |
| HarmonyOS SDK | 26.0.0 Release，API 26，SDK 26.0.0.105 |
| Hvigor | 6.26.8，命令行版本查询通过 |
| ohpm | 26.0.0.630，命令行版本查询通过 |
| IDE 内置 Node | 24.14.1，项目构建使用这套配套运行时 |
| Shell 的 hdc | 3.2.0f，原 PATH 已指向更新后的 IDE；识别到 1 台设备 |
| DevEco Testing | 26.0.0.500，内置 SDK 3.0.1.261；未启动 GUI |
| Testing 内置 hdc | 官方新版包仍为 3.2.0c，与 Studio 内置工具分开 |

Studio 安装包 SHA-256 与官网值一致；Studio 和 Testing 安装前后均通过 `codesign --verify --deep --strict`，公证来源校验返回 Notarized Developer ID。SDK 与各工具版本来自实际安装文件和命令输出。尚未创建工程，因此应用构建、调试签名、安装到设备和原生功能测试仍属于下一阶段。

公开版本说明中的 26.0.0.821 是更早的 Release 构建，不能代替下载中心的最新补丁。[官方版本配套](https://developer.huawei.com/consumer/en/doc/harmonyos-releases/deveco-studio-new-features-2600)

Studio 包 SHA-256 为 `86289edeb2e8e30eb1adf80cba0fc55f0e57cdd4f6dc4ec9c59985a0bc4b8524`，已与官网下载页复制值比对。Testing 包本地 SHA-256 为 `b45332fd508070a1b72ce639b35ebe9f7ded68f29c8e9355b6eef57a07a5a3fc`；后者仅作本地记录，未与官网值比较，已验证 ZIP 完整性和应用开发者签名。

旧版完整备份保留在 `/Users/sitkin/Downloads/starward-hm-toolchain-backup-20261027/`，分别为 `DevEco-Studio-6.0.2.650.app` 和 `DevEco_Testing_for_App-6.1.0.211.app`。原下载包保留，安装时挂载的两个镜像均已卸载；未更改签名凭据或系统安全设置。

API 20 起 SDK 随 IDE 预置，通常不需要再安装另一份同版 SDK。[官方升级说明](https://developer.huawei.com/consumer/en/doc/harmonyos-releases/upgrade-adaptation)

“工具用最新”和“最低兼容系统”是两个决定。compile/target SDK 随新工具链统一，最低支持 API 仍需按发行对象确定。现有真机为 API 26，能够承担首阶段验证，但不等于已覆盖所有兼容设备。

## 技能与知识获取方案

### 官方知识 MCP 作为首选资料入口

已实际读取[华为官方接入说明](https://developer.huawei.com/consumer/cn/doc/start/hosknowledgemcp-0000002664603963)，并通过 HTTP 成功执行 `tools/list`、`searchDocuments`、`getDocumentsById`。查询 MVVM V2 和 Push Skill 时均取得官方 Markdown 正文；本次公开查询未使用账号凭据。

服务地址：

```text
https://connect-api.cloud.huawei.com/api/developerknowledge/mcp
```

服务提供搜索与按文档标识获取全文，后一工具一次最多读取 10 篇。后续工作应先搜索，再读取命中的完整文档；把 SDK/API 版本写进问题，并核对接口版本标记，避免默认使用官网最新样例。

未来可按 Codex 的 HTTP MCP 配置方式接入；下列为待执行示例，本次没有修改配置：

```toml
[mcp_servers.harmonyos_developer_knowledge]
url = "https://connect-api.cloud.huawei.com/api/developerknowledge/mcp"
```

[OpenAI 官方 MCP 配置文档](https://learn.chatgpt.com/docs/extend/mcp?surface=cli)支持项目级 `.codex/config.toml` 和用户级配置。应选择明确的作用域，避免把项目特定约束扩散到所有工程。

### 官方文档索引与本地 SDK 作为后备

华为已提供 [llms.txt 一级索引](https://developer.huawei.com/config/llms.txt)，按架构、设计、开发、测试、上架等分类指向二级索引，再指向 Markdown 正文。[使用说明](https://developer.huawei.com/consumer/cn/doc/start/llms-0000002670606713)

推荐资料优先级：当前后端契约决定业务事实；选定 SDK 的声明和编译器决定接口与语法是否可用；对应版本的官方指南决定生命周期、权限和行为限制；官方样例辅助实现；社区资料用于补充排障。

项目只需维护少量已验证资料：来源链接、适用 API、核验日期、最小复现、解决方法和验证命令。若将来出现持续离线需求或官方检索漏答，再利用官方索引构建本地全文索引。现阶段没有证据需要引入独立向量服务。

### DevEco CLI 与官方 Skills

[官方概述](https://developer.huawei.com/consumer/cn/doc/doccenter-deveco-studio/ide-deveco-cli-overview)说明 DevEco CLI 为通用 AI Agent 提供鸿蒙工具、知识库与 Skills。它适合作为 Codex 的平台工具层；DevEco Code 是另一款完整 AI Agent，不是使用 Codex 开发的必要前置。

[快速入门](https://developer.huawei.com/consumer/cn/doc/doccenter-deveco-studio/ide-deveco-cli-install)区分稳定版与尝鲜版。2026 年 10 月 27 日 npm 元数据：`stable` 为 `1.3.0-stable`，`latest` 为 `1.3.9`；包要求 Node >=22，本机 Shell 的 Node 24.13.0 已满足。不要把 npm 的 `latest` 标签直接解释为稳定版。

待执行的稳定版安装命令：

```sh
npm install -g @deveco/deveco-cli@stable
```

[命令文档](https://developer.huawei.com/consumer/cn/doc/doccenter-deveco-studio/ide-deveco-cli-options)支持 `init`、`docs search/read/catalog`、`check lint/compat`、构建运行、设备及 UI 操作、`skills list/find/add`。`init` 默认会配置所有检测到的 Agent，因此实际接入时应显式限制到 Codex 和本项目，先检查目标目录，再写入；不执行无差别全局 `--all`。

已下载官方稳定版 tarball 并核对 npm SHA512，仅读取文件，没有安装或执行包代码。包唯一内置 Skill 为 `deveco-cli`，其余 `skills list/find/add` 条目来自 Matrix registry。包内还有离线文档与索引，索引时间为 2026 年 8 月 29 日；CLI 的离线资料与官方远程知识 MCP 的时效边界不同。

CLI 1.3.0-stable 的 Codex 适配仍写入 `.codex/skills`；当前 Codex 公开规范列出 `.agents/skills`。建议将目标目录显式设为后者，配置后核验新会话是否实际发现 Skill。待执行示例：

```sh
mkdir -p /Users/sitkin/my_code/starward_hm/.agents/skills
devecocli init --skill --path /Users/sitkin/my_code/starward_hm/.agents/skills
```

`--path` 指 Skill 的父目录，CLI 会追加 `deveco-cli`；它与 `--agent`、`--project` 互斥。`init --mcp` 注册的是本地 LSP 工具服务，与远程官方知识 MCP 分工不同。这里尚未安装 CLI、Skill 或 MCP。

Matrix registry 中已审读的候选还需要筛选，不能把“官方渠道可下载”理解为每条硬规则都适合本项目：

| Skill | 建议 |
| --- | --- |
| `hmos-arkui-develop-skill` 1.1.1 | 可按需补，核验速查表与所用 SDK；不是初始必装 |
| `hmos-arkui-mvvm-pattern` 1.1.0 | 可作参考，但部分引用仍调用旧 MCP，Node 版本说明也与 CLI 实际要求不同；转化为项目自己的简洁规则 |
| `hmos-local-test`、`hmos-instrument-test` 1.0.1 | 测试链路建立后再补；包装器可能在缺少报告时返回 partial success，必须检查真实报告和用例数量 |
| `hmos-arkts-syntax-checker` 1.0.1 | 仍强制依赖旧 CodeGenie MCP，不采用这条安装路径 |

Registry 的 HTML 视觉设计 Skill 和 uni-app/Taro 转换 Skill 不适用于本次全原生复刻。未找到必须依赖的独立桌面卡片 Skill，直接使用 Form Kit 官方资料即可。[Skill registry](https://matrix.openharmony.cn)

Push 阶段已有官方 [hmos-push-kit 场景化消息 Skills](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-skill-scenes)，包含通知、后台消息及 VoIP 子技能。客户端生成 ArkTS，服务端技能当前只生成 Java；当前 PocketBase 后端不能直接整套采用该 Java 服务端模板。只在推送阶段按场景选择，暂不引入 VoIP。

### 社区候选审计

下表为 2026 年 10 月 27 日查询快照。安装数、stars 和更新时间只用于衡量维护状况，不能证明代码正确。候选的实际 SKILL.md 已阅读；本轮没有安装。

| 候选 | 内容与限制 | 选择 |
| --- | --- | --- |
| [CoreyLyn harmonyos-dev](https://github.com/CoreyLyn/harmonyos-skills/blob/main/skills/harmonyos-dev/SKILL.md) | 约 179 安装、32 stars、MIT。先核验本地 SDK、API、权限、SysCap、状态管理版本，再查当前官方资料；工作流较薄 | 官方覆盖不足时优先补充 |
| 同仓 harmonyos-review | 约 111 安装，补充生命周期、存储、并发和权限检查 | 与现有通用审查整合后选择，不必重复安装 |
| [documentation-and-adrs](https://github.com/addyosmani/agent-skills/blob/main/skills/documentation-and-adrs/SKILL.md) | 约 6.4 万安装，MIT。帮助记录架构决定及理由 | 可选；直接维护 ADR 模板也足够 |
| [linhay harmony-next.skills](https://github.com/linhay/harmony-next.skills) | 约 358 安装、367 stars；API12–23 指南加 API26 声明，API26 指南不完整；未发现 LICENSE，还含大量工具脚本与私有 IDE 接口 | 暂不整包启用，可作离线候选 |
| [ArkTS syntax assistant](https://github.com/SummerKaze/skill-arkts-syntax-assistant) | 约 825 安装、88 stars、MIT；2026 年 1 月后未更新，含固定编译失败次数、工具绑定和跳过编译选项 | 不作为默认开发流程 |
| [Midscene Harmony automation](https://github.com/web-infra-dev/midscene-skills/blob/main/skills/harmony-automation/SKILL.md) | 约 2.4 千安装，MIT；依赖 HDC 和另配视觉模型密钥/调用 | 有 App 后评估，初期用官方测试能力 |

可复现候选标识：`CoreyLyn/harmonyos-skills@harmonyos-dev`、`CoreyLyn/harmonyos-skills@harmonyos-review`、`addyosmani/agent-skills@documentation-and-adrs`。未来安装仍应先复核目标 commit 和权限行为，优先放本项目 `.agents/skills/`。[Codex 本地技能作用域](https://learn.chatgpt.com/docs/build-skills)

[open-deveco/deveco-toolbox](https://github.com/open-deveco/deveco-toolbox) 已于 2026 年 6 月归档，其 README 推荐转向官方 DevEco CLI；旧教程中的 DevEco MCP 不应再作为首选。[Context7 的 HarmonyOS 条目](https://context7.com/harmony-55/harmonyos_docs)来自社区镜像，不是华为维护，也不能代替版本校验；无需为了这个项目单独安装 Context7。

通用软件架构技能不是必要安装项。已有代码审查技能可以继续使用；大型架构工具包引入的额外流程和关联技能，对当前规模未必有收益。真正值得固化的是本项目的迁移顺序、资料优先级、编译验证和功能验收规则。

## 原 Web 项目的实际迁移范围

正式路由以 [App.tsx](/Users/sitkin/my_code/questions-web/src/app/App.tsx:36) 为准：登录、主页及场次、资料、奖品、通知、答题、解锁剧情。旧 `?qa/?qas`、独立 Letter/Bless、clearCache 已退出正式入口，不应按历史目录全量重做。

当前项目已经改为 PocketBase 服务端权威。判题、准入、进度、等级经验、惩罚、线索权限、奖励和通知已读状态来自后端。鸿蒙复用同一 HTTPS 业务契约，客户端用 ArkTS 重写类型、校验、缓存和调用，不将旧本地判题逻辑搬回 App。

| 能力 | 必须保留的行为 | 原生改写重点 |
| --- | --- | --- |
| 登录与资料 | 管理员分配账号、首次强制改密、后续改密、昵称、头像裁剪上传、退出清缓存 | 网络/文件上传、凭据存储、账号隔离、系统图片选择及裁剪；按所用能力核验权限 |
| 场次与答题 | 单题/多题、时间窗、等级准入、填空/选择、冷却/锁定、自动前进、线索组合、奖励演出 | 时间偏移、幂等提交、恢复状态、返回栈 |
| 剧情与媒体 | 信纸开合/翻页、粒子、配音、BGM、片尾演出 | ArkUI 动画/绘制、原生媒体、焦点与生命周期 |
| 奖品与通知 | 私人领取信息、核销状态、未读弹窗、归档、标记已读 | 隐私展示、通知去重、后续 Push 衔接 |
| 通用体验 | 明暗与系统主题、浮动 BGM、媒体缩放、抽屉/弹窗队列、返回位置、动画中断 | vp/fp 与安全区、系统返回、手势、无障碍、减弱动画 |

当前认证头为 `Authorization: token`，不要擅自加 `Bearer`。入场和答题已有 requestId 幂等规则，网络重试应保留原请求身份和键。修改密码不自动重试：响应丢失后重放旧密码可能失败，不能把所有写请求套用同一重试策略。[实际客户端](/Users/sitkin/my_code/questions-web/src/api/game.client.ts:139)

受保护头像还涉及 `/api/files/token` 临时文件 Token 的获取与刷新，原生数据层需要覆盖过期和账号切换。[认证与文件状态](/Users/sitkin/my_code/questions-web/src/features/game/GameContext.tsx:58)

DTO 权威源在后端 `/Users/sitkin/my_code/sitkin-pb-backend-management/backend/contracts/game.ts`，Web 的 [game.contracts.ts](/Users/sitkin/my_code/questions-web/src/api/game.contracts.ts:1) 为生成物。ArkTS 不应直接复制含复杂 TS 联合和递归 JSON 的实现；先定义兼容编译器的边界模型，再对同一响应夹具验证。

“一比一”需要在验收中明确：以当前正式 Web 版本为基线，冻结对应 commit、设备尺寸、页面截图、录屏和状态表。当前 checkout 不自动等于线上发布版本，应核对发布元数据后确定基线，并明确尚未发布的功能是否纳入。保留业务及视觉交互，不依赖重设计类技能重新塑造界面。浏览器与系统能力的差异通过原生实现满足同一行为目标。

## 架构建议

采用 **Stage 应用模型、ArkTS、原生 ArkUI、Navigation 导航、状态管理 V2、按业务组织的 MVVM** 作为候选技术基线。升级后用真实编译器核验具体能力，不能仅凭文档样例宣称可运行。[官方 MVVM V2](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-mvvm-v2)

MVVM 管理页面状态和交互；系统层面还应隔开业务用例、数据访问和平台能力。初期保持少量模块，先建立清晰的依赖关系；只有出现构建、团队或复用收益时再拆更多 HAR/HSP。

| 边界 | 责任 |
| --- | --- |
| 页面与 ViewModel | 页面状态、用户事件、加载与错误、弹窗/演出顺序；不直接拼后端 URL |
| 业务用例与领域模型 | 入场、提交答案、读通知、账号切换等流程；以服务端结果为准 |
| Repository 与数据实现 | HTTPS DTO 转换、缓存、运行时校验、重试/幂等、持久化 |
| 平台适配 | 凭据、文件/相册、媒体、网络状态、系统生命周期、深链、卡片与推送 |

业务入口如页面、卡片点击、Push 点击，应进入同一导航与权限检查。Push 和卡片调用相同业务边界，但分别处理平台生命周期。

需记录为 ADR 的首批决定：最低 API、应用及 bundleName、模块边界、V2 状态管理规则、导航/深链、认证与凭据存储、缓存及失效策略、媒体焦点、卡片数据快照、幂等与进程恢复。每份 ADR 写清问题、选择、备选、代价和验证方法即可。

### 卡片预留

桌面服务卡片使用 Form Kit / FormExtensionAbility。官方进程模型说明 UIAbility 和 FormExtensionAbility 内存隔离，因此页面单例不能充当卡片共享状态。应预留持久化摘要、卡片 DTO、刷新入口和统一深链，退出登录时清理旧账号内容。[卡片进程模型](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/arkts-ui-widget-process)

卡片显示的隐私级别、离线数据、刷新频率与网络能力需要按选定卡片类型单独验证。桌面卡片不是 App 页面的小尺寸复制品，刷新也不能沿用 Web 的常驻轮询假设。

### Push 预留

Push Kit 提供云到端消息；Notification Kit 用于本地通知。现有 Web 通知每 5 秒轮询，后续远程推送还需要后端的设备 Token 登记、账号绑定/解绑、发送、失效处理和点击路由。收到消息后回源同步业务事实，不能把推送载荷当新的权威数据库。[Push Kit 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-kit-introduction)

后台消息不是任意后台常驻执行器。Push 服务端凭据留在业务服务端。接入时核验最新 HarmonyOS 指南，不套用 Android HMS Core 的 Gradle、APK 和指纹配置流程。[开通推送服务](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-config-setting)

## 开发前优先消除的风险

1. **原生网络可达性。** [部署记录](/Users/sitkin/my_code/questions-web/docs/production-deployment-20260828.md:26)仍提到 Origin 限制，Web README 提到部分旧 OSS 素材防盗链。登录、API、受保护头像、图片、视频、BGM 都需用原生请求逐条验证；原生不受浏览器 CORS 约束，不代表服务端准入和 Referer 策略自动通过。目前只发现风险，未请求生产业务数据。
2. **ArkTS 与 TS 差异。** 明确对象/DTO、错误和回调类型；不要直接迁移 npm 浏览器库、React hooks、Zod 或 DOM API。语法、JSON 和类型断言的兼容性由选定编译器验证。
3. **状态管理与生命周期。** 新页面统一 V2，旧教程的 V1 装饰器按边界审查；分别处理页面隐藏、App 后台、进程被杀、账号切换和请求返回顺序。
4. **媒体与演出。** 答题成功的服务端状态与 UI 演出状态分开。退出演出或进程重启不能重复提交。BGM、语音和视频的互斥、暂停恢复、焦点变化、计时和资源释放要有显式状态机。
5. **原生视觉验收。** Web 的 CSS/Canvas、手势和头像裁剪需原生重写。重点核验文字换行、字体、弹窗、安全区、键盘遮挡和动画，不把“编译通过”当“复刻完成”。

资料中要区分官方商业 HarmonyOS、OpenHarmony、历史 FA/JS/Java 教程和 Android HMS。SDK 同时包含 `openharmony` 与 `hms` 目录，设备 fullname 含 OpenHarmony，也不足以把本项目判定为开源开发板目标。

## 测试与资料交付

原生验证使用 ArkTS 编译、codelinter、业务单元测试、Hypium/UiTest 和真机操作。已有 Playwright 用例可转换为平台无关验收表，并继续验证 Web 基线，但不能代替 ArkUI 自动化。[官方测试入口](https://developer.huawei.com/consumer/cn/testing/get-started/)

第一条可运行切片宜选择登录、首次改密、主页和一个场次详情，打通命令行构建、调试签名、安装启动、网络、日志和截图。Web 默认直连生产，功能联调优先使用模拟响应或隔离环境；需要生产联调时使用专用测试玩家，避免改变真实玩家的密码、进度及奖励。[开发环境说明](/Users/sitkin/my_code/questions-web/README.md:46) 这个切片属于下一阶段，当前只进行调研与已授权环境更新。

可复用输入：

- [UI 系统](/Users/sitkin/my_code/questions-web/docs/ui-system.md:90)、[答题状态保留规则](/Users/sitkin/my_code/questions-web/docs/question-ui-preservation.md:7)、[动画和中断规则](/Users/sitkin/my_code/questions-web/docs/global-motion-plan.md:117)。
- [语义色与尺寸](/Users/sitkin/my_code/questions-web/src/styles/foundation/tokens.css:1)、[集中中文文案](/Users/sitkin/my_code/questions-web/src/config/ui-copy.ts:1)、现有 E2E 夹具和品牌原图。
- 当前 `game.client.ts`、`game.contracts.ts`、`game.schema.ts`，以及对应的后端契约源。

旧 `docs/api-contract.md`、`storage-contract.md` 混有迁移前逻辑，不能整包直接作为当前知识库。新项目的 AGENTS.md 应规定当前源码、契约、SDK 和官方文档之间的适用优先级；应用规则不要复制 Web 仓库特有的 pnpm 发布命令。

建议下一阶段交付四类项目材料：工具链版本记录、功能与逐状态对照表、架构 ADR、原生构建与验收流程。它们比再安装一批泛化设计技能更能降低鸿蒙开发的不确定性。

## 下个会话的启动要求

先读本文件并核验升级后的真实版本。以当前正式 Web 源码和后端契约制作迁移对照表，再确认模块边界与最低兼容 API；配置官方知识 MCP 和经过审计的 DevEco CLI Skill；建立本项目 AGENTS.md 和验证流程。完成这些工程准备后，再开始第一个原生切片。

所有应用业务代码使用 ArkTS 和原生 ArkUI；保留既有后端服务协议；对视觉、交互和逐状态行为进行对照验收；为 Form Kit 与 Push Kit 预留数据及路由边界。
