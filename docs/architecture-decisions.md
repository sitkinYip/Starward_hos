# Starward 原生架构决策

日期：2026-10-27。状态：“已采纳”表示本轮实现约束，不表示对应功能已实现或验证通过。首切片为登录、首次强制改密、主页、单个场次详情；验收事实另见 [功能验收对照](feature-acceptance-matrix.md)。

## ADR-001：平台、工具链和兼容基线

**问题：** 最新工具与最低支持系统不能混为一个决定；目前可验证设备为 API 26。

**选择（已采纳）：** 商业 HarmonyOS Stage 应用，ArkTS 与原生 ArkUI。首切片 compile/target/compatible API 均为 26，SDK 固定 HarmonyOS 26.0.0.105、DevEco Studio 26.0.0.851 配套工具。实际工程字段以官方模板与编译器接受值为准。

**备选与代价：** 更低 compatible API 能扩大覆盖面，但需要确定发行对象、逐接口兼容检查及对应设备回归。先采用 API 26 降低首链路不确定性；后续降低最低 API 要单独更新此 ADR，不能仅改一个数字。WebView、跨端包装不符合原生迁移目标。

**验证：** 记录真实安装版本；用 IDE 配套 Node/Hvigor/ohpm 编译；检查所用 API 的 `@since`、权限和 SysCap；在 API 26 设备执行安装与行为验证。当前决策不承诺覆盖旧系统。

## ADR-002：应用身份和模块规模

**问题：** 创建工程需要应用标识，当前没有已核验的商店登记资料；过早拆分 HAR/HSP 会增加构建和依赖成本。

**选择（已采纳）：** 临时开发 bundleName `com.sitkin.starward`，显示名 Starward，单 `entry` 模块。以包目录表达边界：页面与 ViewModel → business 用例/领域模型 → data Repository 实现；platform 提供网络、凭据、媒体、文件和生命周期适配。

**备选与代价：** 多 HAR/HSP 暂无可证复用或团队收益。单模块必须通过依赖方向约束防止页面直接调用 HTTP/平台存储。开发 ID 可能影响签名、设备应用数据及未来 Push 绑定；上架/开通服务前核验正式身份并做明确迁移，不默认为已注册。

**验证：** 检查配置身份与目录引用；领域层不依赖 ArkUI/Kit，页面不拼 URL。不得自行开通线上应用或上传签名凭据。

## ADR-003：MVVM 与 V2 状态管理

**问题：** Web hooks 与查询缓存不能直接移入 ArkTS，混用 V1/V2 会使状态所有权与刷新路径难以追踪。

**选择（已采纳）：** 新 UI 使用 `@ComponentV2`；ViewModel 用 `@ObservedV2`、显式 `@Trace` 可观察状态；组件局部状态用 `@Local`，输入用 `@Param` 等 V2 边界。业务 DTO/领域模型不因页面显示需要而全部装饰。ViewModel 管理加载、错误、表单及导航意图，Repository 管理数据访问与转换。

**备选与代价：** 全部状态写在页面可快速形成示例，但难以验证强制改密、并发返回与账号隔离；大而全全局 Store 同样不采用。V2 需要明确集合替换和嵌套可观察规则，以实际编译与界面变化核验。

**验证：** 本机 API 26 SDK `ets/component/common.d.ts` 声明 `ComponentV2`、`ObservedV2`、`Local`、`Param`、`Trace`；前两者 `@since 12`。真实编译后验证提交中防重复、错误恢复、账号变更与页面刷新。官方依据：[MVVM V2](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-mvvm-v2)。

## ADR-004：统一导航与外部入口

**问题：** 页面返回、强制改密、未来卡片/Push 深链必须遵守同一准入规则，不能让外部入口绕过登录或失效目标校验。

**选择（已采纳）：** `Navigation` + `NavPathStack` 为主导航。定义有限业务路由及显式参数模型，只接收允许的页面名和目标 ID。路由解析 → 登录检查 → `mustChangePassword` 检查 → 回源权限/目标有效性 → 入栈。退出登录清空受保护路由；首次改密成功后再进入允许目标。

**备选与代价：** 分别维护 router 与多个独立跳转入口会重复权限逻辑。首切片接收 `starward://assignment/<id>`，只允许字母、数字、下划线和连字符的有限长度目标；待前往目标保留到登录及强制改密完成，退出清除。深链不能指定 API 地址。不注册无真实能力支持的卡片/Push Ability。

**验证：** 本机 SDK `ets/component/navigation.d.ts` 声明 `NavPathStack`、`pushPath`（`@since 10`）及返回栈操作。验收未登录/强制改密不可到主页或详情，详情返回主页，登出后系统返回不能恢复旧页面。非法/下线目标有明确反馈。

## ADR-005：后端契约与 ArkTS 边界

**问题：** 当前 PocketBase 已权威管理业务，Web 生成 DTO 含 ArkTS 不宜直接搬用的 TS 特性。

**选择（已采纳）：** 后端 `backend/contracts/game.ts` 为 DTO 权威；ArkTS 定义明确字段、枚举与边界解析，复用同一响应夹具验证。当前 HTTPS 路径与 `Authorization: token` 保持一致，登录先取得 token 再请求 `/me`，拿到合法玩家后才提交认证状态。

**备选与代价：** 不复制 Zod/复杂 TS 联合/递归 JSON，不把 `JSON.parse` 后强制断言当校验。只为切片使用的响应建立模型，扩展时补充；缺失字段或错误类型返回契约错误，不能以默认值伪装成功。未知新增字段可忽略，必需字段必须检查。

**验证：** 对成功、错误、缺字段、错误字段类型夹具执行边界测试；检查无 Bearer 前缀；判题、准入、等级/进度等禁止客户端推导覆盖服务端结果。契约源与 Web 文件各记录 commit，不仅依赖历史文档。

## ADR-006：凭据、账号代次和首切片环境

**问题：** 首次改密会替换 token；退出后的旧响应、明文落盘与默认生产写入均会破坏账号边界。

**选择（已采纳）：** 首切片默认 mock 或隔离环境，token 仅内存。密码只保留表单操作必需的短期状态，完成/退出时清理，不落盘或入日志。认证成功、改密成功、登出/账号切换递增账号代次；所有请求/异步回调携带发起代次，落地结果前比较。改密成功原子替换 token 和玩家。

**备选与代价：** 首切片不提供“记住登录”；进程退出后重新登录。未来通过独立 `CredentialStore` 平台适配接入 Asset，完成锁屏状态、失效、删除与真机恢复验证后再支持持久凭据。普通 Preferences 不能保存明文密码/token。

**验证：** 强制改密无法绕过；登出时清空玩家、列表、详情、文件 token、导航和未来卡片摘要；延迟的旧请求不恢复任何状态。无专用测试玩家时不向生产执行写入。本机 `@ohos.security.asset.d.ts` 提供敏感数据生命周期 API，服务 `@since 11`；持久属性另有权限要求，未来按实际策略核验，不预先增加无用权限。

