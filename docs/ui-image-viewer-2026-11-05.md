# 题图点击查看小切片

实施前目标与分阶段记录。正文图片显示、失败重试和Refresh分别见[UI复核](ui-parity-review-2026-11-04.md)；本页将查看器实现、实际交互和原图复核分开，不据Web重放或官方API可用性宣称原生查看通过。

冻结Web为`4b7d1a0a00051ac630e459b0fd6c074f821d7455`。已使用本轮隔离真实case0/2的题面和已登记8张原始参考图片，在独立headless浏览器采得[Web参照](../artifacts/validation/ui-image-viewer-20261105/web-reference-01.json)：376×742、字号1、触屏/coarse渲染条件，两主题12状态，正式schema12项及served源码112项核验通过；API与题图均本地重放，外部和后端请求未放行，24条被阻资源console错误留private。未操作缩放slider或伪造触屏手势，不能据此验Native。

用户于2026-11-05确认唯一新增颜色差异：暗色查看器的缩放百分比在日夜主题统一用清晰浅色，修正Web日间深绿色文字对比不足；其余布局和文案保留。

| 状态 | 实现与验收目标 | 当前证据 |
| --- | --- | --- |
| 打开与布局 | 点击当前content块的ready题图，打开该块去重后的图组和精确索引；单图无导航，多图上一张/i/n/下一张，首尾禁用不循环；不拼成全页图集 | 已实现；c789包case0-02/case2-03日夜正常查看窄采集完成，单图及图集3→2→1来源/索引/首尾禁用和原图已核；旧49c及case2-02失败独立保留 |
| 原生容器 | 稳定页面宿主绑定官方`bindContentCover`，不重挂答案树或新增页面路由；暗背景延伸系统区域，交互避让真实安全区；无额外可见大标题 | 已实现并官方构建安装启动；c789两组关闭保同一真实输入实例/草稿，当前正常查看原图的舞台、控件及可见系统安全区已窄复核 |
| 缩放与拖动 | 官方Pinch/Pan，1～4倍、百分比、复位和“双指缩放 · 放大后拖动”；切图归1倍/零偏移，放大拖动不切图；保留捏合中心锚点 | 已实现；8220新包用户手验确认100～400%及放大单指拖动正常，实际终态400%/双向偏移与官方复位100%/零偏移已采；Root逐图复核完成，未声称自动多指或锚点误差专项通过 |
| 1倍滑动 | 单指触屏起始及结束均1倍、全轮无多指/取消，横移绝对值>48vp且>纵移×1.15，松手仅切一次；首尾不循环 | 已实现；c789 case2-03日间实际单指小位移及斜向均不切图，合格横向滑动仅切一次；8220用户手验确认缩回100%后的余指不误切，TouchCancel仍待验 |
| 关闭与返回 | X、外部遮罩、系统Back只关查看器，保留题页、真实输入实例和草稿；不额外GET/start/answer | 已实现；c789 case0/2日间X/Back/蒙层及夜间X实采，同输入实例和草稿保留，普通关闭零业务请求；不扩为所有退出/迟到边界通过 |
| 主题与窗口 | 通过既有`ImmersiveWindow`单一串行写入者统一白色系统栏图标；关闭恢复最新主题；旧查看器迟到回调不能释放新查看器的外观所有权 | 已实现；3项纯lease测试及mutation/恢复已验，c789普通日夜打开浅色图标/关闭恢复主题已核；查看期间主题变化、前后台及实际迟到回调仍待验 |
| 加载/失败/账号边界 | Viewer独立拥有自己的loader/PixelMap，切图/关闭取消并释放；小型原生失败重试；离页、换题、退出立即清私密来源/像素，迟到不恢复 | 已实现；c789 case0/2真实加载/绘制和正常关闭/退出清理有窄证据；用户确认本轮暂无公网入口，Viewer专属404/重试、网络加载中取消及账号迟到仍待验，正文证据不代替 |

官方资料：[全屏模态](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-attributes-modal-transition)、[PinchGesture](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-gestures-pinchgesture)、[PanGesture](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-gestures-pangesture)。知识MCP先搜索后读取全文，并核对固定API26声明：V2双向绑定since18、onWillDismiss since12需显式dismiss、safeArea选项since20；Pan的精确指数量选项since15。手势挂在不变换的stage，图片在其内层变换；onTouch只记录触摸生命周期，不能自行识别手势冒充系统组件。减少动画用官方NONE，正常使用官方ALPHA。

