# 任务1：手机导航、侧栏与账户资料验收

实施前基线日期：2026-10-28；执行结果更新：2026-10-30，Asia/Shanghai。用户已授权执行“补齐手机导航、侧栏和账户资料功能”，并要求按小功能迁移、验证直板机和真实链路后再继续。折叠、悬停、分栏专项在主体迁移后安排，不作为本轮前置门禁。

本轮进入实现前，以下项目均为**未执行**。首切片的37项业务、22项系统UI、42项字号及49项历史HTTPS检查不计本轮通过；旧HAP、runtime、截图、报告保持原归属。

## 范围与真实契约

- 手机主导航、账户侧栏和护照资料入口；首页与详情返回关系、主题、退出和门禁继续有效。奖品/来信业务属于后续任务，入口须明确未开放，不能显示空页面冒充已迁移。
- 昵称编辑：`PATCH /api/questions/v1/me/profile`，纯文本使用JSON `{displayName}`；昵称按Web先trim、不得为空、最多40字符。返回是直接的 `GamePlayer`，不是 `{player}`。
- 头像：同一PATCH使用multipart，文本字段 `displayName`、单个文件字段 `avatar`。服务端允许普通字段只有 `displayName` / `removeAvatar`，头像文件由上传表单读取；不能提交account、XP、等级等字段。
- Web原始选图允许JPEG/PNG/WebP、最多50MiB；裁剪确认后的输出为JPEG、方图边长最多512、目标最多200KiB。服务端头像字段硬限2MiB且受保护。不能将2MiB上传限制误作原图选取限制。
- 受保护头像先认证 `POST /api/files/token`，再访问当前玩家文件路径；文件token、受保护URL和图像不跨账号复用，不写公开报告。页面不拼后端URL。
- 后续改密使用已有 `POST /api/questions/v1/me/change-password`：旧/新/确认三个字段；成功轮换token、更新玩家、清空密码。请求只发一次，结果丢失时不自动重试。

权威输入为冻结后端 `contracts/game.ts`、`pb_hooks/lib/api.js:profile/changePassword`、`pb_migrations/1787788800_game_schema.js`；Web输入为 `game.client.ts`、`useProfileEditor.ts`、`usePasswordEditor.ts`、`game-profile-validation.ts`、`avatar-image.ts`、`GameProfilePage.tsx`、`GameSidebar.tsx`。Web和后端仅只读。

## 实现前逐点表

| 编号 | 小功能与逐状态 | 必须取得的实际证据 | 当前状态 |
| --- | --- | --- | --- |
| N1 | 首页/护照主导航和账户菜单 | 原生菜单各入口、当前选中态、关闭/Back、返回原场次关系；奖品/来信明确未开放且不进空页 | 未执行 |
| N2 | 资料页加载及身份呈现 | 真实player的昵称、账号、等级/经验；缺头像为首字回退，文件失败不冒作成功头像 | 未执行 |
| P1 | 昵称草稿和校验 | 空白不发PATCH、最多40字符；刷新玩家不会覆盖用户正在编辑的草稿；输入/按钮在直板机键盘下可达 | 未执行 |
| P2 | 昵称真实保存 | 本次JSON PATCH200及DTO校验；资料、顶栏/菜单即时回显；重新读取/me一致，账号只读 | 未执行 |
| P3 | 资料失败/重试/并发 | 单次注入503或畸形DTO显示持久错误并保留草稿；显式重试的新PATCH200；双击不产生并发重复写入 | 未执行 |
| A1 | 系统选图、取消和无效输入 | 官方Picker单选；取消不改草稿、不发PATCH；类型和50MiB原图校验，失败有明确提示 | 未执行 |
| A2 | 裁剪预览、调整和取消 | 用户可调整方形裁剪区域并确认；取消/重选不提交，退出释放解码资源；以实际结果核图像方向、方形边长和字节数 | 未执行 |
| A3 | 头像真实上传与显示 | 本次multipart PATCH200，明确包含avatar part；服务端返回非空文件名，随后真实file-token与文件GET成功；头像在资料和菜单/顶栏回显 | 未执行 |
| A4 | 文件token/失败/账号隔离 | token失效后限次重取；文件失败可恢复；登出/切换后旧图或迟到文件响应不得出现，公开证据不含URL/token/个人图片 | 未执行 |
| S1 | 后续改密校验与真实成功 | 无效输入不POST，错误旧密一次POST；成功一次POST200后token轮换、三个输入清空，留在可用资料页面，新密重新登录确认 | 未执行 |
| S2 | 改密结果不确定与退出 | 明确故障注入丢响应后不重放；持久说明可退出再登录确认，退出清空草稿、图像、路由及密码 | 未执行 |
| R1 | 原有手机主链路回归 | 登录/强改密门禁、首页分类/刷新、只读详情及系统返回/主题/退出正常 | 未执行 |

“真实保存通过”必须同时有本次实际请求台账和UI/回源结果；旧数据仍可见、Host协议探测或编译成功均不能代替。图像测试只能使用专用非私人测试图；系统Picker无法自动选择时如实记录人工步骤，不能用直接注入上传字节冒充Picker验收。

## 隔离环境与证据路径

使用新建的一次性真实PocketBase和随机测试玩家，严格HTTPS配置及临时CA由root统一创建；不能复用已经清理的上一轮账号或证书。`scripts/isolated-backend.mjs` 玩家白名单只增加精确 `PATCH /api/questions/v1/me/profile`，已有file-token和受保护文件GET继续透传。控制端仍仅本机、独立凭据，不开放admin或入场/答题。

资料PATCH台账只记录bodyKind、avatarPartPresent、总请求字节数；文件GET只记录是否带token，不保留token值、query、边界、文件名、请求体或图像。503、畸形DTO、延迟和丢响应单列故障注入，不改写正常成功响应。