2026-11-17 冷启动续登采用 `CredentialStore` 和系统 Asset Store Kit。每个打包 HTTPS 端点和受信 CA 组合有独立的资产别名，密文只含令牌和玩家 ID。资产只在设备解锁时可读，禁止跨设备同步，沿用系统默认卸载删除行为。登录、改密和退出按顺序保存、轮换或删除资产。冷启动先用原始授权头调用 `/me` 且确认账号 ID 一致，再进入主页或强制改密。临时故障保留凭据供重试，失效和身份不符清理凭据。退出立即清理内存及导航，系统资产删除成功后完成退出，失败时提供原位重试。模拟模式不创建持久会话。[安全续登验收](feature-acceptance-matrix.md#a10-冷启动安全续登) · [Asset Store Kit 接口](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-asset)

2026-11-20 正式服务登录表单接入鸿蒙系统密码保险箱。ArkUI 负责按输入类型识别账号密码，玩家登录和身份校验完成后，页面在移除表单前请求系统提示保存。保存由用户确认，填充后仍须主动提交给服务器。系统保管其密码条目，应用只持久化原有续登资产。系统按应用识别凭据，正式、预览和测试包共用应用身份，因此普通隔离包不请求保存或填充正式账号。[系统保存接口](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-app-ability-autofillmanager) · [密码保险箱验收](feature-acceptance-matrix.md#a11-系统密码保险箱2026-11-20)

## ADR-007：缓存、文件 token 与失效

**问题：** Web 有账号级查询缓存、5 秒刷新和受保护头像临时 token；原生后台不能照搬常驻轮询。

**选择（已采纳）：** 首切片使用账号绑定的内存数据，重新进入页面可回源刷新；每条缓存都含账号 ID/代次和获取时间。后台暂停刷新，前台恢复时校验认证并刷新当前场景。无数据的加载失败与有旧数据的同步失败分开显示。

**备选与代价：** 首切片不实现跨进程离线业务缓存，也不宣称断网首次启动可用。头像上传与 `/api/files/token` 刷新在资料切片实现；受保护 URL 不长期保存或跨账号复用。

**验证：** 覆盖空列表、首次请求失败、刷新失败、401、账号切换。头像接入时增加到期、重取 token、登出清理与受保护媒体可达性用例。离线缓存引入前确定数据最小化和版本失效规则。

答题页前台按 5 秒间隔读取当前场次。下拉刷新、提交、离场与后台中断会作废在途轮询并销毁其 NetworkKit 请求；账号与读取身份继续拦截迟到结果。下拉完成后从头计时。轮询与手动刷新共用已验证的快照合并和终态清理，轮询独立于表单的忙碌状态；短时故障保留可信快照，以一次可关闭提示呈现本次故障。见 [Q03a](feature-acceptance-matrix.md#q03a-答题页前台自动同步与场次撤回) 和 [NetworkKit HTTP](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-http/)。

## ADR-008：幂等、重试和进程恢复

**问题：** 请求响应丢失与演出中断不等于服务端操作失败，重复提交可能影响进度和奖励。

**选择（已采纳）：** 按操作定义重试。只读请求可在限定次数内重试暂时错误；入场和答题的同一次操作重试复用 requestId、请求体、发起身份；改密不自动重试。401/403/404/410 等终态与临时网络错误分开。业务成功与奖励演出状态分离。

**备选与代价：** 不使用“所有 POST 可重试”的统一包装。首切片进程重启后重新登录并回源恢复；答题切片在实现进程恢复前，单独定义待确认操作记录及演出标记，不以本地答案重放取代回源。

**验证：** 确认改密只发一次；模拟响应丢失有明确恢复方式。后续入场/答题加入重复点击、超时重试、账号切换、服务端成功后杀进程、演出退出/重启用例。

## ADR-009：媒体焦点与生命周期

**问题：** BGM、配音、视频和演出既有时间顺序又受 App 后台/系统音频焦点影响。

**选择（已采纳，后续实现）：** 媒体通过 platform 适配，以显式状态机管理 BGM、语音、视频的优先级、暂停/恢复、焦点、资源释放与播放进度。业务结果提交和 UI 演出播放分开；媒体失败不能重新提交业务。

**备选与代价：** 不在各页面各建播放器，也不复制 Web 自动播放假设。首切片不伪装已有 BGM/配音能力；后续需按原 Web 录屏确定演出时序。

**验证：** 页面隐藏、后台、焦点抢占、耳机变化、动画中断、资源失败与进程重启分别验证。时间与服务端偏移由数据层提供，不能以播放器进度或本机时钟作为业务准入依据。

答题页先实现前台 BGM。当前可读题的服务端配置决定继承、换曲与静音；页面保留用户播放意图，平台层持有单个有效播放代次，通过官方 [AVPlayer](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-media-avplayer/) 读取真实播放状态。已知音频 CDN 依赖固定 Web 来源标头，采用 NetworkKit 严格 HTTPS 有界读取，不附玩家凭据或 Cookie。页面打开既有视频前暂停 BGM，视频退出后根据用户意图及焦点恢复；离场和失权销毁旧播放代次。账号加后端的本地偏好仅保存播放开关，不持久化音频或登录资料。见 [T02a](feature-acceptance-matrix.md#t02a-答题页背景音乐与视频互斥)。

浮标位置和播放开关分别保存在同一个账号与后端的本地偏好下。ArkUI 处理拖动与点击，松手将水平坐标吸附至最近边缘，纵向按安全区可移动范围保存比例。取消手势恢复上次保存的位置。组合线索浮标按已保存的音乐浮标位置避让。见 [T02b](feature-acceptance-matrix.md#t02b-背景音乐浮标拖动与位置记忆)。

2026-11-20 用户授权答题 BGM 在普通后台切换时续播。只有答题分支中实际正在播放且已取得系统后台音频任务的曲目可以续播；前台通过官方 AVSession 与 AUDIO_PLAYBACK 长时任务登记媒体，保留同一 AVPlayer 和位置。后台不新启加载中的曲目、不恢复用户或系统暂停的音频，不恢复业务轮询。入场说明和剧情媒体不扩大为后台播放。视频覆盖、失权、离场、账号变化及 Ability 销毁仍撤销播放能力；长时任务、媒体会话和播放代次的异步释放均须隔离迟到回调。系统媒体展示仅使用品牌和通用“答题背景音乐”，不暴露题面、玩家或受保护资源。见 [T02c](feature-acceptance-matrix.md#t02c-答题-bgm-后台续播2026-11-20)。

## ADR-010：桌面卡片与 Push 的边界

**问题：** FormExtensionAbility 与 UIAbility 内存隔离；Push 需要后端账号绑定和发送能力，不能仅添加客户端 SDK 便称完成。

**选择（已采纳，后续实现）：** 卡片使用独立、最小化、账号绑定的持久化摘要 DTO；App 与扩展各自读取，显式刷新，登出清空。卡片和 Push 点击转为 ADR-004 的业务路由。Push token 登记/解绑、发送凭据、失效处理保留在业务服务端；到达后回源同步。

**备选与代价：** 不共享页面单例，不复制 Web 5 秒后台轮询，不在 Push 载荷放私人领取信息或服务端凭据。首切片仅保留业务入口和平台适配边界；没有创建 FormExtensionAbility、开通 Push 或完成后端协议。

**验证：** 后续分别验证卡片类型、刷新限制、隐私级别、离线快照、账号切换、冷启动深链、失效 token 和重复通知；正式应用身份及服务开通另行核验。官方依据：[卡片进程模型](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/arkts-ui-widget-process)、[Push Kit](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-kit-introduction)。

2026-11-17 核对 API 26 Push Kit 和 PocketBase 现有业务接口。App 可向 Push Kit 申请设备令牌，自动业务通知仍需要服务端把设备令牌绑定到当前玩家，并在真实业务写入成功后向 Push Cloud 发送。现有后端的派发和来信写入只更新 PocketBase，尚无绑定、解绑或发送接口。用户授权本轮在无需服务端改造的情况下接入，因此本轮仅记录依赖。后续第一组可选事件为新场次派发、旅途来信或公告，按玩家的通知授权和实际访问权限发送，点开后统一回源。服务凭据留在服务端。[获取 Push Token](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-get-token) · [官方客户端和服务端接入顺序](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-gettingstart)

2026-11-18 用户授权同时接入原生和后端。正式应用沿用 `com.sitkin.starward`。首个切片用华为系统通知及账号匿名标识，按已授权的安装绑定；签出时优先释出平台绑定，服务器解绑失败由一次性撤回凭据续办。通知仅路由到本应用的场次或来信入口，保留现有 API 鉴权与回源，载荷不含题目、来信正文或领奖信息。通知发送凭据只部署在后端，开发和发布分别显式开关。[通知消息与多账号](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-send-alert/) · [开通推送服务](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-config-setting)

运营后台管理正式消息的发送范围：默认「仅白名单」且名单为空，可由有权管理员选定游戏玩家，或确认切换为「全部开放」。后端持久保存设置和审计记录，保存时须填写修改理由，并校验配置版本，避免两次管理操作相互覆盖。生产总开关仍由部署配置控制；开发测试消息仍只允许部署配置指定的专用玩家，两者不随后台切换而变化。AppGallery 邀请名单只用于分发应用，不参与游戏玩家判断。

正式模式在设备注册、业务事件入队和提交华为前都检查当前范围。全部开放只覆盖已授权、已绑定且符合事件资格的设备，不为历史场次或来信补发通知；缩小范围后，未发送的范围外任务不得提交，华为已接收的消息无法撤回。范围配置变化不改变已有业务数据、原生权限检查或点击回源，也无需重打客户端包。验收见 [F02a](feature-acceptance-matrix.md#f02a-正式-push-发送范围)。

## ADR-011：可复现的原生 HTTPS 隔离联调

**问题：** 验证真实网络、改密及权限撤回需要真实服务端事务；现有玩家及生产环境不适合故障注入。

**选择（已采纳）：** 使用冻结后端的真实 PocketBase、迁移和 hooks，创建一次性数据库及随机测试玩家。玩家代理只开放首切片所需接口；控制端口仅监听本机并要求独立凭据。严格 HTTPS 网关经官方 HDC 反向端口映射送达真机。短期测试 CA 只打包到本 App 的隔离构建，不加入系统信任库；保留证书链和主机名校验、禁止重定向。

**备选与代价：** 临时公网隧道在本机被系统代码签名校验终止，因此采用 USB 链路，不修改系统安全策略。此方案证明原生 HTTPS 与真实后端协议，不能证明公网 DNS、移动网络或生产服务可达。正常响应来自真实后端；故障注入单独记录，不能把合成错误体当成真实业务成功。

**验证：** `integration.json` 仅为本地打包资源，缺省使用明确标识的 mock；存在但无效的隔离配置必须阻止登录。loopback 只允许 `https://127.0.0.1:18443`，CA 必须是公开证书，凭据不打包。TLS 探针分别使用独立连接验证可信 CA 成功、不可信 CA 拒绝、错误主机名拒绝。保存安全请求台账，确认原始 token 认证及改密单次提交。临时私钥、数据库和账号信息只在 gitignore 的 private 目录，停止脚本仅清理本任务资源。

## ADR-012：视觉对照的字体与坐标

**问题：** Web CSS 像素、手机物理像素和 ArkUI vp/fp 不是同一坐标；平台通用 serif 没有得到原站所需的中文衬线效果。

**选择（已采纳）：** 保留冻结 Web 的原字体截图，并增加相同字体字节的控制组。原生使用 OFL 授权 Noto Serif SC，记录来源和 SHA-256。读取真实窗口密度、安全区和字号后，把原生内容区换算成 vp 再与 Web 对照；系统栏独立展示。装饰星图不参与内容固有尺寸，正文决定滚动高度。

**验证：** 深浅主题分别记录同数据、同状态截图和布局矩形；原图保留，不用整图缩放冒充布局精度。大字体使用本 App 字号设置，不修改用户系统设置。记录只读开始按钮、未开放导航及测试环境提示的范围差异，字体抗锯齿差异不宣称像素完全相等。

## ADR-013：官方 ArkUI 组件与沉浸光感优先

**问题：** Web 的通用控件和材质是原生效果的近似；继续手排顶底栏、Tab 和弹层会绕开系统反馈、无障碍、动效及窗口适配能力。用户已明确要求以官方 ArkUI 二次封装，并保留顶栏布局。

**选择（已采纳）：** 页面保留业务和路由所有权，`ui/` 提供官方组件的薄封装。API26 底栏采用 `Tabs.barFloatingStyle`、`barOverlap` 和真实 `uiMaterial.ImmersiveMaterial`；顶栏采用官方 Navigation title 与材质接口，原品牌、标题及操作布局保持。`NavigationTitleOptions.systemMaterial` 只覆盖原生返回/菜单按钮背板，自定义顶栏宿主仍需显式通用 `systemMaterial`。Tabs 分类、Sheet、Refresh、Toast/Dialog 和自定义轻动画分别使用官方能力。

**能力与边界：** 显式沉浸材质按 `isImmersiveMaterialSupported`、系统材质信息及固定SDK声明选择；系统不支持或禁用时使用真实降级。Dialog/Toast 默认材质不能被手工不透明背景覆盖。API26 `ohos.arkui.UIMaterial.state` 元数据及目标API决定默认启用范围；具体组件级配置与手机实际结果单独记录。窗口/容器断点、Navigation.Auto 和平台避让区用于响应布局；折叠硬件与悬停姿态仍须验证。

**首页布局：** 移除固定同步提示区域，内容滚动到浮动底栏下方。原同步文案置于滚动内容末尾，末尾间距用于让文案完整露出；手动同步由官方 Refresh 承接。Refresh 采用独立 UI 状态，实际并发与成功失败仍由 ViewModel 管理。

**动效和反馈：** 保留已确认的 Sheet/Tabs/Navigation 系统动效。其余 Web 动效按实际触发状态迁移，优先用官方组件能力，可用 ArkUI 动画 API 补足的随切片尽量还原。读取系统减少动画 API，动画中断不改变业务结果。Toast 只承接短反馈；认证、契约错误及改密结果未确认保留可操作的持久说明。未实现的业务入口不得生成假页面或成功，只提供可理解的未开放反馈。

**验证：** Web 对照关注品牌、内容、布局和逐状态行为；官方材质、原生反馈及用户批准的悬浮布局另列为平台差异。保留迁移前截图，重新记录材质能力、浮栏与滚动内容重叠、末尾文案可见、下拉回源、减少动画和新容器返回/退出行为。使用官方组件不替代真机测试。

## ADR-014：系统避让区只约束内容，背景与材质延伸到屏幕边缘

**问题：** 只给安全区布局而让状态栏与手势区沿用默认窗口填色，会形成独立的白/黑矩形。2026-10-28 用户明确要求原生沉浸效果，保留安全间距而不保留实心占位块。

**选择（已采纳，待新版实测）：** 使用官方窗口全屏布局并保留系统栏显示，系统栏背景透明。Navigation/Tabs 使用平台安全区能力，先保持原生标题与浮栏自动避让；不对整个 Navigation 叠加顶部和底部占位 padding。自定义标题材质宿主使用无固定高度外层延伸绘制，内部品牌/操作保持原布局。页面背景延伸到系统区，按钮等交互元素仍须实测与避让区不相交。

**边界：** 不隐藏状态栏或手势条，不改变系统设置，不自制背景模糊。Window 系统栏样式由一个生命周期所有者控制，不与 Navigation.systemBarStyle 混用。状态栏图标随应用实际主题变化，异步窗口操作在销毁后不能继续写入。

**验证：** 冷启动记录实际isLayoutFullScreen、systembar透明属性及避让区；深浅两主题截图检查顶部材质连续、底部内容可绘制到边缘，按UI树验证头像、主题选择器和浮栏均在安全交互区域。键盘、返回、Sheet、默认/1.3字号与原业务门禁重新验证。前一版系统UI17项和认证4图保留为历史证据，不推广为沉浸版通过。

**官方依据：** [开发应用沉浸式效果](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-develop-apply-immersive-effects)，本轮从官方知识MCP搜索后读全文，并核API26 SDK的Window、Navigation、expandSafeArea声明；明确区分窗口全屏布局与组件绘制延伸。

## ADR-015：真实业务事实与页面级键盘避让

**问题：** 2026-10-28实测发现：404清空detail后，标题仍渲染空模型的“0/0”；默认OFFSET键盘模式下，1.3字号的主按钮只在UiTest可交互视口露46px，继续滑动位置不变，不能宣称完整可达。

**选择（已采纳，最终影像重测中）：** 只在detail.id非空时渲染标题进度；加载/错误清空模型不显示默认业务计数。认证页通过明确导入Kit的 `KeyboardAvoidMode` 别名配置 `UIContext.setKeyboardAvoidMode(RESIZE)`，让百分比高度容器随键盘压缩，内部Scroll自然提供完整可用滚动范围。不要混用全局同名的DEFAULT/NONE枚举，不手算固定键盘高度。

**验证：** 真实1.3字号下，密码/账号和强改密三个字段分别聚焦，主按钮可滚动到实际App/Scroll/IME交集之内。普通账号IME可截图；历史密码焦点截图全部黑色，原因未确认，只保存脱敏UiTest几何，不把黑图当主题通过。404两主题重新验证不存在detail-progress，重试真实GET200后进度恢复；旧2b构建资料保留于native-pre-final-fixes，不能冒作修复后HAP。

**官方依据：** [UIContext.setKeyboardAvoidMode](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-uicontext-uicontext#setkeyboardavoidmode11)，官方知识MCP先搜索再读全文，核API26 SDK。RESIZE影响页面，不改变Sheet等弹层自己的避让策略；本切片Sheet没有输入字段。

## ADR-016：手机账户导航、资料草稿与头像资源边界

**问题：** 首切片只有账户摘要Sheet和只读场次，不能把外观入口等同完整导航或资料能力。昵称编辑、受保护头像和后续改密带来草稿、二进制、资源释放及token轮换的独立生命周期。

**选择（已采纳，任务1实现与验证中）：** 手机正式入口继续由Navigation/NavPathStack和官方Tabs/Sheet承接，资料页提供身份/安全分区。主页面、菜单和场次返回共享同一受门禁检查的业务路由；未实现的奖品/来信仍明确未开放，不创建假成功或空页面。侧栏摘要展示与完整资料编辑分开，保留Web的品牌、文案、身份和返回场次语义。

**资料与网络：** ViewModel持有昵称及已确认头像草稿，用户开始编辑后后台/me更新不能覆盖草稿；显式保存才调用Repository。纯昵称为JSON PATCH，带头像为multipart PATCH，均对直接GamePlayer返回做完整边界校验。错误保留有用草稿并允许明确重试；同次保存单飞。原生TextInput程序回填触发的相同值回声不作为用户新编辑，避免清除已确认的保存反馈。后续改密仍只发一次，不套资料重试或通用POST重试；成功原子轮换token、玩家及账号代次，清空密码。

**图像与平台：** 系统Photo Picker、图像解码/裁剪/压缩封装在platform和ui中，领域仅接受平台无关的文件名、媒体类型及二进制数据。原图类型JPEG/PNG/WebP、50MiB上限来自Web；输出为用户确认的方图JPEG、边长最多512、目标最多200KiB，服务端硬限2MiB。裁剪确认并非业务保存，取消/重选/离开或账号代次失效释放旧PixelMap、URI访问及临时资源，不自动发资料PATCH。官方组件不能满足裁剪交互时组合ArkUI基础控件，并明确实际交互来源，不冒称官方裁剪能力。

**受保护头像：** Repository负责认证、file-token获取/失效后限次重取、分段编码的文件路径和真实二进制读取；UI不拼URL，不持有受保护URL。头像结果绑定发起账号代次、玩家ID和文件版本；退出、切换或新头像保存后旧响应不能回填。图像解码失败由UI按仍在用的精确图像引用和账号/gate边界回报ViewModel，持久显示失败并等待用户显式重试；返回成功的文件GET不等于图像已解码显示。旧图或旧预览失败不清除新图，读取成功须清除先前图像错误。token与头像只保留运行时内存，不预先宣称安全持久登录；不新增相册全量访问权限以替代系统Picker。

**非空扩展的测试输入：** extraDisplay必须来自服务端正式解析，不在原生硬编码虚构身份信息。隔离验证如需非空值，仅对自有一次性容器中的唯一专用玩家，通过正式管理definition、preview、dispatch及inspect创建目标绑定，再以严格HTTPS玩家/me核对精确tuple和原事实未变。该Host seed与手机实际展示分别记录，不能将准备断言数算作UI或业务完成度；临时管理凭据只允许stdin/进程内存，不落盘或进入报告。

**验证：** 按任务1逐点表验证菜单/页面/场次返回、昵称草稿/真实PATCH/失败恢复、Picker取消、可调整裁剪确认及输出图像、真实multipart/file-token/file-GET、后续改密单次与新密确认、退出与迟到响应隔离。客户端内存测试、真实服务端协议、设备UI和图片结果分别记录，不能互相替代。改密丢响应的每次新实验命令独立记录，不继承失败尝试checks，不自动重放上一次写请求；系统组件禁用状态须读取官方原始UiTest实际属性，不能将CLI省略属性当成false。头像基础链路与退出后迟到文件200分别取证：若使用仅private的长超时配置变体，须核对源码及ABC字节一致、绑定该变体HAP/runtime和显式hold/release过程，不能据此把base 2秒版本记为同版专项通过。折叠等专项留待主体迁移后。实际结果见 [任务1验收](slice-02-profile-validation.md)，当前未执行项不标通过。

## ADR-017：官方浮动Tabs输入事务与业务路由隔离

日期：2026-10-29；2026-10-30追加当前base视觉与网络恢复。状态：当前1a40手机Touch专项9项、完整新core34/S2-13/supplement22已通过，头像基础28及JPEG EXIF6/WebP各8项亦已通过；Web8/Native12/crop4已独立reviewed但保留NAV三项新refinement，两类App输入拒绝已同1a40通过、迟到6项仅独立15秒变体通过；6a新UI主轮39项、独立静态及4次官方注入松手选择已验，交付c2fd的跟手光感、松手选中和侧栏进出方向另获用户手验确认，触感/取消/中断/减少动画仍待验；首次probe的计划点击遮挡已定位为驱动问题，旧30de无点击坐标仍不确定唯一根因，不将index0日志直接等同内容触摸误判。

**问题与已知事实：** 固定DevEco Studio 26.0.0.851、SDK 26.0.0.105及当前API26直板真机上，早期护照点击未开放收藏会回启程，坐标和用户手动操作均复现。日志曾显示click0/will3→0、再click1/will0→1及迟到0回调，但唯一根因未确定，不推广为全部API26设备共同问题。index双向绑定单独调整或命中阻断未形成成功修复证据。

**base30de选择及有限验证：** 保留官方Tabs、BottomTabBarStyle、材质、命中和动画，旧封装在整个Tabs观察Touch事务；只有官方will/click产生pending，Touch Up排队提交最后原生索引，Cancel/外部路由/销毁清理，事务外不形成意图。父selectedIndex是业务目的地，activeIndex!!只同步UI；onContentWillChange仅放行与父允许目的地一致的0/3，onChange不直接反向写路由，根gate及NavPathStack再门控。资料身份/安全Tabs另用section!!及生命周期清密码，不由导航排队驱动写请求。

旧HAP0f799的7步probe、base30de的core34/S2-13/supplement22分别保留对应真实覆盖，不能证明所有内容控件/页签交叉时序均安全，也不能转记新HAP。base30de头像实际20项incomplete：file503显示持久错误后，自动化请求点avatar-retry却回启程且没有新头像GET。此前曾将最小日志解释为“内容Touch开启事务接受phantom0”，但日志没有原始点击位置，只能证明index0路由发生；该根因判断证据不足，现更正为待定位。旧30de驱动viewport只对profile-/security-前缀避让浮栏而遗漏avatar-retry，但没有该次点击点记录；保留incomplete及现象，不将它先定为产品缺陷，也不据后续新HAP测量倒推唯一原因。

**当前1a40候选：** 固定SDK官方barModifier承接仅bar区域Touch，并增加父索引对齐；继续由官方Tabs负责命中、材质及动画，不按自造图标坐标替代导航。候选HAP `1a40c0caffc46d64e0b81e9ccb92f2c7d6b69830bb73bf1f2ed5f02651a761cb`已实际构建/签名/安装，72/72测试、lint0问题/filesChecked0及runtime-09六项passed；这些不是业务验收。候选初次probe回首页，独立 `profile/avatar-retry-hit-geometry.json`已实测：retry rect[67,2580,391,2729]px，计划中心[229,2654]px落在官方NativeTabBar rect[106,2531,1214,2721]px内，旧viewport[0,415,1320,2848]px没有裁掉浮栏。该报告仅测量、未发retryclick，不能算头像重试通过，但足以确认新probe的驱动遮挡，不据此宣布barModifier失败或产品有缺陷。驱动已改为按真实path祖先含profile-scroll统一避让bar，独立crop/menu无此祖先保留自有viewport；产品HAP不变，同1a40 `profile/native-bar-content-probe.json`9项已实际passed：retry新GET200且保持护照、四次收藏/来信不离页、启程/护照切换、内容滚动/昵称焦点不跳首页，cleanup两true。旧S2仅提供当前专用密码key并经Host核身份，未继承旧业务checks。该证据只属于当前Touch专项；随后1a40完整新core34与独立S2-13均已实际passed，report SHA分别ef049839…/5dceb457…且绑定runtime-09，checks不继承30de。新supplement22也已同版passed（SHA0376e398…，绑定上述新依赖），三run各自cleanup通过；新的Avatar已显式new-attempt实际28项基础passed（SHA5f410842…），覆盖真实Picker/裁剪、multipart、403/503/解码恢复和普通退出；JPEG EXIF6及WebP RGB另各8项同版passed。输入拒绝两轮与独立15秒变体迟到6项已另取报告，后者不计base2秒同版通过；同版深浅视觉已有下述独立reviewed基线，当时三项新refinement待验；后续6a独立结果见ADR-018，旧passed数字不得继承。专项9项原字节d044已归档，最新9c3a报告仅追加源SHA/命令/原mtime完成时间元数据，不是新的功能重执行。

**输入范围的已知缺口：** 没有Touch的外设键盘/读屏页签激活目前被守卫明确拒绝，属于已知不支持，不只是未验证，也不属于折叠专项。账户菜单Button提供另一组导航入口，不证明底栏辅助功能或正式可访问性完成；单列缺口，不阻塞当前直板机Touch业务切片。未来接入须有真实键盘/读屏证据，不能将未知回调当有效Touch放行。IME文本编辑独立：base30de core已验昵称及完整52vp保存动作在实际键盘压缩视口可达，不替代外设键盘导航或读屏验证。

**图像专项实际范围：** 1a40基础Avatar28绑定runtime-09、新core34/S2-13及Root新原图SHA回执；JPEG Orientation6与RGB WebP各8项以真实Picker、唯一原生multipart、token/文件200及Host只读结果证明规范化/中心裁剪。HTTP200解码损坏故障在自有精确SHA文件中注入并恢复，不属生产故障；自动同步不应把已报解码失败自动重读，显式重试有实际新GET200证据。普通退出已验，延迟响应退出和实际跨另一账号并发仍分开，不能据基础28称全部账号边界通过。

**Picker输入边界的观察限制：** 同版第三轮搜索观察已finish且六项cleanup true，整体not_observable，不因退出完成而标过滤通过。Root核完整文件名已提交且精确自有50MiB+1 PNG单项visible/enabled、未selected；该事实既不能证明系统过滤生效，也不能证明选中/完成可成功。后续独立negative选择/官方完成已取得两类App兜底拒绝证据，原系统过滤not_observable保持。同1a40/runtime-09的50MiB+1 PNG与GIF两轮已真实选定精确自有URI并点击官方完成，均落到原生错误Sheet：有效裁剪预览缺席、确认禁用、类型/大小文案精确对应；每轮7项cleanup true，未发资料PATCH或改密POST。`profile/avatar-input-oversize-png.json` SHA `5032ba4124f1f695209a29cce2088453bd23101681eb2f28a6a832499f8153aa`，`profile/avatar-input-unsupported-gif.json` SHA `95923a9e6a55a0be0ba3b58e8c283d828ef20a77cf415171abf3a579587577e4`，各有1个实际边界检查。Root分别亲看错误Sheet，独立review SHA为dd1ffe5f…/a166d70d…。通过的是App兜底拒绝与恢复，原Picker过滤not_observable不改。 输入边界与视觉基线分别取证，不能互相代替。

**固定SDK官方能力依据：** `TabsOptions.barModifier`自API15可用，`CommonModifier`自API12，通用onTouch自API7；固定API26声明已核，并已由真实ArkTS编译器通过。SysCap为SystemCapability.ArkUI.ArkUI.Full，Stage模型，无额外权限，生命周期仍由现有Touch Cancel/外部路由/组件销毁清理待提交事务。依据为官方[Tabs接口](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-container-tabs)、[Touch Event](https://developer.huawei.com/consumer/en/doc/harmonyos-references-V14/ts-universal-events-touch-V14)及固定SDK `component/tabs.d.ts`、`api/@ohos.arkui.modifier.d.ts`、`component/common.d.ts`声明；接口可编译不等于全部平台输入通过。

**视觉及后续验证：** 旧头像7图中Button/Slider默认蓝漏品牌token的发现保留原归属；1a40已修后，当前同版Web8（SHA b51d6bf9…）、Native12（SHA 4c639ff6…）和crop4（SHA 05ed5b63…）已全部捕获，Root亲看24张未编辑原图/8组配对。独立 `profile/visual-review.json` status=reviewed，SHA `44fcc1457a8ae83df5fc9f7dd1c5aaa1a7a6f60df1d0ac5f24adc2866b049ca1`，绑定1a40/runtime-09与三份来源，核品牌/文案、权威资料、只读账号及可达动作；官方材质/控件、手机底部Sheet及三Slider裁剪布局列为批准差异。采集报告自身crop themeVerified=false/visualReview=pending保持原样，由Root独立review承接主题目视结论，不混写采集与验收。当时1a40报告的NAV-ICON、NAV-IME、NAV-LIGHT仍pending_new_refinement，后续6a结果见ADR-018，不称零差异、新HAP或全部动效通过；完整键盘/读屏输入范围仍单列。5180回环viewer已准备并启动24PNG，私有manifest SHA `3812ef0edf591f77b3070585bfc817babb03f42f9d9d761e03720ec9e130e179`，不改变原始证据或代替业务验证。参考[Tabs接口](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-container-tabs)及固定SDK声明；输入事务来自本项目边界和实际观察，不是官方对异常根因的认定，工具链或设备变化后须重验其必要性及输入范围。

**恢复与交付边界：** 2026-10-30手机连接中断的实际reverse缺失由 `profile/network-resume-20261030.json`记录（SHA d9bd1926…）；仅恢复自有18443映射，账号/配置/其它映射未改，手机HTTPS登录、资料和fresh light裁剪已重新确认。中断旧light及网络失败独立归档，不改旧结果。输入拒绝两轮与独立15秒迟到专项已完成。本轮旧一次性环境清理已取得三份独立实际报告：`profile/owned-avatar-media-cleanup.json` passed（SHA `7ed276e89d9009f876cf02977b3866d4d08801e8fdc047f86f81389fe5ab9f7f`），仅5个自有测试媒体逐个新读回SHA核验后删除exact URI及各2个精确临时导出，查询均0；`profile/isolated-services-cleanup-final-complete.json` passed/9项（SHA `c4962d816368ed43fda23c8f8b462c2d318a27faf8c91b87447e0b73408ddd55`），旧TLS/gate/backend进程、监听、reverse、一次性容器/DB及运行凭据状态均已消失，其他映射保持不变；`profile/isolated-private-material-cleanup-final.json` passed（SHA `0f7ac7ad37a9ef4b073350f21f9fb0daebdf26542169c7d7b61f1f408a6f0d5a`），8份旧TLS备份材料逐SHA删除，只留非secret清单/恢复日志，持久预览目录之外的旧私钥文件为0。先前三份stop preflight均incomplete、checks为空且未请求官方stop，历史保留；最终服务报告自身不宣称备份已清，由后一份材料报告承接。没有宽泛Docker/目录删除或系统信任/签名修改，固定预览DB/CA/登录文件独立保留。 固定预览已完成真实seed、正式首次改密及显式状态修复，后续直接登录实测已通过，账号已可供审查。首次因Docker stdin缺少`-i`失败，经业务写入0核验后显式恢复prepared；第二次seed和改密成功后，PB0.40.1拒绝删除唯一superuser，保留initializing而未重放。随后 `profile/preview-initialization-reconcile.json` 实际passed，SHA `75ba302cacd5bf9fa5fca9764b92542bd8afdb961efdf12d57db9228724df5c3`：官方CLI对同一bootstrap身份换成不保留的随机密码，password hash/tokenKey均已变化，27个game表逐值与SHA一致、玩家口令/CA不变、seedReplayed=false，核验后才标complete并补回原IDs。最终runner `61059c59de2ec4fc964ee01566557dca7e31fc1535d19ae0559529f6897b0460` 的唯一记录退役及镜像immutableID/逻辑tag/arm64校验已静态复核。`profile/preview-environment.json` 已取得host_ready_native_pending（SHA `87b37b96a5f15571577b21c6d4edcd33cd26acd9f3161a205233c6bf6d7b517c`）：正式玩家直接登录verified_direct_login，独立CA可信200、不可信及错误主机名均拒绝，不开放玩家故障/重置接口；该原报告保持Host范围。新预览HAP `c2fdc34356a6176953fac806157b7c82ac513345575f8368f95524cea8b7408b` 已经官方run构建签名安装，`profile/runtime-preview-final.json` 六项实际passed（SHA `77f6f84e2894cc376594a62afc02dc43af54559bc739fd2584eb0c08612d9527`），包括真机API可信CA接受及不可信/错误主机名TLS_ERROR、系统区透明和深浅内容色。独立 `profile/runtime-preview-freshness.json` passed（SHA `eff6a1351013ebb908bebabbb8062318a0acfa7b3c48fe702d3732143c6860a2`），以当前自有进程的7条原始记录核window/material/TLS/双主题与原报告相同，不保存设备/进程标识，不改原runtime。新预览包的 `profile/preview-native-smoke.json` 已实际passed/13项（SHA `c63aed805a9c218a0589366a623fe91a8d0bfd5b9acb2da16315978307054751`）：固定普通账号从空登录直接进首页，真实四类场次、权威资料/只读账号、菜单Back、显式退出空输入及第二次直接登录均已核；四项收尾全true，第二次会话有意留在已认证首页供用户审查。独立 `profile/preview-native-root-review.json` 为reviewed_static（SHA `467dcc5b64f2a1b70b14900dfc96638e75742330adece9dcb7d29ef068d36cff`），Root逐SHA亲看3张原图，已停止手机自动化。此13项只认证/读取/导航/退出，不重跑资料、头像或密码写链，也没有服务端写台账计数结论。固定账号直接预览现已可交付，服务收口时仍运行且Host直接登录再次验证；需电脑保持唤醒、Docker运行、手机USB连接。独立 `profile/preview-package-source-binding.json` 为offline_binding_verified（SHA `19cf9511b823b3e4d19e1327dadef825ed068eda74ab7443cd3da3cade8bede8`）：35份源、8个导航SVG和包内ABC与6a逐字节相同；48个ZIP成员集合相同，45个内容字节相同，实际仅独立CA、完整1226条symbolMap记录重排及integration JSON空白/fontScale `1.0`→`1` 序列化变化，JSON值/顺序相同且timeout均15000。新signed HAP独立600归档，旧包/报告未改；不解析或归因ZIP之外的签名块。它只作离线来源绑定，不继承6a主轮39项为新包通过。停止/重启持久保留及用户改密后的行为也未因此完成实测。 不算任务1最终完成。

**迟到专项与来源工具的最终边界：** 独立15秒变体HAP `d03bd895ed5ef220b48126186b3502925bb9ec94f72c4aa617174b11e93f42a4`已构建签名安装，`profile/runtime-late-15s.json`六项passed（SHA cb226514…）；`profile/device-profile-avatar-late.json`实际passed/count6，SHA `44f27226a1cb1804251b355b212148e410ee2dfe085ed772d312480855655ec9`。先在同变体完成正常原生头像GET200和实际退出校准，再hold精确SHA的真实文件200，观察空登录后release，下游finish且无client abort；响应结束、Back/Ability重启及冷启动仍为空登录，旧资料/头像/菜单缺席。gate中恰1次原生受保护文件GET、0次Host文件读取，5项cleanup全true。finish仅代表TLS下游写出，不是解码回调；不覆盖真实切到另一账号，也不将2秒base或后续UI包记为同版专项通过。 `profile/hap-timeout-variant-host.json`实际passed/23项，SHA `81c96c7b31787aac356714020376ec27b8a7199388744cf8e8c4834c552a329f`，仅为离线来源验证工具：34份源码、ABC和CA字节一致；除integration timeout由2000改15000外，仅symbolMap的1173条完整唯一记录重排，保留所有键和值，其余打包条目一致。严格校验及反例不忽略symbolMap、不重打包signed HAP，不计业务、签名有效性或UI通过。实际变体安装/runtime来源另见 `profile/late-variant-hap.json`（SHA b762fbe4…）。

2026-11-17，四个目的地开放后重新核对拖动。应用收到正确的底栏坐标，ArkUI 浮动 `Tabs` 在非最左起点仍给出错位的目标索引。行为与公开实现使用起点子项局部坐标命中父底栏的路径一致。首页主导航使用 UIDesignKit 的官方 `HdsTabs` 浮动样式、沉浸材质和主题光色。`onContentWillChange` 负责业务准入，通过后由系统完成选择，`onChange` 同步已实际切换的页面。侧栏及返回仍以同一个目的地索引驱动。取消旧触摸事务和定时器回放，内容区保持禁止横向切主导航。键盘可见时从原生 TabBar 的 `barModifier` 隐藏底栏。[诊断实测](../artifacts/validation/ui-tab-drag-20261117/native-coordinate-diagnostic.json) · [HdsTabs 官方接口](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ui-design-hdstabs) · [ArkUI 开源坐标路径](https://github.com/openharmony/arkui_ace_engine/blob/master/frameworks/core/components_ng/pattern/tabs/tab_bar_pattern.cpp#L3722-L3757)

## ADR-018：键盘期间收起浮栏与官方左右玻璃面板

当前用户手验补充（2026-10-30）：用户在最终交付的 `c2fdc343…` 固定预览中，手动拖动浮栏启程↔护照并松手切换、打开头像侧栏，对“跟手光感、松手选中和侧栏进出方向是否符合预期”明确回复“符合预期”。来源见 `artifacts/validation/profile/native-ui-user-confirmation.json`。这三项从当前待验中移除；6a历史采集、静态及官方注入报告的原限制保留，不反向改写。此次没有新增自动化或Root动态目视，不扩展为触感、取消/中断、减少动画、双主题全覆盖、折叠、重启或主动改密通过。

2026-10-30用户要求修正输入遮挡、空心/实心选中图标、官方触摸流光，并在官方能力允许时按头像所在侧打开菜单。

**选择（已采纳；当前手机主轮39项和静态审阅完成，动态范围单列）：** 保持同一Tabs及表单实例，按真实键盘避让区隐藏原生TabBar并清理未完成的输入事务；收键盘后恢复浮栏。底栏和原四个账户菜单入口复用冻结Web的四组Phosphor regular/fill矢量及MIT许可；菜单资源选中沿用原背景/无障碍条件，不更改布局或路由。仅底栏显式启用官方ImmersiveMaterial交互/流光，并服从减少动画设置；跨项拖动松手选择以真实系统回调和手机结果为准，不自制坐标选择器。

官方SheetType.SIDE要求至少600vp，但补查确认这不限制PromptAction的options-builder自定义Dialog。新增ui封装使用官方Dialog背板、ImmersiveMaterial.THICK、按头像真实窗口坐标选择CenterStart/End与官方TransitionEffect.move；内容顺序、Scroll和业务入口保持。面板受安全区、400vp宽及90%可用高度约束，并额外留异侧空间。不得使用等同customStyle=true的ComponentContent重载，也不制作仿制玻璃或手势。封装负责重复打开、过期异步打开、后台/宿主退出及账号边界，页面负责业务意图；业务事实不由动画结束回调推动。

**当前新UI执行边界：** 当前final-nav HAP `6a5232af434e2fed8d6d56b50e25f7bf86b7cf24de22bd6523bdc79f23d5ad90` 的新主轮 `profile/device-native-ui-refinements.json` 已实际passed/count39，SHA `67f2c8d7a2deb0d2cd6f2bf42d7a1da50c6be1be01fad8755d292e245fa5e1ba`，绑定runtime-ui-final-nav六项与final-nav manifest `830e4aa0…`。本次driver为 `a90202ddf49f69d42538b2cc73c1e601981944c35b1340aff7e6e71fee6b00ad`；六项cleanup全true，真实profilePatch/passwordPost增量各0，旧UI检查未继承。覆盖正常登录、启程/护照及未开放入口保留原页、首页右/详情左官方面板的关闭/Back/可见蒙层与返回、主题/退出，以及昵称和密码键盘、草稿与Back行为。该主轮不保存资料、不改密、不入场答题。

**实际键盘视口：** 昵称与密码均观察到命名IME窗口，但两个IME根均为全屏矩形，已明确拒作键盘几何。可用区取同页无IME基准AppRoot `[0,132,1320,2848]` 与实际RESIZE后的根：昵称 `[0,132,1320,1788]`、密码 `[0,132,1320,1606]`，保持原点/宽度且真实缩短；报告的imeWindowBoundsPx/imeWindowHeightVp为null，缩短量不称IME高度。原始UiTest核实浮栏无可见或命中目标，完整52vp动作位于真实可用区；收键盘后浮栏四项恢复，昵称草稿及三密码保留，后续离开护照清密码，均无资料/改密写。 驱动只接受可证明的可用App区域，不从全屏IME根或经验高度制造键盘边界；fallback不更改产品键盘模式。驱动的11项AST隔离检查已passed，仅验证几何拒绝边界及重复cleanup先清旧标志/写入增量：私有 `artifacts/private/ui-resize-viewport-driver-draft-20261030T045823893635Z/offline-guard-check.json` SHA `705ebfa9a47604681d0e1afbaa5d19473b23cdb25803b5bdeeb3f87f8143af1a`。它没有设备/网络/服务或业务执行，不并入39项或业务完成度。

**独立静态与动态边界：** 独立 `profile/native-ui-root-visual-review.json` 为reviewed_static_with_explicit_limits，SHA `32725c37417962cbe7403c0a5c4b99f95c6f74fcab4b3dae74c133d8e37abb51`，严格绑定本轮39项报告。Root亲看13张原图：12张可观察；密码焦点1张App内容黑，不计像素、布局或主题目视通过。两主题底栏及菜单的regular/fill选中态、首页右/详情左最终位置、官方玻璃与原内容、昵称键盘下浮栏隐藏/完整保存及收起后草稿均已静态核实。静态图不证明跟手流光、松手跨项选择、入退场方向在运动中正确或中断/减少动画行为；松手选择由后续独立官方注入记录承接，其余动态范围继续单列。1a40的24图保持其基线，不替代本轮，也不反向改写旧报告。

**当机官方注入选择与未知动态：** 独立 `profile/native-ui-refinements-drag.json` 保持status=observed、stage=gesture-finished-root-review-pending，SHA `7918b8195b740f9f519124645bae43209fbb2720cd759c992ab9ea5594db4c70`，绑定同6a/runtime/A902。6个实际阶段正常退出，swipe与原生预长按drag各正反方向共4次观察均实际落到目标启程/护照，原生最终索引0/3并记录click→will→intent→param→change；未自制产品手势，也未补点目标。六cleanup全true，资料/改密写增量各0。Root另亲看4张终态原图，选中fill与目的地一致；独立 `profile/native-ui-root-gesture-review.json` 为automated_native_release_selection_verified，SHA `7fa8311e8715adad8660624d4eee76af41f167d134004fa7de22612a8353f731`，verifiedOutcomeCount=4，review自身newCommandsExecuted=0。结论仅为固定API26当前手机/6a的官方注入松手选中结果，不是人工操作通过、所有平台能力或回调总顺序保证；跟手移动光感、触感、未抬手/取消/中断、减少动画和入退场运动仍未目视或专项验收。

**裁剪宿主独立回归：** 当前6a独立 `profile/native-ui-crop-cancel-regression.json` 实际passed/count10，SHA `c9f8bf03aa11d5bda6dad1a27da65bdc1cf1ab00cfba1ee310e17bcce7f86fcb`，绑定39项主轮67f2…、同HAP/runtime和私有助手adf8dca9…。实际exact自有PNG选择并点击系统Complete，原生方形预览无错误，随后只取消：无pending、昵称与头像经新HTTPS读取保持不变；8项cleanup全true，资料/改密写增量0。Root亲看两张新原图，独立 `profile/native-ui-crop-cancel-root-review.json` 为reviewed，SHA `7ed3eea195b6e2837df80d11888120e73de245137077ed7240fc6b4082e199ab`；源采集报告visualReview=pending保持原样，由该独立review承接目视。范围只为当前SidePanel宿主兼容的真实Picker→裁剪预览→cancel，不确认、不上传，不扩写全部裁剪控件安全区或6a重新跑过1a40完整上传链。恢复follow-system仅记录动作/控件和无错误，选中辅助属性不可观测，不作动态跟随系统主题通过。

**旧尝试保留：** 旧193b/6a的incomplete10、首aa失败的incomplete0，以及在旧IME几何门禁中断的incomplete21均独立保留，完成cleanup不改功能状态。count0归档 `profile/attempts/device-native-ui-refinements-20261030T044247730768Z.json` SHA52d9a5e6…；count21归档 `profile/attempts/device-native-ui-refinements-20261030T050029215328Z.json` SHA `b328a858ad8cecbf657a4675466268b7feee1cd7f1411be99eb6caae96ec45e9`，二者六cleanup全true。USB重接后只恢复精确自有reverse且严格Host200，`profile/network-resume-reconnect-20261030.json` SHA c10b847b…保留该恢复事实；新的A902 run独立开始，不继承旧checks。

版本、官方来源及原型/验收入口见[本轮UI调整](native-ui-refinements-2026-10-30.md)。旧1a40的底部Sheet截图与检查继续属于其基线；新面板Back、蒙层、动作可达及退出已在当前39项核对，最终位置与玻璃有独立静态目视；运动中的方向、跟手、取消/中断和减少动画仍独立验证，不能从静态图或官方配置推定。

**固定工具链lint的证据含义：** `profile/lint-native-evidence.json`（SHA `df12779b2c2214c13ae78e5918d2454513d0ed9982164bcddba53bb7df534ca2`）解释原11:31固定工具链执行，不是新lint或新增验收：原 `lint.json` 仍0 issues/filesChecked=0。Studio先过滤无缺陷文件，CLI统计剩余报告路径，因此该字段不是输入扫描数；原ArkPerf FileCount35及HPAuditor的35条唯一路径与当前35文件集合一致，独立证明当时处理这些输入路径。报告中的当前源码SHA仅绑定本次说明时的字节，不作当时逐文件SHA的回溯证明。原日志“文件不存在”定位为扫描后临时规则文件unlink ENOENT，具体缺哪一个未记；默认配置按官方分流跳过ESLint，HPA的12项安全规则flag启用，而ArkPerf独立registry的InvalidRule不等于全局规则失效。零缺陷不作安全认证或逐规则覆盖证明；未改配置、旧日志或原结果，也未重跑。

2026-11-02局部补充：底栏通过官方 `LightEffectOptions.color` 使用现有 `app.color.accent` 日夜资源，仅扩展 `StarwardMaterial.create` 的可选光感颜色参数；保持材质能力与减少动画门控。标准SVG `BottomTabBarStyle.iconStyle` 没有独立发光入口，本轮不改图标实现。接口依据及局部验证状态见[底栏主题色光晕](bottom-bar-theme-light-2026-11-02.md)。

## ADR-019：人工预览与故障验收分别持有隔离环境

2026-10-30用户要求固定专用账号直接登录预览。**选择（已采纳；静态审阅完成，实际状态修复及Host已完成，预览新包runtime六项及直接登录13项/3原图已验）：** 另建本机持久PB和HTTPS预览，固定starward_preview账号通过真实初始化改密后进入普通登录状态；不在App绕过服务端强改密门禁。预览与一次性故障/改密验收不共用DB、玩家、状态、CA或控制入口，预览玩家代理不提供故障与重置API。原生会话仍仅内存，不声称支持记住登录。

用户要求的固定口令仅保存在忽略的本机600权限登录文件；不进入代码、样例或公开报告。停止预览保留DB/CA/登录信息，启动核验原进程、容器、监听及官方USB映射归属；用户改密后不静默重置。证书续期和恢复步骤见[隔离预览说明](isolated-preview-environment.md)。最终可为用户保留预览服务，但必须完成旧一次性环境的凭据、DB、CA及映射清理，不能误用同一套清理命令销毁预览。 固定预览已完成真实seed、正式首次改密及显式状态修复，后续直接登录实测已通过，账号已可供审查。首次因Docker stdin缺少`-i`失败，经业务写入0核验后显式恢复prepared；第二次seed和改密成功后，PB0.40.1拒绝删除唯一superuser，保留initializing而未重放。随后 `profile/preview-initialization-reconcile.json` 实际passed，SHA `75ba302cacd5bf9fa5fca9764b92542bd8afdb961efdf12d57db9228724df5c3`：官方CLI对同一bootstrap身份换成不保留的随机密码，password hash/tokenKey均已变化，27个game表逐值与SHA一致、玩家口令/CA不变、seedReplayed=false，核验后才标complete并补回原IDs。最终runner `61059c59de2ec4fc964ee01566557dca7e31fc1535d19ae0559529f6897b0460` 的唯一记录退役及镜像immutableID/逻辑tag/arm64校验已静态复核。`profile/preview-environment.json` 已取得host_ready_native_pending（SHA `87b37b96a5f15571577b21c6d4edcd33cd26acd9f3161a205233c6bf6d7b517c`）：正式玩家直接登录verified_direct_login，独立CA可信200、不可信及错误主机名均拒绝，不开放玩家故障/重置接口；该原报告保持Host范围。新预览HAP `c2fdc34356a6176953fac806157b7c82ac513345575f8368f95524cea8b7408b` 已经官方run构建签名安装，`profile/runtime-preview-final.json` 六项实际passed（SHA `77f6f84e2894cc376594a62afc02dc43af54559bc739fd2584eb0c08612d9527`），包括真机API可信CA接受及不可信/错误主机名TLS_ERROR、系统区透明和深浅内容色。独立 `profile/runtime-preview-freshness.json` passed（SHA `eff6a1351013ebb908bebabbb8062318a0acfa7b3c48fe702d3732143c6860a2`），以当前自有进程的7条原始记录核window/material/TLS/双主题与原报告相同，不保存设备/进程标识，不改原runtime。新预览包的 `profile/preview-native-smoke.json` 已实际passed/13项（SHA `c63aed805a9c218a0589366a623fe91a8d0bfd5b9acb2da16315978307054751`）：固定普通账号从空登录直接进首页，真实四类场次、权威资料/只读账号、菜单Back、显式退出空输入及第二次直接登录均已核；四项收尾全true，第二次会话有意留在已认证首页供用户审查。独立 `profile/preview-native-root-review.json` 为reviewed_static（SHA `467dcc5b64f2a1b70b14900dfc96638e75742330adece9dcb7d29ef068d36cff`），Root逐SHA亲看3张原图，已停止手机自动化。此13项只认证/读取/导航/退出，不重跑资料、头像或密码写链，也没有服务端写台账计数结论。固定账号直接预览现已可交付，服务收口时仍运行且Host直接登录再次验证；需电脑保持唤醒、Docker运行、手机USB连接。独立 `profile/preview-package-source-binding.json` 为offline_binding_verified（SHA `19cf9511b823b3e4d19e1327dadef825ed068eda74ab7443cd3da3cade8bede8`）：35份源、8个导航SVG和包内ABC与6a逐字节相同；48个ZIP成员集合相同，45个内容字节相同，实际仅独立CA、完整1226条symbolMap记录重排及integration JSON空白/fontScale `1.0`→`1` 序列化变化，JSON值/顺序相同且timeout均15000。新signed HAP独立600归档，旧包/报告未改；不解析或归因ZIP之外的签名块。它只作离线来源绑定，不继承6a主轮39项为新包通过。停止/重启持久保留及用户改密后的行为也未因此完成实测。 临时superuser优先删除确切自有记录；PB0.40.1禁止删除唯一记录时，核验sole记录与当次认证完全一致，再在归属核验后的容器内使用官方superuser update轮换为不保留的随机密码，不新增管理员或绕过核心删除限制。`profile/public-artifact-scan-pre-ui-resume.json`本轮实际passed，973个公开候选文件、0发现、0读取错误，SHA `85f9d649242febf9c5b01a3bacd24b684a29e292ec4eb9c4803b07a5ed977744`；本次未提供known-device，不扩大为已覆盖特定设备标识的扫描，也不代替最终环境清理。

## ADR-020：玩法快照与账号绑定的写操作

2026-11-04，已采纳，按小切片实施验证。保留原只读详情投影，新增平台无关GameplaySnapshot及完整关卡/题目解码，Repository承接同一认证会话的start与snapshot请求。玩法状态与草稿由专属V2 ViewModel持有，页面不拼URL或判题；登录门禁、账号代次、Navigation返回仍由根页面协作管理。

入场和答题各自保存一次逻辑意图：requestId、原始请求体、发起玩家和账号代次。并发点击单飞；暂时失败的显式重试沿用同一意图，不能因答案trim或编辑而悄悄改变重试体。未确认的写结果先回源或重试原命令；账号变化和退出使旧回调失效。进程重启重新登录并GET权威快照，不从本地答案自动重放。资料改密重试策略不改。

入场线索仅由当前入场命令的成功回执排入既有普通线索队列。回执显式为空时保持静默，旧回执缺少字段时与命令发起前的授权 ID 比较，同键重试沿用该基线。首题尚未完成时，自动演出按当前账号及场次授权核验，手动档案继续按已完成题卡显示。读取、页面退出和系统后台切换不得重新触发入场演出。见 [C01o](feature-acceptance-matrix.md#c01o-首次入场后的普通线索演出)。

后端完整快照决定题目解锁、进度、惩罚和完成，答题结果中的player替换经验事实，不本地累加xpDelta。非autoNext答对后保留已完成题并显式下一题；已完成回访与already_completed不产生新的完成反馈。线索/媒体演出与写入结果分开，未迁移能力不使用假实现。逐点验证见[玩法切片](slice-03-gameplay-validation.md)。

等级提升属于一次性答题演出。新正确回执返回更高的等级顺序时排入演出，比较依据是提交逻辑意图时同一账号的服务端等级与回执等级。ViewModel 先完成普通线索与自动切题，再发布升级提示。普通多题末题等待完成提示和组合线索。页面用 ArkUI 原生弹窗承载主题样式，关闭或中断不发写请求。离场、普通后台切换与失效账号清除队列，读进度不重放升级。

终章确认先于普通线索，随后是组合线索和一次性旅程入口。外链采用与独立线索共用的官方 `openLink` 交接及失败反馈。用户主动打开后，返回保留答题页及原滚动位置，通过只读同步确认链接仍获授权。原生留存返回位置，交付外部浏览器的地址不附加 Web 的 `returnTo` 场次路径。点「稍后前往」或没有有效外链时可以展示待发的升级提示。终章与外链已纳入本轮，站内剧情另做。见 [Q04b](feature-acceptance-matrix.md#q04b-终章演出与旅程出口)。

隔离包可通过既有`probeTls`开关启用写响应边界日志，仅记录固定操作名、HTTP状态和会话代次是否有效；默认关闭，不记录URL、玩家/关卡ID、请求体、答案或凭据。接收位置在平台transport返回完整响应之后、账号代次检查之前，用于区分上游已提交与客户端实际收包；日志不改变拒绝旧会话的顺序，也不作为业务状态来源。

首次多题引导以账号和后端为范围保存一个已见标志。答题页使用 ArkUI Scroller 定位实际表单，短时高亮独立于输入焦点和答题命令。键盘避让和已有浮动音乐控件的停靠位置以窗口、引导的实际布局为准。见 [Q01a](feature-acceptance-matrix.md#q01a-首次多题答题引导)。

场次公告与关卡提示使用正式场次快照中的 `extraDisplay`。客户端复用护照扩展项的字段清洗及上限，只展示纯文本，跟随原有入场、答题、轮询和下拉刷新响应。未发放的关卡正文和提示均不展示。关卡提示与题卡共用阅读区域，自动定位以这一区域为起点，顶栏显隐阈值仍由题卡上缘决定。见 [Q01b](feature-acceptance-matrix.md#q01b-场次公告与关卡提示)。

## ADR-021：题图下载、解码与查看独立于判题和头像认证

2026-11-04，已采纳，分显示与查看小点实施，尚未据此宣称图片功能通过。实际题图CDN需要正式Web来源Referer，且存在HTTP MIME与原始JPEG不符的资源；不能直接假设`Image(url)`或严格头像MIME规则适用。

- `platform/QuestionImageLoader`使用官方NetworkKit/ImageKit，固定公开来源`https://sitkin.top/`，不附玩家Authorization/Cookie，不沿用头像file token或隔离后端CA；外部HTTPS采用系统信任，下载不持久化。相对图片地址按Web站点解析，禁止凭据、危险scheme和字面本地地址URL；不把后端API origin当媒体origin。普通主机名交给系统DNS/TLS，SDK没有解析地址pin接口，不增加无法保证实际连接目标的二次DNS探测，也不声称抗DNS重绑定。
- 下载字节、原始尺寸、解码尺寸分别有界；以实际图片magic与ImageSource确认格式，容忍已知HTTP MIME误标。自然尺寸来自原图，解码可降采样；布局不把源像素除density，也不用缩略分辨率替代自然大小。
- 每个挂载图片有独立请求代次。取消关闭自己的HttpRequest；解码不能强停时，迟到结果释放。ImageSource操作完成后释放，PixelMap 由显示组件和当前场次缓存分别持有，最后一个引用释放时回收。
- 题图、选项缩略图、线索正文及查看器共享当前玩法页的内存缓存。按完整来源和统一的 2048 px 解码尺寸上限复用成功结果。最多保留 24 张和 48 MiB，以解码行字节数计费，按最近使用顺序淘汰。回看直接使用已解码 PixelMap，首次读取、失败与重试走现有路径。离开场次、退后台、失去授权快照或账号代次变化清空缓存，已发出的加载不能填回失效缓存。见 [C01g](feature-acceptance-matrix.md#c01g-题图和线索查看器回看缓存2026-11-12)。
- Swiper 当前页与相邻可读页保留同一题图组件，使用场次加题目标识持有显示引用。相邻页只绘制已有解码结果，缓存未命中的图片由落定后的当前页发起读取。题卡共用当前实测正文宽度，活动状态变化时保留已就绪的图像节点。见 [C01h](feature-acceptance-matrix.md#c01h-横滑中的相邻题图)。
- 2026-11-05补充：平台层以每实例的窄`QuestionImageIO`封装HTTP、ImageSource和PixelMap句柄，默认实现仍只调用固定SDK；不全局替换Kit，也不在发行配置加入测试延迟。受控Promise用于验证HTTP迟到、decode迟到、旧请求清理与新请求隔离、source释放期间取消四种资源交付竞态。测试句柄不伪造可绘制PixelMap；受控时序通过不等于实际SDK解码/TLS/释放行为通过，真实加载与绘制继续用真机验证。
- 页面/账号失效时立即清图片与查看数据；同题只读Refresh保持图片所有者，不重挂输入或以图片回调驱动判题。图片403是局部媒体错误，不触发玩家登出或答题重试。
- 场次背景使用同一安全图片解码器与场次级缓存。当前可读关卡和授权快照决定来源，切题取消不再需要的读取，装饰层与滚动前景分离。缺图或失败回到主题底色，主动刷新提供新的加载机会。见 [T03a](feature-acceptance-matrix.md#t03a-答题场次与逐题背景图)。
- 默认氛围为答题页面级 ArkUI 装饰。它叠在配置背景图与交互前景之间，固定在窗口并独立于关卡、媒体请求及答题状态。系统减少动画时仅保留静态装饰，退后台或离场移除动画子树。见 [T03b](feature-acceptance-matrix.md#t03b-答题页默认氛围)。
- `ui/`内V2组件封装官方Image和加载/失败重试反馈，保留Web图片顺序、自然比例、手机340高度上限、图集min150/gap10及选择图130高Cover。查看后续以官方bindContentCover/Pinch/Pan组合原有索引、缩放、滑动与关闭；不自制触摸识别器或声称有完整系统图库组件。
- 状态栏/手势栏保持可见；查看器如用固定深色背景，必须由现有窗口策略统一确保图标对比度并恢复，不能默认容器会替业务处理。视频、BGM和线索演出不接入本决策的图片成功状态。

每点实际加载、错误重试、取消/账号边界与原图对照分别验证。真实题目和明确标注的失败/富文本合成夹具分开记录，不把本地图片字节重放或源码检查写成Native真实加载通过。

2026-11-11 补充：普通线索是当前已完成题目的只读视图，由服务端发放快照投影；打开文字、切换图集和关闭弹层不发送玩法命令。文字通过 ArkUI PromptAction 居中弹层呈现，正文图片和独立图集沿用本决策的下载、解码与查看器。弹层和图集按账号代次、场次、题目及线索授权绑定；退出或失效时关闭并清理。视频、组合线索与自动演出仍单独迁移，逐状态验收见 [C01a](feature-acceptance-matrix.md#c01a-普通文字与图片线索2026-11-11实施前)。

2026-11-12 补充：组合线索的手动入口取当前已完成场次最新授权快照中按 Web 顺序最后一条。仅本次正确答题产生的完成事件能排队，区分显式空效果与字段缺失；GET、刷新和页面重建不重播。完成提示消失后交由 ArkUI 居中弹层接续，离开账号/场次或丢失授权即取消队列。入口通过 [ArkUI PanGesture](https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-gesture-common/) 拖动，[PersistenceV2](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/arkts-new-persistencev2/) 只保存设备本地的两个无量纲坐标，无账号、场次和线索数据。未迁移终章的场次完成后仍能手动读取已授权组合线索，终章自动序列另做。见 [C01b](feature-acceptance-matrix.md#c01b-组合线索2026-11-12)。

2026-11-12 完成提示由 [ArkUI PromptAction](https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-apis-uicontext-promptaction/#opencustomdialog12) 承载模态、焦点、遮罩和转场，品牌内容用原生组件构建。提示句柄按当前账号和场次持有，退后台或失效时撤销。仅当前提示被明确确认并完全关闭后，才读取仍然获准的组合队列。空队列保留「知晓了」及系统返回。见 [C01e](feature-acceptance-matrix.md#c01e-组合谜题完成提示的主题样式2026-11-12)。

2026-11-12 线索正文外链使用 ArkUI `Span` 维持行内排版。平台边界只向 `UIAbilityContext.openLink` 交付校验后的 HTTP(S) 地址，由系统选择关联应用或默认浏览器。玩法页按当前弹层和单次打开动作登记交接，通过官方启动回调处理失败或取消。主动点按外链会取消尚未执行的自动前进，回前台使用保留题目实例的只读同步。普通后台返回沿用原有重载，账号、场次及线索授权继续由现有代次和快照约束。见 [Span](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-span/)、[openLink](https://developer.huawei.com/consumer/en/doc/harmonyos-references/js-apis-inner-application-uiabilitycontext/#openlink12) 和 [C01c](feature-acceptance-matrix.md#c01c-线索正文外链2026-11-12)。

独立外链卡共用系统交接和错误反馈。卡片来源为当前已完成题目下的服务端授权，点击时绑定账号代次、场次、题目和线索快照；交接返回沿用同一答题实例，只读确认最新授权。外链仅由点按发起，排除于自动播放和组合演出。见 [C01n](feature-acceptance-matrix.md#c01n-独立外链线索卡)。

## ADR-022：普通视频线索的播放与临时文件

2026-11-26 补充。答题页的内嵌及独立播放器在收到有效的 ArkUI 原生全屏事件后，按旋转校正后的显示尺寸选择主窗口方向。主窗口平台层串行处理进入与退出，恢复进入前的方向策略。授权、播放尝试、预览层、临时文件与 BGM 仍由现有播放器生命周期管理。

2026-11-12，冻结 Web 的 7 个已发布视频样本均为 HTTPS MP4，约 0.31–2.72 MB。去掉 Web 站点 `Referer` 的单字节 GET 均返回 403，带该来源的请求均返回 206。固定 API 26 的 ArkUI [Video](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-media-components-video) 自带播控，其数据源参数接收 URL 或资源。

- 普通已授权视频由 [NetworkKit HTTP](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-http) 附固定 Web 来源取回完整 MP4，使用严格 HTTPS，拒绝重定向，关闭代理、缓存和 Cookie，不发送玩家凭据。16 MiB 上限覆盖已检查样本，限制播放器前置缓冲占用。隔离包只对已配置的同源本机媒体夹具使用专用 CA。
- 单次播放持有独立的应用沙箱临时文件和官方 Video 控制器。优先使用 [AVMetadataExtractor](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-media-avmetadataextractor) 的视频尺寸与方向保持画面比例。结束、关闭、退出前台、账号/题目或授权失效时释放播放器并删除文件。能力启动时清理上次异常退出遗留的专用临时文件。
- 网络完成、播放器准备、播放结束均检查同一授权和尝试身份。手动播放结束后关闭当前媒体预览。重试只创建新的媒体读取尝试。手动播放验收见 [C01f](feature-acceptance-matrix.md#c01f-普通视频线索手动播放2026-11-12)。

题面、选项及普通线索共用播放器和 BGM 互斥。题面视频绑定当前可读关卡和对应内容块，选项视频额外服从答题可编辑条件。可选封面走现有图片读取与缓存，播放器可复用同一已解码图片，不另向视频组件交付远程封面地址。打开与重试只操作媒体。见 [C01p](feature-acceptance-matrix.md#c01p-题面视频) 和 [C01q](feature-acceptance-matrix.md#c01q-选项视频)。

2026-11-12 补充：非末题正确响应可按当前题已发放的效果启动视频序列。显式效果优先，字段缺失才比较前后授权。查看器在浮层消失后报告本次播放是否自然结束；ViewModel 依据已结算的自动前进配置和当前题位置决定切题。提前关闭取消自动前进，重试沿用媒体读取，退后台或离开场次清空队列并让在途答题响应的演出失效。答题响应仍独立结算，GET 不创建播放事件。见 [C01i](feature-acceptance-matrix.md#c01i-答对后自动播放视频线索)。

非末题的文字、图片与视频共用按授权顺序推进的演出队列。原生阅读弹层及独立图集通过各自的消失事件结束一步。文字内嵌图仍是当前阅读的一部分。普通后台中断使队列及迟到响应失效，正文主动外链交接保留阅读及队列，通过只读回源复核授权并沿用取消自动前进的规则。隔离包开启 TLS 探针时，仅在配置的精确本机 HTTPS origin 上为两条合成 PNG 路径使用打包 CA，外部图片继续使用系统信任。见 [C01j](feature-acceptance-matrix.md#c01j-答对后的文字与图片线索演出)。

普通多题的末题成功响应在结算后登记本次组合授权，普通线索队列排空时才发出完成提示事件。提示确认后由原有组合队列接续。视频提前关闭只影响自动前进的资格，仍结束当前普通线索步骤。场次、账号或播放会话失效丢弃未展示的提示及队列，GET 不产生新的完成事件。见 [C01k](feature-acceptance-matrix.md#c01k-末题普通线索完成提示与组合线索)。

题卡扫光、组合浮标呼吸和完成提示装饰按冻结 Web 周期接入原生属性动画。题卡仅在前台当前题卡可见时运行，浮标及弹窗的装饰随各自组件挂载并服从系统减少动画设置。装饰层退出布局测量和命中。完成提示通过 ArkUI 分别管理内容转场与系统遮罩，旋转底纹、边光和点粒子绘制于面板。验收见 [C01l](feature-acceptance-matrix.md#c01l-题卡组合线索浮标与完成弹窗动效)。[ArkUI 属性动画](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/arkts-attribute-animation-apis/) · [弹窗遮罩](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/arkts-dialog-mask/) · [粒子动画](https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-particle-animation/)

2026-11-13 答题顶栏的头像外圈、计数、题卡反馈和线索动效由 V2 UI 组件持有，计数与答题结果继续来自权威快照。头像的菜单徽记及点击区域固定。可复用的媒体装饰只动背景和边框，保留图库像素、手势坐标及官方播放器控制。ArkUI 弹层管理遮罩和退场，线索队列仍由原有弹层消失事件接续。持续动效由前后台、可见性及减少动画控制，装饰层不接收点击。验收见 [C01m](feature-acceptance-matrix.md#c01m-已迁移答题与线索动效复查2026-11-13)。

题面、题内提示及两种文字线索共用旧富文本解析。样式、链接、图片和视频划分为有序的原生组件，线索卡只取文本预览。正文内可以直接使用 ArkUI Video 播控或主动展开。两种模式单独拥有播放尝试，切换时释放上一尝试。展开从头播放。对刚在同一题面或提示中播放过的视频，展开层消失后使用 ArkUI Video 的暂停定位恢复最近上报的播放进度。两种线索关闭展开时返回正文及封面。切题、收起提示、中断阅读或退出时校验阅读身份并释放相应媒体，保留原有的答题与线索结算。

## ADR-023：站内剧情路由与授权读取

2026-11-16。`Navigation` 使用独立剧情页面和类型化场次、剧情标识。首个来源是本次终章「继续旅程」，站内目标与当前完成快照一致时入栈。Repository 对正式 `/assignments/{assignmentId}/narratives/{contentId}` 发起授权读取。该接口决定访问权限和内容类型。剧情状态由账号及页面生命周期管理，离开清空内容并使迟到读响应失效。返回仍保留答题页和滚动位置，已接续的终章演出不再播放。

原生信纸持有阅读会话及视觉节奏。打开、关闭、翻页、跳过和重试都只影响阅读状态。答题页面被剧情覆盖时暂停页面配乐与轮询。见 [N01a](feature-acceptance-matrix.md#n01a-终章接续与原生信纸)。[ArkUI Navigation](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/arkts-navigation-jump/) · [ArkUI 目的页生命周期](https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-basic-components-navdestination/)

信件配乐和段落配音由阅读会话持有的原生 AVPlayer 管理。段落配音与正文打字同时推进，遇到配音结束或失败才允许进入下一段。配音期间降低配乐音量。当前会话、页面前后台与播放器回调需要共同校验，避免过期的声音或段落更新。纸面背景按阅读会话切换并复用账号隔离图像缓存，保留已显示画面直到新图解码完成。见 [N01b](feature-acceptance-matrix.md#n01b-三种信纸的版式与媒体)。

星海信笺根据当前账号的正式场次详情汇总服务端已发放的信纸线索和已完成的信纸终章。终章目标缺少子类型时，经同一个授权读接口确认类型，列表仅保留授权入口及展示摘要。点击后按账号和来源校验并再次读取正文，阅读页返回原有列表实例。该路径没有玩法写入。见 [M02a](feature-acceptance-matrix.md#m02a-星海信笺的信纸回访)。

祝福复用同一剧情路由和星海信笺的授权读取。一次播放会话持有 ArkUI 星场、前台演出计时器、原生 BGM 和配音两路播放器。正文按配置停留，片尾配音按实际播放结束推进，失败则按该行配置时长继续。切到后台暂停计时和音频，退出释放两路音频与画布帧回调。系统减少动画时保留同一文案与播放顺序。每次重新进入从开场开始，播放状态与结算无关。见 [N02](feature-acceptance-matrix.md#n02-原生祝福演出与星海信笺回访)。

题内信纸和祝福按服务器已发放的线索身份进入同一剧情路由。区分题内来源以便剧情读取失败时仍返回原题，原生导航保留答题页实例。题卡以当前已完成关卡筛出已获授权的剧情。前一题待开启剧情使用单一浮动提醒。用户主动打开后，按后端、账号和场次保存至多 128 个已打开线索键，供题内展示参考。授权及任何结算仍由服务端决定。浮层在同一底部安全区内避让，待开启提醒先于答题引导出现。见 [C01r](feature-acceptance-matrix.md#c01r-题内信纸与祝福线索及待开启提醒)。

## ADR-024：旅途来信的账号状态与答题浮标

收件箱和答题浮标共享当前账号的来信列表及已读回执。正式 GET 保持服务端的收件顺序，答题弹信从最早未读开始。正式已读接口返回 `readAt`，同一账号一次只提交一个已读操作。提交前取消在途列表读取，防止较旧列表覆盖已读回执。账号退出、改密轮换或被禁用后，使迟到结果失效并清空来信内容。

收件箱进入时读取，下拉可以重试。入场前说明页或已进入的答题目的页可见且应用前台时，每五秒只读同步。两者沿用场次目的页上的单一轮询所有者、当前账号和已读回执。说明页先展示已经取回的未读来信，来信或入场演出占用界面时按当前阶段安排展示。已读和归档状态可跨说明页到答题页延续。打开剧情、离开或手动刷新答题时暂停。`CONTENT_COVER` 引起的目的页可见性变化只影响展示队列，保留轮询，关闭后按当前账号和最新来信重新判断。系统返回优先处理当前媒体、来信，再交给导航。收件箱主动阅读保留原状态，答题小列表和自动弹信各按 Web 已读触发时机提交。浮标持久化仅保存设备本地的归一化坐标，信件和已读状态只存会话内存。[ArkUI 目的页生命周期](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-navdestination/) · [验收表](feature-acceptance-matrix.md#m01a-旅途来信收件箱与答题浮标)

## ADR-025：场次目的页的资料与入场状态同步

同一个场次目的页在前台可见时，入场说明和答题阶段以五秒间隔读取 `/me`。`SliceViewModel` 持有当前账号的读取和定时器，同一个定时器只允许一条未完成的资料读取。隐藏、后台、下拉刷新、资料写入、答题结算或账号失效时取消相应在途读取。接受响应时同时核对账号代次、资料版本及当前读取身份。答题成功的玩家快照仍按已有逻辑提供等级和经验，读取玩家资料不加入演出队列。

说明页使用正式场次快照的同一 GET 加载与轮询。快照显示另一端已入场时，复用该响应恢复答题实例和当前题，独立于入场成功回执及演出。说明页离开、即将发起入场或改密时取消相应读取。每次推入场次目的页时分配导航实例编号，只有当前目的页的可见性回调可以停止相应读取，避免旧场次的隐藏事件中断新场次。入场未确认期间保留原写意图，禁止只读恢复把原意图覆盖。已撤回的快照结束说明轮询并展示对应状态。首次失败或失权清空不可再用的内容，提供显式重试。

场次和玩家读取各自记录故障状态，共用同一个非模态同步提示，关闭状态在说明页到题面的切换中延续。两路恢复后结束本次提示，玩家或场次任一路仍未恢复时保留同一次故障编号。临时错误保留已显示的事实和题目草稿。玩家失权或强制改密沿用登录门禁和账号内容清理。[说明页验收](feature-acceptance-matrix.md#q01c-入场说明页状态同步与撤回) · [题面验收](feature-acceptance-matrix.md#2026-11-16-答题留项迁移)

## ADR-026：说明页与答题共用场次背景和配乐

场次目的页按账号和本次导航实例持有配置背景、默认氛围、BGM 播放器和浮标位置。说明页读取已授权 `assigned` 快照的场次级配置。进入答题后按可读关卡解析媒体覆盖。冻结 Web 在说明页已应用首题覆盖，原生在首题可读后应用，说明阶段使用场次自己的图和配乐。同一 HTTPS 音源跨说明、答题及同曲关卡延用当前播放尝试，音源变化才交接。无背景或配乐时沿用主题画布和默认氛围，回避无用的媒体请求。

来信与答题媒体各自报告是否占用音频。播放器确认静音后才开始视频，关闭视频后沿用玩家此前的播放选择。前后台和剧情覆盖切换沿用原配乐的前台策略，保留当前目的页的媒体占用状态，应用退后台或剧情覆盖时停止装饰并清理解码背景缓存。离开、换账号或失去场次授权时立即清理。背景、动画和媒体回调不发起入场或答题写入。[场次氛围验收](feature-acceptance-matrix.md#t03c-入场说明页的氛围与配乐)

## ADR-027：奇遇收藏使用玩家奖品快照

底栏与头像侧栏使用同一原生收藏页。正式 `GET /api/questions/v1/rewards` 返回当前账号的有序奖品快照，包括脱离具体场次发放的奖品。HTTPS 层验证条目归属及必需字段，只保留可领取奖品的私密领取内容。列表与选中详情只留在账号会话内存，详情随成功回源更新，删除或失权即关闭。

收藏可见且应用前台时每五秒回源，任一时刻只有一个读请求。下拉和显式重试替换在途读取，离开、后台或账号变化取消对应读取。短暂错误保留同账号快照并允许恢复，身份或权限失效清除列表和详情。原生底部弹层仅展示已授权快照，关闭回到原列表位置。领取、核销和撤销由后台负责。[收藏验收](feature-acceptance-matrix.md#r01a-奇遇收藏的奖品列表与详情)

详情底部的避让间距属于滚动内容。ArkUI Sheet 的主题底色连续绘制到系统手势区。双向绑定保留独立的弹层可见状态，按关闭按钮时先让系统收起弹层和遮罩，退场完成后清理选中的奖品。点遮罩、系统返回和下滑由 Sheet 处理。权限失效及时停止媒体并清除私密内容。[ArkUI 半模态转场](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-attributes-sheet-transition) · [安全区](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-attributes-expand-safe-area)

## ADR-028：生产 HTTPS 的只读联调包

生产联调包沿用当前开发身份和官方调试签名。构建时显式选择独立的 `production-smoke.json` 标记，固定使用正式 Web 已部署的 `https://api.sitkin.top`。应用拒绝混有隔离配置或额外 CA 的生产标记，使用系统证书和主机名校验。运行时的外部路由、测试代理和资源 URL 无法改写游戏 API origin。构建助手先归档验证过的 HAP，再以同一份签名产物安装，固定预览资源原样恢复。

会话仍用原生关键资产存储，生产 origin 与隔离 origin/CA 各有别名。只读联调包仅发送 GET、密码登录和受保护文件临时令牌申请。联调诊断记录无凭据 `/me`、操作类型和 HTTP 状态，授权图片另记解码成功。只读候选的生产写入及正式签名另有验收范围。[逐状态验收](feature-acceptance-matrix.md#p01-公网生产-https-登录与只读联调)

生产写入验收通过显式的 `production-write` 打包标记选择。该候选延用固定生产 origin、系统校验和同源约束，允许 Repository 正常发送业务 GET、POST、PATCH，沿用当前账号代次和请求 ID。调试诊断只记录操作类别和状态，账户、场次 ID、答案和凭据不入日志。构建脚本默认仍选生产只读，对两种签名包分别检查资源及模式。发行签名和正式应用身份另行核定。[生产写入验收](feature-acceptance-matrix.md#p02-首版生产候选与真实答题闭环)

## ADR-029：本机主题偏好

`platform/AppTheme` 通过 ArkData Preferences 保存 `system`、`light` 或 `dark`，单个轻量值在用户点选时同步落盘。偏好属于当前 App 安装，登录前和侧栏共用。启动时从首选项初始化选中态，在主窗口页面加载成功后调用 `ApplicationContext.setColorMode`，已有窗口配置监听继续更新沉浸系统栏。缺少有效偏好时跟随系统。[系统配色 API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-inner-application-applicationcontext/) · [用户首选项](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-data-preferences/) · [逐状态验收](feature-acceptance-matrix.md#u01-日夜主题冷启恢复)

## ADR-030：正式应用身份与邀请测试签名

「赴星之约」以 `com.sitkin.starward` 登记为 sitkin 主账号同名项目下的 HarmonyOS 应用，首轮支持手机。沿用此 APP ID 及分发签名进行后续版本和 Push 绑定。首个邀请包从干净源码在独立工程中构建为 Release `.app`，仅打入已联调的生产 HTTPS 模式。DevEco Studio 使用云管理发布证书与 Profile 重签，保留本机调试签名及隔离预览资源。验证实际签名后上传到「仅测试」渠道。[发布签名说明](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-publish-app/) · [邀请测试验收](feature-acceptance-matrix.md#p03-发布签名与首轮邀请测试)

环境标识仅供开发调试。启动时用已安装应用的 `ApplicationInfo` 判断，只有系统标明调试模式且签名 Profile 类型为 `debug` 才显示。正式发行与 AppGallery 邀请测试包均不展示这类标签；后端环境、隐私门禁与错误提示仍按打包配置决定。[ApplicationInfo](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-bundlemanager-applicationinfo/)

## ADR-031：邀请包的 AppGallery 隐私托管

邀请包使用 `production-invite` 资源标记、固定生产 HTTPS 和 AppGallery 隐私托管。启动、回到前台及收到系统签署通知时，使用 AppGallery Kit 查询当前隐私声明及同版本的完整签署记录。官方弹窗负责接受或拒绝。登录和 Asset 续登要在签署确认后开始。应用内通过系统接口获取政策链接并交给系统浏览器。

确认未同意时，清理当前会话和本机续登记录。服务暂时无法查询时隐藏业务页面，废弃在途请求，保留原有加密续登记录。查询恢复后以官方签署状态决定续登或清理。隔离调试包可显式开启同一门禁并使用官方调试元数据。预览和此前两种生产联调模式沿用各自打包配置。[AppGallery 隐私管理](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/store-privacy/) · [签署验收](feature-acceptance-matrix.md#p04-首轮邀请的隐私政策和签署检查)

## ADR-032：设置目的页和一次性通知授权

设置是头像侧栏下的原生导航目的地，不改变当前主 Tab。显示偏好继续使用 ADR-029；通知行展示系统允许状态，并通过 Notification Kit 打开系统设置。设备绑定失败独立提示和重试，不把系统允许显示成生产发送已启用。

首次正常到达前台已认证首页、通过托管隐私和密码安全门禁后，先写入一次性本机通知申请标记，再尝试系统提示。标记属于当前安装，不绑定玩家，拒绝后不再自动弹出。登记、停止通知后的解绑和账号代次继续沿用现有契约。[Notification Kit](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-notificationmanager) · [验收项](feature-acceptance-matrix.md#f02b-设置入口和首次通知授权实施前)

## ADR-033：按是否可继续操作选择错误反馈

玩家仍可操作的即时网络失败，使用 `ui/StarwardErrorToast` 封装华为官方 HdsSnackBar，沿用应用日夜主题。由触发操作所属的页面显示和关闭，退出、切换账号或离开此页面时不遗留提示；关闭不会执行业务动作。后台同步沿用单次中断提示，已读到的同账号内容（包括成功读取的空列表）仍可使用。

需要修改输入时在表单附近提示；续登、密码修改结果未确认或关键内容尚未取得时保留页内说明及有效的恢复动作。「回到首页」由确实拥有返回路径的页面显式开启。提示和重试不改变会话、请求代次、幂等规则或服务端事实。[HdsSnackBar](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ui-design-hdssnackbar) · [逐状态验收](feature-acceptance-matrix.md#u02-低干扰的网络与操作反馈)

## ADR-034：共享来信同步与未读入口

前台、已通过账号和隐私门禁时，主页面共享一个同账号来信轮询；进入答题目的页后由原有答题同步接管，刷新或后台会取消本轮读取。首次成功读取建立未读基线，后续新通知按 ID 去重；冷启积压不反复弹出 Toast。来信底栏角标和答题浮标来自同一服务端列表，完整来信页保留历史。

用户确认保留答题自动弹信及原有五秒门槛。普通关闭仅暂缓本次场次的自动展示，不写已读；刷新、媒体覆盖和短暂后台保留暂缓记录，实际离场或账号更换时清理。手动浮标仅列未读，只有明确确认且服务端回执成功才移除；最后一封确认后提供可前往历史收件箱的轻提示。

原生使用官方 HdsSnackBar 的查看／关闭操作。HdsTabs 的默认底栏样式没有角标参数，保留官方底栏及拖选，官方 Badge 通过渲染后的原生信封节点坐标贴在右上角，不参与命中。Web 采用相同未读、自动弹出与回访语义。系统 Push 与前台应用内同步保持独立，此轮无需改动服务端或生产发送配置。

## ADR-035：具体场次订阅与推送分类

2026-11-19。用户将剧情来信和关卡消息归为订阅通知，平台公告和运营推广保留 MARKETING。系统通知许可、设备绑定、正式发送范围与具体场次订阅分别判断，不互相替代。客户端通过 Repository 读取和修改当前玩家的场次订阅；默认关闭，先订阅具体场次，再独立询问是否接收其推送，设置页提供取消。写入携带 requestId 和预期版本，账号代次及服务端回执决定最终状态。

运营通知显式区分场次动态与平台公告。只有关联到该玩家具体场次、存在有效订阅且允许推送的场次动态，才进入订阅投递。取消会使尚未发送的旧版本任务失效，重新订阅不恢复旧任务。发送端再次核对资格；部署侧确认华为 SUBSCRIPTION 权益获批后才使用该分类，未获批不得声称已解除营销额度。应用内来信、已读及玩法结算不由推送订阅改变。新场次首次分配发生在订阅之前，沿用 MARKETING。[华为分类与订阅要求](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-apply-right/) · [验收目标](feature-acceptance-matrix.md)

## ADR-036：个人冒险动态的一次订阅（替代 ADR-035 的逐场粒度）

2026-11-19 用户纠正并授权：玩家一次主动订阅及独立通知确认后，应持续接收分配给本人的新场次、剧情来信与关卡动态，后续不逐场重复操作。订阅对象固定为“我的专属冒险动态”，不包含公告与推广；这两类仍走 MARKETING。账号级订阅由服务端保存，默认关闭，使用 requestId、预期版本、账号代次和回源确认。既有逐场同意不能自动扩大；没有账号级明确同意即不投递该主题，新记录的关闭/取消成为权威，旧记录和旧队列均不能绕过。

真实新下发和对应场次来信统一经过该范围的投递资格判断，取消退役旧版本待发任务，重新开启不补发旧事件。页面显示、已读、答题与结算保持各自业务事实。分类批准与实际发送配置分开：只有匹配真实范围的 SUBSCRIPTION 权益获批并启用后才使用该分类，不能承诺保证送达或无系统频控。MARKETING 的公开正式额度不满足用户每日每设备至少 20 次业务提醒的目标；这仍是待完成的业务能力，不能以调测额度替代。

用户授权先直接实现、隔离后端和直板真机验证，再撤回旧逐场分类申请，以真实设置/确认/取消、场次列表、来信列表及具体内容截图重新申请；如申请不通过，再走工单。此次授权替代此前先工单的推进顺序。华为指南没有明确要求逐场次，但也未直接批准本应用的新范围；提交申请与审核通过分别记录。当前本条为实现决策，非功能验收或平台获批证据。[分类与订阅要求](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-apply-right/) · [消息频控](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/push-msg-freq-control)

执行结果另见[九组直板 UI/隔离 HTTPS 验证](../artifacts/validation/push-account-subscription-20261119/device-ui-https.json)与[华为重新申请记录](../artifacts/validation/push-account-subscription-20261119/huawei-application.json)：新实现已验证，六图申请已重新提交，控制台为审核中；生产新接口、匹配新实现的邀请包及真实 SUBSCRIPTION 投递尚未完成。

## ADR-037：旅途订阅与通知的场次关联解耦

2026-11-19。用户确认新增「定向旅途消息（无需关联场次）」。这是 ADR-036 已说明的个人剧情来信与旅途动态范围的技术解耦，不是任意「重要消息」通道，不改变现有账号范围、默认关闭和两阶段同意。原生已经展示的同意文案包含之后分配给玩家的新场次、剧情来信与关卡动态；没有把一个具体场次 ID 作为订阅对象。

后台新用途仅允许指定玩家，服务端显式区分场次上下文与账号上下文，旧场次行通过前向迁移保持原义。场次用途继续检查本人的有效分配；定向用途不要求虚构分配。未知、缺损上下文不能使订阅投递降级为营销；未读、撤回、过期、账号、设备和当前订阅版本仍在发送前核验。取消订阅使旧任务失效，重新开启不补发。公告和推广仍使用 MARKETING。

华为分类权益和用户同意仍是发送条件，后台选项不代表权益获批。MARKETING 的每日条数是平台频控，不是付费余额。此处仅记录实现边界，生产发布及实际投递另行验收。

## ADR-038：登录后顺序询问通知与账号订阅

2026-11-19。沿用安装级系统通知申请及 ADR-036 的两阶段账号同意，在通过隐私、认证和安全门禁的前台首页主动引导。系统申请先结束，再读取服务端账号订阅；仅没有既有决定的新范围主动展示。系统通知许可、订阅与接收通知分别判断，不因登录自动开启。

应用自己的展示历史由平台 Preferences 保存，以端点、CA、账号和订阅范围生成不含原始身份的键，在展示前持久提交。拒绝、关闭和中断后不自动反复询问；设置仍有独立入口。询问使用独立的订阅读取实例，复用既有 Repository、版本和幂等写入；导航、弹层、后台或账号安全状态变化立即失效，旧响应不恢复弹窗。导航同时核对即时路径深度与转场状态，防止初始读取在进入设置时过早消耗询问记录。此轮不改变后端分类或发送开关。[逐状态验收](feature-acceptance-matrix.md#f02d-登录后的主动授权询问2026-11-19)

状态：已实现，完成本轮直板机与隔离真实 HTTPS 验收。构建通过，完整测试 290/290（新增 23）、失败/忽略 0；lint 0 错误/0 警告、1 条既有建议。中间包 7 组检查与修复导航缺口后的最终包 3 组复验分别保留；最终包验签、安装及 131 个 ETS 同源通过，见[实现与验收记录](push-onboarding-2026-11-19.md)及[设备证据](../artifacts/validation/push-onboarding-20261119/device-ui-https.json)。本次已有系统通知许可，没有重验全新系统拒绝；原安装级系统许可逻辑未改，实际 Huawei 投递仍为独立验收。公告暂缓，新邀请包尚未修改或提交。

## ADR-039：系统推送展示来源标题

2026-11-20。用户授权系统推送展示现有来信标题和新场次标题，正文保留通用订阅提示。发送端在领取任务的同一事务中核对现有账号、设备、订阅、分配及通知有效性，再从有效来源读取标题；标题仅放入本次内存载荷，不新增持久化字段。空或异常标题回退品牌名，控制与方向字符清除、空白合并，最多60个 Unicode 码点。

来信全文、题面答案和奖励信息不加入载荷。标题将经过华为推送服务并可能显示于锁屏，此显示范围已由用户确认。点击仍按原有业务路由回源核对身份和目标，载荷不是业务事实。现有客户端、通知权限和账号订阅交互保持；不需要新原生包。实现与生产投递分别记录于[标题验收](push-titles-2026-11-20.md)。

## ADR-040：极光玻璃 v2 原生迁移基线

2026-11-25。采用 Web `feat/ui-glass-v2` 提交 `46188fc585026066bd1e92d52ce162c3bb827cde` 的视觉、布局和状态规则。新版从本次迁移起取代旧深绿／古金、头像侧栏抽屉、答题顶栏仅回页顶恢复、旧题卡与作答栏一体及魔法阵加载规则。旧记录继续说明相应历史包和设备实测。原生映射见[设计规范](design-system-aurora-glass-v2.md)。

保持单 `entry`、ArkTS 状态管理 V2、官方 Navigation 与真实安全区。L0 管理底景和系统避让，L1 使用轻量主题表面，L2 复用官方薄封装和系统材质。已批准的 native 通知权限、订阅、密码保险箱、头像裁剪、配乐后台能力、媒体会话、账号隔离和隔离预览纳入回归。判题、经验、通知与奖励仍按权威快照显示。

2026-11-26 补充。答错浮层属于当前题目的短时演出，显示和关闭由答题页管理。服务端结算及题目限制由 ViewModel 持有，独立于浮层生命周期。系统触感只消费本次有效判题回执，采用平台使用场景和预设，权限或硬件不可用时视觉反馈照常显示。通用交互圆角共用同一组语义数值。

答题振动是本机设置，通过系统授权的 `ohos.permission.VIBRATE` 使用游戏触感场景。设置关停后不发起振动，系统触感反馈关闭时由系统抑制。作答栏动效只作用于切题的内容，原生材质、题目所有权和输入组件生命周期继续由现有宿主管理。

用户确认护照设置卡在「外观」下方提供整行「设置」，护照底部保留隐私政策。原生版本信息在设置页底部展示安装包的版本名和版本代码，取消五连击版本弹窗。答对星芒显示期间沿用现有 `autoNext`，允许已配置的自动推进；题目、账号或页面所有权变化即停止旧演出。手动下一题仍由现有导航意图处理。

用户确认鸿蒙登录首屏贴近底部安全区，普通直板机收起键盘后完整显示账号、密码、登录按钮和帮助入口。帮助说明由官方半模态底部 Sheet 承接。保留表单操作高度和系统 RESIZE，短视口、键盘及行内错误沿用原生滚动。Web 手机对照应先设置目标视口再访问页面；桌面切回手机单独核对。

用户确认启程进行中场次卡的扫光改为主题色呼吸光。深浅主题分别读取现有冰蓝资源，描边和固定位置的光晕以透明度变化表达进行中。关闭非必要动效时使用静态描边。

本版本同时处理架构审查事项。权限等待与 Push token 更新按同一同步所有者管理，专用 Push 视图归所属功能；Repository 运行模式由组装工厂决定。答题与信函沿独立生命周期拆分。同一媒体查看器共享关闭语义和全屏底色，官方弹层共用一致的转场参数。原有账号代次、表单草稿与媒体挂载层级约束随各实现迁移。

护照复用同一账号的场次与收藏读取。收藏详情只在收藏页可打开，护照读取只更新摘要，未知与有效零值分开。三个原生分段复用胶囊外观，页签选择仍由各功能管理。来信媒体在打开及继续呈现时匹配最新正文与会话。剧情纯分页留在 UI 层，保留原有测量、字型、翻页和音频所有权，换页时保留显式空段。

用户确认统一弹窗和抽屉背后的蒙层。根页面使用 ArkUI `backdropBlur` 和深浅主题透明色绘制共享蒙层，延伸到状态栏、手势区与刘海避让区，保持底层页面可辨。来信和答题断线恢复由同窗口官方 `PromptAction` 呈现，答题提示与护照资料、密码、外观使用官方 `bindSheet`，各弹层持有独立的蒙层生命周期。阅信、返回和编辑仍由所属功能管理。系统关闭材质时由共享蒙层提供半透明背景，仅使用原生遮罩的弹层仍经 `maskColor` 使用同一半透明色。答题滚动自身采用原生无裁断的顶侧视口，页首内容间距、安全区与胶囊显隐由现有答题布局管理。媒体及剧情全屏内容使用既有阅读底景。

2026-11-26 用户要求进一步使用原生光感宿主。启程身份和答题胶囊使用官方 `Navigation`／`NavDestination` 自定义标题，路由层负责宿主，功能页继续负责局部的显示和返回意图。标题采用透明 `STACK` 保持页面延伸，`THICK` 材质限定在实际胶囊内，关闭会越过胶囊并在标题宿主边沿被切断的阴影。选择浮层沿用其原生锚定和状态所有权，使用与旧侧栏同档的 `THICK` 材质。独立 TabBar 试验验证了触控和系统折射，正式答题的切题、浮层和无障碍语义仍按真实作答容器处理。

用户随后批准接入单内容页 `HdsTabs`。仅作答栏使用官方浮动样式，题目横滑仍由现有 Swiper 处理。输入组件通过编辑事件切换底板材质，保留同一题目的输入实例。数据、草稿、弹层归属与切题权限继续由答题页和 ViewModel 负责。无沉浸能力时使用原作答栏布局。

2026-11-27 用户确认输入／折叠选项与主操作分开，并接入智感握姿。作答宿主管理两枚胶囊的位置、同一高度及避让。官方握持手事件由平台层转换为左右布局，状态只服务当前可见答题栏。输入和原生选项锚点留在同一实例，答题页继续持有切题和提交意图。

按逐状态验收表的切片顺序推进。原生布局或行为存在实质分歧时记录确切差距并向用户确认。各片分别记录编译、签名、lint、业务测试、直板机安装、隔离 HTTPS 交互和原图对照。此条记录迁移决策。

## ADR-041：主界面聚合读取与未读状态

2026-11-26 用户确认在启程、收藏和来信的底栏与列表展示未读，并在各页标题旁清空当前未读。主界面通过账号授权的 `GET /api/questions/v1/home` 读取场次、收藏和来信快照。每次聚合同步替代这三份列表的独立轮询，账号状态继续通过 `/me` 验证，场次详情、答题内来信与用户主动刷新仍遵循各页面的生命周期。旧服务明确返回路由不存在时继续使用已有接口。

成功打开场次详情后，将交付 ID 记录到当前环境和账号的本机已看列表。收藏按当前待领取的发放 ID 清除本机提醒，服务器继续掌管场次进度和领取状态。清空仅确认点击时的已知 ID。来信用 `POST /api/questions/v1/notifications/read-all` 在同一事务保存已知 ID 的已读回执，每批最多 200 封。单封入口沿用现有接口，较早的聚合响应按读取代次弃用。未授权、撤回、过期或随后收到的来信保持各自服务端状态。

## ADR-042：指定场次的进度订阅

2026-11-26。运营后台允许为一个游戏账号授予另一玩家的具体场次进度，包含到期、撤权和审计。ArkUI 复用普通账号会话，设置页只根据有效授权显示入口，详情与 Push 点击统一回源。授权与订阅版本由服务端持有，手机负责主动开启订阅、选择事件和独立确认系统通知。来信与提示仍由运营后台发送。

判题事务将符合订阅条件的真实提交交付给既有 Push 投递流程，末题在两项均开启时只生成通关提醒。详情在同一读取快照校验授权、读取进度和判题记录。按用户补充要求，通知标题显示玩家展示名，正文显示场次与简短结果。仅对获授权场次的答错详情返回玩家实际提交的内容。独立场景审批控制进度 Push，复用正式应用身份、设备绑定、投递租约与凭据。写入提交后由 PocketBase 的独立定时任务拾取，失败可经持久队列重试；通知开关、授权、版本、场次、账号和设备在发送前再次核验。旧服务的 404 在手机设置中按能力不可用处理。

## 验证记录边界

上述本机声明于 2026-10-27 只读核验，SDK 元数据 `apiVersion=26`、`version=26.0.0.105`、`releaseType=Release`。本文件不是构建或真机测试报告；实际执行结果必须记录在构建验收文档及对照表，失败和未执行项保留原状。
