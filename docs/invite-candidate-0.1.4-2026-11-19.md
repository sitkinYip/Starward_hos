# 0.1.4（6）主动授权邀请候选

用户取消公告优化，要求把当前已验收的登录后主动授权改动发布为新的邀请测试。0.1.4（6）已完成全新源码冻结、官方完整 Release App Pack 构建、候选副本测试、lint、正式云签及内容核验。Studio 仅测试上传成功，平台包合法性已达标；已提交原单人账号组的邀请测试，实际显示「0.1.4测试版本 - 预审中」。窗口为北京时间 2026 年 11 月 19 日至 12 月 19 日。预审、正式审核通过、实际下载与分发仍未验证，不沿用已有 0.1.3 的结果。

本版在普通登录或安全续登后主动询问账号旅途订阅，并保留独立的通知确认和设置入口。只有尚无决定的新账号范围才询问；暂不、返回和已有决定不会反复触发。系统安装级许可逻辑未改，没有第二次系统授权请求。公告、关卡提示、来信与后端均保持原状，具体行为及本轮隔离直板机结果见 [授权专项记录](push-onboarding-2026-11-19.md)。

## 当前状态

| 环节 | 本轮实际结果 |
| --- | --- |
| 发布工具 | 14/14 通过，包含包内容、身份、云构建号窄允许变化及冻结时凭据排除 |
| 全新冻结 | 新建私有副本，未复用加入侧载隐私调试元数据的旧工程。快照 2540 个文件；219 个版本管理范围内的 `entry/src` 源码及资源与根目录一致，候选仅额外添加生产模式标记，共 220 个文件 |
| 运行与测试源 | 131 个运行时 ETS 与最终隔离真机基线逐文件一致；33 个测试 ETS 随候选冻结。219 项完整源码及资源哈希均已记录，测试和 lint 前后内容未改变 |
| 候选完整测试 | 在新副本重新执行，严格报告 290/290、失败 0、忽略 0；其中新增授权流程 23/23。不以既有测试摘要替代本次源码绑定 |
| 官方 Release 构建 | 完整 App Pack 构建成功，产物为 0.1.4（6）、`debug=false`。编译报告 36 条 ArkTS 警告，未写为零警告 |
| Release lint | 错误 0、警告 0、建议 1；为既有信纸模糊效果建议。工具报告 `filesChecked=1`，不扩大为全文件扫描数量 |
| 未签名内容检查 | `production-invite-push`、正式 HTTPS、Push listener 与点击 action 均在包中；无隔离配置、CA、侧载隐私调试元数据、源码或签名材料。全部 HAP 内容在测试和 lint 后保持一致 |
| 独立只读审查 | 冻结输入、签名前后 App Pack、9 份公开 JSON、真实测试与签名脚本输出核对无阻塞；219 项源码仍与候选一致。平台 UI 事实来自主任务直接观察，独立验包不冒称重新执行 UI 提交 |
| 正式签名及身份核验 | 官方 SDK 验证 App Pack 和 Profile 通过，Profile 当前有效且含 Push 能力，与既有 0.1.3 分发身份一致；同一「赴星之约」项目及 `com.sitkin.starward` |
| 云上传与包合法性 | Studio 显示 `project-default-re-signed.app已上传。`；平台为 0.1.4（6）／build 1、仅测试、18:43:22 上传，合法性「已达标」。上架自检仍为「未检测」，与合法性分开记录 |
| 邀请范围与窗口 | 原「赴星之约首轮单人测试」组，1 组／1 位成员，发送测试通知；北京时间 2026-11-19 18:31:38 至 2026-12-19 18:31:38，手机／中国大陆 |
| 邀请提交、审核与下载 | 已点击提交审核，实际显示「0.1.4测试版本 - 预审中」；旧 0.1.3 测试保留。预审、市场审核通过和实际可下载状态未验证 |

构建 36 条 ArkTS 警告包括：19 条调用可能抛异常、2 条 `media`、3 条 `createMd`、11 条 `audio` 设备能力提示，以及 1 条既有 `Index.ets` Monitor 提示。该构建输出与 codelinter 的 0 错误／0 警告／1 建议分别记录。

证据见 [未签名包与构建](../artifacts/validation/release-0.1.4-20261119/release-unsigned.json)、[完整源码与测试绑定](../artifacts/validation/release-0.1.4-20261119/source-verification.json)、[219 项源码清单](../artifacts/validation/release-0.1.4-20261119/source-manifest.json)、[副本真实测试摘要](../artifacts/validation/release-0.1.4-20261119/local-test-summary.json)、[Release lint](../artifacts/validation/release-0.1.4-20261119/release-lint.json)、[发布工具测试](../artifacts/validation/release-0.1.4-20261119/release-tools.json)、[固定工具链](../artifacts/validation/release-0.1.4-20261119/toolchain.json)、[签名验包](../artifacts/validation/release-0.1.4-20261119/release-signed-verification.json)及[实际平台结果](../artifacts/validation/release-0.1.4-20261119/platform-invitation.json)。较早 unsigned 报告与验包工具的上传／提交字段分别描述采集时点和工具能力，保留原值，不覆盖后续平台 UI 事实。