本轮报告集中在 `artifacts/validation/profile/`，实际原生及Web截图、原始日志、会话与非私人测试图准备记录使用gitignore的 `artifacts/private/`，公开报告仅保存不含凭据的状态、摘要和来源。实际命令、HAP摘要、用例数、失败数和清理结果须在执行后回填。不得覆写首切片已冻结manifest/runtime/图像并冒换来源。

### 测试后端启动等待适配

前两次隔离环境启动未取得可用后端：第一次Docker容器创建返回API500；第二次版本探针通过但原测试harness约20秒的就绪等待超时、无服务日志，且均未创建本轮state。两次私有失败日志保留，不记通过。只读核对Client/Server均29.2.0/API1.53、服务端最低1.44，不能把首个错误提示等同API不兼容。确认引擎无容器及其他客户端任务后，经root追加授权用官方Docker Desktop命令重启；随后自有、无业务hook/seed的临时HTTP容器健康检查200，总启动19.24秒，已停止并删除，其他资源未改。原故障唯一根因仍未确认。

本仓库 `scripts/prepare-isolation-harness.mjs` 读取冻结的后端 `tests/server.mjs`，仅对三处各自恰好出现一次的锚点作本地测试适配：runtime静态导入改为原后端绝对file URL；启动循环改为120秒显式deadline；每次健康探测使用1500ms AbortSignal超时。任一锚点数量不符即失败关闭，原文件、业务hooks、migrations、seed、契约及50ms轮询间隔不变。原文和适配版只写入private/harness，重读核字节及原source未改，runner默认导入此适配版。`artifacts/validation/profile/environment-harness.json` 记录source/adapter SHA和改动范围；顶层prepared_not_executed属于准备阶段，2026-10-29新增execution记录本轮专用后端已启动、玩家代理健康检查HTTP200。准备和后端启动均不代替原生HTTPS或功能UI验收。

## 当前执行结果（2026-10-30）

上方逐点表保留进入实现前的基线。当前已加入手机账户菜单、护照资料、昵称草稿/保存、系统选图/裁剪及后续改密代码。对照Web后新增共享 `StarwardPassport`，恢复护照标题、等级名与Lv序号、XP/RANK、进度及下一等级名；菜单保留相应紧凑经验信息。`Player.extraDisplay`按Web可选扩展兼容规则解码并在护照进度后展示，不解释服务端规则或HTML。非空扩展文案已分别取得正式管理API派发/严格HTTPS /me的Host证据及base30de手机截图精确label/text目视证据；只覆盖这一条实际扩展，不扩写全部长字段或畸形状态。

以下只按已经取得的报告回填，尚未通过直板机和真实链路的功能继续保持未验收。**历史定位与当前边界：** base30de头像恢复自动化请求点击 `avatar-retry`后页面回启程且无新文件GET，旧日志只证明index0路由发生，未记录原始点击点，尚不能确定是内容触摸被误判。新1a40独立几何测量已确认其首次probe的计划点位于真实NativeTabBar内：驱动遗漏avatar-retry浮栏避让。旧30de那次未存点击坐标，唯一根因仍不确定，不能倒推相同归因。驱动已按profile-scroll实际祖先统一避让bar；1a40同HAP的9项专项已实际通过重试GET200并保持护照，且新完整core34/S2-13已实际同版通过；同版supplement22、基础头像28及JPEG EXIF6/WebP各8项也已通过。同版Web8、Native12及crop4已捕获并完成Root逐图对照，保留NAV-ICON/NAV-IME/NAV-LIGHT三项待新refinement；输入拒绝两轮已同版通过，迟到专项也已在独立15秒变体通过；后者不计2秒base同版通过。当前6a UI整轮与最终清理仍待完成，不扩写任务或全游戏通过。core34、S2-13和supplement22只保留各自覆盖，候选新HAP不得继承旧计数为同版通过。

新完整run开始前，`profile/attempts/evidence-archive-20261029T051741266386Z.json`冻结65份文件/报告/私有图片副本，记录每个original→archive及SHA（manifest SHA `2351fbba22a42ebec842cf59fdc5530d74aa10456799c4f8cba2a7bfe7ba09d9`）。下表base30de的旧报告和图片均按该映射读取原字节，不因新run覆盖同名输出而换来源；旧base来源另存 `profile/attempts/base30de-base-hap.json`。当前 `profile/base-hap.json`为1a40候选，冻结私有signed HAP及34份源码精确副本（manifest SHA `7e42dea6d38dd7a9069a721147cb44b1f6f18cc1354aebfc71d3ad462e583c53`），不再将其指作旧30de来源。首切片历史未改。

