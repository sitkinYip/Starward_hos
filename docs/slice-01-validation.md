# 首个原生功能切片验收记录

日期：2026-10-27；2026-10-28追加系统区沉浸验证（Asia/Shanghai）。首切片为登录 → 首次强制改密 → 主页场次列表 → 开始前只读详情 → 返回/退出。构建、Local Test、设备UI、实际网络和视觉对照分别计证据，不互相替代。

## 当前结果与范围

ArkTS、Stage、ArkUI V2、Navigation、Repository及平台分层已落地。2026-10-28修复空详情进度及键盘避让后，最新源码 **37/37 Local Test通过，0失败、0忽略**、lint 0 issues；独立1.3字号构建已 **42/42通过**。正常字号HTTPS构建**22/22系统UI与6项运行时检查通过，认证4图及主视觉18图captured**，来源绑定同一HAP且清理完成。最终默认mock已签名安装，**13/13冒烟与4项运行时检查通过**；Web20/原生22图完成逐图对照，仍有菱形装饰位置和重试短文案两项非官方细节待调。旧mock13项、17项系统UI、修复前22项UI及22图均保留各自版本归属，不借旧计数推定新HAP通过。

本轮一次性真实PocketBase的严格USB HTTPS验收报告已 **passed，49项流程断言通过**：core28、resilience13、改密响应丢失4、配对数据准备1、显式退出3。覆盖真实认证/改密、深链恢复、七态/空态、边缘返回、503/终态/超时/后台同步恢复及退出清理。49项中配对数据准备由主机严格HTTPS读取，不能统称49例原生UI测试。该结果继续有效，但新容器的交互和视觉须重新取证，不能由原网络报告替代。详见 [HTTPS及视觉复核](slice-01-https-and-visual-validation.md)。