查看器与图片显示分开验收，尚未迁移的选择图、富文本正例、视频/BGM、线索演出和整页表单/反馈/顶栏显隐不从本页推定通过。折叠等专项仍后置。

## 2026-11-05：49c包实现与单图首轮采集

查看器及平台lease已实现，Root已核官方Run01的构建、signed产物、安装和启动成功记录，原始运行日志仅private。该轮历史HAP为`49c6e5649b76886af6ab3fa61c1f80a6a305130546735d6a3dd54ebaa18df6c9`；[该轮运行时](../artifacts/validation/ui-image-viewer-20261105/runtime-image-viewer-20261105-01.json)五项实际passed。构建、签名、安装启动与后续UI结论分别记录，8b正文显示收尾不受本次查看器实现结论影响。

[lease与lint回执](../artifacts/validation/ui-image-viewer-20261105/lease-and-lint-validation.json)核实唯一3项`ImmersiveSurfacesTests`实际全过；唯一一次移除“最后一个lease”条件的mutation使重叠lease用例失败1项，逐字节恢复后fresh三项再次全过，不计为6个唯一测试。lint实际issues/errors/warnings/suggestions均0、filesChecked=0；验证前后signed HAP相同。该回执的完整源码绑定包括：

| 源文件 | SHA-256 |
| --- | --- |
| `ui/StarwardImageViewer.ets` | `1ba875ec087a60650c0d79a97644a50abd0c179fe64c1360abeaa598ab240e0b` |
| `ui/StarwardQuestionImages.ets` | `30ddd0faddc00732cb9fa3ca23b61fa36e86bf21e5b642da97917103bb551b11` |
| `features/GameplayPage.ets` | `a963230911d70fb8cb656b28ec03ea6575c3fac6d7b2e2980329af74025fa252` |
| `platform/ImmersiveSurfaces.ets` | `2bf15ef66bdfd5eeaf4b2ec30332e36b4fda2547ce7ff2769fc36f2c74fb9d70` |
| `platform/ImmersiveWindow.ets` | `78be29e73efb74f97bca0ba6839602c36fe9f561b54fbe05d97422e07c4cae50` |

[native-case0-01](../artifacts/validation/ui-image-viewer-20261105/native-case0-01.json)状态为`captured_native_viewer_narrow`，3项目标检查、10个实际状态，五项cleanup全true；不是查看器整体验收通过。两主题单图真实加载，初始100%且无图集导航；日间分别X、Back、蒙层关闭及夜间X关闭，真实输入accessibilityId/hashcode与草稿保留，查看开关无新增业务请求。页面Back后重进仅GET，无额外start/answer/profile/password写入。10状态不等于10张原图，也不换算整体功能完成度。

Root已实际查看case0的`viewer-open-light`原图，确认该屏布局与同数据Web对应、百分比按已批准差异用清晰浅色；其余原图尚未完成逐张复核。原采集报告的`visualReview=pending_root_original_review`和`viewerAcceptanceComplete=false`保持，不扩大为14图或全状态视觉通过。case2仍作为运行中轮次待回填，本次不登记图集通过。

真实Pinch、放大Pan、4倍上限、放大后复位、TouchCancel、余指继续移动、Viewer专属加载失败/重试与加载中取消仍未执行。官方Python多指SDK仅完成只读能力与初始化副作用研究，受控helper正在准备，尚未导入/安装或连接；未创建ohosTest文件或执行instrumentation。后续实际手势、失败边界和私有SDK环境准备须各自取证，不从Web重放、源码审查、纯lease测试或正文404报告推定通过。

## 2026-11-05：图集首次失败与命中测试修正候选

[native-case2-01](../artifacts/validation/ui-image-viewer-20261105/native-case2-01.json)已结束为`incomplete`、0项通过、五项cleanup全true；只采到日间从第三张打开的3/3状态，不能算图集切换通过。Root确认“上一张”的原始enabled为true，但实际点击没有响应。49c包及Viewer `1ba875ec…`旧源码已私有归档，case0窄采集与case2失败报告各自保留，不覆盖或合并计数。