| 环节 | 结果 |
| --- | --- |
| 契约与现有Web行为只读核查 | 已完成；本节仅为实现输入，不算功能通过 |
| ArkTS/Hvigor构建 | 已实际BUILD SUCCESSFUL；私有原始日志 `artifacts/private/profile-validation/build-01.log` |
| 业务测试 | 首轮60/60；护照及可选扩展补全后65/65；最新实际72/72通过、失败0、忽略0，见 `artifacts/validation/profile/local-test-summary.json`。这些业务回归不代替系统Picker、真实网络或底栏交互验收 |
| codelinter | base30de曾有issues=1、errors=0、warnings=1、filesChecked=1，来源是Touch→beginInput→hilog.info高频调试日志，保留为当时真实结果。后续1a40候选源码去除高频debug后，当前 `artifacts/validation/profile/lint.json` 实际issues/errors/warnings/suggestions均0、filesChecked=0；不把0扫描文件写成非零覆盖，不以lint代替交互 |
| mock签名与安装启动 | `scripts/hm.sh run`已实际完成；日志 `artifacts/private/profile-validation/mock-install.log`，安装HAP SHA-256为 `b51702dcaf1a2bb7e5cb393d31ddb23a728e1c11a8ef33e72bcd9bf200221a88`。这是演示环境，不是隔离HTTPS构建 |
| mock原生运行时 | `artifacts/validation/profile/mock-runtime.json`为passed，4项实际窗口、沉浸、透明系统栏及字号检查通过，绑定上述b517构建；不等于资料交互通过 |
| mock资料UI冒烟 | `artifacts/validation/profile/mock-profile-smoke.json`为incomplete，count=0，因官方 `devecocli ui layout` 超时而未完成；不计任何资料UI通过 |
| 隔离环境恢复 | 电脑重启后已重新创建本轮专用后端，玩家代理健康检查HTTP200；`artifacts/validation/profile/isolated-tls.json`为Host严格TLS三项passed，未关闭证书校验、未修改系统信任库 |
| 首轮HTTPS签名安装与运行时 | 官方 `scripts/hm.sh run`成功，日志 `artifacts/private/profile-validation/https-install-reboot-01.log`。HAP `090f75d0ba7fac9e80d0c6ad14d8242c08672070342ebe7f988d6ff117eac889` 对应 `profile/runtime.json`，6项实际窗口、沉浸、透明栏、字号、原生TLS及深浅系统栏内容检查passed |
| 首轮资料核心UI | `profile/attempts/core-20261029T024445671736Z.json`为incomplete/count8，停在“点击未开放底栏应保留护照”检查；独立复现确认实际回到首页，是功能缺陷。该轮faultNeutralised=true、loggedOut=false，不能记整轮功能或清理通过 |
| 导航与密码输入调整 | 底栏增加本地 `activeIndex!!`与父级导航同步；资料Tabs改用 `section!!`并由section Monitor在离开安全页时清密码。官方[Tabs文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-container-tabs)说明属性变化可能使index回到初值，建议使用双向绑定；该建议不证明本次底栏问题已解决 |
| 中间HTTPS构建与未完成尝试 | HAP `2da7204e26afcf0b5e8e34ffb8cf96b97f123fa1671e6403781b500981a8021b` 已官方安装且 `profile/runtime-02.json`6项passed。随后两次core由测试操作者主动中断，保留incomplete来源，不作为独立产品故障或重复失败计数。护照增高后的离屏输入须由驱动先seek，不放宽可见性/几何断言 |
| 上一轮完整core来源 | HAP `2a52d1e34dbcb9fbe367d45fa98fdd666feefe72e370997feb5f334a0f35a0b8` 已官方安装，日志 `artifacts/private/profile-validation/https-install-04.log`；`profile/runtime-04.json`6项passed，但归档 `profile/attempts/core-20261029T030910257663Z.json`为incomplete/count8，停在未开放底栏应保留护照的检查。本次faultNeutralised=true、loggedOut=true；清理完成不改变该轮功能未通过 |
| 底栏真实故障与定位 | 原生最小事件日志观察到点击收藏先产生click0/will3→0，再产生click1/will0→1且第二次被拦截；坐标点击也复现，用户手动确认“会跳回启程”。迟到0回调的唯一根因仍未确认，不以旧onChange猜测或单次命中阻断解释全部情况，也不推广为所有API26设备的共同问题 |
| 底栏兼容策略与最小复验 | 按[ADR-017](architecture-decisions.md#adr-017官方浮动tabs输入事务与业务路由隔离)，Touch观察器挂整个Tabs，内容触摸也开启事务，只有官方页签will/click产生pending并排队提交最终原生索引；Cancel/外部路由/销毁清pending，根gate/返回栈再次门控。保留官方命中、材质和动画，不按坐标自制手势。HAP `0f799c580cb3b0f533a1146c711b6977c0975c7cb4d725d518ee3aa518a0e4e2`的 `profile/navigation-input-probe.json`实际7步passed，仅覆盖该组手机触摸导航，不证明所有输入路径或N1整项。没有Touch的外设键盘/辅助功能页签激活当前会被拒绝，非触摸导航尚未接入/实测，留后续专项 |
| 已知非触摸页签缺口 | 当前守卫明确拒绝没有Touch事务的外设键盘/读屏页签激活，属于已知不支持，不只是未验证。账户菜单Button提供替代导航入口，不证明底栏辅助功能已可用或正式可访问性完成。该缺口单列，不属于折叠专项、不阻塞本轮Touch业务链路；未来非触摸路径须实现并单独实测，当前不标通过 |
| base30de HTTPS构建、签名、安装与运行时 | `scripts/hm.sh run`已实际成功，私有日志 `artifacts/private/profile-validation/https-profile-echo-install.log`。当时安装HAP为 `30de19566545126979d3cfa2a779f2a258d17ace101bfa9be5e5f7296af58683`，`profile/runtime-08.json`实际6项passed；包含真实窗口、沉浸透明系统栏、fontScale=1、独立TLS三项和深浅栏内容。`profile/attempts/base30de-base-hap.json`另冻结旧HAP/ABC与34个ArkTS来源SHA，仅为来源证据，不算功能通过 |
| IME与系统Back修复 | `profile/ime-back-probe.json`在旧HAP `03e562ab41402ef1e8cccc986ed43f12d58aedc9e7efd30cae07ece2af819f23`上4项passed：草稿保留，第一次Back只关实际显示的IME，下一次Back回首页，显式退出清空登录字段。页面依据实际键盘避让区高度判断，不以visible=true但高度0当仍有IME；封装先清焦点再调用公开IMEKit hideTextInput。该探针不归入当前30de的同版计数 |
| 昵称成功提示专项复验 | 原生程序回填产生相同值onChange曾清掉保存提示；当前输入封装与ViewModel对相同值回声不作用户编辑。`profile/profile-save-probe.json`绑定base30de HAP，4项passed：真实JSON保存、服务端trim并显示保存成功、重新读取/me一致、无真实编辑时重新聚焦仍保留提示且不多发写请求；最终退出字段清空。只证明该组专项，不扩写整轮任务通过 |
| base30de完整core（档案） | `profile/device-profile-acceptance.json`绑定base30de及runtime-08，2026-10-29T04:22:40Z实际passed/count34，原字节SHA-256为 `9a6b2059c62e5231947d5137c4b6dd1b28ad58768a0c956c7397c93c75dc6e4b`。本次为fresh_disposable_player_reset完整新run，确实执行首次强改密，不继承旧run或resume检查。实际覆盖菜单/底栏未开放目的地保持护照、Sheet Back、资料只读账号、P1实际IME下昵称及完整52vp保存动作可达/空白不PATCH/前台/me保留草稿、P2 JSON200/服务端规范化与回源、P3注入延迟双击仅一次写/503保留草稿/显式新PATCH200、S1不一致无POST/错误旧密400/成功一次200/清三密码/新密Host与手机重登入、场次→资料返回原场次、详情Back首页及Authorization原token无Bearer。faultNeutralised与loggedOut均true，仅证明本次core收尾；整个环境与测试媒体清理仍另验 |
| 当前执行与脚本修正边界 | 护照增高后驱动先seek可见目标，菜单关闭等待恢复页面；hide_keyboard只发一次Back并等待IME消失，避免把未完成关闭误作返回。当前重试前一次识别守卫遗漏“仅密码框可见”的登录状态，未发送认证请求，已补password等真实页面锚点；该次incomplete保留，不当成产品登录失败。脚本修正不代替真实功能复跑 |
| base30de S2改密结果不确定与恢复 | `profile/device-profile-password-uncertain.json`于2026-10-29T04:38:55Z实际passed/count13，原字节SHA-256 `a578628c26ec6ced5d7dee3388993463f8210930855ee144d9e8aa835c5c9395`，绑定base30de/runtime-08及core SHA `9a6b2059…`。本次是新的完整initial→new显式实验，不继承旧checks；上游实际一次POST200后故意丢响应，UI持续显示未知结果、密码/昵称/头像写动作禁用（官方原始UiTest enabled字符串核实），点击禁用保存不重放，切页/前后台不清解释或重发。显式退出清字段，新的Host和手机认证确认目标密码已生效、资料恢复可编辑，最终Back及Ability重启仍停空登录；本次faultNeutralised/loggedOut均true，不替代整个环境清理 |
| S2未完成尝试归档 | `profile/attempts/password-uncertain-20261029T042850894702Z-b185543df46c.json`为incomplete3：驱动按boolean读CLI已省略的enabled，而原始UiTest属性实际为字符串；`password-uncertain-20261029T043358400931Z-ea44df8e0636.json`为反向实验incomplete7：退出按钮离屏，驱动未seek。二者不写产品功能失败或通过，旧检查不继承。每轮是独立明确的新实验命令，不把多次实验改密解释为自动重试，也不重放前一次丢响应请求 |
| base30de supplement补充检查 | `profile/supplement/device-profile-supplement.json`于2026-10-29T04:48:24Z实际passed/count22，原字节SHA-256 `5a65db540e7245bd634fffcb908403465e1c347e639b7625b39dbe0108d9ca9d`，明确依赖同30de的runtime-08、core34及S2-13报告SHA。实际核实护照/菜单的权威昵称、等级、EXP/RANK/下一等级信息；原生输入41个ASCII仅保留前40且不PATCH；未保存草稿离页不写且服务端名未变；离开安全子页及整个护照均清三密码且不POST；当前/历史切换；一次官方Refresh恰好一个新非注入GET200；深浅主题动作后资料值、护照事实和完整保存动作可达，最后恢复followSystem。loggedOut/themeRestoredToSystem/noProfileOrPasswordWrites均true。主题与菜单的辅助功能选中属性在该CLI树中not_observable，不凭颜色推断；该报告不包含原生图片目视对照 |
| 非空extraDisplay真实Host准备 | `profile/profile-extra-seed.json`实际passed，checks数组9项、无count字段，原字节SHA-256 `913a0317e53be1175a6ae61a8038d62afc769ada310afbe1e1dc58276a95d8ba`。先核唯一自有一次性container及loopback runtime，再在其中创建临时superuser/game_admins，通过正式definition→preview唯一自有玩家→dispatch→inspect链路配置扩展；新的玩家严格HTTPS /me返回exact tuple，身份、密码门禁、头像、等级及经验事实均未改。临时凭据仅stdin/内存，不落盘。此9项是Host准备和正式契约链路证据，非手机UI通过；手机实际非空展示另有下行单独目视报告 |
| 迟到响应gate工具Host验证 | `profile/response-gate-host.json`为Host合成passed/count29，原字节SHA-256 `965bfa5d68d3bee2c1c250fd1199817ed4f0f908ec7d282c7615625586d9d2e6`，固定Studio Node v24.14.1并记录工具源SHA。只验证代理的严格绑定、单次hold/release、原字节/header不变、abort/expiry及敏感信息排除等工具行为；不计业务或手机通过。该29项仍是工具来源，后续真实TLS激活与迟到专项另见下行独立变体报告，不改写本行Host范围 |
| 头像基础链路局部事实 | `profile/device-profile-avatar.json`绑定base30de/runtime-08，2026-10-29T05:02:18Z为incomplete/count20，原字节SHA-256 `0f42a91a77475a2f8b2d9dadd8bffacf485b13b7c3ee71a933fa2fdaf29d8e28`。实际已验官方Picker选自有图、取消裁剪/系统重选及二次裁剪保留先前pending且不PATCH；真实multipart503保留草稿后显式PATCH200、重新file-token/文件GET200；实际输出512px方形JPEG≤200KiB、无EXIF，四象限及全图MAE符合独立中心裁剪而非整图拉伸。file403实际恰两次token及403→200、主账号不注销；file503显示持久头像错误。以上局部检查不算头像整项通过 |
| 头像恢复未完成与根因置信度 | base30de在file503后自动化请求点击 `avatar-retry`，UI回启程且无新头像GET，报告error为New avatar request did not complete。旧 `avatar-retry-navigation.log`只记录index0路由、缺原始点击位置，不能据此确认“内容Touch接受phantom0”，也不能用后续新HAP几何倒推它的唯一根因。新1a40首次probe的浮栏遮挡已由下面独立实测确认，不算barModifier失败或产品导航故障 |
| 1a40实际点击几何与驱动修正 | `profile/avatar-retry-hit-geometry.json`为passed/count1，但scope明确仅测量、未发retryclick，报告SHA `c0087e631bb9366f8d950237407bdbe3f63a8cad87d6407d2764c167c997d74b`，绑定1a40/runtime-09。实际retry rect=[67,2580,391,2729]px，旧驱动计划中心=[229,2654]px，官方NativeTabBar rect=[106,2531,1214,2721]px，旧viewport=[0,415,1320,2848]px，plannedClickInsideNativeBar=true。该次cleanup两true，直接确认新probe自动化计划点击被真实浮栏遮挡。`ProfileUI.viewport`已按实际path祖先含profile-scroll统一避让bar，覆盖avatar-retry；独立crop/menu无该祖先，保持自身viewport，不按avatar前缀误裁。产品HAP仍1a40，修驱动后实际专项9项已通过，范围如下，不据此把旧头像未完成报告改成通过 |
| 新1a40候选构建与验收边界 | 官方barModifier仅观察bar Touch、父索引对齐及Crop品牌token修正已形成候选HAP `1a40c0caffc46d64e0b81e9ccb92f2c7d6b69830bb73bf1f2ed5f02651a761cb`，已实际构建、签名和安装；最新业务测试72/72、0失败/忽略，当前lint零问题/filesChecked=0，`profile/runtime-09.json`6项passed（报告SHA `5779a9f5b375deafd4792a0059f3fc5d19b2bd3f61cb48f40f417b1ebfd1931a`）。该候选首次重试probe回首页的计划点击遮挡现由独立几何确认，不能据此宣称barModifier失败；修驱动后同HAP专项已9项passed，不能据此宣布完整头像、所有导航时序或任务通过。core34/S2-13/supplement22和原头像20项均属base30de，不迁移为候选同版通过；完整同版core34、S2-13、supplement22及Avatar基础28已有下行新证据；系统过滤仍not_observable；App输入拒绝与独立变体迟到专项已有下行新证据；同版视觉基线已完成并保留三项新包待验，详见下行独立报告 |
| 1a40原生bar/内容专项复验 | `profile/native-bar-content-probe.json`实际passed/count9，当前原字节SHA `9c3a314a548fa2620f8b41b6d95f8f2a44e596da767d88a416e3f694c3160f6d`，绑定1a40/runtime-09。修正viewport后内容avatar-retry触发新真实GET200且保持护照；四次收藏/来信保留护照；启程/护照可切换；内容滚动和昵称焦点位置不生成首页路由。loggedOut/faultNeutralised均true。旧S2仅用于取得当前专用密码key，Host重新核身份，不继承旧S2业务checks。此处仅当前手机Touch专项，不扩写外设键盘/读屏或完整头像通过。原9项功能执行后的报告字节 `d0444c26…`另存 `profile/attempts/native-bar-content-probe-09-before-provenance.json`；随后只补源SHA、命令和来自原filemtime的完成时间元数据，没有重新执行功能，也没有增加通过检查 |
| 1a40完整core新run | `profile/device-profile-acceptance.json`于2026-10-29T05:28:02Z实际passed/count34，原字节SHA `ef049839ce0c0def220e901ebcdb0fb07aba5d7f63ec2a3ac4d03fd7d61ca8d1`，同1a40/runtime-09。fresh_disposable_player_reset且forcedPasswordPerformedThisRun=true，完整新run实际发出首次强改密新命令，再验完整昵称/普通改密及菜单/返回/原主链路，checks不继承30de。faultNeutralised/loggedOut均true，仅本run收尾，不替代全部环境清理 |
| 1a40 S2新run | `profile/device-profile-password-uncertain.json`于2026-10-29T05:33:11Z实际passed/count13，原字节SHA `5dceb457c4e475f0c20075978d01f9dd29fcfa811ab3613a760b88320ac07407`，绑定同1a40/runtime-09及本次core SHA `ef049839…`。独立新initial→new实验，一次真实上游POST200后丢响应，未知状态/严格原始UiTest禁用/不重放/显式退出与新密Host及手机确认完整覆盖，未继承30de检查；finalPasswordKey=newPassword只是私有状态键名，不公开实际凭据。faultNeutralised/loggedOut均true |
| 1a40 supplement新run | `profile/supplement/device-profile-supplement.json`于2026-10-29T05:43:11Z实际passed/count22，原字节SHA `0376e3986d0e64f08c2d398a91cc05c7ba6f6e61bbce1e850a1f691ea547b880`，明确绑定同1a40/runtime-09及新core SHA ef049839…/S2 SHA5dceb457…。完整覆盖本报告原定护照事实、40字符/草稿、子页及整个护照清密码、分类/官方Refresh及主题控件可达子项，loggedOut/themeRestoredToSystem/noProfileOrPasswordWrites均true。core-09.log、s2-09.log、supplement-09.log分别成功0退出；全部新run检查不继承30de |
| 1a40 Avatar基础新attempt | `profile/device-profile-avatar.json`于2026-10-29T05:55:22Z实际passed/count28，原字节SHA `5f410842bbc7953e9ca3be9ca113c25f52becac726ed751f7499adebe349c18b`，同1a40/runtime-09，明确绑定新core ef049839…/S2 5dceb457…；旧30de incomplete20仍独立归档，不继承checks。真实Picker选择exact URI后完成、取消裁剪/系统重选/二次裁剪保留pending且无PATCH；multipart503保留草稿后显式200，随后新token/文件GET200。实际512×512 JPEG 29980bytes≤200KiB、无EXIF，中心裁剪MAE5.116179，对错误整图拉伸13.930321。403恰一次换token并200恢复、主账号不注销；503持久错误经显式新GET200恢复；普通退出/Back/重启无旧资料或图片 |
| 1a40实际解码故障与目视 | 上述28项独立包含实际HTTP200/image/jpeg返回有效JPEG头但损坏4字节的自有文件故障；原生显示持久解码错误，前台/me同步不自动重读，精确恢复原SHA后显式新GET200清错误。injectedStorageFault.restored=true、cleanupLoggedOut=true，恢复链无资料/改密写，不属生产故障。Root按新7图SHA回执（receipt SHA `8bd40b6bdf493c6f624145d33547a3042a636881535b7ea2d1d7203382d837a1`）核实头像在资料/菜单真实渲染、Slider裁剪改变与重选取消保留，不据pending外观声称内存字节身份；深浅品牌色专项另验 |
| JPEG EXIF6真实原生输入 | `profile/avatar-source-jpeg-exif6.json`于2026-10-29T05:58:30Z实际passed/count8，报告SHA `f1f19918535ed60b3098b7e7ccfd51c20b0fc2e2004188db50662abc4095f844`；同1a40/runtime-09并绑定新core/S2/基础Avatar SHA。实际系统Picker选1024×640、Orientation6 JPEG，裁剪确认仅草稿、一次显式原生multipart200及新token/GET200，Host只读回源。输出512方形JPEG 33069bytes≤200KiB，无EXIF，按顺时针90°规范化的中心裁剪MAE4.870021，对忽略EXIF的错误假设84.88443，象限C/A/D/B匹配；loggedOut/emptyLoginInputs均true |
| WebP RGB真实原生输入 | `profile/avatar-source-webp-rgb.json`于2026-10-29T06:02:50Z实际passed/count8，报告SHA `d0202724a15894dfede7c55a0881caaa589baa75b68fbbe7b9ca652c916d7942`；同版及上述新依赖。真实Picker选择无alpha的1024×640 RGB WebP，经原生裁剪/唯一multipart200/token/GET200，输出512方形JPEG 31401bytes≤200KiB，无EXIF，正确中心裁剪MAE5.083350，对错误整图拉伸23.316803，象限A/B/C/D匹配；loggedOut/emptyLoginInputs均true。不扩写alpha WebP、其他EXIF方向、云相册或所有格式边界 |
| Picker搜索观察完成，过滤仍未验收 | 第三轮已finish，`profile/device-picker-filter.json`为not_observable（2026-10-29T06:18:08Z），报告SHA `a4f70632f034ce5bd897ee36f54144d91136f14043e221e8e3307a49f71d3e64`；pickerCancelled/profileUnchanged/noNewProfilePatch/noNewPasswordWrite/loggedOut/emptyLoginInputs六项cleanup均true，不把收尾成功当过滤通过。Root实际原始树查验另记 `profile/picker-filter-root-observation.json`（SHA `3fec191153d9ddf88d154c7c90feaee1821244b71159f05ec706b7803c3f43d5`）：完整文件名已提交，精确自有52428801bytes即50MiB+1 PNG仍有1项可见且enabled，未选中。该观察不证明系统已过滤，也不证明选择/完成会被接受；后续已完成精确选择/官方完成后的App兜底拒绝，见下一行；系统过滤仍不标通过 |
| 1a40两类原图输入拒绝 | 同1a40/runtime-09的50MiB+1 PNG与GIF两轮已真实选定精确自有URI并点击官方完成，均落到原生错误Sheet：有效裁剪预览缺席、确认禁用、类型/大小文案精确对应；每轮7项cleanup true，未发资料PATCH或改密POST。`profile/avatar-input-oversize-png.json` SHA `5032ba4124f1f695209a29cce2088453bd23101681eb2f28a6a832499f8153aa`，`profile/avatar-input-unsupported-gif.json` SHA `95923a9e6a55a0be0ba3b58e8c283d828ef20a77cf415171abf3a579587577e4`，各有1个实际边界检查。Root分别亲看错误Sheet，独立review SHA为dd1ffe5f…/a166d70d…。通过的是App兜底拒绝与恢复，原Picker过滤not_observable不改。 |
| 头像原图目视与已知品牌差异 | Root已逐张查看7张私有原图，`artifacts/private/profile-device/root-avatar-visual-review.json`绑定每张SHA（回执SHA `428208f2a1b54937fa285cbf6c5eaa699178a6eb41e70955f0c70c5005e92501`）。实际资料和菜单显示四象限头像，Slider调整确实改变裁剪，取消重选保留裁剪，取消新裁剪仍可见先前pending与原昵称；不据外观声称pending字节身份。发现裁剪Button/Slider默认蓝色漏接品牌token，固定Web源码核实为真实差异，不归入批准的官方材质差异。新1a40已接入品牌token并去除高频debug日志；后续同版双主题crop4已由Root目视确认品牌控件，见下行当前视觉报告。此行旧7图及默认蓝缺口保持原归属 |
| 非空扩展手机目视 | `profile/extra-display-ui-review.json`实际passed，报告SHA-256 `956789298399b9792fe29efc93ae80949ede2c0a1008d9d09b6153b9a3e61821`，绑定base30de、正式seed报告SHA及实际profile截图SHA。Root目视确认本次正式配置label/text精确显示；不是向原生注入DTO，不扩写长字段/畸形扩展全部UI状态 |
| 迟到文件专项与版本边界 | 独立15秒变体HAP `d03bd895ed5ef220b48126186b3502925bb9ec94f72c4aa617174b11e93f42a4`已构建签名安装，`profile/runtime-late-15s.json`六项passed（SHA cb226514…）；`profile/device-profile-avatar-late.json`实际passed/count6，SHA `44f27226a1cb1804251b355b212148e410ee2dfe085ed772d312480855655ec9`。先在同变体完成正常原生头像GET200和实际退出校准，再hold精确SHA的真实文件200，观察空登录后release，下游finish且无client abort；响应结束、Back/Ability重启及冷启动仍为空登录，旧资料/头像/菜单缺席。gate中恰1次原生受保护文件GET、0次Host文件读取，5项cleanup全true。finish仅代表TLS下游写出，不是解码回调；不覆盖真实切到另一账号，也不将2秒base或后续UI包记为同版专项通过。 |
| 独立变体来源工具23项 | `profile/hap-timeout-variant-host.json`实际passed/23项，SHA `81c96c7b31787aac356714020376ec27b8a7199388744cf8e8c4834c552a329f`，仅为离线来源验证工具：34份源码、ABC和CA字节一致；除integration timeout由2000改15000外，仅symbolMap的1173条完整唯一记录重排，保留所有键和值，其余打包条目一致。严格校验及反例不忽略symbolMap、不重打包signed HAP，不计业务、签名有效性或UI通过。实际变体安装/runtime来源另见 `profile/late-variant-hap.json`（SHA b762fbe4…）。 |
| Web资料视觉输入 | 新 `profile/web-profile-visual.json`为passed（SHA `b51d6bf904dfb6dc60085b19143e1005f8815242f0fa759ca651460cf225e10b`），冻结Web4b7d的identity/security/menu/crop各深浅共8图已实际捕获；Root现已连同Native12和crop4共24张原图逐张核对，独立结论见visual-review，而非由捕获状态推断。消费新的只读玩家快照及真实已上传头像字节回放；browserUsesRealBackend=false，所有API由Playwright拦截、浏览器不做真实业务写。旧Web6参考保持原归属；Web捕获/目视不代替ArkUI或最终配对验收 |
| 深浅主题与必要布局对照 | 同1a40/runtime-09的 `profile/native-profile-visual.json`已passed，共12张identity/security/menu的深浅上下位置原图，报告SHA `4c639ff60ccaae87a1482327161838d0eed9bde8904bb68fd8198c127455d6aa`；全部actualThemeVerified=true，logout/空登录/hilog停止三项cleanup true。`profile/native-avatar-crop-visual.json`已complete，共4张深浅crop顶部/完整操作区原图，报告SHA `05ed5b63f2093ebb0d4d4e2f29e0d98361f32154cc24a579cb6b782d7437ecee`；每主题5项cleanup true、PATCH/改密写入增量均0。采集报告自身themeVerified=false/visualReview=pending保持不改，独立Root目视结论由下行review承接 |
| 当前base独立视觉复核 | `profile/visual-review.json`为reviewed，SHA `44fcc1457a8ae83df5fc9f7dd1c5aaa1a7a6f60df1d0ac5f24adc2866b049ca1`，绑定上述Web8/Native12/crop4来源SHA及1a40/runtime-09。Root亲看24张未编辑原图、8组配对，核品牌/文案、权威护照/扩展/头像、只读账号、底部完整保存动作及菜单；官方材质/原生控件、手机底部Sheet和三Slider裁剪布局列为批准差异。NAV-ICON（regular/fill图标）、NAV-IME（输入时浮栏收起）、NAV-LIGHT（官方交互流光及拖放选择实测）仍pending_new_refinement，不称零差异、完整动效或新refinement HAP通过 |
| 本轮视觉viewer | 已准备24张原PNG并启动本机回环 `http://127.0.0.1:5180/`，私有白名单manifest为 `artifacts/private/profile-comparison/review-20261030T023133491575Z/manifest.json`，SHA `3812ef0edf591f77b3070585bfc817babb03f42f9d9d761e03720ec9e130e179`；这只是当前base图像与来源的可审查入口，不代替业务或新包验收，旧5179保持首切片归属 |
| 2026-10-30网络恢复 | `profile/network-resume-20261030.json`记录实际手机登录“连接中断”时官方reverse列表为空；Root仅恢复自有18443到既有严格TLS监听映射，不改其它映射、账号或打包配置。报告SHA `d9bd1926fb8f4f87881205e97690c41da90e0101e7a6966189529256c997bb8c`，phoneHttpsRecheck=passed_actual_native_login_profile_and_crop并绑定新crop报告SHA。旧light中断stage及该次网络失败已归档，后续fresh light有独立新证据，不将失败记录改成通过 |
| 当前6a新UI包及USB边界 | 当前final-nav UI HAP为 `6a5232af434e2fed8d6d56b50e25f7bf86b7cf24de22bd6523bdc79f23d5ad90`，绑定final-nav manifest SHA `830e4aa03223c20714f9a9bcc65cb7aa7039301d81484ad15cc2cc90aa4707bd`；已真实编译签名安装及运行时检查，`profile/runtime-ui-final-nav.json`六项passed，SHA `66c45cbe66f9e525d9337e03c4c0925203ffbbca02b31b14e579eebdbd190a9d`。其图标、IME浮栏、官方流光和左右菜单完整验收仍pending。上一6a run incomplete10已独立归档且cleanup六项true，不是完整通过。新driver SHA `27ccd0f88953f12ee6a79faa5dd41ec5a3b652e845c798a61880b0e6a8ef0ce4`的最新run保留incomplete/count0：已完成Host只读身份及beforeCounts，首个官方aa命令返回失败，deviceStarted未置位，未取得UI动作或启动成功证据；Root另查HDC targets为Empty，已请用户重接USB。脚本未发业务写请求，但结束后的写入增量尚未核验，cleanup.noBusinessWrites仍false，不能记已验证零写或完整清理。该次恢复不改产品，USB恢复后先原有cleanup，再显式new-attempt。1a40的24图及193b旧包独立右面板观察均不升级为6a视觉/功能通过。 |
| 固定隔离预览 | `scripts/preview-environment.mjs`已独立静态复核，并实际执行prepare生成独立本机私有配置；当前manifest为initialized=false、initializationStatus=prepared。尚未start服务、完成真实初始化改密、配置预览新包或手机直接登录；固定账号可用性、持久保留及用户改密后的行为未验收，不记PVIEW通过。 |
| 本轮公开文件扫描 | `profile/public-artifact-scan-pre-ui-resume.json`本轮实际passed，973个公开候选文件、0发现、0读取错误，SHA `85f9d649242febf9c5b01a3bacd24b684a29e292ec4eb9c4803b07a5ed977744`；本次未提供known-device，不扩大为已覆盖特定设备标识的扫描，也不代替最终环境清理。 |
| 凭据、图像和环境清理 | 最终测试媒体、旧一次性DB/CA/凭据及官方映射清理尚未执行；单run cleanup不等于全环境清理。固定预览目录及持久数据与旧验收环境分开，不能用旧清理命令销毁预览 |

已执行命令为 `scripts/hm.sh build`、`STARWARD_VALIDATION_DIR=artifacts/validation/profile scripts/hm.sh test`、`STARWARD_VALIDATION_DIR=artifacts/validation/profile scripts/hm.sh lint` 及演示/隔离HTTPS各自配置下的 `scripts/hm.sh run`。本轮摘要保存在独立profile目录，首切片默认测试摘要、lint、HAP/runtime与截图来源不覆写。准备的core、S2、头像及补充验证脚本、截图数量均不折算业务完成率。

## 当前1a40复现命令与剩余验收

以下为本轮新链实际顺序执行的命令；依赖已建立的专用隔离后端、严格HTTPS配置和同版runtime-09。core为新的显式fresh reset实验，后续S2也是一次新的显式改密实验；不是自动重试旧写请求，且不能并行接管同一手机。

```sh
python3 scripts/device-profile-acceptance.py --runtime-report artifacts/validation/profile/runtime-09.json
python3 scripts/device-profile-password-uncertain.py --runtime-report artifacts/validation/profile/runtime-09.json
python3 scripts/device-profile-supplement.py --runtime-report artifacts/validation/profile/runtime-09.json
```

实际私有日志为 `artifacts/private/profile-validation/core-09.log`、`s2-09.log`及`supplement-09.log`，三者均0退出；最终通过数和来源SHA以上表为准，不仅看进程退出码。

新Avatar执行使用配套带Pillow的Python，并明确新attempt；以下为本次新attempt已实际使用的起始命令，后续阶段按真实Picker操作逐步完成；最终基础结果以上述28项报告为准，迟到专项不包含在内：

```sh
/Users/sitkin/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 scripts/device-profile-avatar.py begin --new-attempt --runtime-report artifacts/validation/profile/runtime-09.json --receipt artifacts/private/profile-device/avatar-import-receipt.json
```

任务1尚余当前6a UI包的NAV-ICON/NAV-IME/NAV-LIGHT及左右菜单逐状态真机验收、最终专用测试媒体与旧验收环境清理，以及固定预览首次启动/初始化和手机直接登录。输入边界两轮与独立15秒迟到6项已有上述实际结果；原Picker过滤观察仍not_observable，不改旧结果。6a最新尝试在aa失败后未取得UI启动成功证据，手机USB断开待重接；Host只读前置已执行，不能称无请求。当前1a40的Web8/Native12/crop4已捕获和独立reviewed，但不计6a视觉通过。固定预览仅prepare-only、尚未start。24张图和8组配对是证据范围，不折算业务完成度，也不宣布任务1或全游戏完成；主体入场/答题等仍未迁移。

主Avatar基础28、JPEG EXIF6的8项、WebP RGB的8项均已实际同版通过，后两份source报告按fixture manifest SHA `5bbab8a5e022fe2ee1d9ee323225f349675782010ab17655b9775eb66f4b9cd8`复现，使用 `device-profile-avatar-source.py begin/confirm --case jpeg-exif6|webp-rgb --manifest <private-manifest> --runtime-report artifacts/validation/profile/runtime-09.json`，begin与confirm之间必须实际完成官方Picker选择，不以Host上传替代。上述输入格式成功不替代Picker拒绝无效/过大来源的独立验收。

`capture-native-avatar-crop.py`已完成同版深浅两轮，只取消、不确认上传，每轮权威资料不变且无业务写；中断旧light阶段单独归档。`capture-native-profile.py --runtime-report artifacts/validation/profile/runtime-09.json`的新12图与Web8/crop4已由Root逐图复核。`serve-profile-visual-report.py`现通过私有白名单及Root SHA配对回执在本机5180展示本次24图；旧5179继续只表示首切片，不能混作本次或后续refinement证据。
