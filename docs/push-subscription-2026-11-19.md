# 旅途订阅与 Push 分类 · 2026-11-19

## 当前账号级实现与待完成事项

2026-11-19 用户明确要求一次订阅即可接收后续分配给本人的新场次、剧情来信与关卡动态，不接受逐场订阅。新账号级流程现已实现，并完成直板机与隔离真实 HTTPS 验证；先前逐场版本与原报告保留为历史。每日每设备至少 20 次仍是业务目标，权益申请和实际投递尚未证明达成，不能把本地分类配置写成平台已批准的额度。

本次重新读取华为现行[权益分类指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-apply-right/)、[消息频控](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/push-msg-freq-control)和[频控 FAQ](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-faq-5)：普通订阅需范围具体、默认关闭、可取消，并独立确认是否接收推送；没有明文规定必须逐场次。MARKETING 每日每设备按应用类别为 2 条或特定持证新闻类 5 条，未找到本应用可调至 20 条的公开途径。测试消息每日项目共用 1000 条的调测规则不能替代正式额度，QPS 也不是单设备每日额度。

当前设置提供固定范围 `personal_journey_v1`，文案为「分配给我的新场次、剧情来信与关卡动态」。`GET/PUT /api/questions/v1/me/push/journey-subscription` 是唯一当前授权来源；无记录时 false / false / 0。先保存 true / false，再由独立确认保存 true / true，取消为 false / false。PUT 使用 requestId 和 expectedRevision；成功回执可能是历史快照，原生仍回源读取。旧逐场授权不自动扩大，旧接口返回 `409 PUSH_SUBSCRIPTION_SCOPE_CHANGED`。

新场次实际分配和场次关联的剧情来信/关卡动态都按这一次账号授权判断；没有新同意、未独立确认或已取消则不投递。取消在同一事务丢弃待发的新旧旅途任务，重新订阅不恢复旧事件。获华为对应权益并由服务端启用后才使用 SUBSCRIPTION；当前未获批/未启用时这些业务提醒停发，不降级为 MARKETING 消耗两条额度。公告和推广继续 MARKETING，不冒充 MAIL / IM。实际订阅消息模板为「你订阅的旅途动态有新消息，打开应用查看。」。

原生 257 / 257 测试通过；后端 Docker PocketBase 0.40.1 全套 134 / 134、后续测试断言补充后的定向 5 / 5 通过，含默认关闭、两阶段确认、旧授权不扩权、迁移恢复副本、未来事件分类、取消/重订不复活、未批停发及公告保留营销分类。运营台 48 / 48 和生产构建通过。发送器为合成 provider，没有使用正式密钥或调用华为云端；见 [原生摘要](../artifacts/validation/push-journey-subscription-20261119/local-test-summary.json)和[后端摘要](../artifacts/validation/push-account-subscription-20261119/backend-summary.json)。

直板真机已通过 9 组真实 UI/隔离 HTTPS 检查：默认关闭；先订阅及拒绝通知；日夜主题、返回与后台关闭确认；显式接收及取消入口；回访与官方冷启持久化；取消及提交前 503 的原命令重试；GET 局部失败恢复；服务端已提交但响应丢失后以同 requestId/请求体重试且只递增一次；退出后私密状态清除。入场/答题始终为 0，打开来信素材未提交已读；两条订阅开关与平台批准状态分别展示，未把系统通知许可当成业务同意。见 [设备 UI/HTTPS 证据](../artifacts/validation/push-account-subscription-20261119/device-ui-https.json)。