根因已由固定API26 `ets/component/enums.d.ts`及官方命中测试说明核实：`HitTestMode.Block`只允许节点自身命中，会阻断子节点、兄弟及祖先；旧`image-viewer-panel`误用该值，导致其内导航/复位与手势区域无法正常收到输入。此前静态审查未识别此语义错误，其“无高置信阻塞”结论不能代替实际交互验收。

Root仅将该属性改为API20起支持的`HitTestMode.BLOCK_HIERARCHY`，允许自身及子节点命中，同时阻断低优先级兄弟/父节点，保留外侧蒙层关闭语义。新Viewer源码SHA为`d4073696b459b0c31d8f2fd82bff59e2325df61d417606a070950e60b295cc6d`；官方Run02/lint02属于新候选验证，本次不登记构建、安装、运行时或UI通过。新包须独立复验正常打开/关闭、图集按钮及实际手势，49c和正文8b的证据均不冒充该候选的执行结果。

## 2026-11-05：c789正常查看与原图窄复核

前段候选待验为当时记录。Root现已核官方Run02实际exit0，完成构建、signed产物、安装和启动；当前HAP为`c7895c09a3b414e9237d18f08786fca6f5bcd4a5c8564b5ee6c606e587208641`，Viewer为上述`d4073696…`。lint02实际exit0，[原报告](../artifacts/validation/ui-image-viewer-20261105/lint-02/lint.json)issues/errors/warnings/suggestions均0、filesChecked=0；[runtime02](../artifacts/validation/ui-image-viewer-20261105/runtime-image-viewer-20261105-02.json)真实五项passed。其余UI/平台源码绑定见两份新Native报告，不继承49c执行结果，也不改8b正文收尾归属。

[case0-02](../artifacts/validation/ui-image-viewer-20261105/native-case0-02.json)为`captured_native_viewer_narrow`，3项目标检查、10状态、8张原图；[case2-03](../artifacts/validation/ui-image-viewer-20261105/native-case2-03.json)同状态、3项目标检查、15状态、13张原图，两轮五项cleanup均true。单图无图集导航；图集日夜从第三张精确打开，上一张依次到2/3、1/3，首尾按钮禁用，切图均100%/零偏移。case2日间另用官方单指命令实际验证：20vp小横移和100vp斜向均不切图，120vp合格横向仅切一次。此处不把单指滑动当作Pinch或放大Pan通过。

两组日间X、系统Back、蒙层及夜间X均保留真实输入accessibilityId/hashcode和未提交草稿，普通查看开关零新增业务请求；页面返回后重进仅GET，无额外start/answer/profile/password/fault/reset。正常加载后的关闭及退出清理不代表加载中取消、TouchCancel、余指或账号迟到边界已验。25个采集状态不等于25项独立测试，21张原图也不换算功能完成度。

[独立原图复核回执](../artifacts/validation/ui-image-viewer-20261105/root-delegated-normal-visual-review.json)逐项保存实际查看路径与SHA：受Root委派的reviewer以`view_image`查看17张Native独有原图及同数据/索引/主题的12张Web原图，共29张未编辑、未裁切原图；Native另外4个文件仅核逐字节相同，明确为`byteEqualNotViewed`，不冒称额外目视。Root亲看当前case0日间打开及Back关闭两图另列，不叠加到该reviewer计数。正常范围未见图片来源/顺序、Contain比例、控件/字级可读性、间距或系统安全区阻塞；日间百分比浅色为批准差异，Native遮罩近实黑而Web隐约透出背景纹理的可见差异亦保留，不宣称逐像素或整页还原通过。原采集报告`visualReview=pending_root_original_review`原字节保持，由独立回执承接这次窄复核，`viewerAcceptanceComplete=false`保持。

[case2-02](../artifacts/validation/ui-image-viewer-20261105/native-case2-02.json)仍为incomplete、0检查，五项cleanup为true。Root核实际raw dump没有任何`image-viewer`节点、只见底层玩法页，而此前CLI等待曾见viewer pixels；转场/消失与dump不一致的原因尚未确认，不能定性为网络失败。该失败与49c的case2-01各自保留，03使用同一冻结helper重新采集，不覆盖02或继承其状态。