## 冻结与构建

通过既有发布工具新建 `artifacts/private/invite-candidate-0.1.4-snbv3yq3/project`。仅在该副本设置 0.1.4（6），根应用版本未改；本机签名配置、隔离资源与凭据没有复制。副本 `build-profile.json5` 与不含签名材料的 example 一致，实际 `signingConfigs` 为空，Release 构建按预期跳过签名。

冻结时 HEAD 为 `d05d6a94fe86381cc76932e18602b616001c466b`，工作树包含已验的主动授权改动。随后代码已提交为 `504013f3aea6d023ce2005fc5e037d8c93713f3e`（`feat:push授权优化`）；只读逐文件比对确认，该提交的 219 项源码及资源哈希与候选清单相同。不用提交时间替代真实源码哈希。

```sh
python3 scripts/test-invite-package.py
python3 scripts/prepare-invite-candidate.py --version-name 0.1.4 --version-code 6
```

在新副本中，使用 Studio 26.0.0.851、SDK 26.0.0.105 / API 26、捆绑 Node v24.14.1、ohpm 26.0.0.630 和 DevEco CLI 1.3.0-stable：

```sh
scripts/hm.sh install
# 固定捆绑 Node/JDK/SDK 工具路径后执行完整 App Pack 构建。
DEVECO_CLI_STUDIO_PATH=/Applications/DevEco-Studio.app devecocli build --product default --build-mode release
STARWARD_VALIDATION_DIR=../release-validation scripts/hm.sh test
STARWARD_VALIDATION_DIR=../release-validation scripts/hm.sh lint
```

首轮测试的原始报告混入 ArkCompiler GC 输出，重复了一条 `test=` 声明，严格校验统计为 291 声明／290 成功并返回 1；该次不计通过，原报告及哈希保留。未改测试、解析器或断言，重新执行完整测试后得到严格 290／290、退出码 0，见源码绑定报告中的 `earlierAttempt` 和最终结果。

未签名产物位于私有副本的 `project/build/outputs/default/project-default-unsigned.app`，大小 **17,607,618 字节**，SHA-256 为 `2cdaf97beac902c34d6c41f7b7e3df766c0748d224d1c6978624ea8e2f88de21`；编译 ArkTS 载荷 SHA-256 为 `c90fa261951911b577f712ab15c53407fdbf6d74bd39b6405d5f73b5b91a460d`。

## 正式签名与平台提交

主任务通过官方 Studio「Build → Upload Product」完成云签及仅测试上传，使用原应用的分发身份，没有生成或轮换发布凭据。正式签名包位于同一私有构建目录的 `project-default-re-signed.app`，SHA-256 为 `c45defd5e75689ef8ad685423d6606c7f62bc30250821872df87c2e13499c3eb`。

以既有已验证 0.1.3 签名包为身份基线，现有 `verify-invite-package.py` 核对版本、Push 能力、有效 Profile、分发证书和应用身份。真实云签仅给 `module.json:app.buildVersion` 与 `pack.info:summary.app.version.build` 添加字符串 `1`；原始 HAP 条目哈希并非全同，明确允许这两处元数据后，其他清单语义、条目集合、资源和编译代码均一致。独立复核再次只读调用同一验包函数及官方 SDK，输出与公开签名报告逐字段一致，未重新构建或签名。

上传后平台包列表实际显示 0.1.4（6）／build 1、仅测试、合法性「已达标」，上传时间为 2026-11-19 18:43:22。邀请页面保留原单人组，审核资料已填写且完整，未另行输入或更改凭据；公开发布报告不含凭据值。关联原托管隐私政策，发送测试通知。点击提交审核后，主任务实际观察到「0.1.4测试版本 - 预审中」及平台关于预审后转市场审核的说明。一个月窗口为北京时间 **2026-11-19 18:31:38 至 2026-12-19 18:31:38**；旧 0.1.3 测试保持。

## 验收边界

同源 Debug 代码已完成本轮隔离真实 HTTPS 与直板机验证；本次 Release 构建不重复手机 UI，也不能替代正式邀请安装后的首次隐私、全新系统通知拒绝、实际下载和 Huawei 投递验证。SUBSCRIPTION 权益、发送配置与额度不由候选模式或本地编译决定；本版没有部署服务器或更改正式发送设置。
