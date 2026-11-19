# 0.1.3（5）邀请候选与提审记录

0.1.3（5）已完成独立源码冻结、Release App Pack 构建和官方云签，签名及内容核验通过，平台包合法性已达标。2026-11-19 13:23 已提交原单人账号组的邀请内测，华为显示「预审中」；窗口为 11 月 19 日至 12 月 19 日。匹配的账号级后端已完成 `recorded`（revision 15）并恢复服务。预审通过、正式审核、实际下载和 Push 投递仍待各自证据。原「赴星之约」项目及 `com.sitkin.starward` 不变；0.1.2 冻结包及其历史记录不回写。

本版把逐场订阅改为一次账号级「我的专属冒险动态」：后续仅分配给本人的新场次、剧情来信与关卡动态属于固定范围 `personal_journey_v1`。默认关闭，先订阅，再独立确认接收通知，随时可取消；旧逐场同意不自动扩大。业务与边界见 [订阅专项记录](push-subscription-2026-11-19.md)。根工作区仍为开发版本 0.1.0（1），0.1.3（5）只设置在独立候选副本内。

## 当前状态

| 环节 | 本轮证据与状态 |
| --- | --- |
| 发布工具 | 14 项发布工具边界测试通过，包含云构建号添加、其他内容篡改、发布身份和冻结时凭据排除 |
| 源码冻结与测试复用 | 214 个 `entry/src` 文件及 8 项本轮运行/测试变更源与最终测试基线匹配；复用实际 257/257 原生业务测试报告，失败和忽略均为 0。核对报告与源码哈希，没有重复执行全量测试 |
| 构建与 lint | 官方依赖安装、Release 完整 App Pack 构建通过。构建报告 30 项 ArkTS 警告；Release lint 为 0 错误、0 警告、1 项既有模糊效果建议，官方报告 `filesChecked=1`，不声称全文件扫描 |
| 云签与本机验包 | 官方 SDK 的 App Pack 与 Profile 验签通过，与 0.1.2（4）原分发身份一致，Profile 当前有效且含 Push 能力。云构建号为字符串 `1`，仅允许两处已核实的构建元数据添加；其他 HAP 内容一致 |
| 云上传与合法性 | DevEco 云上传界面已显示成功；平台包列表为 0.1.3（5）/ build 1、仅测试、合法性已达标。本机验包工具本身不证明上传或平台检测 |
| 邀请范围与窗口 | 已提交原单人账号组，2026-11-19 13:15:21 至 2026-12-19 13:15:21（北京时间）；原专用审核账号身份匹配且口令字段已填写，未输出或转存口令。平台显示「预审中」，实际审核通过及可下载状态待核验 |
| 通知自分类 | 已撤回旧逐场申请，以新账号级范围及六张真实原生截图重新提交，查看进展为「订阅／审核中」，尚未获批。旧记录保留的创建时间不是本次重新提交时间 |
| 新后端 | 本地后端 134/134、管理端 48/48 通过，管理端构建通过；生产备份、恢复演练、迁移、切换、健康复核及最终 `recorded`（revision 15）通过。新增两表为空且私有，新迁移恰好一次，正式 HTTPS 健康 200、四个匿名探针 401、容器健康且零重启 |
| 运营台与 CI | 配套源码 `8902dfe` 已正常快进推送；Deploy to Server #73 与 PocketBase backend CI #20 均成功。管理端 48/48；后端 CI 共 134 项，133 通过、1 项可选 OpenSSL 条件用例跳过（本地显式开启时 134/134）。13:30:33 线上 JS/CSS 与本地构建 SHA 完全一致，账号级订阅及未批不降级营销的说明已上线；未保存生产配置或启用发送 |
| 正式 Push | 最近只读核查的生产发送及订阅权益开关均关闭，无发送凭据配置。本次后端升级不激活发送，不改变白名单。真实华为 SUBSCRIPTION 投递及频次尚未验证 |
| 直板机与隔离 HTTPS | 同源 Debug 包完成 9 组账号级订阅检查，覆盖默认关闭、独立确认、双主题、回访、失败重试、响应丢失和退出；后续首次分配场次及新来信无需再次订阅。该结果不替代 0.1.3 正式邀请包首次隐私与实际分发验收 |