真实多指仍未取证：[工具尝试02](../artifacts/validation/ui-image-viewer-20261105/multitouch-tooling-attempt-02.json)在SDK导入前因所选官方`python3.12`无执行权限而停止，未改SDK模式或配置；Root随后核实同安装前缀的官方`python3`可执行且为3.12.10，仅修本仓helper解释器路径。[SDK03](../artifacts/validation/ui-image-viewer-20261105/native-multitouch-03.json)又在导入前因旧私有设备ref不匹配当前手机而incomplete、0手势/0检查，原cleanup中的false保持；[独立恢复记录](../artifacts/validation/ui-image-viewer-20261105/multitouch-tooling-attempt-03-recovery.json)只核当前手机空登录、私密玩法/Viewer不存在、自有TLS映射保留、daemon为0、SDK缓存仍不存在，不能改写旧报告为通过。新ref后续尝试尚无SDK验收结果，未创建ohosTest文件。

用户确认本轮暂无公网入口，先完成正常查看与手势；Viewer专属失败/重试及网络加载中取消继续待验。[媒体工具尝试01](../artifacts/validation/ui-image-viewer-20261105/media-tunnel-attempt-01.json)仅合成PNG离线准备及loopback health成功，cloudflared实际-9且无输出，原因不推断；自有媒体server已精确停止，没有公网TLS、PNG/missing请求、Native媒体加载、媒体派生case或后端修改。本次正常查看、单指和原图证据不扩为真实Pinch/放大Pan/4倍上限/放大复位、TouchCancel/余指、Viewer失败重试或加载中取消通过。

SDK04使用当前唯一手机完成官方连接，但在手势注入前因本机主机名反查被进程网络审计阻止而停止，[原报告](../artifacts/validation/ui-image-viewer-20261105/native-multitouch-04.json)仍为incomplete、0检查，主流程五项cleanup为true，SDK清理八项false和一次审计阻止均保留。固定SDK的`get_local_ip()`在该查询抛错时本来会回退到`127.0.0.1`；正在核验如何如实区分已阻止的可选本机诊断与意外操作，尚未登记真实多指通过。

[SDK04独立恢复回执](../artifacts/validation/ui-image-viewer-20261105/multitouch-tooling-attempt-04-recovery.json)仅证明失败后的精确收尾：Python已退出，SDK daemon已自行消失；Root对照原先不存在的资源、当前唯一转发增量、代理原始hash/stat及完整退出缓存清单，移除本轮SDK转发和代理、两个文件及两个自建缓存根目录，保留HDC、自有HTTPS映射和原有设备文件。未使用递归删除、广泛进程清理或修改SDK，原失败报告不回写为成功。

## 2026-11-05：SDK05/06停止于连接阶段，资源另行收尾

[SDK05](../artifacts/validation/ui-image-viewer-20261105/native-multitouch-05.json)使用helper `db92ae4c…`，试图对固定SDK的可选本机地址诊断作窄区分，但实际`socket.gethostbyaddr`仍被审计阻止；原报告为`incomplete`、0检查、0手势、0状态，`realMultiPointerInjected=false`。主流程五项cleanup为true，SDK八项cleanup仍为false；这两组原值分别保留，不互相替代。该轮并未取得可用于手势的连接所有权回执，不能因SDK初始化曾执行就宣称连接或Pinch通过。

[SDK06](../artifacts/validation/ui-image-viewer-20261105/native-multitouch-06.json)使用helper `0dc265cc…`：离线策略在resolver真正执行前用`OSError`阻止全部反查及非数字loopback正查，让固定SDK自身的错误回退生效，没有伪造本机IP或修改SDK。报告保留2次被阻查询及脱敏调用栈；实际链路是`get_local_ip`由`ohos.config.config_manager.get_devices`调用，不能沿用此前猜测的调用来源。此次`auditDeniedEvents`为空不等于连接或验收成功：连接阶段随后仍有原因未明确的`RuntimeError`，报告继续为`incomplete`、0检查/手势/状态，主流程五项cleanup为true、SDK八项false。真正的多指、放大拖动与从放大复位均未执行。