六张新材料来自同一最终签名调试包与专用合成玩家：默认关闭、独立确认、已接收可取消、合成场次列表、旅途来信列表和具体来信。全屏 PNG 只转为 JPEG，未裁切、缩放或新增覆盖，均为 1260×2720，见 [素材清单](../artifacts/validation/push-account-subscription-20261119/material-manifest.json)。详细验收状态见 [F02c](feature-acceptance-matrix.md#f02c-账号级旅途订阅与消息分类2026-11-19)。

旧逐场 SUBSCRIPTION 申请撤回后，主任务已在同一记录编辑为新账号级范围、附六图并重新提交。页面先显示「申请完成」，查看进展为「订阅／审核中」，尚未获批。记录创建时间仍为 `2026-11-19 11:43:36`，这是原记录时间，不能当成本次重新提交时间；见 [新申请平台事实](../artifacts/validation/push-account-subscription-20261119/huawei-application.json)。新账号级迁移/API 已于 13:21 完成生产 `recorded`（revision 15），健康 200、四个匿名接口 401，新两表为空且私有、迁移恰好一次；正式发送和分类权益仍关闭，Push 环境变量及凭据挂载均为空，见 [最终生产复核](../artifacts/validation/release-0.1.3-20261119/backend-recorded.json)。匹配的 0.1.3（5）已验签及通过平台合法性，于 13:23 提交原单人组邀请，窗口为 11 月 19 日至 12 月 19 日，平台显示「预审中」；旧 0.1.2 审核已撤回，见 [邀请记录](invite-candidate-0.1.3-2026-11-19.md)。后续仍需新范围获批、正式发送配置、邀请实际安装和真实投递验证，不能以本轮测试替代。用户要求先申请，不先发工单；未提交工单或勾选其声明。

真机已退出合成玩家并完成真实解绑，绑定数为 0。本轮专用 HTTPS 代理、控制 socket 与 PocketBase 容器已停止，临时登录凭据、CA/私钥和临时库已删除，原请求记录完整保留；没有操作持久预览、生产或设备映射。最终 127 条代理请求中，订阅 PUT 为 9 笔：7 个 200、2 个故障注入 503，其中 1 个在真实提交后丢响应。入场/答题始终为 0、已读保持 1，素材阶段新建一封合成来信使未读由 2 增至 3，查看内容没有标记已读。详见 [隔离清理与最终计数](../artifacts/validation/push-account-subscription-20261119/isolated-cleanup.json)。

## 旧逐场实现与发布记录（历史）

以下保留较早逐场实现、测试、旧申请和 0.1.2 候选的历史记录；其中「审核中」「生产 recorded」与 MARKETING 回退均指当时的旧切片，不描述当前新账号级流程。旧逐场申请已撤回并以新账号范围重新提交，当前新申请仍待获批。

### 保留的工单草稿（当前不发送）

应用「赴星之约」（`com.sitkin.starward`）为线下解谜活动提供随行服务，账号由主办方分配，不向所有用户推荐公开活动。拟由玩家主动订阅一次“我的专属冒险动态”，并在独立弹窗确认接收消息；默认关闭、设置中可取消。范围只含之后实际分配给该玩家的新场次、对应剧情来信与关卡动态，不含平台公告、活动推广或内容推荐。请确认该持续订阅对象是否满足 SUBSCRIPTION 的具体范围要求，并明确是否覆盖首次新场次分配。业务需要单设备每日至少 20 次有效事件投递，理解仍受设备/系统频控；如上述范围不适用，请明确可申请的匹配分类或正式额度路径。现有逐场申请与拟调整流程不同，拟按确认后的范围补充实际流程截图及通知样例。

本轮已实现原生场次订阅、取消和默认关闭的订阅通知确认，直板真机 17 项真实 UI/隔离 HTTPS 主验证通过，后端分类及权限测试通过。0.1.2（4）已云签上传并完成官方 SDK 验包，平台合法性通过；生产后端已完成 `recorded`（revision 15）。订阅分类申请已提交，控制台显示「审核中」，尚未获批。正式候选隐私、邀请提交结果及真实 Huawei 投递仍待独立证据，不由本轮主验证替代。

## 产品与原生实现

入口位于现有设置页的「场次订阅」，保持既有字号、品牌色和表面样式。采用 V2 组件及官方 `PromptAction.openCustomDialog` 定制确认弹窗，展示具体场次名称，不向玩家显示分类代码或权益申请细节。

1. 同时读取当前场次和当前玩家已有订阅记录。两者均成功后才补出未订阅的默认行；读取失败显示局部「重新读取」，不把错误解释成未订阅。
2. 点某场次「订阅」先仅保存 `subscribed=true/pushEnabled=false`。保存后回源确认当前状态，再弹「接收『具体场次』通知？」；「暂不接收」或关闭弹窗都保留通知关闭。
3. 独立确认「接收通知」后才保存 `subscribed=true/pushEnabled=true`，覆盖该场次的剧情来信和关卡动态。已有订阅也可再次从该行打开确认。
4. 「取消订阅」一次保存两个开关为 false。已撤回、下线或不再出现在当前场次列表的历史订阅仍保留取消入口，不能因列表变化让用户失去取消能力。

系统通知许可与上述业务订阅分离。系统许可已开不代表同意订阅；业务同意也不代表系统会投递，系统许可关闭时提供原生设置入口。设置页离开或应用后台取消当时的读取、关闭确认；退出、改密或切换账号清除旧账号订阅状态，旧响应不能恢复内容。

独立代码复核发现一个非阻断的后台省流边界：保存尚未结束时离开设置或进入后台，PUT 随后成功仍会启动两次回源 GET；账号代次仍校验，后台不弹确认或自动开启通知。当前提审包保留此行为，后续可将回源延至前台。不把“取消当时读取”扩大写成“后台绝不发起新读取”。

不做乐观假成功。写入待确认期间冻结原命令与 `requestId`，失败可用同一命令「重试确认」；版本冲突重新读取。幂等写回执可能是另一台设备修改前的历史快照，因此每次写入成功后仍回源读取当前订阅，才更新列表或显示确认。回源失败明确显示「操作已保存，当前订阅状态尚未同步」，不将旧回执作为当前事实。`SESSION_OFFLINE` 作为场次局部错误处理，不退出玩家登录。

本轮订阅操作不调用入场、答题、已读或奖励接口。已知边界：当前场次摘要未向本组件提供完整截止状态，过期场次可能仍显示订阅动作，服务端会拒绝开启并显示真实错误；本轮未扩展该展示边界。

## API 与服务端

以 `sitkin-pb-backend-management/backend/contracts/game.ts` 为事实来源，响应均为裸 DTO：

| 接口 | 本轮契约 |
| --- | --- |
| `GET /api/questions/v1/me/push/subscriptions` | `{items:[{assignmentId,title,subscribed,pushEnabled,revision}],subscriptionApproved}`；只列已有记录，原生与当前场次列表合并 |
| `GET /api/questions/v1/assignments/:id/push-subscription` | `{assignmentId,subscribed,pushEnabled,revision}`；无记录时为 false/false/0 |
| `PUT /api/questions/v1/assignments/:id/push-subscription` | 严格请求 `{requestId,subscribed,pushEnabled,expectedRevision}`；响应为该命令的订阅回执 |

服务端校验玩家归属、账号状态、场次可用性、独立确认、版本及幂等性。直接从未订阅状态请求打开通知返回 `PUSH_SUBSCRIPTION_CONFIRMATION_REQUIRED`；版本不匹配返回 `PUSH_SUBSCRIPTION_CONFLICT`。取消、重新订阅或开关变化会使旧同意版本对应的待发送消息作废，不复活积压通知。

增量迁移 `1795075200_push_subscriptions.js` 新增三个私有集合：`game_push_subscriptions`、`game_push_notice_contexts`、`game_push_notice_deliveries`。集合不开放通用客户端 CRUD；业务仅走账号校验后的专用路由。该迁移已在生产恰好执行一次，三个新集合为空，历史迁移与既有结构保留；生产已切换新镜像并完成发布记录，见 [生产发布事实](../artifacts/validation/push-subscription-20261119/production-deployment.json)。

剧情来信与关卡动态只有在该场次已订阅且明确接收通知时才进入投递。`STARWARD_PUSH_SUBSCRIPTION_APPROVED=1` 仅用于原应用实际获批后启用 `SUBSCRIPTION` 分类；未获批时，已同意的场次消息仍按 `MARKETING` 发送并受其限制。拒绝或取消的场次消息直接不投递，不降级绕过选择。平台公告、运营活动以及尚无订阅关系的新场次下发继续使用 `MARKETING`。发送前再次检查场次、订阅版本、已读、撤回和权益状态。

分类并不替代全局发送开关、运营白名单、绑定令牌、系统通知许可、实际服务凭据或华为平台限制。当前没有证据证明订阅分类已获批，不能承诺高频实际送达。

## 已执行验证

| 环节 | 实际结果与证据 |
| --- | --- |
| 原生 Debug 编译 | 固定 API 26 官方构建通过，见 [实现记录](../artifacts/validation/push-subscription-20261119/native-implementation.json) |
| 原生业务测试 | 255 项全通过，失败/忽略 0；包含本轮 10 个订阅用例，覆盖独立确认、取消、读取失败、失响应同请求重试、冲突、账号及后台边界、历史取消入口和历史幂等回执重新同步；见 [真实测试摘要](../artifacts/validation/push-subscription-20261119/local-test-summary.json) |
| 后端测试 | Linux Docker PocketBase 0.40.1、合成玩家与数据、OpenSSL 校验，133/133 通过，失败/跳过/取消 0；provider 为合成实现，本轮未真实调用华为投递。见 [后端原始摘要副本](../artifacts/validation/push-subscription-20261119/backend-summary.json) |
| Release 冻结与编译 | 独立副本 0.1.2（4），`production-invite-push`；官方依赖安装及完整 App Pack Release 编译通过。无隔离 CA/配置、无签名材料，生产 HTTPS 及 Push action 均已核对；13 个本轮运行/测试变更源与测试基线一致、完整 214 个 `entry/src` 文件与冻结源一致，未重复业务测试。见 [未签名包报告](../artifacts/validation/push-subscription-20261119/release-unsigned-0.1.2.json) |
| lint | 原生及 Release 均 0 错误、0 警告，1 项既有信纸模糊效果建议；工具 `filesChecked=1`，不将此数字扩大解释。见 [Release lint](../artifacts/validation/push-subscription-20261119/release-lint-0.1.2.json) |
| 隔离 Debug 安装启动 | 同既有签名身份覆盖安装并启动通过，未卸载、清数据或操作偏好；该安装准备本身没有执行 UI 操作。中间关闭 Push 的调试包只有安装启动证据，未暴露订阅入口，不能计订阅 UI 验收，见 [中间包安装记录](../artifacts/validation/push-subscription-20261119/debug-subscription-only-installation.json) |
| 恢复官方侧载隐私调试配置 | 该中间阶段恢复 `--push-test`、预置上一轮已批准的 Debug 政策，官方覆盖安装启动及 SDK 验签通过，应用身份不变；当时未操作 UI，不计隐私或订阅验收。后续实际过程见下文。见 [恢复配置后安装记录](../artifacts/validation/push-subscription-20261119/debug-privacy-configured-installation.json) |
| 最终无诊断日志包 | 私有数值诊断已移除，打包字节码中无诊断 tag，127 个运行源码与根目录逐字节一致。用户同意系统隐私后覆盖安装、启动通过；重启见登录表单。见 [最终包证据](../artifacts/validation/push-subscription-20261119/debug-final-no-probe.json) |
| 真实直板 UI/HTTPS | 17 项主验证通过，见 [逐项状态、原图哈希与脱敏 HTTP 记录](../artifacts/validation/push-subscription-20261119/device-ui-https-main.json)。未打开来信、未入场或答题，已读数保持 1、未读数保持 2 |
| 隔离登记与申请截图 | 同一最终 HAP、同 CA 与原隔离库，附加代理放行真实隔离 PocketBase 的登记/注销接口后，实际登记返回 200 且 `registered=true`，设置页同步错误消失。另以三笔真实隔离 PUT 重拍未订阅、独立确认、已接收可取消三态；官方全屏 PNG 仅用标准 JPEG 编码，均 1260×2720、各小于 1 MB。无生产连接或正式发送凭据，未实际调用华为投递，见 [素材与脱敏接口证据](../artifacts/validation/push-subscription-20261119/application-screenshots.json) |
| 新版云签验包 | 主任务已云签上传 0.1.2（4）。官方 SDK 验证 APP/Profile 签名、同发布身份、有效期与 Push 能力通过；云端仅增加 buildVersion/build=`1`，其余 HAP 内容与 unsigned 一致。见 [签名报告](../artifacts/validation/push-subscription-20261119/release-signed-strict-verification.json)；报告本身不验证平台合法性或邀请提交 |
| 生产后端发布 | 已完成 `recorded`、revision 15，备份及恢复验证通过，增量迁移恰好一次，新镜像健康与匿名拒绝符合预期。全局发送器关闭、Push 环境变量为空，本轮未配置正式发送凭据或开启分类权益，见 [生产发布记录](../artifacts/validation/push-subscription-20261119/production-deployment.json) |
| 华为分类申请 | 2026-11-19 11:43:36 已提交「订阅」，申请记录显示「审核中」。使用三张经过独立复核的真实设备 JPEG，未遇到新的法务确认；尚未获批或启用。见 [平台申请事实](../artifacts/validation/push-subscription-20261119/huawei-subscription-application.json) 与 [平台事实与原图摘要](../artifacts/validation/push-subscription-20261119/huawei-invitation-platform.json) |

隔离侧载 `--push-test` 副本未预置官方隐私调试元数据时，隐私继续动作失败。排障中曾仅在该私有 Debug 副本关闭 hosted privacy 与系统 Push provider，保持同 CA、后端、签名身份和业务源码，再次覆盖安装启动；但设置页由 `pushVisible` 同时控制订阅组，该模式隐藏了入口，先前“可用它做订阅 UI 验收”的判断有误，不计验收。

恢复同一副本 `--push-test`，补入官方侧载调试元数据后曾再次出现隐私确认打开失败。已核对 HAP 内实际元数据，以及 Debug Profile 与已验证生产 0.1.1 的同一应用标识；未找到额外官方调试开关。私有副本仅临时加入错误码、托管类型及数量诊断，不打印 URL、凭据或错误栈；诊断包安装后实际观察到华为系统隐私弹窗，托管类型为 FULL_MODE、链接数为 1，没有捕获到原先失败的错误码。用户自行阅读并同意后，已移除诊断并覆盖安装最终同源 HAP，保留同意状态，未卸载或清数据。最终重启见登录表单，后续真实登录、cold/revisit 均可用。

这条时间线不能证明临时日志修复了问题，原失败根因仍未确定，不宣称正式包隐私已完全修好。正式候选没有加入侧载调试元数据，仍需按正式分发路径独立验隐私及 OS Push。

## 真实直板机主验证

本轮使用最终无诊断日志 HAP、专用合成玩家和真实 HTTPS 代理到隔离 PocketBase：

- 默认订阅/通知关闭；首次订阅只发一笔 true/false，服务端状态读取成功后才出现具体场次的独立确认。
- 「暂不接收」、系统返回和点蒙层三种关闭都没有第二笔 PUT；显式接收才写 true/true。设置回访及官方 force-stop/start 后保持，均无额外 PUT；取消一笔写 false/false。
- PUT 503 时保持原状态，显示可重试反馈并禁用竞争动作；重试请求的 requestId 与完整业务请求体相同，成功后再 GET 当前状态才显示确认。故障在上游提交前注入，不记作 after-commit 失响应实测。
- GET 503 时只在订阅区域显示错误，外观和返回仍可用，旧行禁止写入；「重新读取」恢复，离开设置再进入也能回源恢复。
- 确认弹窗期间切后台，回前台已关闭且未开启通知；退出账号后订阅行、弹窗及设置页均不在登录界面。没有把单纯 UI 隐藏扩大解释成已执行真实换账号迟到响应测试。
- 日夜两种主题采图并自审，App 主题恢复初始跟随系统。全过程未触碰系统设置，控制端确认入场和答题写入始终为 0、已读始终为 1、未读始终为 2。

真实设备共观察到 5 笔 PUT，包括一次提交前 503 和同命令的成功重试。逐步骤保存 UI 原始树、官方截图及真实服务端状态；公开报告仅含安全状态与 requestId 哈希，不输出账号、设备标识、令牌或受保护 URL。采集器按独立步骤追加动作分支并保留三个版本前缀，报告明确这不是一次冻结的全自动套件执行，不用合并计数冒充测试运行报告。

“服务端已提交但响应丢失后另一设备修改、原请求回放”、版本冲突和迟到旧账号响应等更深边界由 ViewModel/后端测试覆盖，真机未执行；分类发送使用合成 provider 测试，不等于实际华为投递。

## 现场状态与剩余工作

2026-11-19 主任务在 AppGallery Connect 复核：已有 0.1.1 为「测试中」，上架自检通过。新版 0.1.2（4）已独立云签上传、SDK 验签及平台合法性通过，选择原单人组、11 月 19–30 日窗口后提交邀请，平台显示「预审中」。预审、正式审核和实际分发仍待平台结果，具体见 [邀请候选与提审](invite-candidate-0.1.2-2026-11-19.md)。原始浏览器截图含邀请分享链接，保留在本机私有目录；[公开平台事实](../artifacts/validation/push-subscription-20261119/huawei-invitation-platform.json)仅记录安全字段与原图 SHA。

本轮生产后端发布已到 `recorded`、revision 15，未留进行中的发布锁。发布记录核对增量迁移、新镜像、连续健康与匿名接口拒绝均通过；发送器关闭、Push 环境变量为空，本轮未配置正式发送凭据或执行生产业务写入。订阅分类申请已于 2026-11-19 11:43:36 提交，官方申请记录显示「订阅／审核中」，尚未获批，生产权益开关仍关闭。管理前端已由 CI 部署，主任务真实浏览器刷新确认新用途选择、场次范围约束及关闭状态提示；未提交生产配置或发送表单，白名单仍为原两人。首次后端 CI 暴露 Linux 临时文件清理权限错误，已修正测试 Docker 的宿主 UID/GID，并经 Linux 原生文件系统对照复现后重跑通过：132 通过、0 失败、1 跳过。唯一跳过为未设置 PB_PUSH_VALIDATE_OPENSSL 的合成 RSA / OpenSSL 签名用例，本机隔离报告已执行该项；不是华为真实投递测试。原失败记录保留。

旧隔离代理未放行现有 Push 登记，设置页系统通知区显示同步错误；订阅 API 主验证未受影响，旧原图保留。保留原库、原控制记录和 CA 后，附加 HTTPS 代理仅放行现有登记/注销/撤销接口到真实隔离 PocketBase，专用合成玩家登记成功，真实设置页同步错误消失。没有连接生产、挂载正式凭据或启用实际发送。

申请用 [未订阅列表](../artifacts/validation/push-subscription-20261119/subscription-default.jpg)、[独立确认](../artifacts/validation/push-subscription-20261119/subscription-confirmation.jpg)、[已接收可取消](../artifacts/validation/push-subscription-20261119/subscription-enabled.jpg) 三张已重拍并逐张自审，状态和控件均可读，没有裁切或新增系统栏占位。原始官方 PNG 留在私有证据目录，JPEG 只重新编码、不缩放、不加覆盖内容；大小分别 207748、211490、211414 字节。该次固定采集器独立执行，新增三个成功订阅 PUT，主验证原始五笔 PUT 基线不重写；入场/答题仍为 0、已读仍为 1、未读仍为 2。主任务已实际独立查看主验证的日夜确认原图，以及这三张干净 JPEG，品牌、可读性、独立确认及取消入口均通过。此视觉复核不替代正式包隐私或 Huawei 实际投递验收。

素材复核后，已通过官方设备 UI 退出本次合成验收玩家到登录表单，真实隔离撤销接口返回 200、`registered=false`，再精确移除本任务拥有的 USB HTTPS 反向连接。没有入场、答题或已读变化，没有操作用户持久预览环境。隔离服务由后端任务按依赖顺序统一清理，设备任务未提前停止服务。见 [设备收尾记录](../artifacts/validation/push-subscription-20261119/device-cleanup.json)。

三张真实 JPEG 已上传并用于上述分类申请；提交成功与申请审核中均有控制台证据，不等于获批或突破营销额度。后续仍需华为分类审核结果、正式候选隐私确认、邀请审核通过及真实送达证据。折叠屏等专项适配不纳入本轮。

管理端发布、首次 Linux CI 清理失败及修复后的最终双工作流结果，见 [部署与 CI 收尾证据](../artifacts/validation/push-subscription-20261119/admin-deployment.json)。这些检查没有开启正式 Push 或验证真实华为投递。