用户于2026-10-27更新原生体验策略，已记入 [ADR-013](architecture-decisions.md#adr-013官方-arkui-组件与沉浸光感优先)。保留品牌、文案、业务和既定信息布局；通用容器、材质、反馈和动效优先使用官方ArkUI并封装在 `ui/`。顶栏保留布局并使用真实官方沉浸材质，底栏采用官方浮动Tabs，分类、Sheet、Refresh、Toast和动画使用对应能力。首页移除固定同步块，原句“场次与进度会自动同步，放心去探索。”作为自然滚动内容的最后一项，列表延伸到浮栏下方。2026-10-28再按 [ADR-014](architecture-decisions.md#adr-014系统避让区只约束内容背景与材质延伸到屏幕边缘)让背景和材质延伸到状态栏及手势区，仅交互内容保留实际安全距离；不增加独立实心占位块。实现与历史回归见 [官方ArkUI验证](arkui-system-validation.md)，最终沉浸版另取证。

最终复核又发现404空模型标题仍显示“0/0”，且1.3字号密码IME下主按钮仅露46px、多次滑动位置不变。按 [ADR-015](architecture-decisions.md#adr-015真实业务事实与页面级键盘避让)改为detail.id非空才显示进度，认证页采用官方页面级 `KeyboardAvoidMode.RESIZE`，用实际App/Scroll/IME交集验证完整控件可达。修复前资料保存于 `artifacts/native-pre-final-fixes/`，其通过计数不覆盖这两项已知缺口。

详情“开始本场冒险”禁用并解释只读范围。没有本地伪造入场、判题、经验、奖励或通知已读。头像、答题、媒体/剧情、奖品、通知、卡片与Push尚未实现；有限的 `starward://assignment/<id>` 深链已接入并实测冷启动门禁及改密后恢复，不等于已验证生产App Links域名关联。

## 基线、工具与数据

- 固定工具链：DevEco Studio **26.0.0.851**，HarmonyOS SDK **26.0.0.105 / API26**，Hvigor **6.26.8**，ohpm **26.0.0.630**，Studio Node **24.14.1**，DevEco CLI **1.3.0-stable**。MCP与Skill作用域见 [工具接入记录](toolchain-and-tools.md)。
- 临时开发bundleName为 `com.sitkin.starward`，单entry，compile/target/compatible API26；只代表当前研发设备覆盖。
- Web冻结源码 `4b7d1a0a00051ac630e459b0fd6c074f821d7455`，后端 `c28f488d6b682ae213713ccdd2d992595a941ae3`。生产公开version.json返回403，尚未证明冻结源码等于线上版本；两个源仓库均只读。
- 没有打包隔离配置时使用明确标识的内存mock。公开演示账号 `alice`、初始密码 `Starward1234`；改后密码仅在该App进程有效。随机隔离玩家的账号、密码和控制token在测试期间仅暂存gitignore的private目录；实时状态及三个含凭据检查点已在最终扫描后删除，冻结无凭据DTO保留。
- 本轮真实后端为PocketBase **0.40.1 / linux arm64**，运行冻结迁移与hooks、全新数据库及虚构场次。正常业务响应不改写；503、畸形DTO、延迟和丢响应明确标为故障注入。
- 链路为原生Network Kit → 严格HTTPS → 官方HDC USB反向映射 → 本机玩家代理 → 真实PocketBase。临时CA只由本App测试构建信任，保留证书链及主机名校验；没有修改系统信任、关闭TLS或访问生产玩家。它不证明公网或生产服务可达。
- token和密码不持久化，认证头仍为原token且无Bearer。打包配置存在但无效时禁止认证，不能回退成功mock；外部Want不能修改API地址。
- 原始完整Web响应夹具仍保留，来源与哈希见 [夹具记录](fixtures-provenance.md)。真实网络证据与夹具/transport stub分开；Web视觉浏览器回放真实隔离DTO快照，不执行真实浏览器改密。

## 工程验证

| 项目 | 实际结果 | 证据及边界 |
| --- | --- | --- |
| 官方知识MCP | tools/list、searchDocuments、getDocumentsById实际返回API26资料 | 项目级配置和工具接入记录；写入配置不等于会话热加载 |
| 官方本地MCP | 初始化后check两文件无diagnostics | `artifacts/validation/mcp-check.json`，不代替编译 |
| 初始未签名构建 | BUILD SUCCESSFUL，生成unsigned HAP | `artifacts/validation/build.log`；该历史日志明确跳过签名，不能用它证明安装 |
| 调试签名、安装、启动 | 官方Studio自动签名后SignHap、CLI安装和启动成功，实际UI已显示 | `artifacts/validation/signed-device-run.log`；后续隔离构建摘要见 `https-installed-artifact.json`，最终产物另随最终运行更新；本机签名配置及原始输出不入库 |
| 最终沉浸版构建与安装 | 修复后edge-to-edge-v1已构建、签名并真机启动 | `native-system-visual-hap.json` 固定正常字号HAP `3bacb424…`，viewRevision为 `authoritative-progress-and-keyboard-resize`；认证/主视觉与系统UI报告须回验其原字节SHA。旧17项在 `native-pre-edge-to-edge/`，旧2b构建22项及22图在 `native-pre-final-fixes/`，不可替换为新SHA |
| codelinter | 修复后最新源码实际复跑exit0；issues/errors/warnings/suggestions均0 | `scripts/hm.sh lint`；`artifacts/validation/lint.json` 的summary.filesChecked=0照实保留，不能据此推算扫描文件总数或称穷尽验证 |
| Local Test | 修复后实际复跑exit0，**37 passed、0 failed、0 ignored** | `scripts/hm.sh test`；`artifacts/validation/local-test-summary.json`，源报告 `entry/.test/default/intermediates/test/coverage_data/test_result.txt` 已重新生成并核验；原始执行日志保留在private目录，不公开 |
| 历史条件反转实验 | endsAt由 `<= now` 反转为 `> now`，5例中1例失败，验证器exit1 | `mutation-summary.json`、`mutation-test-result.txt`、`mutation-test.log`；恢复后当时31/31通过，当前源码仍为 `<= now` |
| 独立代码审查 | 认证/代次/不确定改密/配置失败封闭及动态UI修复已记录 | [审查记录](slice-review.md)；运行发现真实400不显示错误后，错误区域改为V2参数组件并以真机400/503/畸形me复测 |
| 最终源码独立复核 | no blocking findings | `artifacts/validation/final-native-source-review.json`；只读核对API26 RESIZE、空详情进度、沉浸窗口生命周期及顶/底栏避让；不代替设备动态报告 |
| 公开产物隐私扫描 | **passed，814个公开候选文件、敏感命中0、读取错误0** | `artifacts/validation/public-artifact-scan.json`；已知隔离账号2、控制token2、密码4及仅内存传入的实际设备标识1；state无auth token，另扫解码JWT形状、PEM私钥头、签名扩展名。两处PRIVATE KEY拒绝代码引用另列，Web/后端工作树改动均0；不输出敏感值 |
| 隔离环境最终清理 | **status=passed**，设备恢复默认mock | `artifacts/validation/isolated-environment-cleanup.json`；runner UID/argv/cwd归属核验后按TLS→后端顺序只停自有资源，移除专用USB映射、临时CA/私钥目录、一次性数据库/容器与实时状态，扫描后删除3份私有检查点；四个自有监听及Web基线服务关闭，无关资源未改，安全viewer仍本机200 |
| 捕获产物离线核验 | **117项通过**，22张原生图来源与特定内容完整性核验完成 | `native-system-visual-content-check.json`、`native-capture-final-audit.json` 绑定3bac HAP及runtime SHA；18张主图全部新采、0继承。117是离线文件/像素/枚举内容检查，不是新增UI用例或完整Web视觉等价结论 |
| Web/原生视觉对照 | 20张Web、22张原生及额外四卡图已逐图目视，保留两项非官方差异 | `artifacts/visual-comparison/visual-review.json`，status为 `reviewed_with_known_non_platform_differences`；来源配对18/18、显式404 2/2、原生普通账号IME2/2，不称22项视觉全通过 |
| 预览框架验证 | HTTP **14/14**、浏览器22状态图加载，0页面/CSP/非favicon HTTP错误 | `visual-report-server-http-checks.json`、`visual-report-server-browser-checks.json` 均固定最终pairs SHA；privateFilesServed=false。只验证预览框架，不计原生UI验收 |

初始31例的历史报告、模拟13项和本轮37例不是同一组计数；没有把Web测试或协议探测计入Local Test。

最终源码lint与Local Test执行前后，固定捕获HAP的SHA均为 `3bacb424dee59591cc7cb9604bc53a3ab9e32e05fb89e2b9ab2cfee8d3eeaebe`，没有重建或替换正在取证的安装包。

## Local Test覆盖

| 套件 | 数量 | 验证内容与边界 |
| --- | --- | --- |
| Domain | 5 | 密码长度、UTF-8、确认、新旧不同；状态优先级；时间/等级边界；active不被客户端重新锁场 |
| Contract | 7 | 冻结Web完整响应与首切片投影、认证/改密边界、缺字段/错类型/错误体；不是全量题目媒体迁移 |
| Repository | 10 | 账号归一化、验证后提交凭据、改密单次与token轮换、退出/迟到响应/旧401隔离、跨账号拒绝 |
| ViewModel | 11 | 门禁、空输入、单飞、会话失效清理、迟到详情、改密不确定恢复、5xx与4xx文案及不重试、空态/重试 |
| Routes | 2 | 有限目标ID、拒绝未知外部URL、保留待认证目标及暖入口通知 |
| Environment | 2 | 无效配置不能进入mock成功链路；没有隔离配置时保持明确演示模式 |

## 设备与真实网络

| 项目 | 当前状态 | 证据及边界 |
| --- | --- | --- |
| 最终默认mock构建与安装 | `scripts/hm.sh run` exit0，构建/签名/安装/启动成功 | `native-mock-installed-hap.json`，HAP `82baeefc…`；integrationConfigPackaged=false、publicCaPackaged=false，28份App源码SHA仍匹配最终检查记录 |
| 最终默认mock设备流程 | **13/13通过**，6张原生图 | `artifacts/validation/device-smoke.json`、`artifacts/screenshots/`，报告绑定82ba HAP并明确in-memory mock；覆盖门禁、改密、主页/详情/历史、返回/退出及两主题，不计真实网络验收 |
| 最终默认mock运行时 | **4项通过，status=passed** | `native-mock-runtime.json` 绑定82ba HAP；fontScale1、实际窗口/全屏、两系统栏透明，TLS=null，不借HTTPS构建的TLS结果填充mock |
| 主机真实协议 | HTTP 25/25；严格HTTPS 25/25 | `real-pb-local-probe.json`、`real-pb-https-probe.json`；含真实改密/旧token失效/四场景/files-token协议，后者不等于头像UI已实现 |
| 主机TLS | 可信CA成功、无CA拒绝、错误主机名拒绝，3/3 | `isolated-tls.json`，未绕过校验 |
| 原生TLS | 恢复网关后重新冷启动实时采集，三项独立握手通过；两个拒绝均TLS_ERROR | `native-tls-and-metrics.json`，实际fontScale=1；不以网络失败冒充TLS拒绝 |
| 真实HTTPS core | **28项通过** | `device-https-acceptance.json` 的core phase；含真实请求状态/次数与UI断言 |
| 故障恢复 | **13项通过** | list/detail503保留与新GET200重试；403/404/410/409清旧详情；原生超时及恢复；前台/me回源；真实停用后/me及详情401清私有UI |
| 改密响应丢失 | **4项通过** | 真实改密POST200完成后明确注入丢响应；原生提示未确认且不重放；强制页退出清空输入；新密码真实登录确认写入成功 |
| 配对数据准备 | **1项通过** | 主机严格HTTPS取得改密后、单ready场景的真实DTO；这是准备证据，不算截图或原生UI通过 |
| 显式退出 | **3项通过** | 账号菜单退出清输入和私有内容，Back/Ability恢复仍受门禁，三个theme控件均可达；不等于系统主题动态跟随已验 |
| 迁移前HTTPS总报告 | **49项通过，status=passed** | `artifacts/validation/device-https-acceptance.json`；phase及请求台账完整，恢复来源另列；保留为历史证据，不代替新系统UI真机回归 |
| 沉浸调整前官方系统UI | **历史17/17通过** | `artifacts/native-pre-edge-to-edge/device-system-ui.json`；原容器、Refresh/503恢复、浮栏/末句、Sheet、返回与退出证据仅归该构建 |
| 修复前沉浸版系统UI及视觉 | 历史22/22系统UI、认证4图及主视觉18图captured | `artifacts/native-pre-final-fixes/` 绑定旧 `2b757938…` HAP；已知404默认“0/0”和大字号密码IME可达性缺口明确归档，`currentAcceptanceCredit=false` |
| 最终正常字号系统UI | **22/22通过，status=passed** | `device-system-ui.json` 绑定最终3bac HAP与来源JSON SHA；重新覆盖透明系统区、主题图标、真实上下避让、容器、Refresh/503恢复、末句、返回/退出，cleanup两项true |
| 最终正常字号认证视觉 | **captured4，流程清理完成** | `artifacts/native-system-visual/auth-capture-summary.json` 绑定同一3bac HAP；登录/强改密两主题，唯一UI改密响应200已确认，cleanup三项true。captured不等于完整Web视觉对照通过 |
| 最终正常字号主视觉 | **captured18/18，全新单次完整捕获** | `artifacts/native-system-visual/capture-summary.json` 绑定同一3bac HAP，newCapturedCount=18、resumedFrom=null；主页/历史/详情/退出/普通账号IME及等待/过期/等级不符/注入404均深浅两图，themeVerified。404均隐藏默认进度且各经实际GET200恢复；cleanup场景恢复/退出/故障中和全true。额外多卡透底图不计18；完整Web对照另评 |
| 修复后1.3字号与键盘 | **42/42通过，status=passed** | `device-large-font.json` 绑定独立HAP `fdda3840…`；`native-system-font-runtime.json` 实测fontScale1.3，来源SHA匹配。覆盖字段/完整CTA的实际IME可达、密码显隐、帮助、浮栏/末句、详情返回和退出；cleanup三项true且无额外改密 |
| 最终沉浸材质与窗口 | **6项运行时检查通过**；材质supported=true、ENABLE(1)、IMMERSIVE(2)、EXQUISITE(0)，全屏enabled、两栏透明，深浅系统内容色白/黑 | `native-system-runtime.json` 绑定 `3bacb424…` HAP；1320×2848px、density3.375、top131/bottom94px、cutoutTop84px、fontScale1。运行时检查不代替整页视觉、禁用/不支持设备降级或硬件适配验收 |
| 最终沉浸版原生TLS | **三项独立握手通过** | 同报告tls字段：customCaAccepted=true，不可信CA与错误主机名均被TLS_ERROR拒绝；USB映射恢复后的实际冷启动采集，不用NETWORK_ERROR冒充TLS拒绝 |
| Hypium instrument-test | 未建立 | 设备证据是官方CLI/UiTest操作；Local Test单独计数，不冒称instrument报告 |
| 生产公网、素材与发布 | 未执行 | USB隔离HTTPS不证明生产DNS/移动网络、头像或媒体可达；没有生产写入或发布 |

core的前18项来自有效core-20检查点，两个滚动状态重测后完成core28；后续恢复运行只继承已完成core，重新执行resilience13项。`resumedFrom`保存core20→core28的两层SHA链和重新检查项，初始中断不算一个通过的完整phase，不能称为单次不中断运行。

本机TLS网关曾意外退出，原因未确认；恢复沿用原CA、证书、端口和USB映射，没有重置业务库。`isolated-tls-resume.json`记录主机3/3重验及12次断连压力后网关/后端仍存活，随后原生三项TLS亦重新实时采集通过。不能据此把未查明的本机进程终止归因于生产后端。

所有UI输入通过官方UiTest替换并在内存校验；公开UI树去除输入值。原始密码、token、设备标识和签名输出不进入公开报告。复现与清理见 [隔离环境](isolated-https-environment.md)，不与其他测试同时重置同一隔离玩家。

各阶段归属分别固定：旧系统UI17项及当时HAP/runtime在 `artifacts/native-pre-edge-to-edge/`；修复前2b构建22项及22图在 `artifacts/native-pre-final-fixes/`。最终正常字号捕获HAP由 `native-system-visual-hap.json` 固定为 `3bacb424…`，该JSON原字节SHA为 `b1b472c9881673be8b204ccd5ed2508897ceb0444c116de2a57e95b1b3cfec9e`；新认证/主视觉及系统UI报告须同时保存此来源与HAP SHA。独立1.3字号HAP为 `fdda3840…`，其runtime原字节SHA `25b8e465c851779cfc3b64d7ebc46ff9d33e8ecf3ec03a05b550ff770b73311a` 已由42项报告回验；当前安装的默认mock为 `82baeefc…`，另存摘要及runtime，不覆盖HTTPS捕获来源。

跨日后旧测试控制端的场景更新返回失败，原因未确认。仅重建一次性PocketBase数据库与随机玩家，冻结后端commit、CA、HTTPS入口和玩家代理端口保持；新控制场景成功、严格HTTPS健康200，见 `edge-isolation-recreated.json`。旧49项、旧17项和旧数据快照仍保留原环境归属，不改写为新数据库执行结果。

最终证据冻结并完成默认mock复测后，临时HTTPS与一次性后端已安全清理，当前不再提供该隔离服务。公开扫描在含凭据检查点删除前实际覆盖814个文件，命中0、读取错误0；清理报告固定该扫描文件SHA，随后3份旧/新/restart私有检查点均删除。冻结的无凭据DTO、已脱敏UI树、原始PNG与本机白名单视觉viewer保留，其他仓库和无关容器/映射未改。

## Web与ArkUI视觉

[视觉对照](web-native-visual-comparison.md) 保存冻结Web原始12图、同字体控制12图及迁移前原生图。Web继续用于品牌、文案、业务状态和布局核对；官方材质、浮动容器、平台反馈及动效属于批准差异，另按官方能力和真机表现验收，不设为Web材质逐像素目标。真实设备为1320×2848px、density3.375、top131px/bottom94px，内容约391.111×777.185vp；实际内容对照使用391×777 CSS px，原390×844参考保留。

迁移前登录两主题已完成量测：主要字段和CTA纵向差小于0.6vp，星中心相对Web差约(+0.4074,+0.0891)vp，完整绘制且不再被故事宿主裁切。输入frame宽的余差、正文平台字体、密码图标、系统栏及隔离徽标明确记录；这些量测保留为历史对照，不推广到新系统UI。

首次改密Web参考已读取真实改密前/me快照，只用于本地渲染，没有请求场次或执行真实浏览器改密。迁移前认证4图已captured；原主页等18项捕获报告为incomplete、count=5，第5张键盘图的主题校验失败，不能记为5项视觉通过。修复前2b构建后续取得认证4图与主视觉18图captured，仍因404默认进度等缺口归档，不能替代最终HAP影像。最终正常字号已重新取得认证4图与主视觉18图captured，均绑定3bac HAP且清理完成；主视觉18图为全新单次完整运行，没有继承旧计数。同epoch的Web20图保留冻结来源，与原生22图逐图核对；最终pairs SHA为 `6f9ac03c3ce9a81af067149c1a817f17f118150572efdc13cb2909a22f815a3b`，HTTP及浏览器检查均固定此SHA。主配对18/18、显式404 2/2，普通账号IME2/2仅有原生证据；四卡透底额外图不计主18。交互式并排入口为 `artifacts/visual-comparison/index.html`。

目视结论为 `reviewed_with_known_non_platform_differences`：主要业务内容/状态与入口已对应，仍有两项待调整的非官方细节。首页卡片编号栏菱形在原生顶部与01轻微重叠，Web在栏底部；404重试按钮原生“重试”，Web“重新尝试”，恢复语义和操作保留。它们不属于批准的官方材质差异，不宣称逐字逐像素全过。117项离线核验只证明枚举文件与内容条件，不覆盖这项完整Web审查。

最终404两主题均由明确故障注入触发，记录authoritativeProgressHidden=true，错误空模型不再显示“0/0”。各自重试均为本次真实GET200，且authoritativeProgressRestored=true；不能把合成404称为真实后端业务失败。等待/过期/等级不符参考来自隔离玩家成功GET；普通账号IME两主题截图已核主题色，历史密码焦点黑图仍无视觉通过信用。

最终正常字号22项实测Scroll底2848px到达物理屏底，末句2419–2473px完整在浮栏顶2531px上方，浮栏交互项2544–2707px在手势区上缘2754px之上；标题动作避让实际131px顶部安全区。Refresh产生一次新列表GET，503保留旧列表并经新真实GET恢复；Sheet首次打开/Back关闭、未开放目的地拒绝跳转、详情边缘返回及退出后Back门禁均重验通过。修复后独立1.3字号实测浮栏底2721px、末句2401–2471px，未修改系统全局字号；普通账号IME截图中CTA完整露出，密码及强改密三个密码焦点只以脱敏UiTest几何确认实际IME可达，不计主题视觉通过。Toast/通用动效完整视觉、减少动画、材质降级和折叠等仍待专项证据。

## 仍需单独证明

旧环境真实HTTPS49项、沉浸调整前UI17项、修复前22项及22图分别保留。修复后最新源码37/37业务测试和lint 0 issues已实际复跑通过；独立1.3字号42/42通过，最终正常字号22项UI与6项运行时检查通过，认证4图及主视觉18图captured；设备已恢复最终mock，13/13冒烟和4项runtime通过。Web配对和目视对照已完成，菱形装饰位置/轻微重叠与404重试短文案仍待调整。密码焦点历史截图曾出现App与IME区域全黑，原因未确认；本轮密码焦点只留脱敏UiTest可达性，普通账号键盘视觉单独记录。实际语音读屏、连续录屏、减弱动画平台设置、材质降级及折叠等硬件场景尚无通过证据。

不支持开始、答题、头像/媒体、奖品/通知、卡片或Push；不提供记住登录、进程重启凭据恢复或离线首次启动。原Web和后端源码只读，因此没有执行其发布门禁或修改线上版本。