[离线守卫验证02](../artifacts/validation/ui-image-viewer-20261105/multitouch-audit-guard-validation-02.json)的52项是纯断言数，核固定stdlib及SDK AST的现有回退、脱敏诊断与意外connect/send/write仍致命等规则；SDK导入、实际resolver、网络和设备调用均为0。它不证明任何Native姿态或手势。Root已停止继续扩展SDK连接排障，后续正常手势采用单独的人工真机操作与实际姿态/原图/复位观察记录。

[SDK05恢复回执](../artifacts/validation/ui-image-viewer-20261105/multitouch-tooling-attempt-05-recovery.json)与[SDK06恢复回执](../artifacts/validation/ui-image-viewer-20261105/multitouch-tooling-attempt-06-recovery.json)分别核Python已退出、daemon已自行消失，再按各轮退出清单与私有所有权回执精确移除1条自建forward、1个自建agent、2个自建缓存文件及2个原先不存在的缓存根目录；原HDC、自有TLS reverse、其他设备文件与源码/SDK字节保留。两轮缓存均恢复到原先不存在状态，未递归或glob删除、未广泛杀进程，未改写原报告的失败与SDK清理false。这是失败后的收尾证据，`gesturesVerified`和`viewerAcceptanceComplete`仍为false。

## 2026-11-05：lint归一化计数的范围澄清

上文lint01/02的exit0及归一化报告0issue原值不变。固定官方CLI 1.3.0-stable源码`DR`取`NR(input).size`作为`filesChecked`；`NR/qd`递归收集JSON中`filePath/file/path`，不是实际扫描文件总数。空缺陷数组可得到0个已报告路径，因此`filesChecked=0`既不能证明扫描覆盖为0，也不能证明全部源码已扫描。适用CLI文件SHA为`c443988de8954aa459c9941aa76d54d7f152b110fd6707a2d9ddd3049b4c1d37`；adapter完成后会删除原生临时报告，现存归一化报告与日志不能补证实际扫描覆盖数。准确结论为“官方CLI exit0，归一化报告0issue，实际扫描覆盖数未证明”，不扩大为全项目lint覆盖通过。

## 2026-11-05：电脑重启后的新验证代次，进行中

重启后实际检查发现旧临时`state.json`、TLS目录、数据库与临时container均不在；没有可继续使用的旧临时DB或服务。固定预览的数据库、CA、账号私有文件仍保留，与临时验证环境分开。旧终止原因不据此推断，历史c789正常查看/单指/视觉证据继续绑定当时产物与环境，不继承给新环境。

Root已重新启动DevEco、Docker、HDC、冻结Web参照服务及临时后端/TLS。新临时DB重新按原fixture导入3个真实案例、19条完整映射记录，另建独立7条正文失败派生案例，共4个隔离玩法账号，未恢复或伪称旧玩家进度。[新TLS回执](../artifacts/validation/ui-image-viewer-20261105/reboot-recovery-01/isolated-tls.json)仅核Host正向HTTP200、未信CA及错误主机名均拒绝三项，使用新CA，系统信任未修改；不能代替手机HTTPS或UI验收。

继续手势前仅对新case2以隔离玩家正式`start`接口做一次入场准备；私有前后诊断为assigned→active、progress与start receipt各0→1，答题提交/答题receipt/XP ledger/总XP仍为0。这是明确的新DB准备写入，不是Native入场复验或手势通过。新CA要求重新构建安装HAP并取得相符的运行时、案例引用与采集器绑定；当前正在构建安装阶段，本段不登记安装、运行时、正常查看或手势通过。Viewer专属失败/重试与网络加载中取消仍按用户决定待后续公网入口验证。

上述进行中状态随后取得以下独立回执，旧段保留为当时记录。[服务恢复回执](../artifacts/validation/ui-image-viewer-20261105/reboot-recovery-01/service-recovery.json)核官方Run日志存在build completed、installed、launched信号；该进程exit code未捕获，明确为`officialRunExitCodeCaptured=false`，不补写exit0。新signed HAP为`8220a2ecc82b9e7f1236073316f9aace0245a08e6096526af3011c1c620b95d1`。[离线包比较](../artifacts/validation/ui-image-viewer-20261105/reboot-recovery-01/package-comparison.json)核与c789包相同的48个ZIP成员，仅`ets/symbolMap.map`、公开测试CA和integration配置字节不同；配置JSON值相同，全部ABC字节相同。包比较用于说明本轮恢复范围，不继承历史UI验收，也不推断symbolMap的JSON语义相同。