证据分别见 [源码与测试复用](../artifacts/validation/release-0.1.3-20261119/source-verification.json)、[未签名包与构建](../artifacts/validation/release-0.1.3-20261119/release-unsigned.json)、[Release lint](../artifacts/validation/release-0.1.3-20261119/release-lint.json)、[发布工具测试](../artifacts/validation/release-0.1.3-20261119/release-tools.json)、[签名验包](../artifacts/validation/release-0.1.3-20261119/release-signed-verification.json)及 [签名审计](../artifacts/validation/release-0.1.3-20261119/release-signing-audit.json)。各报告的上传、提交及部署字段只描述其采集时点或工具能力，不能覆盖后续另行核验的事实。

## 冻结与构建

继续使用 [0.1.2 发布流程](invite-candidate-0.1.2-2026-11-19.md)中的独立私有副本方式，不复制本机签名配置、隔离 HTTPS 配置或凭据，不修改原已提交候选。准备命令为：

```sh
python3 scripts/test-invite-package.py
python3 scripts/prepare-invite-candidate.py --version-name 0.1.3 --version-code 5
```

副本采用 `production-invite-push`，保留正式托管隐私配置；本版包中无侧载隐私调试元数据、隔离资源、源码或签名材料。随后在副本安装官方依赖，以固定工具链构建完整 Release App Pack 并运行 lint：

```sh
scripts/hm.sh install
scripts/hm.sh doctor
DEVECO_CLI_STUDIO_PATH=/Applications/DevEco-Studio.app devecocli build --product default --build-mode release
STARWARD_VALIDATION_DIR=../release-validation scripts/hm.sh lint
```

本轮固定工具链为 Studio 26.0.0.851、SDK 26.0.0.105 / API 26、Node v24.14.1、ohpm 26.0.0.630、DevEco CLI 1.3.0-stable，见 [工具链记录](../artifacts/validation/release-0.1.3-20261119/toolchain.json)。冻结快照共 2495 项文件；相关 8 项源与既有 257 项实际测试报告哈希一致，因此复用业务测试结果。发布过程未改变根运行源码。后续运行源码变化须重新冻结和核验，文档更新不回写已冻结副本。

未签名 App Pack SHA256 为 `52d5d143a880b52030f869637f6b7e82f61d564bbc70946f1de8d5ce2781de1e`，编译 ArkTS 载荷 SHA256 为 `a83d0862808889faa00329bdf9cd3e699723f43014e79546be01b7b286d88afc`。这些内容检查不证明签名、安装、网络或平台分发通过。

## 云签及验包

DevEco Studio 官方云签沿用同一应用的分发身份，不创建或修改凭据。以 0.1.2（4）已验证签名包为基线，运行参数化验包工具：

```sh
python3 scripts/verify-invite-package.py \
  --unsigned-app /absolute/path/to/unsigned.app \
  --signed-app /absolute/path/to/re-signed.app \
  --baseline-app /absolute/path/to/verified-0.1.2.app \
  --version-name 0.1.3 --version-code 5 \
  --cloud-build-version 1 \
  --output /absolute/path/to/new-verification.json
```

真实云签给 `module.json` 的 `app.buildVersion` 和 HAP `pack.info` 的 `summary.app.version.build` 各新增字符串 `1`。报告诚实记录原始 ZIP 条目并非逐字节全同；明确允许这两处添加后，其他清单语义、条目集合、资源及编译代码均匹配。官方固定 SDK 同时核验 App Pack、当前与基线 Profile，确认同一分发身份及有效 Push 能力。

正式签名 App Pack SHA256 为 `efe88a21c7fdf09d431c9da14cc39cc744b93f5920d007761333db439cb79544`。签名前后私有产物及验签日志均保留在本机私有候选材料中，不进入版本库。上传界面成功与签名核验分开记录；平台合法性及邀请提交见 [平台事实](../artifacts/validation/release-0.1.3-20261119/platform-invitation.json)，正式下载仍须独立核验。

## 生产接口依赖

0.1.3 的设置页使用 `GET/PUT /api/questions/v1/me/push/journey-subscription`。生产旧接口尚不具备账号级能力时，新路径返回 404，原生保留可重试的读取失败，不把错误解释成成功或默认关闭。分发前必须完成 `push-account-subscription-20261119` 后端发布并核验 `recorded`，不能只根据本地镜像或 stage 状态宣称接口已上线。

本次唯一新迁移为 `1795075260_push_journey_subscription.js`，只新增 `game_push_journey_subscriptions` 与 `game_push_journey_deliveries` 两张私有空表。旧逐场授权不迁入新范围；新后端对旧逐场订阅 API 明确返回 `409 PUSH_SUBSCRIPTION_SCOPE_CHANGED`，普通游戏 API 保留。旧 0.1.2 的订阅入口因此不是透明兼容，不能把它作为新版账号订阅已通过的依据。

冻结后端包已完成双层校验和、镜像 manifest/config digest 对应、31 项镜像源及 17 项已审文件核对；候选 Compose 只替换镜像，执行器不启用发送或订阅权益。只读预检及 stage 分别见 [后端准备](../artifacts/validation/release-0.1.3-20261119/backend-preparation.json)与 [stage 状态](../artifacts/validation/release-0.1.3-20261119/backend-stage.json)。stage 不停服；后续人工闸门和生产迁移仍独立执行。健康接口预期 200，四个未登录探针预期 401，包含新账号订阅路径；这些仅证明健康及认证边界，不替代生产订阅写入或云端投递。

## 分类申请及邀请范围

新申请的固定主题为「我的专属冒险动态」，明确包括订阅后首次下发的本人新场次、剧情来信和关卡动态。六张材料来自同一合成专用玩家和同源原生 Debug 包，依次展示默认关闭、独立确认、已接收与取消、场次列表、来信列表及具体来信；已在申请中说明隔离合成数据。旧三图已移除，新范围重新提交后控制台显示「审核中」，见 [分类申请事实](../artifacts/validation/push-account-subscription-20261119/huawei-application.json)与 [直板机隔离 HTTPS 验收](../artifacts/validation/push-account-subscription-20261119/device-ui-https.json)。

个人旅途消息只有新账号同意及独立通知确认同时成立、权益开关已批准且其他发送条件满足时才可走 SUBSCRIPTION；获批前停发，不降级为 MARKETING。公告和推广仍归 MARKETING。申请审核中不等于认可分类，也不证明每天至少 20 次到达。[官方通知自分类要求](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-apply-right/)

邀请 UI 已按用户要求选择原单人账号组，窗口为北京时间 **2026-11-19 13:15:21 至 2026-12-19 13:15:21**。沿用原专用审核玩家，身份匹配且口令字段非空，未输出或转存口令；托管隐私关联和 0.1.3（5）/ build 1 包的合法性结果均已核对。提交后页面显示「0.1.3测试版本－预审中」，说明预审通过后自动转市场审核。当前未证明预审通过或已向测试用户分发。

现行 HarmonyOS NEXT 邀请服务支持多个测试版本，旧 0.1.2 处于预审中本身不等于必须撤回。本轮新后端会令旧逐场订阅 API 返回 409，因此撤回被新版替代的 0.1.2 审核，控制台已显示「撤销提交」；保留旧包和历史，不修改 0.1.1 测试。此次撤回是为避免审核使用旧订阅流程。[邀请测试概述](https://developer.huawei.com/consumer/cn/doc/App/agc-help-invite-test-overview-0000002287701773/) · [邀请版本发布流程](https://developer.huawei.com/consumer/cn/doc/app/agc-help-appgallery-release-testapp-0000002258174266/)

生产发布与健康证据见 [后端最终复核](../artifacts/validation/release-0.1.3-20261119/backend-recorded.json)。2026-11-19 13:21:03 已 `recorded`，13:23:51 复核无发布阻塞或活动操作，最近三次独立健康探针均通过。正式发送及订阅权益仍关闭，Push 环境变量为空且无凭据挂载，未执行生产业务写入验收或云端投递。

运营台配套发布已由 [Deploy to Server #73](https://github.com/sitkinYip/sitkin-pb-backend-management/actions/runs/44465491873) 完成，源码对应 `8902dfe8e973659b38a559b45d6ae71674106756`；[PocketBase backend CI #20](https://github.com/sitkinYip/sitkin-pb-backend-management/actions/runs/44465491909) 同样成功。线上入口返回 200，JS/CSS 与本地构建哈希逐项一致，见 [线上产物核对](../artifacts/validation/release-0.1.3-20261119/admin-online-assets.json)。这些证据验证静态部署，不替代生产配置写入或正式 Push 投递。

13:31:06 的 [最终只读复核](../artifacts/validation/release-0.1.3-20261119/backend-final-readonly.json) 再次确认 `recorded`、无未决操作、健康且零重启，最近三次不同健康探针成功；两张新私有表仍为空，正式发送、权益与凭据状态继续关闭。

后端仓库最后以 `4543553` 补齐四篇发布文档；其触发的 Deploy #74 和 backend CI #21 均完成并成功，主干与远端一致、工作树干净，未再改运行源码。完整来源及流水线见 [配套发布收尾](../artifacts/validation/release-0.1.3-20261119/admin-release-final.json)。

后续待补事实为：平台审核通过、邀请实际下载，以及正式邀请安装后的首次隐私、Push 绑定和华为真实投递；不沿用隔离 Debug 包的成功结论。