[新runtime](../artifacts/validation/ui-image-viewer-20261105/reboot-recovery-01/runtime.json)实际五项passed，绑定上述8220包：窗口1316×2832px、density3.5、376vp、fontScale1，真实透明系统栏及独立的信CA成功/不信CA拒绝/错误主机名拒绝。固定预览的manifest、login、数据库及CA四个文件SHA与恢复前相同；本轮临时DB未覆盖固定预览。

[人工手势准备回执](../artifacts/validation/ui-image-viewer-20261105/reboot-recovery-01/manual-prepare.json)实际为`prepared_awaiting_manual`、1个新case2日间状态，非手势通过。26项历史源码/参照绑定逐字节保持，允许变化的恢复绑定明确只有CA、caseReference、config、HAP和runtime，并分别绑定新值；`historicalNormalAcceptanceInherited=false`。原生普通登录后进入已active案例，实测该次进入为2个GET200；记录真实输入实例及未提交草稿后打开同组第二张，实际2/3、100%、水平和垂直偏移均0。私有请求账本保存Host认证/只读与Native认证/只读，未增加start、answer、profile、password、fault或reset，答题/答题receipt/XP ledger/总XP仍0，原先准备的start receipt和progress各1。

Root已亲自用`view_image`查看该轮未经编辑的初始原图，SHA为`cf4f0e525a9700582dd89ea128a5853da21e24b92211db434954488a182feaf1`；这只承接此张100%/2/3正常打开图的目视，不能扩为新包全部正常状态或多指验收。当前正在等待用户真机操作与反馈，Viewer特意保持打开；prepare的`loggedOut/loginInputsEmpty/privateGameplayAbsent=false`为真实未收尾状态，`remoteRawFilesRemoved/zeroForbiddenWrites=true`另列，不将前三项改写为通过。之后须另取放大拖动后的实际姿态/原图、复位、关闭保草稿及退出清理回执；手势上下限和余指反馈也须区分用户报告与仪器观察。


## 2026-11-05：8220人工正常手势与实际复位收尾

用户已对已准备的第2/3张实际执行双指放大到400%、缩回100%、先松一指后余指横划、全部抬手后再放大及单指斜向拖动，明确回复“均正常，已保持放大并拖动后的画面”。这些上下限、拖动体验与余指不误切是人工确认，不改写为SDK自动多指注入通过。

[终态采集](../artifacts/validation/ui-image-viewer-20261105/reboot-recovery-01/manual-finish.json)实际为`captured_manual_finish`、failure为空、五项cleanup全true。原始姿态为400%、水平−60.2vp/垂直195.7vp，仍为2/3；官方单指点击“复位”后100%、双向0，再点X恢复日间题页，同一真实输入accessibilityId/hashcode和未提交草稿保留。显式退出后空登录、私密玩法消失、自有远端采集文件清除；准备到收尾的台账没有新增入场、答题、资料或密码写入，答题/receipt/XP ledger/总XP均0，原入场receipt及progress各1。

[Root独立复核](../artifacts/validation/ui-image-viewer-20261105/reboot-recovery-01/root-manual-review.json)绑定实际报告SHA和三张未编辑原图：Root逐图查看放大拖动、复位和X关闭，确认放大图在stage内裁切、复位恢复Contain、浅色百分比清晰、关闭恢复浅底深色系统图标与草稿。本次没有Web注入假手势，亦未重跑未改动的历史正常全状态。新包、相关34项绑定及33份唯一文件已私有归档，后续选项样式改动不覆盖本轮证据。

本轮正常查看与手势范围可以继续推进下一小点；查看器整体验收仍为false。Viewer专属404/重试和网络加载中取消仍按用户决定待公网测试入口，TouchCancel、账号迟到、查看期间主题/前后台及捏合锚点精度没有专项通过证据，不用人工“均正常”补齐这些未操作边界。
