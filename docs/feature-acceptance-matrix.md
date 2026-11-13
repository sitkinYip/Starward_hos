# 原生迁移基线与功能验收对照表

## 2026-11-04：UI还原复核，当前待修复

用户指出新增玩法UI与Web明显不符。此前主链业务和原生交互结果保留；14张原图的可读性/状态语义review不能作为Web还原通过。当前侧栏头部/高度、Rank底距、玩法结构/字级/题卡/表单/反馈、真实题图及已确认的顶栏显隐均列入待实现或待复验，见[UI复核与流程提案](ui-parity-review-2026-11-04.md)。用户确认本轮做题图与页面，视频、BGM及线索演出后续拆片；不能把它们记为本次UI已完成。

本次浏览器实际读取线上version.json为production1.17.1、commit4b7d1a0…，与冻结Web一致。完整题库改用接口或只读数据库采集；页面抽样不算完整数据导出，也不算同基准视觉验收。

首组样板（侧栏头部/高度、Rank底距）已在最终334ab6dd…预览包完成官方构建/安装、lint、实际窗口/TLS及目标直板机29项检查，原生6张/Web4张同数据原图已由Root核对；用户回复“符合，后续按此规范推进”，本组样板已确认，不记整体UI通过。双主题侧栏只有星标/护照/关闭一行、退出初始可见，Rank至实际原生标题边界34物理像素（density3.5，约9.714vp）。具体命令、首次失败及最终报告见[样板记录](ui-parity-review-2026-11-04.md#首组样板实际验证)。其余玩法版式、题图、顶栏显隐仍待后续小点；放大字号及短窗口本次未复测。

完整内容库已在生产SQLite单个只读事务采得12表376行（28题、41场次、121关卡关联），无缺表/阻断表/显式检查issue；不含玩家/认证/运行时数据，没有生产写入。只读采集完整性与业务、UI验收分开，见[内容回执](../artifacts/validation/ui-parity-20261104/content-capture.json)及[UI覆盖清单](../artifacts/validation/ui-parity-20261104/content-ui-coverage.json)。

题卡框架/手机字级与均衡换行已在108affda…包完成三组真实题面、两主题直板机/隔离HTTPS及同数据Web原图对照；Root复核范围仅边框、宽度、字级/行高、长短及隐藏题名换行，详见[窄范围报告](../artifacts/validation/ui-question-frame-20261104/root-frame-review.json)。后续499bbf…包已清理正文重复摘要/常驻大按钮并接官方Refresh，活跃单题两主题、保留真实输入实例/草稿、503重试、404清旧进度/草稿、真实IME与Back及退出后完整迟到GET均已直板机/隔离HTTPS验证。Root核5张原图，见[本点窄复核](../artifacts/validation/ui-gameplay-layout-20261104/root-layout-review.json)。多题导航、题图及其他玩法版式仍另点，不从本点推定通过。

正文结构化题图显示的实施前计划及[ADR-021](architecture-decisions.md#adr-021题图下载解码与查看独立于判题和头像认证)已登记，现已实现并完成构建/signed产物/安装、相关7测试及lint；真实/派生隔离夹具已19+7条读回，新Host TLS通过。最终ddc149ba…包首次启动曾被官方10106102锁屏错误阻断，不能以CLI整体exit0替代启动成功；当时的[待设备回执](../artifacts/validation/ui-question-images-20261104/build-and-device-pending.json)保留，解锁后的实际结果见下方追加。点击查看、选择图/Radio及富文本正例另点；8张参考字节和Web重放不算Native加载。

## 2026-11-05：题图显示分阶段回填

手机已解锁，同一ddc149ba…包的[runtime-01](../artifacts/validation/ui-question-images-20261104/runtime-01.json)真实5项全部passed。[native-case0-01](../artifacts/validation/ui-question-images-20261104/native-case0-01.json)仅日间真实解码/绘制与图片几何通过1项；dark重进因新采集器错误要求恰一次detail GET而incomplete，cleanup全部true。已独立确认现有`Index → 详情投影 → 完整玩法快照`路径顺序发两次同detail GET200；旧Frame仅要求GET-only。

首轮报告及原图保留，不继承计数。两个新采集器修正为恰两次GET200后，fresh正常三组各3项、独立404失败/重试3项实际passed，cleanup全true，零答题/XP。Root核14张原生/Web原图，同题内容与presentation对应，正文单图/三图图集及小尺寸原生失败重试已窄范围复核，见[root-body-display-review](../artifacts/validation/ui-question-images-20261104/root-body-display-review.json)；该原报告不扩大为Refresh或整页还原结论。

同一ddc149ba…包的[native-refresh-03](../artifacts/validation/ui-question-images-20261104/native-refresh-03.json)独立2项passed、七项cleanup全true。冷启动空登录后，一次原生下拉仅发一次无故障detail GET200，图片cell/frame/pixels及输入四个节点的真实accessibilityId/hashcode与未提交草稿保留；同一PID初始图片loading→ready一组、Refresh重载0，新增start/answer均0、XP仍0，退出后登录空输入和私密内容清理均确认。GET过快，pending未直接观察，不能据此前后结果标pending保留、实际取消或迟到解码释放通过。

[Refresh01](../artifacts/validation/ui-question-images-20261104/native-refresh-01.json)仍为手势前incomplete：采集器误读CLI enabled字段，原始UiTest实际`'true'`，cleanup全true；[Refresh02](../artifacts/validation/ui-question-images-20261104/native-refresh-02.json)在登录时USB映射缺失、连接中断，未刷新，原cleanup false如实保留。仅精确自有映射经[恢复回执](../artifacts/validation/ui-question-images-20261104/usb-reverse-restored-20261105.json)恢复，另有[runtime-02](../artifacts/validation/ui-question-images-20261104/runtime-02.json)真实五项passed；03新轮已恢复空登录/退出清理事实，不重写旧失败，不记环境收尾或固定预览恢复通过。

加载中取消/迟到解码释放的四组资源IO竞态测试正在实现，尚待运行与验收；小原图/高度上限分支、图片查看、选择图、富文本正例及整页还原尚未通过。Native媒体网络与参考图片字节重放分开记录，未抓包核下载SHA。详见[图片分阶段记录](ui-parity-review-2026-11-04.md#2026-11-05解锁运行时与首轮采集器修正)及[Refresh独立记录](ui-parity-review-2026-11-04.md#同题refresh实例与usb重接补验)。

### 2026-11-05：正文显示当前覆盖子点完成

前述资源补验计划为阶段历史；当前结论见[8b包正文收尾](../artifacts/validation/ui-question-images-20261105-races/root-body-loader-closure.json)。唯一4项受控IO竞态测试实际全过；唯一mutation只使第4项失败，原字节恢复后fresh四项全过，不叠加唯一用例数。新8b8d4869…包已构建/signed/安装启动、lint零issue（filesChecked=0）及真实运行时五项通过；默认SDK路径另有正常单图3、404失败/重试3、Refresh2项实际passed，各轮cleanup全true、零答题/XP。

Root亲看4张新原图，8b验收时相关UI/Page/VM/Index字节与ddc已验版相同；三图图集几何仍使用ddc原报告，不写成8b重执行。旧incomplete及原14图窄视觉复核保持归属。正文已覆盖的显示/失败重试/同题Refresh及受控IO资源协议子点完成；真机实际加载中取消/迟到PixelMap释放时序仍false，pending未直接观察，下载字节SHA、小原图及340上限触发分支仍未验，不推定整页通过。

点击查看进入独立[实施与验收表](ui-image-viewer-2026-11-05.md)，[Web12状态参照](../artifacts/validation/ui-image-viewer-20261105/web-reference-01.json)只是同内容只读重放，无Native查看通过结论。用户已批准缩放百分比日夜统一浅色，项目skill与新表已登记；选择图、富文本正例、视频/BGM及线索演出仍后续拆点。

### 2026-11-05：查看器已实现，单图窄采集完成

查看器与沉浸lease在49c首轮已实现，该轮历史HAP `49c6e5649b76886af6ab3fa61c1f80a6a305130546735d6a3dd54ebaa18df6c9`已由官方Run01构建、生成signed产物、安装启动；[该轮真实运行时五项](../artifacts/validation/ui-image-viewer-20261105/runtime-image-viewer-20261105-01.json)全部passed。[lease与lint](../artifacts/validation/ui-image-viewer-20261105/lease-and-lint-validation.json)实际3个唯一测试全过，唯一mutation使最后lease门控用例失败1项、原字节恢复后三项全过；lint零issue、filesChecked=0。源码/HAP绑定详见[本轮实现记录](ui-image-viewer-2026-11-05.md#2026-11-0549c包实现与单图首轮采集)，不改变8b正文收尾归属。

[case0单图报告](../artifacts/validation/ui-image-viewer-20261105/native-case0-01.json)仅`captured_native_viewer_narrow`：3项检查、10状态、cleanup全true，两主题打开和日间X/Back/蒙层、夜间X关闭保真实输入实例/草稿，查看开关零业务请求，页面重进GET无重复start/answer。Root已核日间打开一张原图的布局与批准的浅色百分比，尚未完成整组原图复核，不标全视觉/全功能通过；case2运行中轮次不提前回填通过。

官方Pinch/Pan绑定已实现，但真实捏合、放大拖动、4倍上限、放大后复位、取消/余指及Viewer专属失败重试/加载中取消仍待实测；查看期间主题变化和前后台亦不从普通开关推定。官方Python SDK受控helper尚在准备、未导入/安装或连接，未创建ohosTest文件。Web12状态仍只作本地同内容只读重放参照，正文失败报告和纯lease测试不代替查看器这些边界。

查看器图集首轮已由运行中转为[incomplete/0检查](../artifacts/validation/ui-image-viewer-20261105/native-case2-01.json)，cleanup全true；只打开第三张3/3，“上一张”enabled虽为true却未响应。Root核固定API26与官方说明，旧panel的`HitTestMode.Block`会阻断子节点；49c及旧Viewer1ba源码/失败证据均保留，case0窄采集不推定图集通过。仅修为允许子节点命中并阻断低层目标的`BLOCK_HIERARCHY`，新Viewer源码d4073696…及官方Run02/lint02为待复验候选，本次不标新包构建/运行时/UI通过。详见[失败与修正记录](ui-image-viewer-2026-11-05.md#2026-11-05图集首次失败与命中测试修正候选)；8b正文收尾归属不变。

### 2026-11-05：c789正常查看窄范围回填

前述候选待验及SDK准备状态为阶段历史。当前HAP `c7895c09a3b414e9237d18f08786fca6f5bcd4a5c8564b5ee6c606e587208641`已由官方Run02实际exit0完成构建/signed产物/安装启动；lint02实际exit0、[零issue且filesChecked=0](../artifacts/validation/ui-image-viewer-20261105/lint-02/lint.json)，[runtime02五项](../artifacts/validation/ui-image-viewer-20261105/runtime-image-viewer-20261105-02.json)passed。Viewer d4073696…与相关源码绑定见新报告，不把旧49c执行迁移到新包。

[case0-02](../artifacts/validation/ui-image-viewer-20261105/native-case0-02.json)为`captured_native_viewer_narrow`，3检查/10状态/8原图；[case2-03](../artifacts/validation/ui-image-viewer-20261105/native-case2-03.json)同状态，3检查/15状态/13原图，cleanup各五项全true。两主题单图及图集精确打开3/3、上一张2/3→1/3/首尾禁用、普通关闭和原输入实例/草稿保留已取证；日间单指小位移/斜向不切图，合格横向仅切一次。查看开关零业务请求，页面重进仅GET，无重复start/answer或资料/改密写入。

[独立原图复核](../artifacts/validation/ui-image-viewer-20261105/root-delegated-normal-visual-review.json)保存实际路径/SHA：reviewer逐张查看17张Native独有原图+12张同数据Web原图；另外4张Native仅逐字节相同、明确未重复目视。Root另亲看当前case0两图单列。正常查看范围未见来源/顺序、比例、控件可读性/间距或可见系统安全区阻塞；批准的日间浅色百分比及Native遮罩更实黑的差异单列，原采集报告不改写，不声称整页、逐像素或完整Viewer通过。正文8b及ddc原证据归属保持。

[case2-02](../artifacts/validation/ui-image-viewer-20261105/native-case2-02.json)仍incomplete/0检查且cleanup全true：Root实际dump无Viewer节点、只有底层玩法页，与此前CLI等待见pixels不一致；原因未定，不写成网络故障，49c case2-01亦保留。真实多指[工具尝试02](../artifacts/validation/ui-image-viewer-20261105/multitouch-tooling-attempt-02.json)在SDK导入前因官方解释器路径执行权限失败；仅改本仓helper使用同前缀可执行`python3`，不改SDK。[03尝试](../artifacts/validation/ui-image-viewer-20261105/native-multitouch-03.json)因旧设备ref不匹配在导入前阻断，0手势/0检查及cleanup false保留；[独立恢复](../artifacts/validation/ui-image-viewer-20261105/multitouch-tooling-attempt-03-recovery.json)只确认当前手机空登录、自有TLS映射和0 daemon/缓存等事实，不代替SDK验收。

用户确认暂无公网入口，本轮先正常查看与手势；Viewer专属失败/重试和网络加载中取消待验。[合成媒体尝试](../artifacts/validation/ui-image-viewer-20261105/media-tunnel-attempt-01.json)只完成离线准备/本地health，tunnel -9无输出、自有server已停，无公网媒体/Native加载或后端派生写入。真实Pinch、放大Pan、4倍上限、放大复位、取消/余指仍无通过证据，`viewerAcceptanceComplete=false`；未创建ohosTest文件。

2026-11-05重启恢复另立新代次：[服务恢复](../artifacts/validation/ui-image-viewer-20261105/reboot-recovery-01/service-recovery.json)确认固定预览数据库/账号/CA四份材料逐SHA未变，临时环境则为重新导入同一19条真实内容及7条独立正文失败派生记录的新库。新HAP `8220a2ecc82b9e7f1236073316f9aace0245a08e6096526af3011c1c620b95d1`已取得官方构建/安装/启动日志和[五项真机runtime](../artifacts/validation/ui-image-viewer-20261105/reboot-recovery-01/runtime.json)；[包对照](../artifacts/validation/ui-image-viewer-20261105/reboot-recovery-01/package-comparison.json)48个ZIP成员中仅CA、配置序列化和symbolMap变化，ABC字节相同，不继承旧c789正常查看或视觉验收。隔离Host仅对新case2正式入场一次作准备，0答题/XP；不是Native入场复验。

[人工手势准备](../artifacts/validation/ui-image-viewer-20261105/reboot-recovery-01/manual-prepare.json)实际为`prepared_awaiting_manual`：新账号直接登录、该题两次GET200、正文真图及第2/3张100%原图已采，26项源码/参照绑定与历史正常采集相同，5项环境绑定显式更新。Root已亲看准备原图；查看器有意留在前台，退出/空输入等cleanup为false，不标成已清理。人工上下限、放大拖动和余指不误切问题已发出、尚待回答及终态采集；真实多指仍不标通过。SDK05/06失败与各自独立精确收尾、lint扫描覆盖数未证明的说明见[查看器记录](ui-image-viewer-2026-11-05.md)。

## 2026-11-04：入场与答题主链

本轮按[入场与答题逐点表](slice-03-gameplay-validation.md)顺序验证E0新手机环境、E1入场、E2取题、E3答题、E4进度及E5完成。每点先完成直板机和独立隔离后端验证再推进。未改动的原链路不重跑完整回归，折叠等专项后置。

| 业务能力 | 当前状态 |
| --- | --- |
| 新直板机运行环境 | 已恢复HDC/DevEco，通过官方自动签名为新手机重新安装启动；独立TLS及真实窗口检查已完成 |
| 入场及取题 | 已实现并完成直板机/隔离真实HTTPS验证，包含pending、未入场/未来题保护、真实失败与同命令重试、返回及GET恢复、退出后的实际迟到响应丢弃 |
| 文本答题 | 已实现并完成新直板机/隔离HTTPS验证：空白、真实键盘、pending、错答200、正确结算和只读答案；首次发现的UI快照滞留已修复并用新玩家完整复验 |
| 选择答题、处罚和答题重试 | 已实现并完成新直板机/隔离真实HTTPS验证：未选零POST、错答/正确、真实冷却到期、永久锁定及回访；503和提交后丢响应均以原命令重试且不重复结算，退出后的完整迟到答题响应被丢弃 |
| 进度及普通完成 | 已实现并验证服务端进度、上一题只读、手动下一题和autoNext、普通单题内联/多题官方完成弹窗、历史2/2与GET回访不重复提交或庆祝；护照经验区未单独重跑，终章/出口不在此次完成范围 |
| 线索/媒体/终章/出口/奖励领取 | 普通文字和图片线索见 [C01a](#c01a-普通文字与图片线索2026-11-11实施前)，组合线索的解锁、顺序、入口和回访见 [C01b](#c01b-组合线索2026-11-12)。正文外链见 [C01c](#c01c-线索正文外链2026-11-12)，普通视频手动播放及答后自动播放见 [C01f](#c01f-普通视频线索手动播放2026-11-12)、[C01i](#c01i-答对后自动播放视频线索)。非末题演出见 [C01j](#c01j-答对后的文字与图片线索演出)，普通末题完成演出见 [C01k](#c01k-末题普通线索完成提示与组合线索)。独立链接卡、开场演出、题面及选项视频、BGM、终章、出口和奖励领取另列。 |

具体包、源码和逐状态证据见本轮记录。此前首切片、资料头像、安全及底栏各自的历史验收保持原版本范围，不作为新增玩法通过的替代证据。

本轮一次性测试服务、DB、TLS及凭据state已精确清理；原固定预览DB、CA和口令保持，已重新启动并在新手机直接登录留在首页。交付包b4d5…与已验玩法包8cd…的ArkTS字节码一致，只切换预览配置；新包另有真实窗口/TLS及只读登录/列表验证。固定预览当前只有单道文本主链，选择及组合仍由本轮一次性玩家的独立报告证明。服务清理、原Host报告归档、交付包和息屏设置恢复见[本轮收尾](slice-03-gameplay-validation.md#环境收尾与固定预览交付)。

## 2026-11-02：底栏主题色光晕局部调整

仅检查官方 API26 底栏材质能力，不开展业务大规模回归。`LightEffectOptions.color` 已由官方全文和固定SDK核实，可使用现有主题色资源；选中SVG图标的微光仅在标准 `BottomTabBarStyle` 提供对应接口时接入，不替换底栏或自绘效果。

| 小点 | 本轮状态 |
| --- | --- |
| 触摸光晕随日夜主题色变化 | 已接入 `LightEffectOptions.color` 与 `app.color.accent`。新包官方构建/签名/安装启动、lint通过；夜间金色由Root查看实际按压原图确认，日间绿色由用户手动回复“能看到绿色光晕”确认。仅局部检查，未做业务大回归。见[本轮记录](bottom-bar-theme-light-2026-11-02.md) |
| 选中图标微光 | 标准SVG `TabBarIconStyle` 只有选中/未选中颜色，没有独立发光入口；按用户要求本轮不做，保持现有图标 |


核验日期：2026-10-30（Asia/Shanghai）。当前6a新包39项手机主轮与独立静态审阅已完成，独立预览新包另有13项直接登录及3原图已验，动态专项及预览重启/主动改密边界仍待验；下方实施前计划和首切片历史结果保留来源。2026-10-28曾追加系统区沉浸、空详情进度及键盘避让修复。本表把功能存在、代码实现、实际运行和视觉对照分开记录；列出验收项不等于通过。首切片修复后当时源码37/37业务测试及lint（0 issues、filesChecked=0）已实际复跑通过；迁移前真实HTTPS49项和沉浸调整前官方UI17项保留各自版本归属。独立1.3字号构建已42/42通过；正常字号HTTPS构建22/22系统UI与6项运行时检查通过，认证4图及主视觉18图captured且清理完成。最终默认mock另有13/13冒烟与4项运行时检查通过，已恢复设备；Web20与原生22图已逐图对照，保留两项非官方细节待调，不标逐字逐像素全过。旧正常字号22项UI与22图已归档为修复前证据，不借旧计数推定新HAP通过。完整结果见 [首切片验收记录](slice-01-validation.md)、[HTTPS及视觉复核](slice-01-https-and-visual-validation.md) 与 [官方ArkUI验证](arkui-system-validation.md)。

当前用户手验补充（2026-10-30）：用户在最终交付的 `c2fdc343…` 固定预览中，手动拖动浮栏启程↔护照并松手切换、打开头像侧栏，对“跟手光感、松手选中和侧栏进出方向是否符合预期”明确回复“符合预期”。来源见 `artifacts/validation/profile/native-ui-user-confirmation.json`。这三项从当前待验中移除；6a历史采集、静态及官方注入报告的原限制保留，不反向改写。此次没有新增自动化或Root动态目视，不扩展为触感、取消/中断、减少动画、双主题全覆盖、折叠、重启或主动改密通过。

## 本轮补充验收计划（2026-10-30，实施前）

用户要求继续任务1，并在收尾后处理预览账号及底栏体验。以下仅列计划，不代表已实现或验收通过；1a40/runtime09及既有报告继续保留原版本归属。

| 编号 | 小功能与逐状态验收 | 当前状态 |
| --- | --- | --- |
| PVIEW | 独立持久隔离PB/HTTPS；固定专用预览账号登录直接进入；重启保留数据；用户自行改密后不静默重置；预览不暴露故障控制，不使用生产账号 | 准备中；尚未启动、安装或手机登录验收 |
| NAV-IME | 真实键盘出现时隐藏浮栏及其命中区域；保留页面/表单实例与草稿；输入、滚动及主要动作可达；键盘关闭后浮栏恢复，返回不误切页 | 待实现及直板机实测 |
| NAV-ICON | 四个页签使用Web正式regular/fill矢量；未选中空心、选中实心；深浅色均清楚，暂未开放入口保持原页 | 待实现及深浅色目视 |
| NAV-LIGHT | 使用官方ImmersiveMaterial交互和触摸流光；先保留输入守卫，实测点击、拖动、松手及取消；没有官方跨项选择事件时不得自制坐标手势冒充系统能力 | 官方能力调研完成，未实现或实测 |
| MENU-SIDE | 保留官方沉浸玻璃材质，按头像实际位置左右侧入；Back/关闭/蒙层/菜单路由、滚动及账号退出逐项验证 | 补查确认官方PromptAction options-builder Dialog支持同材质及官方move转场；原Sheet SIDE的600vp限制不代表所有官方弹层都不支持。组合原型待应用、构建及手机验证，不自制模糊或手势 |

## 当前业务完成度与推进顺序（2026-10-30）

当前基础只读切片和任务1资料能力已有真实验证，6a手机导航/键盘/账户菜单主轮39项已通过；固定隔离预览的独立新包已13项直接登录及3原图通过并留在首页；动态专项仍单列，原生端仍不能完成一次冒险。下述范围来自实际页面及Repository接口，不以通过的测试数量折算整体迁移百分比。

| 业务部分 | 当前实际状态 |
| --- | --- |
| 登录、首次强制改密、退出及门禁 | 已实现并验证；凭据仅内存，尚不支持重启恢复登录 |
| 首页场次列表 | 当前/历史分类、状态展示、空态、错误/重试、刷新已实现并验证 |
| 场次页 | 仅开始前只读详情及状态/返回；开始按钮禁用，无入场或答题 |
| 侧栏/账户菜单与底栏 | 已接通启程/护照及账户菜单路由，收藏/来信明确未开放；6a已验首页右/详情左官方玻璃面板、关闭/Back/蒙层/滚动和退出，键盘隐藏/恢复浮栏；regular/fill两主题静态已核。当机官方注入松手选择4次已核；交付c2fd预览的跟手光感、松手选中和侧栏进出方向另获用户手验“符合预期”，仅当前实际场景；触感、取消/中断、减少动画及双主题动态全覆盖仍未验 |
| 个人资料 | 昵称草稿/校验/真实保存与失败恢复、头像Picker/可调裁剪/真实上传/受保护显示、普通改密与未知结果恢复已实现并有1a40真实链路证据；6a另验表单/IME/Back且不写业务，裁剪预览取消宿主回归已独立10项及两原图review，仅取消不扩写新包上传链。实际并行切到另一凭据账号的头像竞态仍未验 |
| 入场与答题 | 入场、取题、填空/选择、多题导航、判题/冷却/锁定、进度和完成结算均未实现 |
| 线索、剧情与媒体 | 文本/图片/视频线索、信纸/祝福、BGM/配音/视频、完整演出与中断恢复均未实现 |
| 奖品与来信 | 奖品列表/领取信息、通知列表/未读弹窗/已读写入、星海信笺均未实现 |
| 后续原生能力 | 安全持久登录、桌面卡片、Push未实现；不计为已迁移的Web业务 |

按用户最新优先级，后续按手机业务模块拆小片推进：补齐正式导航及账户/资料功能 → 入场与答题完整链路 → 线索、剧情、媒体、奖品与来信逐点迁移 → 直板机完整回归。每一小点先核契约和逐状态要求，再实现、构建/业务检查、真机操作及隔离真实请求验证，不把空页面或仅编译成功记为完成。

折叠、悬停、分栏及窗口变化专项（V05）放到主体功能迁移完成后再用模拟器/对应设备逐个验收；当前保留官方组件和响应式实现边界，不为这些未执行项阻塞手机业务迁移。既有测试和截图继续证明对应小切片，不能代替尚未迁移的业务。

## 任务1实施前检查点（2026-10-28）

用户已授权先执行手机导航、侧栏与账户资料模块。实现前逐点表和实际结果入口见 [任务1验收](slice-02-profile-validation.md)，边界见 [ADR-016](architecture-decisions.md#adr-016手机账户导航资料草稿与头像资源边界)。本段及顶部实施前逐点计划保留开始本轮的历史；上方业务能力表已按2026-10-30实际范围更新，本轮结果单独分版追加，不改写首切片证据。

小点依次核对：手机导航与侧栏/护照入口、资料加载和只读账号、昵称草稿/保存/错误重试、系统选图取消及校验、用户可调裁剪与受限输出、multipart上传及受保护头像、后续改密和不确定结果恢复、退出清理及原手机链路回归。奖品/来信业务、入场答题、剧情媒体及安全持久登录不因菜单出现而计完成。折叠/悬停/分栏专项延后，不阻塞当前直板机功能迁移。

### 任务1执行结果追加（2026-10-30）

手机账户菜单、护照资料、昵称草稿/保存、头像选图裁剪及后续改密代码已加入；当前有部分实际手机/隔离HTTPS通过证据，任务1尚未整体验收。共享 `StarwardPassport`已补齐与Web一致的护照标题、等级名/Lv、XP/RANK、进度、下一等级名及菜单紧凑经验信息；`Player.extraDisplay`兼容清洗与原文展示已实现，非空扩展已分别取得正式管理派发/严格HTTPS /me的Host证据和base30de实际截图label/text目视证据，仅覆盖本次一条扩展。ArkTS/Hvigor已实际构建成功，最新业务测试72/72、失败0、忽略0，见 `artifacts/validation/profile/local-test-summary.json`。base30de曾有Touch调试hilog高频调用1 warning/filesChecked=1，保留当时归属；新1a40候选移除后，当前 `profile/lint.json` issues/errors/warnings/suggestions均0、filesChecked=0；该字段只数报告路径，不能单凭它推定覆盖。原日志另有35个输入路径证据，见下方lint-native-evidence说明，不作交互通过。

旧演示HAP `b51702dc…` 的runtime4项、未完成mock UI，以及旧隔离HAP `090f75d0…`、`2da7204e…`、`2a52d1e3…`各自runtime/失败尝试保留，不继承到新版本。底栏“护照点击收藏跳回启程”已由日志、坐标和用户手动复现；先click0/will3→0、再click1/will0→1被拦截及迟到0回调的唯一根因仍未确认，不推广为所有API26设备行为。

按[ADR-017](architecture-decisions.md#adr-017官方浮动tabs输入事务与业务路由隔离)采用真实Touch输入事务：观察整个Tabs，只有官方页签will/click产生pending，只提交最终原生索引，取消/外部路由/销毁清待提交，根gate/返回栈再门控，保留官方命中、材质和动画。HAP `0f799c58…` 的 `profile/navigation-input-probe.json`7步触摸导航passed仅属于旧版有限探针；base30de完整core中也已实际验证收藏/来信的底栏及菜单入口不进入空页且保留资料。无Touch的外设键盘/读屏页签激活目前被明确拒绝，属于已知不支持的路径，不只是未验证，也不属于折叠专项。菜单Button有替代导航入口，不等于底栏辅助功能或正式可访问性完成；该缺口单列，不阻塞当前手机Touch业务切片，未来须实现并独立实测。

旧base官方安装的HTTPS HAP为 `30de19566545126979d3cfa2a779f2a258d17ace101bfa9be5e5f7296af58683`，`profile/runtime-08.json`6项passed，`profile/attempts/base30de-base-hap.json`冻结旧HAP/ABC/源码SHA。`profile/profile-save-probe.json`在同版4项passed，核实真实JSON保存、服务端trim、/me回源及无真实编辑时保存提示保持。`profile/ime-back-probe.json`的4项则属于旧HAP `03e562ab…`，证明先Back关闭实际IME、再Back回首页及退出空字段，不混作30de同版计数。

当前 `profile/device-profile-acceptance.json`在2026-10-29T04:22:40Z实际passed/count34，原字节SHA-256为 `9a6b2059c62e5231947d5137c4b6dd1b28ad58768a0c956c7397c93c75dc6e4b`，同30de/runtime-08。本次fresh reset完整新run确实执行首次强改密，无旧检查继承；真实覆盖菜单/底栏、P1昵称IME可达/空白校验/草稿、P2 JSON保存与回源、P3注入延迟/503及显式重试、S1错误旧密和单次普通改密200/字段清空/新密重登入，以及原详情返回关系。该core的faultNeutralised和loggedOut均true；不代表全部测试环境已清理。S2同版最新独立完整initial→new实验已13项passed，报告SHA `a578628c26ec6ced5d7dee3388993463f8210930855ee144d9e8aa835c5c9395`，明确绑定core SHA `9a6b2059…`。实际单次上游POST200后丢响应，未知结果持续可见，原始UiTest核实密码/资料写入禁用且没有重放，退出后Host及手机新认证确认目标密码、恢复资料使用，最终空登录且cleanup两true。此前incomplete3为CLI省略enabled及类型误读，独立反向实验incomplete7为离屏退出按钮驱动未seek，均归档、无checks继承；每次改密均为新的显式实验，不是自动重试。同版supplement已22项passed，报告SHA `5a65db540e7245bd634fffcb908403465e1c347e639b7625b39dbe0108d9ca9d`，明确绑定runtime-08/core34/S2-13。实际覆盖昵称40字符原生上限、未保存草稿离页无写、子页及整个护照离开清三密码、当前/历史、一次官方Refresh恰一新GET200，以及深浅主题动作后的资料数据/控件可达；恢复followSystem，logout/主题恢复/无资料改密写三项cleanup均true。CLI未暴露的菜单/主题辅助功能选中态仍not_observable，不等于正式可访问性或目视对照完成。

非空extraDisplay的 `profile/profile-extra-seed.json`已Host passed，checks数组9项、无count字段：仅唯一自有一次性容器内，经正式管理definition/preview唯一目标/dispatch/inspect，再用玩家严格HTTPS /me核exact tuple且原身份/头像/等级等事实不变，手机实际展示另见 `profile/extra-display-ui-review.json` passed（SHA `956789298399b9792fe29efc93ae80949ede2c0a1008d9d09b6153b9a3e61821`），绑定base30de和实际原图，Root核准精确label/text；不扩写全部扩展边界状态。`profile/response-gate-host.json`的29项为Node v24.14.1下的合成代理工具行为检查，不是业务或手机通过，该29项只记当时的工具准备；后续真实gate激活和独立15秒迟到结果另列，不改变此Host范围。头像base30de真实运行已到20项但incomplete（报告SHA `0f42a91a77475a2f8b2d9dadd8bffacf485b13b7c3ee71a933fa2fdaf29d8e28`）：已验Picker/裁剪取消与pending保留、真实multipart503→200、512方形JPEG≤200KiB/无EXIF/中心裁剪MAE、文件403两token且200恢复不注销、503持久错误。其后自动化请求点击头像重试却回启程且没有新GET，恢复未完成。旧事件日志仅证明index0路由，缺少点击点；旧30de缺点击坐标，唯一根因仍待确认，不能把“内容触摸触发phantom0”写成已定事实。新1a40首次probe由 `profile/avatar-retry-hit-geometry.json`仅测量passed确认：retry rect[67,2580,391,2729]px、计划点[229,2654]px落在真实NativeTabBar rect[106,2531,1214,2721]px内，旧viewport[0,415,1320,2848]px遗漏浮栏避让。测量没有发送retryclick（报告SHA `c0087e63…`、cleanup两true），只证明新probe的驱动遮挡，不倒推旧30de原因或算barModifier失败。驱动已按profile-scroll实际祖先统一避让bar，独立crop/menu保持自有viewport，修正后同1a40的 `profile/native-bar-content-probe.json`已9项passed（最新SHA `9c3a314a548fa2620f8b41b6d95f8f2a44e596da767d88a416e3f694c3160f6d`）：内容retry实际新GET200且保持资料，四次收藏/来信保留护照，启程/护照切换及内容滚动/昵称焦点正常，cleanup两true。旧S2仅提供当前密码key并经Host重新确认身份，不继承其业务checks；不扩写外设键盘/读屏或完整头像验收。该9项原字节d044另存attempts/native-bar-content-probe-09-before-provenance.json，最新仅补源SHA/命令/原mtime完成时间，并未重新执行或增加检查。core34/S2-13/supplement22仅保留各自实际覆盖，不能移到新HAP。

此前旧头像目视阶段已查看7张原图并以私有回执绑定SHA，核实profile/menu四象限头像、调整裁剪及取消保留可见pending；当时Crop Button/Slider默认蓝未接品牌token，是固定Web对照确认的真实差异，不属官方材质批准差异，保留该发现的旧版归属。新候选已修品牌token和高频debug日志，源码修正不替代新图目视。新1a40候选HAP `1a40c0caffc46d64e0b81e9ccb92f2c7d6b69830bb73bf1f2ed5f02651a761cb`已实际build/签名/安装，采用官方barModifier仅bar Touch及父索引对齐；72/72业务测试、lint零问题/filesChecked=0、runtime-09六项passed。候选初次probe遮挡定位为驱动，校正后9项Touch专项通过；新完整core已同版34项passed（SHA `ef049839ce0c0def220e901ebcdb0fb07aba5d7f63ec2a3ac4d03fd7d61ca8d1`）、新S2已13项passed（SHA `5dceb457c4e475f0c20075978d01f9dd29fcfa811ab3613a760b88320ac07407`），均绑定runtime-09并cleanup两true；core为fresh reset实际首次强改密，S2为独立initial→new一次丢响应实验，不继承30de checks。新supplement已同版22项passed（SHA `0376e3986d0e64f08c2d398a91cc05c7ba6f6e61bbce1e850a1f691ea547b880`），明确新runtime/core/S2依赖，logout/主题恢复/无profile或password写三cleanup true；三份09日志均0退出，不借旧22。1a40 Avatar新attempt已基础28项passed（SHA `5f410842bbc7953e9ca3be9ca113c25f52becac726ed751f7499adebe349c18b`）：实际Picker/可调裁剪与取消保留、multipart503→200、512方形JPEG29980bytes/无EXIF及中心裁剪MAE、403一次换token/503显式重试、真实200损坏图解码持久错误与精确恢复后手动GET200、普通退出/Back/重启，以及Root新原图SHA目视。旧30de incomplete20仍按原版归档，不继承为新检查。独立迟到文件logout已在15秒变体通过6项，实际切另一账号并行头像读取仍未验，不把基础或变体通过写成全部A4通过。同版原生逐状态Web配对已完成独立reviewed，当时保留NAV-ICON/NAV-IME/NAV-LIGHT待新refinement；后续6a独立结果另列；本轮旧环境最终清理已由下表三份报告独立完成。“退出后迟到200”已完成独立private 15秒变体与真实hold/release，报告及来源工具见下表；不计base2秒通过，也不继承到新UI包。旧Web6图保留原归属；新 `profile/web-profile-visual.json`已passed共8图（identity/security/menu/crop深浅，SHA `b51d6bf904dfb6dc60085b19143e1005f8815242f0fa759ca651460cf225e10b`），Root现已逐张查看Web8/Native12/crop4共24张原图，独立结论另见下段visual-review。browserUsesRealBackend=false，使用只读快照/实际头像字节本地回放，不代替原生功能、真实写入或最终配对通过。

新run前65份旧文件/报告/私有图已按 `profile/attempts/evidence-archive-20261029T051741266386Z.json`保存original→archive和SHA映射，避免同名输出重写使旧来源失真。当前 `profile/base-hap.json`已冻结1a40 signed HAP和34份源码精确副本，旧base30de manifest另存attempts；上述旧报告SHA按档案核验，不迁移为1a40通过。首切片历史未改。

同1a40/runtime-09的真实格式补充已各8项passed：JPEG EXIF6报告SHA `f1f19918535ed60b3098b7e7ccfd51c20b0fc2e2004188db50662abc4095f844`，实际规范化顺时针90°后中心裁剪，512方形JPEG33069bytes/无EXIF，正确MAE4.870021而忽略方向84.884430；WebP RGB报告SHA `d0202724a15894dfede7c55a0881caaa589baa75b68fbbe7b9ca652c916d7942`，512方形JPEG31401bytes/无EXIF，中心裁剪MAE5.083350、错误整图拉伸23.316803。均为实际Picker→原生裁剪/唯一multipart200→新token/文件GET200→Host只读回源，依赖新core/S2/Avatar SHA且logout/空登录两true，不扩写alpha WebP或其他全部方向。

同1a40/runtime-09视觉基线现已完成：`profile/native-profile-visual.json`passed/12图，SHA `4c639ff60ccaae87a1482327161838d0eed9bde8904bb68fd8198c127455d6aa`，全部actualThemeVerified=true、三cleanup true；`profile/native-avatar-crop-visual.json`complete/4图，SHA `05ed5b63f2093ebb0d4d4e2f29e0d98361f32154cc24a579cb6b782d7437ecee`，两主题各5cleanup true、PATCH及改密写入增量0。采集层的crop themeVerified=false/visualReview=pending不改写，由独立 `profile/visual-review.json` reviewed（SHA `44fcc1457a8ae83df5fc9f7dd1c5aaa1a7a6f60df1d0ac5f24adc2866b049ca1`）绑定三份来源并承接Root亲看24原图/8组配对的结论。品牌、文案、权威资料与可达操作已核对；官方材质/手机Sheet/三Slider裁剪布局为批准差异，NAV-ICON、NAV-IME、NAV-LIGHT仍pending_new_refinement，不声称零差异、完整动效或新包通过。5180回环viewer已准备并启动24PNG，私有manifest `artifacts/private/profile-comparison/review-20261030T023133491575Z/manifest.json` SHA `3812ef0edf591f77b3070585bfc817babb03f42f9d9d761e03720ec9e130e179`，旧5179保持首切片归属。

2026-10-30恢复时，Host严格HTTPS可达而手机登录连接中断，实际官方reverse映射为空；Root仅恢复自有18443到既有TLS监听，未改其它映射、账号或配置。`profile/network-resume-20261030.json` SHA `d9bd1926fb8f4f87881205e97690c41da90e0101e7a6966189529256c997bb8c`记录phoneHttpsRecheck=passed_actual_native_login_profile_and_crop并绑定新crop SHA。旧light中断stage与网络失败已归档，新fresh light另取证，不改旧结果。

尚余触感、取消/中断及减少动画等专项观察，以及固定预览停止/重启持久性及用户主动改密后的专项验收。最终测试媒体、旧一次性服务/DB/CA/凭据及映射已由独立报告完成精准清理；当机官方注入的松手选中已独立验证；交付c2fd后的用户手验另确认跟手光感、松手选中和侧栏进出方向，其他动态边界仍未验。固定预览已有独立状态修复、Host、新包runtime六项、手机直接登录13项及3原图审阅，可交付直接预览；停止/重启和主动改密后的专项行为尚未实测，不把整组PVIEW边界或任务1动态全部标通过。任务1不标最终完成，入场、答题、剧情/媒体、奖品与来信仍未迁移。 输入兜底拒绝两轮与独立15秒迟到已完成，顶部实施前计划保持原状，当前状态以上方能力表及下方分版证据为准。

### 2026-10-30收尾证据与当前待验包

| 版本/范围 | 当前可核事实 |
| --- | --- |
| 1a40输入拒绝 | 同1a40/runtime-09的50MiB+1 PNG与GIF两轮已真实选定精确自有URI并点击官方完成，均落到原生错误Sheet：有效裁剪预览缺席、确认禁用、类型/大小文案精确对应；每轮7项cleanup true，未发资料PATCH或改密POST。`profile/avatar-input-oversize-png.json` SHA `5032ba4124f1f695209a29cce2088453bd23101681eb2f28a6a832499f8153aa`，`profile/avatar-input-unsupported-gif.json` SHA `95923a9e6a55a0be0ba3b58e8c283d828ef20a77cf415171abf3a579587577e4`，各有1个实际边界检查。Root分别亲看错误Sheet，独立review SHA为dd1ffe5f…/a166d70d…。通过的是App兜底拒绝与恢复，原Picker过滤not_observable不改。 |
| 1a40视觉基线 | Root已亲看Web8/Native12/crop4共24原图、8组配对；visual-review为reviewed并绑定1a40/runtime-09，NAV三项新refinement仍pending。不计6a新包视觉通过。 |
| d03独立15秒变体 | 独立15秒变体HAP `d03bd895ed5ef220b48126186b3502925bb9ec94f72c4aa617174b11e93f42a4`已构建签名安装，`profile/runtime-late-15s.json`六项passed（SHA cb226514…）；`profile/device-profile-avatar-late.json`实际passed/count6，SHA `44f27226a1cb1804251b355b212148e410ee2dfe085ed772d312480855655ec9`。先在同变体完成正常原生头像GET200和实际退出校准，再hold精确SHA的真实文件200，观察空登录后release，下游finish且无client abort；响应结束、Back/Ability重启及冷启动仍为空登录，旧资料/头像/菜单缺席。gate中恰1次原生受保护文件GET、0次Host文件读取，5项cleanup全true。finish仅代表TLS下游写出，不是解码回调；不覆盖真实切到另一账号，也不将2秒base或后续UI包记为同版专项通过。 |
| 来源工具 | `profile/hap-timeout-variant-host.json`实际passed/23项，SHA `81c96c7b31787aac356714020376ec27b8a7199388744cf8e8c4834c552a329f`，仅为离线来源验证工具：34份源码、ABC和CA字节一致；除integration timeout由2000改15000外，仅symbolMap的1173条完整唯一记录重排，保留所有键和值，其余打包条目一致。严格校验及反例不忽略symbolMap、不重打包signed HAP，不计业务、签名有效性或UI通过。实际变体安装/runtime来源另见 `profile/late-variant-hap.json`（SHA b762fbe4…）。 |
| 6a最终导航UI包 | 当前final-nav HAP `6a5232af434e2fed8d6d56b50e25f7bf86b7cf24de22bd6523bdc79f23d5ad90` 的新主轮 `profile/device-native-ui-refinements.json` 已实际passed/count39，SHA `67f2c8d7a2deb0d2cd6f2bf42d7a1da50c6be1be01fad8755d292e245fa5e1ba`，绑定runtime-ui-final-nav六项与final-nav manifest `830e4aa0…`。本次driver为 `a90202ddf49f69d42538b2cc73c1e601981944c35b1340aff7e6e71fee6b00ad`；六项cleanup全true，真实profilePatch/passwordPost增量各0，旧UI检查未继承。覆盖正常登录、启程/护照及未开放入口保留原页、首页右/详情左官方面板的关闭/Back/可见蒙层与返回、主题/退出，以及昵称和密码键盘、草稿与Back行为。该主轮不保存资料、不改密、不入场答题。 |
| 6a实际键盘可用区 | 昵称与密码均观察到命名IME窗口，但两个IME根均为全屏矩形，已明确拒作键盘几何。可用区取同页无IME基准AppRoot `[0,132,1320,2848]` 与实际RESIZE后的根：昵称 `[0,132,1320,1788]`、密码 `[0,132,1320,1606]`，保持原点/宽度且真实缩短；报告的imeWindowBoundsPx/imeWindowHeightVp为null，缩短量不称IME高度。原始UiTest核实浮栏无可见或命中目标，完整52vp动作位于真实可用区；收键盘后浮栏四项恢复，昵称草稿及三密码保留，后续离开护照清密码，均无资料/改密写。 |
| 6a独立静态与动态范围 | 独立 `profile/native-ui-root-visual-review.json` 为reviewed_static_with_explicit_limits，SHA `32725c37417962cbe7403c0a5c4b99f95c6f74fcab4b3dae74c133d8e37abb51`，严格绑定本轮39项报告。Root亲看13张原图：12张可观察；密码焦点1张App内容黑，不计像素、布局或主题目视通过。两主题底栏及菜单的regular/fill选中态、首页右/详情左最终位置、官方玻璃与原内容、昵称键盘下浮栏隐藏/完整保存及收起后草稿均已静态核实。静态图不证明跟手流光、松手跨项选择、入退场方向在运动中正确或中断/减少动画行为；松手选择由后续独立官方注入记录承接，其余动态范围继续单列。1a40的24图保持其基线，不替代本轮，也不反向改写旧报告。 |
| 6a独立官方注入选择 | 独立 `profile/native-ui-refinements-drag.json` 保持status=observed、stage=gesture-finished-root-review-pending，SHA `7918b8195b740f9f519124645bae43209fbb2720cd759c992ab9ea5594db4c70`，绑定同6a/runtime/A902。6个实际阶段正常退出，swipe与原生预长按drag各正反方向共4次观察均实际落到目标启程/护照，原生最终索引0/3并记录click→will→intent→param→change；未自制产品手势，也未补点目标。六cleanup全true，资料/改密写增量各0。Root另亲看4张终态原图，选中fill与目的地一致；独立 `profile/native-ui-root-gesture-review.json` 为automated_native_release_selection_verified，SHA `7fa8311e8715adad8660624d4eee76af41f167d134004fa7de22612a8353f731`，verifiedOutcomeCount=4，review自身newCommandsExecuted=0。结论仅为固定API26当前手机/6a的官方注入松手选中结果，不是人工操作通过、所有平台能力或回调总顺序保证；跟手移动光感、触感、未抬手/取消/中断、减少动画和入退场运动仍未目视或专项验收。 |
| 6a独立裁剪预览取消 | 当前6a独立 `profile/native-ui-crop-cancel-regression.json` 实际passed/count10，SHA `c9f8bf03aa11d5bda6dad1a27da65bdc1cf1ab00cfba1ee310e17bcce7f86fcb`，绑定39项主轮67f2…、同HAP/runtime和私有助手adf8dca9…。实际exact自有PNG选择并点击系统Complete，原生方形预览无错误，随后只取消：无pending、昵称与头像经新HTTPS读取保持不变；8项cleanup全true，资料/改密写增量0。Root亲看两张新原图，独立 `profile/native-ui-crop-cancel-root-review.json` 为reviewed，SHA `7ed3eea195b6e2837df80d11888120e73de245137077ed7240fc6b4082e199ab`；源采集报告visualReview=pending保持原样，由该独立review承接目视。范围只为当前SidePanel宿主兼容的真实Picker→裁剪预览→cancel，不确认、不上传，不扩写全部裁剪控件安全区或6a重新跑过1a40完整上传链。恢复follow-system仅记录动作/控件和无错误，选中辅助属性不可观测，不作动态跟随系统主题通过。 |
| 驱动工具11项 | 驱动的11项AST隔离检查已passed，仅验证几何拒绝边界及重复cleanup先清旧标志/写入增量：私有 `artifacts/private/ui-resize-viewport-driver-draft-20261030T045823893635Z/offline-guard-check.json` SHA `705ebfa9a47604681d0e1afbaa5d19473b23cdb25803b5bdeeb3f87f8143af1a`。它没有设备/网络/服务或业务执行，不并入39项或业务完成度。 |
| 旧UI尝试及USB恢复 | 旧193b/6a的incomplete10、首aa失败的incomplete0，以及在旧IME几何门禁中断的incomplete21均独立保留，完成cleanup不改功能状态。count0归档 `profile/attempts/device-native-ui-refinements-20261030T044247730768Z.json` SHA52d9a5e6…；count21归档 `profile/attempts/device-native-ui-refinements-20261030T050029215328Z.json` SHA `b328a858ad8cecbf657a4675466268b7feee1cd7f1411be99eb6caae96ec45e9`，二者六cleanup全true。USB重接后只恢复精确自有reverse且严格Host200，`profile/network-resume-reconnect-20261030.json` SHA c10b847b…保留该恢复事实；新的A902 run独立开始，不继承旧checks。 |
| 原lint独立解释 | `profile/lint-native-evidence.json`（SHA `df12779b2c2214c13ae78e5918d2454513d0ed9982164bcddba53bb7df534ca2`）解释原11:31固定工具链执行，不是新lint或新增验收：原 `lint.json` 仍0 issues/filesChecked=0。Studio先过滤无缺陷文件，CLI统计剩余报告路径，因此该字段不是输入扫描数；原ArkPerf FileCount35及HPAuditor的35条唯一路径与当前35文件集合一致，独立证明当时处理这些输入路径。报告中的当前源码SHA仅绑定本次说明时的字节，不作当时逐文件SHA的回溯证明。原日志“文件不存在”定位为扫描后临时规则文件unlink ENOENT，具体缺哪一个未记；默认配置按官方分流跳过ESLint，HPA的12项安全规则flag启用，而ArkPerf独立registry的InvalidRule不等于全局规则失效。零缺陷不作安全认证或逐规则覆盖证明；未改配置、旧日志或原结果，也未重跑。 |
| 固定预览 | 固定预览已完成真实seed、正式首次改密及显式状态修复，后续直接登录实测已通过，账号已可供审查。首次因Docker stdin缺少`-i`失败，经业务写入0核验后显式恢复prepared；第二次seed和改密成功后，PB0.40.1拒绝删除唯一superuser，保留initializing而未重放。随后 `profile/preview-initialization-reconcile.json` 实际passed，SHA `75ba302cacd5bf9fa5fca9764b92542bd8afdb961efdf12d57db9228724df5c3`：官方CLI对同一bootstrap身份换成不保留的随机密码，password hash/tokenKey均已变化，27个game表逐值与SHA一致、玩家口令/CA不变、seedReplayed=false，核验后才标complete并补回原IDs。最终runner `61059c59de2ec4fc964ee01566557dca7e31fc1535d19ae0559529f6897b0460` 的唯一记录退役及镜像immutableID/逻辑tag/arm64校验已静态复核。`profile/preview-environment.json` 已取得host_ready_native_pending（SHA `87b37b96a5f15571577b21c6d4edcd33cd26acd9f3161a205233c6bf6d7b517c`）：正式玩家直接登录verified_direct_login，独立CA可信200、不可信及错误主机名均拒绝，不开放玩家故障/重置接口；该原报告保持Host范围。新预览HAP `c2fdc34356a6176953fac806157b7c82ac513345575f8368f95524cea8b7408b` 已经官方run构建签名安装，`profile/runtime-preview-final.json` 六项实际passed（SHA `77f6f84e2894cc376594a62afc02dc43af54559bc739fd2584eb0c08612d9527`），包括真机API可信CA接受及不可信/错误主机名TLS_ERROR、系统区透明和深浅内容色。独立 `profile/runtime-preview-freshness.json` passed（SHA `eff6a1351013ebb908bebabbb8062318a0acfa7b3c48fe702d3732143c6860a2`），以当前自有进程的7条原始记录核window/material/TLS/双主题与原报告相同，不保存设备/进程标识，不改原runtime。新预览包的 `profile/preview-native-smoke.json` 已实际passed/13项（SHA `c63aed805a9c218a0589366a623fe91a8d0bfd5b9acb2da16315978307054751`）：固定普通账号从空登录直接进首页，真实四类场次、权威资料/只读账号、菜单Back、显式退出空输入及第二次直接登录均已核；四项收尾全true，第二次会话有意留在已认证首页供用户审查。独立 `profile/preview-native-root-review.json` 为reviewed_static（SHA `467dcc5b64f2a1b70b14900dfc96638e75742330adece9dcb7d29ef068d36cff`），Root逐SHA亲看3张原图，已停止手机自动化。此13项只认证/读取/导航/退出，不重跑资料、头像或密码写链，也没有服务端写台账计数结论。固定账号直接预览现已可交付，服务收口时仍运行且Host直接登录再次验证；需电脑保持唤醒、Docker运行、手机USB连接。独立 `profile/preview-package-source-binding.json` 为offline_binding_verified（SHA `19cf9511b823b3e4d19e1327dadef825ed068eda74ab7443cd3da3cade8bede8`）：35份源、8个导航SVG和包内ABC与6a逐字节相同；48个ZIP成员集合相同，45个内容字节相同，实际仅独立CA、完整1226条symbolMap记录重排及integration JSON空白/fontScale `1.0`→`1` 序列化变化，JSON值/顺序相同且timeout均15000。新signed HAP独立600归档，旧包/报告未改；不解析或归因ZIP之外的签名块。它只作离线来源绑定，不继承6a主轮39项为新包通过。停止/重启持久保留及用户改密后的行为也未因此完成实测。 |
| 公开文件扫描 | `profile/public-artifact-scan-pre-ui-resume.json`本轮实际passed，973个公开候选文件、0发现、0读取错误，SHA `85f9d649242febf9c5b01a3bacd24b684a29e292ec4eb9c4803b07a5ed977744`；本次未提供known-device，不扩大为已覆盖特定设备标识的扫描，也不代替最终环境清理。 |
| 固定预览公开凭据补扫 | 补充 `profile/preview-public-secret-literal-scan.json` 实际passed（SHA `27f446cbc316df9babf3a1895ef376e0abd34fb57bf5c638d401043184615dbe`）：998个Git-visible文件、2个仅内存读取的预览口令/控制token字面量，发现0、读取错误0，来源文件均ignored/mode600；不把值写入报告。最终公开范围扫描以 `profile/public-artifact-scan.json` 的最新执行为准，不在文档嵌其滚动摘要；前述973文件扫描仍是pre-UI历史检查点。 |
| 最终清理 | 本轮旧一次性环境清理已取得三份独立实际报告：`profile/owned-avatar-media-cleanup.json` passed（SHA `7ed276e89d9009f876cf02977b3866d4d08801e8fdc047f86f81389fe5ab9f7f`），仅5个自有测试媒体逐个新读回SHA核验后删除exact URI及各2个精确临时导出，查询均0；`profile/isolated-services-cleanup-final-complete.json` passed/9项（SHA `c4962d816368ed43fda23c8f8b462c2d318a27faf8c91b87447e0b73408ddd55`），旧TLS/gate/backend进程、监听、reverse、一次性容器/DB及运行凭据状态均已消失，其他映射保持不变；`profile/isolated-private-material-cleanup-final.json` passed（SHA `0f7ac7ad37a9ef4b073350f21f9fb0daebdf26542169c7d7b61f1f408a6f0d5a`），8份旧TLS备份材料逐SHA删除，只留非secret清单/恢复日志，持久预览目录之外的旧私钥文件为0。先前三份stop preflight均incomplete、checks为空且未请求官方stop，历史保留；最终服务报告自身不宣称备份已清，由后一份材料报告承接。没有宽泛Docker/目录删除或系统信任/签名修改，固定预览DB/CA/登录文件独立保留。 |

具体逐状态结果和版本归属持续回填 [任务1验收](slice-02-profile-validation.md)。测试数、准备脚本、部分断言和截图数量均不作为整体迁移完成率。

## 冻结基线与证据边界

| 对象 | 本次实测 | 含义 |
| --- | --- | --- |
| Web 工作树 | `/Users/sitkin/my_code/questions-web`，`main`，干净；HEAD `4b7d1a0a00051ac630e459b0fd6c074f821d7455`，提交时间 `2026-10-27T09:59:24+08:00`，标题 `feat:pwa适配` | 原生首切片冻结的本地正式入口源码候选；本地跟踪的 origin/main 包含该提交，不代表刚刚查询过远端 |
| 后端契约 | `/Users/sitkin/my_code/sitkin-pb-backend-management/backend/contracts/game.ts`；HEAD `c28f488d6b682ae213713ccdd2d992595a941ae3`；该文件 SHA-256 `7264d8e16a65a64c8de8f39088327647bdfb5c1c635cb9393ebf80ae085c43bf` | DTO 权威。Web `src/api/game.contracts.ts` 为生成物，运行校验在 `src/api/game.schema.ts` |
| 本地既有 dist | `dist/version.json` 为 `0.0.0-local`、`channel: local`，commit `671c062210a3564335ad7be8f3f5a28352f573a4`，builtAt `2026-10-27T01:54:57.939Z` | 早于当前 HEAD，不能作当前视觉或正式发布证据 |
| 生产版本探测 | 无凭据 GET `https://sitkin.top/questions/version.json` 返回 HTTP 403 | 本轮未能确认线上 release commit。不得把当前 checkout 声称为线上同版；未读取私人业务数据，未执行生产写操作 |
| 视觉与交互基线 | 冻结源码390×844深浅12图、同Noto字体12图已捕获；迁移前391×777登录配对及认证4图留存 | 历史登录主要控件纵向差小于0.6vp、星中心差约0.41/0.09vp；旧主页等18项捕获仅incomplete/count5，键盘图主题校验失败。以上是历史截图证据。已批准的原生材质和系统动效差异按下文验收准则处理。详见 [视觉对照](web-native-visual-comparison.md) |

正式路由权威是 Web `src/app/App.tsx`：`/login`、`/`、`/profile`、`/rewards`、`/notifications`、`/play/:id`、`/play/:id/content/:contentId`。旧 `?qa/?qas`、独立 Letter/Bless、clearCache 和编辑器预览不属于本次玩家正式入口；正式解锁剧情中的 letter/bless 仍须迁移。PWA 安装机制由原生安装机制承接，无需复制浏览器 Service Worker。

后续发布基线确认应保存 production `version.json` 与对应 git commit 的核验结果；若与本表候选不同，明确差异清单后调整。不得静默换基线。

## 原生体验验收准则（2026-10-27、2026-10-28更新）

按 [ADR-013](architecture-decisions.md#adr-013官方-arkui-组件与沉浸光感优先)，保留品牌、文案、业务语义和既定信息布局，通用容器、材质、反馈及动效优先采用官方ArkUI并封装于 `ui/`。Web继续决定业务、布局和逐状态对照；官方沉浸光感、浮动容器及平台交互是已批准差异，分别记录实际支持、降级和设备表现。

每个 UI 切片在实施前列出冻结 Web 实际生效的动效及其触发状态。ArkUI 能实现的随切片还原，并用直板真机连续画面对照。按该切片实际范围记录触发、进出场、循环、中断和系统「减少动画」下的表现。平台能力差异、暂缓项及未实测状态写入对应验收项。操作成功和静态截图分别作为交互与布局证据，动效通过以实际动态证据为准。详见 [starward-ui-parity](../.agents/skills/starward-ui-parity/SKILL.md)。

顶栏布局保持，使用官方Navigation及真实通用沉浸材质；底栏采用官方浮动Tabs，分类采用Tabs/SubTabBarStyle，Sheet、Refresh、Toast和动画使用相应原生能力。首页移除固定同步块，列表延伸到浮栏下方，原句“场次与进度会自动同步，放心去探索。”作为自然滚动内容的最后一项，只保留浮栏和安全区所需间距。Refresh动画独立持有UI状态，不能与 `vm.listBusy` 双向绑定或由动画结束驱动业务写入。

2026-10-28按 [ADR-014](architecture-decisions.md#adr-014系统避让区只约束内容背景与材质延伸到屏幕边缘)追加系统区沉浸：状态栏和底部手势区透明，背景与材质延伸到屏幕边缘，仅交互内容按真实避让区留距，不放独立白/黑占位块、不隐藏系统栏。当前HAP来源为 `native-system-visual-hap.json`，准则与窗口版本必须同时匹配 `arkui-system-v1 / edge-to-edge-v1`；后续字号或mock构建另存产物摘要，不覆盖该来源。

按 [ADR-015](architecture-decisions.md#adr-015真实业务事实与页面级键盘避让)，详情ID为空时不绘制默认进度；认证页使用官方页面级 `KeyboardAvoidMode.RESIZE`，按实际App/Scroll/IME交集验证字段和完整主按钮可滚动到达。旧构建实测404仍显示“0/0”，1.3字号密码IME下主按钮仅露46px且继续滑动无变化；这两项缺口不能由旧报告的通过计数抹去。

沉浸调整前官方系统UI17项通过报告在 `artifacts/native-pre-edge-to-edge/`；修复前 `2b757938…` 构建的系统UI22项、认证4图和主视觉18图在 `artifacts/native-pre-final-fixes/`，其 `archive.json` 明确不计当前验收。更早的Web近似布局图在 `artifacts/native-legacy-pre-system`。正常字号最终HAP为 `3bacb424…`、viewRevision为 `authoritative-progress-and-keyboard-resize`；独立1.3字号HAP为 `fdda3840…`，不得互换。官方组件提供的窗口适配能力单独记录，折叠、悬停、分栏和窗口变化须有对应实测，不因选用了官方组件而标通过。

## 首切片范围

首切片是“登录 → 首次强制改密 → 主页场次列表 → 一个场次的开始前详情”。允许以可辨识的本地 mock 构建打通，HTTPS 实现使用同一 Repository 契约。答题、领取、通知、剧情及完整媒体不在本次实现范围，保留下一切片入口边界，不能显示为已经完成的业务能力。

如果为了完整演示包含“开始”写操作，必须另行满足 B09/B10 的幂等和返回结果验证；只有详情只读时不要用点击后本地改成 active 冒充服务端已开启。

下表未明确标注修复后版本的“真机已验”，仍指迁移前49项或已注明的历史设备报告；最终版本结果须附匹配HAP、viewRevision及窗口版本的报告。

| 编号 | 触发/逐状态 | 必须保留的行为与可观察断言 | Web/后端证据 | 原生验收证据 |
| --- | --- | --- | --- | --- |
| A01 | 未登录启动或直达受保护详情 | 转登录；不闪现私人内容；合法待前往路由可恢复；不能跳至外部 URL | `GameContext.tsx`、`GameLoginPage.tsx` | 真机已验：HDC Want冷启动 `starward://assignment/<id>` 进入登录/强制改密，门禁前无列表或详情请求，真实改密成功后恢复原目标；有限ID/拒绝外链另有Routes测试。未宣称生产App Links域名关联已验证 |
| A02 | 登录空账号/空密码、输入/显示密码 | 输入标签、密码显隐、键盘遮挡；空值不发请求；帮助说明账号由管理员提供，无注册 | `GameLoginPage.tsx`、`e2e/game-pages.spec.ts` | 历史真机空输入不发认证POST已验。修复后1.3字号42项验证账号/密码焦点、完整CTA在实际IME上方可滚动到达、无键盘区手势，并用非敏感探针核验密码显隐；探针不发认证请求。普通账号IME有截图，密码焦点只用脱敏UiTest几何，不计主题截图通过；实际读屏语音另验 |
| A03 | 正常登录及重复点击 | POST 账号 trim+lowercase，密码保持原值；请求中禁用；只有 auth 返回与 /me 均通过结构验证才完成登录；密码不持久化 | `game.client.ts`、`game.client.test.ts` | 真机已验：带首尾空格及大写账号登录，认证延迟下双击仅一条POST；auth及/me验证后进入门禁。请求台账确认原token且无Bearer；身份不符与迟到响应另有Repository/ViewModel测试 |
| A04 | 账号错误、网络错误、超时、503 | 原位错误，可再次提交；不进入主页；保持有用输入；不会把 HTML/空成功体当正常 DTO | `game.client.ts`、`e2e/api-errors.spec.ts` | 真实错误密码400与注入认证503均原位显示错误；18秒注入延迟已触发配置2秒的原生超时，并经后续新GET200恢复。代理错误体业务回归已过；改密丢响应另见A08，不将注入当生产故障 |
| A05 | /me 响应缺字段/错类型 | 明确契约错误；不得展示半截私人内容或接受未校验玩家 | `game.schema.ts`、`e2e/api-errors.spec.ts` | 真机已验：本次auth200后，带认证的/me实际消费注入200畸形DTO，显示精确契约错误且不读列表/详情；缺字段、错类型、身份不匹配另有Contract/Repository测试。该畸形体是故障注入 |
| A06 | mustChangePassword=true | 强制展示改密，主页/详情/深链受同一门控；可退出；系统返回不能绕过 | `GameContext.tsx`、`PasswordPage.tsx`、`e2e/quest-flow.spec.ts` | 真机已验：首次改密前无列表/详情请求；系统Back及实际边缘返回不能绕过门禁；改密后恢复原深链。强制页显式退出后账号/密码为空，仍回登录门禁 |
| A07 | 首次改密的无效输入 | 当前/新/确认密码有标签；两次不同、长度或 UTF-8 字节越界、与旧密相同均不进入成功状态；服务端仍权威 | `PasswordEditor.tsx`、后端 `api.js:changePassword` 与 `rules.js:password` | 真机四类输入已验且无改密POST：过短、新旧相同、确认不一致、UTF-8超限；完整长度边界由Domain测试覆盖。服务端真实旧密码校验另见A08 |
| A08 | 改密成功、旧密错误、响应丢失 | POST 只发一次且不自动重试；成功替换 token/player 并清空三个密码输入，解除门控；失败留在改密；响应不确定时允许重新登录确认 | `game.client.ts`、`usePasswordEditor.ts`、后端 `api.js` | 真机已验旧密错误单次POST、成功改密后恢复详情；明确注入“真实写已200完成后丢响应”，原生不自动重放，退出后新密码登录确认成功。5xx/4xx文案及token代次另有Local Test；故障注入不称生产网络故障 |
| A09 | 退出、401、账号切换期间旧请求返回 | 清 token、玩家数据、头像 file token、路由与旧账号缓存；旧请求成功/401 不污染新账号；退出后回退仍不可见私有页 | `GameContext.tsx`、`game.client.test.ts` | 迁移前强制页/菜单退出、Back及Ability恢复门禁、真实停用/me及详情401清理已验；最终正常字号22项再次验证Sheet退出清输入与私有内容，Back不能恢复主页，cleanup两项true。修复后1.3字号另验退出清空输入；跨账号/迟到响应及旧401隔离另有业务回归；头像file token未接入原生UI |
| H01 | 主页正常数据 | 原文案、玩家昵称/等级/经验；待赴之约只含 assigned/active；旅途回响只含 completed/cancelled，计数正确、顺序遵从后端 | `GameDashboard.tsx`、`PlayerPassport.tsx` | 真实隔离列表已验七态分类/文案及后端顺序；最终正常字号22项重新验证Navigation标题、分类历史空态、首次头像Sheet及Back关闭，报告绑定3bac构建。最终同账号Web/原生两主题图已目视核对；编号栏菱形位置/轻微重叠待调，见V01 |
| H02 | 首次加载、空列表、失败及重试 | 对应加载、两类不同空文案、错误可重试；不把错误显示为空列表 | `GameDashboard.tsx`、`GameState.tsx` | 真机已验两类独立空文案：历史空态与真实归档测试session后的当前空态；注入列表503保留旧列表，显式重试由本次新GET200恢复，不把错误显示为空列表。加载帧另随视觉记录 |
| H03 | 七类场次状态 | completed→故事已解开；cancelled→旅程已撤回；过期→已过开放时间；未开始→静候启程；等级不符→等级暂不符合；active→探索进行中；可开始→可以出发，按源码优先级 | `game-presentation.ts:assignmentState`、`AssignmentCard.tsx` | 七态均已在真实隔离记录上逐个定位状态Text并精确验文案；active/completed/cancelled通过专用assignment真实状态切换验证。优先级及时间/等级边界另有Domain和条件反转证据 |
| H04 | 时间变化、后台返回 | 时间窗变化后重新计算；前台恢复回源；已知详情 serverTime 时使用偏移，不把本地时间当准入权威 | `GameDashboard.tsx`、`GamePlayPage.tsx` | 真机已验后台再前台实际发出新的/me请求，详情同步可在暂时失败后恢复；serverTime偏移已实现、时间边界有业务测试。没有人工修改系统时钟或宣称已覆盖所有时钟偏差 |
| H05 | 首页滚动、手动同步和浮栏重叠 | 列表延伸到官方浮动Tabs下方；原同步句为滚动内容末项且可完整露出；官方Refresh独立管理UI动画，触发本次真实回源且不阻断并发门控 | 用户2026-10-27更新、ADR-013；Web保留文案与信息布局 | 最终正常字号22项重验：Scroll底2848px到物理底，末句2419–2473px完整在浮栏顶2531px上方，浮栏交互项2544–2707px在手势区上缘2754px之上；无固定同步块，Refresh一次新成功GET，503保留列表且由新真实GET恢复。独立1.3字号末句2401–2471px与浮栏安全几何另有42项证据 |
| B01 | 点击场次卡片打开一个 assigned 详情 | GET /assignments/:id；展示标题、描述、题数、等级范围、开放/结束时间、进度及开始前说明；返回保持主页分类和合理位置 | `AssignmentCard.tsx`、`AssignmentBrief.tsx` | 迁移前真实GET详情200、只读投影及返回已验；最终正常字号22项重新验证NavDestination标题、开始不可用及实际边缘返回。独立1.3字号另验只读开始控件完整可达及Back回主页；最终两主题真实详情已与同账号Web参考逐图核对 |
| B02 | 详情未到开放时间、过期、等级不符 | 正确原因；开始禁用；过期提供回首页；客户端仅展示，后端最终控制 | `AssignmentBrief.tsx`、`e2e/game-pages.spec.ts` | 时间/等级业务边界及四类列表状态已验；当前开始按钮保持只读并解释范围。最终主视觉含等待/过期/等级不符各深浅两图，来源为真实隔离玩家成功GET，均themeVerified，已与对应Web逐图核对；这不扩写为全部交互/动效通过 |
| B03 | 详情 401/403/404/410/SESSION_OFFLINE | 不继续展示被撤销的缓存私人题目或空模型默认进度；明确错误和返回/重登入口；409 SESSION_OFFLINE 也属致命资源错误 | `isFatalGameError`、`e2e/api-errors.spec.ts`、ADR-015 | 历史终态清旧DTO及真实401回登录保留。最终3bac主视觉中明确注入404的深浅两图authoritativeProgressHidden=true，空模型“0/0”已消失；两主题各自重试实际GET200且authoritativeProgressRestored=true。注入不是生产业务故障；旧2b缺口图保留归档 |
| B04 | 后台同步短暂失败 | 有旧有效数据时保留页面，显示同步中断；恢复后更新；不得把短暂失败等同注销 | `GameContext.tsx`、`GamePlayPage.tsx`、`e2e/api-errors.spec.ts` | 真机已验注入列表/详情503时保留旧有效数据，显式重试必须由本次新GET200恢复；后台返回触发回源，18秒延迟触发原生超时后亦能重试。没有把旧卡片可见等同于新请求成功 |
| B09 | 可选：开始请求及超时重连 | POST /assignments/:id/start {requestId}；一次用户命令固定原账号/内容/requestId，重试沿用；阻止连续点击；按返回 assignment 更新 | `game.client.ts`、`GamePlayPage.tsx`、`e2e/api-errors.spec.ts` | 超出只读详情，若实现则待验证 |
| B10 | 可选：进程中断后的开始结果不确定 | 回源 detail 确认；不能生成新 requestId 盲目补发；未持久化命令不得宣称恢复同一命令 | 后端幂等契约、预研风险 4 | 超出只读详情，若实现则待验证 |
| V01 | Web布局参考、小屏ArkUI、键盘打开 | 品牌、文案、信息布局及状态对应；主要CTA、字段、错误不被裁切；记录实际像素、vp、字体/字号和安全区，官方材质/反馈差异另列 | `e2e/game-pages.spec.ts`、`tokens.css`、`game.css`、ADR-013/015 | 最终Web20/原生22图已逐图核对，主配对18/18、故障2/2、原生普通账号IME2/2，绑定3bac HAP及新窗口；1.3字号另有42/42可达性证据。结论为已对照、两项非官方差异待调：编号栏菱形在原生顶部与01轻微重叠而Web在底部；404按钮“重试”对Web“重新尝试”。主要信息/入口与恢复语义保留，但不标逐字逐像素全过，也不归入官方材质批准差异 |
| V02 | 深/浅/系统主题 | 暗色金/黑、浅色绿/白语义色和同一信息层级；系统变更有响应；官方材质随系统能力与主题降级 | `GameThemePicker.tsx`、`tokens.css`、`e2e/theme.spec.ts`、ADR-013 | 原生冷启动日志实测supported=true、ENABLE(1)、IMMERSIVE(2)、EXQUISITE(0)。最终3bac认证4图与主视觉18图全状态深浅PNG的themeVerified已核，并完成Web逐态目视；系统主题动态跟随、禁用或不支持设备降级仍另验 |
| V03 | 系统返回、手势、读屏、大字体、减弱动画 | 合理路由栈，改密不可绕过；可访问名称及选中语义；焦点/输入、对比度、目标大小；使用系统动画并响应减少动画，动画中断不改业务结果 | `e2e/accessibility.spec.ts`、`global-motion-plan.md`、ADR-013/015 | 修复后独立1.3字号42/42已验登录/强改密字段和IME下完整CTA、密码显隐、帮助、浮栏/末句、详情Back及退出；runtime实测fontScale1.3，未改系统全局设置。最终正常字号22项重验Sheet Back、详情边缘返回及退出后Back门禁；49项强改密门禁保留原归属。实际语音读屏、连续录屏、减弱动画设置无通过证据 |
| V04 | 官方顶底栏、分类、Sheet和短反馈 | 顶栏保留品牌/标题/操作布局并采用Navigation及真实官方材质；底栏官方浮动Tabs；分类Tabs/SubTabBarStyle；弹层/Toast用官方反馈且不掩盖持久错误 | 用户2026-10-27更新、ADR-013、固定API26声明及官方指南 | 官方能力已实现；最终正常字号22项重新验证Navigation/分类/Sheet、未开放目的地拒绝跳转、浮栏和返回/退出，绑定3bac构建。材质支持有最终runtime日志；Toast/通用动效完整视觉、减少动画及降级继续单独验收 |
| V05 | 窗口、折叠、悬停和分栏 | 按实际窗口/容器断点及避让区布局；内容和操作可达；分别记录官方组件能力与硬件结果 | 项目规则、ADR-013、官方Navigation/Tabs能力 | 当前仅有上述手机窗口参数；折叠、悬停、分栏及窗口变化无对应通过证据，不能由采用官方组件推断 |
| V06 | 系统状态栏与底部手势区域 | 背景/材质延伸至物理边缘；系统栏透明且保留显示；图标随实际主题保持可读；标题、浮栏和末句按实际避让区保持可达 | 用户2026-10-28更新、ADR-014、固定API26窗口能力 | 最终正常字号HAP的6项runtime及22项UI均通过：fontScale1、immersiveLayout=enabled、两栏alpha=0、深浅系统内容色白/黑；标题动作避让131px顶部区，浮栏交互项在手势区上缘2754px之上，Scroll到物理底2848px，末句完整可达。全状态视觉继续另取证 |

表中 Contract、Domain、Repository、ViewModel 及 Routes、Environment 指 `entry/src/test/` 中同名 Hypium 套件。37/37是修复后最新源码实际复跑的Local Test总数，0失败、0忽略，不是37项UI验收；原始test_result已重新生成。lint的issues/errors/warnings/suggestions均0，filesChecked=0照实保留；两项执行前后捕获HAP仍为3bac且SHA未变。沉浸调整前17项设备检查单独计数。迁移前真实HTTPS49项含1项主机配对数据准备，并非49例Hypium/UI测试。报告保留core20→core28的SHA检查点链，仅继承28项已确认core断言，重新执行故障恢复及后段；不声称单次不中断全过。

H03 的展示优先级：completed、cancelled、endsAt≤now、startsAt>now、仅 assigned 的等级限制、active、ready。对于 active，等级变化不应单靠客户端重新锁场；请求仍须服从后端。

## 首切片真实 HTTPS 契约

基地址由本地打包的受控配置提供，Web 默认 `https://api.sitkin.top`；原生缺省为明确标识的mock，配置存在但无效时禁止登录。本轮真实联调使用一次性PocketBase测试玩家和严格USB HTTPS，不请求生产玩家；启动/隔离/清理见 [隔离环境](isolated-https-environment.md)。所有业务请求的认证为 `Authorization: <token>`，没有 Bearer 前缀。错误规范为 `{error:{code,message}}`；PocketBase 原生认证错误可能只有顶层 message，需要安全映射，不能依赖业务 error 嵌套一定存在。

| 操作 | 方法与路径 | 请求 | 响应及验证要点 | 重试约束 |
| --- | --- | --- | --- | --- |
| 登录 | POST `/api/collections/game_players/auth-with-password` | `{identity: account.trim().toLowerCase(), password}` | `{token:string, record:{id:string}}`，随后使用新 token GET /me；校验 player.id 与登录记录一致可额外防御 | 不跨账号重放；不得记录密码/token |
| 玩家 | GET `/api/questions/v1/me` | Authorization | `GamePlayer`：id/account/displayName/avatar 字符串；mustChangePassword 布尔；totalXp 非负整数；level 为 GameRank；nextLevel 为 GameRank/null | 读重试可限次；401 仅清同一身份 |
| 首次及后续改密 | POST `/api/questions/v1/me/change-password` | `{oldPassword,password,passwordConfirm}` | `{token:string,player:GamePlayer}`；新密码 10～71 字符且 UTF-8≤72 字节；两次相同且不同旧密；服务端旧密校验 | 禁止自动重试；丢响应视为结果未确认 |
| 主页列表 | GET `/api/questions/v1/assignments` | Authorization | `{items:GameAssignmentSummary[]}`；status 仅 assigned/active/completed/cancelled；maxLevel 数值或 null；日期为空串合法 | 可限次读重试 |
| 详情 | GET `/api/questions/v1/assignments/{encodeURIComponent(id)}` | Authorization | `GameAssignment` 扩展 summary：presentation、completionTarget/null、currentIndex、clues、levels、serverTime；question=null 在未解锁时合法 | 可限次读重试；致命错误清当前资源 |
| 受保护头像（有头像时） | POST `/api/files/token`，之后 GET `/api/files/game_players/{id}/{avatar}?token={fileToken}` | body `{}`，主 token 请求 file token | `{token:string}`，头像 URL 分段编码；刷新临时 token；token 不写日志、不跨账号复用 | 需单独覆盖过期/切换；没有头像不能伪称已验证 |

GameAssignmentSummary 的字段为 id、player、session、status、order、startsAt、endsAt、startedAt、completedAt、previousAssignment、title、description、minLevel、maxLevel、completedLevels、totalLevels。GameRank 为 id、order、name、minTotalXp、visualConfig，另有可选 defaultName/customTitle。DTO 边界允许未知兼容字段，但已消费字段必须逐项校验；不能用裸 JSON.parse 类型断言代替校验。

首切片若暂不渲染完整 GameAssignment 扩展字段，应说明投影范围，保留后续解码入口；不得把该投影宣称为全量契约迁移。

## 全功能后续验收范围

| 编号 | 业务能力与逐状态 | 原生验收目标 | 源码/现有用例 |
| --- | --- | --- | --- |
| P01 | 资料：昵称读取、草稿、JSON 保存、失败与重试 | 草稿不被同步覆盖，保存后回显；昵称服务端权威 | `GameProfilePage`、`ProfileEditor`、`e2e/game-pages.spec.ts` |
| P02 | 头像：选图、无效类型、超大、裁剪、取消、压缩、multipart 上传 | 原生系统选图/裁剪；压缩方图≤512、≤200KB 的 Web 目标对照；后端上限 2MB；失效 file token 续取 | `avatar-image.ts`、`AvatarCropDialog`、`e2e/game-pages.spec.ts` |
| P03 | 后续改密及退出 | 保留本表 A07/A08/A09；成功状态文案和输入清空 | `PasswordEditor`、`game.client.test.ts` |
| Q01 | 单题/多题、填空/选择、锁定未解锁题、前后导航与返回位置 | 后端返回 question 决定可看题；本地不得恢复旧判题/解锁逻辑 | `GamePlayPage`、`QuestCard`、`e2e/quest-flow.spec.ts` |
| Q02 | 空答、正确、错误、already_completed、并发及重复点击 | UI 输入校验只防空，正确性、XP、奖励、进度由响应决定；答题 requestId 原样重试 | `game.client.ts`、`e2e/api-errors.spec.ts` |
| Q03 | 冷却、永久锁、时间偏移、到期、后台恢复 | 计时依据 serverTime；进程恢复回源，不能把本地倒计时完成当权限恢复 | `GamePlayPage`、`session.test.ts` |
| Q04 | 自动下一题、手动下一题、答对演出、中断/离开/重启 | 演出状态与业务完成状态分开；不能重发已成功提交，允许安全中断与恢复 | `useGamePresentation`、`session-presentation.ts`、`question-ui-preservation.md` |
| C01 | 普通/多题组合线索：文本、图片、视频、链接、题目/场次来源 | 解锁与组合来源来自服务端；旧返回结构兼容只按已验证规则；自动播放顺序与手动重开一致 | `clue-presentation.ts`、`MultiQuestClueDialog`、`e2e/desktop-clue-video.spec.ts` |
| N01 | 解锁剧情：缺权限、读取失败、letter 开合/分页/全文/滑动/音频 | 统一路由门控；原生文字排版、翻页与中断；保护未解锁内容 | `GameNarrativePage`、`LetterExperience`、`letterPagination`、`e2e/bless-flow.spec.ts` |
| N02 | bless 粒子、配音、BGM、片尾、再次访问与退出 | 原生绘制/媒体；生命周期显式暂停/释放；不因回放重新结算 | `features/bless`、`features/completion`、`global-motion-plan.md` |
| R01 | 奖品：loading/empty/error/available/redeemed/voided | 私人领取信息只归本人；状态、数量、核销与快照来自服务端；客户端不提供伪核销 | `GameRewardsPage`、`makeRewards` |
| M01 | 来信：未读弹窗队列、关闭/收下、标已读、归档、关联场次 | 已读写成功后更新；去重及账号隔离；定时同步按前后台生命周期控制 | `GameNotificationCenter`、`GameNotificationsPage`、`e2e/mailbox.spec.ts` |
| M02 | 星海信笺：已解锁信件/祝福、旅途终章、重开 | 只聚合有权读取的服务端内容，保留返回场次关系 | `features/mailbox`、`star-letters.test.ts` |
| T01 | 主题、安全区、导航/抽屉/弹窗、toast、媒体缩放、大字体 | 逐个状态截图和真机可访问性验证；系统返回关闭顶层，焦点合理恢复 | `ui-system.md`、`e2e/mobile-layout.spec.ts`、`e2e/accessibility.spec.ts` |
| T02 | 浮动 BGM、语音/视频抢占、静音偏好、拖动、后台/焦点中断 | 平台媒体适配有状态机；前后台及音频焦点安全处理；账号隔离偏好 | `BgmControls`、`useQuestBgm`、`e2e/music-control.spec.ts` |
| F01 | 后续 Form Kit：未登录、摘要、离线、刷新、点击 | 进程隔离持久化摘要；私密字段裁减；退出清卡片；统一鉴权深链 | 预研“卡片预留”，需官方版本核验 |
| F02 | 后续 Push Kit：token 注册/轮换/解绑、消息/点击、去重 | 后端绑定和发信；收到消息回源；推送不成为事实源；统一鉴权路由 | 预研“Push 预留”，当前没有等价 Web 推送能力 |

以上是首切片冻结的后续范围表，不自动等于当前全部未实现。P01/P02/P03在任务1已有分状态实际证据，详见本表执行结果追加和对应报告；其余业务仍按各切片验证。每次须明确本次覆盖编号，未覆盖状态不因入口或部分通过而算完成。

## 夹具、文案和视觉输入

- 首选 `questions-web/e2e/fixtures.ts:mockStarwardApi`：玩家 `playeralice`/`alice`，昵称“远航者”，等级“初见”，totalXp=0；场次 `assignment1`/`session1`，标题“星辰探险”，描述“解开谜题，发现惊喜。”；`mustChange` 开关可覆盖强制改密。未开启时 levels.question 为 null，是合法服务端权限状态；mock 仅验证 UI，不证明后端事务/权限。
- `questions-web/src/test/game-fixtures.ts` 提供护照、场次摘要、奖品和通知展示夹具；`e2e/session-preview-fixture.ts` 可参考复杂场次，但编辑器预览不属于首切片路由。
- 文案权威：`src/config/ui-copy.ts` 的 common、authLayout、gameLoginPage、passwordEditor、gameDashboard、gamePresentation、assignmentBrief、assignmentCard、gameLoadingScreen。登录标题“以你的名字，\n开启冒险。”，按钮“进入冒险”；强制标题“首次登录，请先修改密码”，按钮“保存新密码”；主页标题“下一段故事，等你落笔。”，分类“待赴之约”“旅途回响”。不要重新撰写近义文案。
- 品牌色与布局参考：`src/styles/foundation/tokens.css`；暗色 canvas `#10110f`、surface `#151612`、text `#e7e6e1`、accent `#d4bc7d`；浅色 canvas `#ffffff`、surface `#f7f9f8`、text `#293c38`、accent `#187b69`；Web控件高52、圆角10、面板圆角18、间距4/8/12/16/20/24/32/40/48/64记录为输入。通用容器、材质及反馈按官方ArkUI策略验收，批准的平台差异另列。CSS px不能无条件等同物理像素，ArkUI使用vp/fp并记录实际尺寸。
- 现有品牌位图位于 `public/branding/`，包含 starward-icon 和 starward-mark 多尺寸；优先复用原图，勿新造品牌。`CelestialAtlas` 可参考其参数用原生 Canvas/Shape 重写，无需引入 WebView。

## 实际验收记录要求

每次运行记录时间、构建产物摘要、IDE/SDK/API、模拟或真实数据源、设备系统 API（不公开设备 ID）、用例编号、命令和真实通过数。Hypium/UiTest 必须检查报告及非零用例数；CLI 包装器成功或编译成功不等于 UI 验收成功。

视觉证据至少覆盖登录、首次改密、主页两类、详情可开始/等待/过期/等级不符、错误、键盘打开；每组保存深/浅主题Web与ArkUI配对截图，核对布局、文案和状态，并独立记录官方材质、反馈与动效。迁移前证据归档保留，新官方容器须补浮栏/滚动末句、Refresh回源、Sheet/Toast、材质降级及返回门禁。动态/生命周期至少录制登录到主页到详情返回、系统返回无法绕过改密、网络中断恢复；完整动画验收在相应切片补录。没有对应截图、真机操作、网络或录屏报告的条目继续标待验证。

本轮只读 questions-web 和后端源码，没有修改二者；没有执行其 pnpm 发布门禁，也不把历史报告计入本次鸿蒙验证。

## 分阶段真机回填

2026-10-27的历史模拟13项、Local Test37项、真实HTTPS49项（含1项主机配对数据准备）、主机HTTPS25/25和原生TLS三项握手分别保留。沉浸调整前官方UI17/17验证了容器、Refresh/503恢复、浮栏/末句、Sheet和详情返回及退出清理，已归档；这不等于2026-10-28最终沉浸版通过。

最终正常字号HAP `3bacb424…` 的冷启动6项检查与22/22系统UI通过，认证4图及主视觉18图captured；各报告绑定同一HAP，来源JSON原字节SHA已核对。UI cleanup两项true；认证仅一次UI改密且响应200已确认，cleanup三项true。主视觉newCapturedCount=18、resumedFrom=null，为全新单次完整捕获，场景恢复/退出/故障中和三项true；404两主题隐藏默认进度且真实GET200恢复进度。最终Web20/原生22已目视核对，来源配对18+2+2；保留V01两项非官方差异待调，预览14项HTTP与22状态图片加载检查单独通过。修复后的独立1.3字号HAP `fdda3840…` 已42/42通过，runtime来源SHA匹配；cleanup确认新密码、恢复singleReady、退出均true，cleanup无额外改密。跨日后旧隔离控制场景请求失败，原因未确认；仅重建一次性数据库和随机玩家，保留同CA、HTTPS入口/玩家代理端口和冻结后端，已验证新控制场景及严格HTTPS健康200，见 `edge-isolation-recreated.json`。原生产与源仓库不受影响。

最终默认mock经 `scripts/hm.sh run` 构建/签名/安装/启动成功，HAP为 `82baeefc…`，不打包integration配置或临时CA；实际fontScale1、全屏与透明系统栏的4项runtime检查及13项UiTest冒烟均passed。报告为 `native-mock-installed-hap.json`、`native-mock-runtime.json`、`device-smoke.json`；28份App源码SHA仍匹配 `final-source-checks.json`，该mock流程不计真实HTTPS或最终22图的来源。

环境收尾已passed：先核自有runner的UID/argv/工作目录，再停止自有TLS和一次性后端；专用USB映射、临时CA/私钥目录、数据库、1个自有容器、实时状态与扫描后的3份私有检查点已移除，四个自有loopback监听及Web基线服务已关闭，未改无关容器/映射。冻结无凭据DTO与安全视觉viewer保留，viewer仍在本机响应200。`public-artifact-scan.json` 最终扫描814个公开候选文件，敏感命中0、读取错误0；覆盖旧/新隔离凭据、仅内存传入的设备标识、解码JWT形状、PEM私钥头和签名扩展名，两处PRIVATE KEY拒绝校验引用另列。原Web和后端工作树改动均0，清理证据为 `isolated-environment-cleanup.json`。

Web原始12图、同字体控制12图已冻结；迁移前登录配对及认证4图保留，旧主页18项捕获仅incomplete/count5且键盘图主题校验失败，归档为未完成证据。首次改密Web参考只消费真实改密前/me快照，未请求场次或执行浏览器真实改密；其余本地回放同样仅作视觉输入。原生实际网络由TLS及请求台账证明。生产release commit仍因403未确认，公网/生产联调未执行。

2026-11-05人工手势续验：[manual-finish](../artifacts/validation/ui-image-viewer-20261105/reboot-recovery-01/manual-finish.json)已为`captured_manual_finish`、五项cleanup均true。用户手动确认100%～400%上下限、放大拖动及余指不误切正常；仪器实际终态为第2/3张、400%、水平−60.2vp/垂直195.7vp，随后官方单指复位到100%/零偏移，关闭后保留同一真实输入实例/草稿，零答题/XP。Root亲看准备、放大和复位三张原图，见[root-manual-review](../artifacts/validation/ui-image-viewer-20261105/reboot-recovery-01/root-manual-review.json)。上下限/余指全过程属于用户手验，终态、复位、关闭及退出属于采集证据，不改写为自动多指注入；Viewer专属失败/重试和加载中取消仍待验，完整查看器仍未标全通过。

## 2026-11-05：下一小点——选择选项与选项题图（实施前）

本点按已确认UI尺度还原冻结Web `4b7d1a0a00051ac630e459b0fd6c074f821d7455` 的 `ChoiceOptions.tsx`、`QuestAnswerForm.tsx`、`quest.css` 和手机媒体查询；不调整判题、处罚或提交命令协议。当前原生仍有额外Radio圆点、圆角和字级/间距偏差，尚未显示 `option.imageUrl`。以下为实施和验收目标，全部待新产物验证，不继承旧选择主链或正文图片的视觉结论。

| 状态/范围 | 实施目标与实际验证要求 | 当前结论 |
| --- | --- | --- |
| 未选与选中 | 官方Radio完整内容定制，移除额外圆点；手机竖列间距10，方角1边框，文字头部最小58、内距上下8/左右14、字母列40与28方框，UI正文16；选中为accent边框/淡底、左3内线、字母反色，保留Web微位移和反馈并服从减少动画 | 仅源码/官方API核对，待实现、构建、真机与日夜原图对照 |
| 同数据选项图 | 使用同一真实case1：A/B/C各一张已登记原图，D无图；手机选项头下方全宽130高、Cover裁切、顶部1分界，不套正文Contain及340上限；无图选项不留空图框 | 参考fixture和字段已核，Native加载、几何及视觉均待验 |
| 单选与图片命中 | A→B→A实际只选一个，字母和边框即时随V2事实变化；图片是Radio的兄弟原生Button，选B后点A图只打开A自己的单图查看器，不改选中答案，不组成A/B/C图集；关闭保原选择与真实节点实例 | 待直板机操作、原始树/PNG与隔离台账验证 |
| 禁用/已完成 | Web的fieldset同时禁用Radio和图片Button：提交pending、永久锁定、冷却、已完成均不得选答或打开选项图；完成态展示服务端lastAnswer。原生沿既有ViewModel权威门控，禁止用DOM式事件阻断代替正确兄弟结构 | 先核新切片实际覆盖状态；未覆盖冷却/锁定不能借历史业务测试写成本轮UI通过 |
| 图片资源与账号 | 每张缩略图独立使用现有有界loader；源/关卡/账号变化取消，迟到释放，不恢复私密图；loading及失败用既定小尺寸原生反馈，retry与图片共同服从disabled；原始媒体URL/凭据仍仅private | 实现与本点实际失败/重试边界待验；正文404、Viewer待验项不代替新缩略图状态 |
| Refresh与返回 | 同题真实Refresh后选择和已就绪缩略图/Radio实例保持；查看开关零start/answer/XP；本点退出后私密选项/查看器不存在 | 待新包直板机、隔离HTTPS与台账；不重复未改动的旧主链大回归 |
| 对照范围 | 376vp、字号1、同真实题目和选中状态，分别保存Web重放与Native真实加载原图；复核文字换行、列宽、间距、边框、Cover来源及两主题选中可辨性。视频优先播放语义仅保留数据边界，播放继续后续切片 | 构建、lint、业务、原生交互与视觉分别登记；不声称折叠、全页或媒体播放通过 |


### 2026-11-06：选择图完成态的颜色修正目标

真实完成态同数据原图发现，官方禁用Button会同时压暗其子Image；Web仅禁用交互，三张缩略图保持原色。另有选中左线覆盖Native缩略图边缘、Web被缩略图盖住的差异。本次只调整照片与Button的绘制层、选中线绘制顺序：同一PixelMap的Cover图保持原色，原生Button仍实际disabled，完成后不能开图；可编辑时原生Button仍只打开自己的单图且保留答案；保持尺寸、字母、主题、账号边界和请求行为。新包的正常点击、只读原图及真实禁用状态仍待独立确认，不重提已完成的答案。

### 2026-11-06：选择选项与选项题图实际验收

| 范围 | 结果与证据 |
| --- | --- |
| 直板机正常/选中、选择图 | [Native04](../artifacts/validation/ui-choice-options-20261105/native-normal-04.json)的8项检查通过：深浅主题中A/B/C有图、D无图框，四个原生Radio互斥；选B后点A只开单图，关闭和返回保留原选择。滚回顶部再下拉只产生一次新GET 200，控件/图节点保持；退出清理、零答案及XP。 |
| 真实答题/完成/历史重进 | [完成01](../artifacts/validation/ui-choice-options-20261105/native-completed-01.json)仅提交一次，服务端结算一条完成记录及50 EXP，四个Radio与三个图Button禁用。报告仍为incomplete；随后独立[历史重进](../artifacts/validation/ui-choice-options-20261105/native-completed-reentry-01.json)从「旅途回响」验证两次GET 200、原凭证/经验保持，未再写入。 |
| 同数据深浅对照 | [正常原图复核](../artifacts/validation/ui-choice-options-20261105/root-delegated-normal-final-review.json)已逐图检查本点布局、裁切与选中可读性。完成态对照发现原生Button连子图变暗；新包将图和点击层分开，选中线只露在文字头。 |
| 新包定向复验 | 官方构建、签名安装启动与lint通过。新包在原已结算账号上[检查两主题三图](../artifacts/validation/ui-choice-options-20261105/native-photo-color-completed-01.json)，颜色保留、按钮仍禁用、两次GET无新结算；用另一隔离玩家[确认可编辑图仍能打开](../artifacts/validation/ui-choice-options-20261105/native-photo-color-active-01.json)，关闭保留同一选择，零答题/XP。 |
| 待验/后续 | 本点未捕获提交中状态；冷却、永久锁定、缩略图失败/重试/取消无本点真机结论。查看器失败/重试/加载中取消、填空输入、提示/反馈、答题顶栏显隐、媒体播放和折叠屏不在本点通过范围。 |

构建与报告归属详见[选择选项小点](ui-choice-options-2026-11-05.md)。固定预览恢复只做直接登录和读列表，单列[恢复回执](../artifacts/validation/ui-choice-options-20261105/fixed-preview-restored-01.json)，不计隔离答题写入验收。

### 2026-11-06 填空输入实施前

冻结 Web `4b7d1a0…` 的 `QuestAnswerForm` 在手机上用单行、全宽、透明方角的 line 输入框。用同一真实填空题对照，预检 Web 内容宽314px、输入高58px、左右内距2px、字号18px、单行居中、仅1px底线，题面到表单24px。实触聚焦后底线变为主题色且上移1px，输入外圈出现2px主题色轮廓，外偏移3px。完成态禁用并保留服务端答案。提交区与反馈另按对应切片核对。

| 状态 | 本片目标与验证 |
| --- | --- |
| 初始与编辑 | 官方 `TextInput` 保留无障碍“答案”名称和服务端占位文字。日夜核全宽、字级、透明背景、底线与输入焦点，保留系统键盘和文字编辑。 |
| 键盘与草稿 | 实际 IME 出现时，可在应用真实可用区到达输入与完整提交按钮。系统返回收键盘，保留原输入节点和草稿。空值与纯空格给现有反馈，真实台账零 POST。 |
| 提交与完成 | 专用隔离玩家只入场及提交一次，核真实服务端进度和经验。完成态仍用同一个字段展示权威答案，点击不唤起键盘。历史回访只读回源。提交中只按实际可观测证据记录。 |
| 边界 | 输入复用既有 ViewModel 的编辑门控、草稿与提交命令。Native 在处罚状态仍沿用既有门控。提示、提交反馈、顶栏和图片故障继续独立验收。 |

本表为目标。构建、直板机、隔离请求和同数据原图分别回填。

### 填空完成态可读性修正目标

首包真实交互通过。同数据完成原图显示官方 `TextInput` 已降低禁用文字的亮度，再给整个字段加0.5透明度使答案过淡。仅移除字段整体透明度，保留原生禁用文字和真实禁用属性。底线单独使用半透明主题色。用同一已完成场次重新采日夜原图，核对原答案、点触、原凭证及50 EXP，保持零新增入场和答题。

### 填空输入实际验收

原生 V2 `StarwardAnswerInput` 以单行 `TextInput` 复用现有草稿、服务端答案和提交门控。常态为透明方角和1vp主题底线，18fp正文和占位，聚焦用2vp官方描边及1vp位移，尊重减少动画。触控焦点时原生描边贴边，Web 外偏3px。原生普通态输入到提交按钮的间距为16vp，Web 为18px，按钮形态与反馈区留在下一片。原生的现有冷却及锁定编辑门控沿用。

| 范围 | 实际结果 |
| --- | --- |
| 构建、质量和运行时 | 首包 `2a036c32…` 官方 `scripts/hm.sh run` 构建、签名、安装、启动均完成。[运行时](../artifacts/validation/ui-gameplay-text-20261106/runtime-01.json)的5项检查通过，`scripts/hm.sh lint` [归一化0项](../artifacts/validation/ui-gameplay-text-20261106/lint-01/lint.json)。定向 `scripts/hm.sh test GameplayAnswerViewModel` [12项全过](../artifacts/validation/ui-gameplay-text-20261106/answer-view-model-01/local-test-summary.json)。 |
| 输入、键盘和草稿 | [首包真机](../artifacts/validation/ui-gameplay-text-20261106/native-01.json)共7项，5项清理均通过。376vp、字号1，输入实际1100×204px（约314.29×58.29vp）。两主题都实测了系统IME与应用实际缩小可用区，输入与完整提交按钮可达。Back收键盘，保留同一输入节点和草稿并实际失焦。空答案与纯空格均不发答题POST。 |
| 真实结算与历史重进 | 同一专用隔离玩家在原生入场一次并正确答题一次，真实后端各记录一个入场凭证、答案、答题凭证、完成进度和经验流水，结算50 EXP。完成后同一输入实例展示服务端答案并禁用，实际点触不开键盘。历史回访只发两次详情GET 200，保持原凭证和经验。提交中的瞬态未采到。 |
| 同数据原图 | [Web八态](../artifacts/validation/ui-gameplay-text-20261106/web-reference-01.json)为相同活跃/完成DTO及同草稿的深浅本地重放，真实后端和外部请求放行0。独立[首轮原图复核](../artifacts/validation/ui-gameplay-text-20261106/delegated-original-visual-review-01.json)核8张Web及10张Native，确认常态与焦点信息和布局，另定位完成文字被叠加压暗。Web焦点样张不模拟原生键盘。 |

本片复用一次性隔离后端，不将真实题库的答案、凭据、受保护地址或设备标识写入公开报告。采集器入口为 `scripts/device-gameplay-text-field.py run` 和 `scripts/capture-web-text-answer.py run`。每轮使用新报告目录，并绑定对应 HAP、运行时、源码、同题DTO和私有原图。固定账号用于预览。

完成态修正包 `67cf8e74…` 去除整字段透明度，底线使用单独的日夜半透明颜色资源，保留原生禁用字色及编辑状态。首个修正候选的内部方法与通用 `borderColor` 同名，ArkTS 编译拒绝，改为输入专用方法与主题资源后才完成官方构建、签名、安装和启动。[修正包运行时](../artifacts/validation/ui-gameplay-text-20261106/runtime-readonly-01.json)五项通过，[lint](../artifacts/validation/ui-gameplay-text-20261106/lint-readonly-01/lint.json)归一化0项。

[完成态定向复验](../artifacts/validation/ui-gameplay-text-20261106/native-readonly-01.json)由 `scripts/device-gameplay-text-readonly.py run` 执行，2项检查及5项清理通过。同一已结算玩家从历史重进只发两次详情GET 200，点触禁用输入无焦点、无IME，台账零新增入场或答题，原答题凭证和50 EXP保持。[修正原图复核](../artifacts/validation/ui-gameplay-text-20261106/delegated-readonly-visual-review-01.json)逐张核两主题新原图及同数据Web，整句可读，底线仍弱化。字形对比样本由日间1.48升至2.32、夜间1.77升至3.44，原生禁用字色仍比Web偏淡。正常输入和键盘由首包结果覆盖，修正包验收范围为完成态。

固定预览已换装修正版并直接登录停在首页，沿用原账号、证书及数据库。预览包与修正隔离包的应用代码成员相同，环境与验收账号分开，见[固定预览交还](../artifacts/validation/ui-gameplay-text-20261106/fixed-preview-restored-text-20261106-02.json)。

后续为提示、判题反馈与重连。填空提交瞬态和其他输入规格继续保留各自验收边界。

### 2026-11-06 题内提示、判题反馈与重连实施前

以冻结 Web `4b7d1a0…` 的 `QuestContent`、`QuestAnswerForm`、`AnswerFeedback` 和 `GameRetryDialog` 为参照。应用仍用服务端判题与原答题请求重试，展示的自动消退和弹窗关闭属于界面行为。

| 状态 | 本片实施与验收目标 |
| --- | --- |
| 题内提示 | 内容块内保留透明左线、三角和「查看提示」。展开显示正文，收起仍用原文案，方向和无障碍状态随展开变化。两次真实点击后原答题实例及草稿保持，台账零答题。 |
| 提交与处罚 | 手机操作区在输入后留18vp，用左对齐胶囊按钮。提交中仍显示「提交答案」，输入和动作实际禁用；真实冷却及锁定由既有门控展示。 |
| 判题反馈 | 表单后有状态徽章、标题和服务端语义正文。空答/错答显示「验证未通过」，约3秒后消退；真实正确显示「验证通过」。反馈消退只影响界面，处罚和草稿独立，历史重进不重放成功。 |
| 响应不确定 | 官方模态保留题面和输入。展示「答案还在，等待回音」「重新连接」「留在当前页面」。留在页面或系统返回关闭模态，保留原命令及显式恢复入口；提交中和重连中拦重复操作，重连中按钮禁用。 |
| 隔离链路 | 新一轮隔离环境使用同一审核真题。真实错答零经验；对真实正确答题注入响应延迟及丢失，先观察提交中，再显式恢复，核同请求 ID、请求体、账号和关卡，服务端只结算一次。日夜 Web 原图来自同 DTO 本地回放。 |

题号导航、滚动顶栏、场次解锁线索及答对演出另切片。以下状态均须按实际证据回填。

### 题内提示、判题反馈与重连实际验收

提示用 ArkUI Button 保留44vp触达和原题展开内容。提交区为左对齐胶囊，输入至动作留18vp。状态卡放在动作之后，使用独立3秒展示时钟。重连由官方 `bindContentCover` 承载居中弹层，用户关闭后可从原提交位置重新打开。请求身份、草稿、进度及冷却仍由原 ViewModel 与后端管理。

| 范围 | 实际结果 |
| --- | --- |
| 隔离环境 | 旧一次性库先经 SQLite 只读归档及完整性检查。首次新库启动因重启凭据在隔离目录外被拒，保留[失败回执](../artifacts/validation/ui-gameplay-feedback-20261106/disposable-epoch-01/setup.json)。将同一凭据移入其允许目录后[续跑通过](../artifacts/validation/ui-gameplay-feedback-20261106/disposable-epoch-02/setup.json)，同一审核内容19条，三组专用场次均从零入场、零答题和零经验开始。 |
| 构建与质量 | 首包 `4fed2eb3…` 和修正包 `1381b523…` 经官方 `scripts/hm.sh run` 构建、签名、安装和启动。修正包[运行时](../artifacts/validation/ui-gameplay-feedback-20261106/runtime-02.json)5项通过，[lint](../artifacts/validation/ui-gameplay-feedback-20261106/lint-02/lint.json)归一化0项。相同答题 ViewModel 的 `scripts/hm.sh test GameplayAnswerViewModel` [12项全过](../artifacts/validation/ui-gameplay-feedback-20261106/answer-view-model-01/local-test-summary.json)。 |
| 提示与反馈 | [首轮](../artifacts/validation/ui-gameplay-feedback-20261106/native-01.json)在日夜实测收展，保持同一输入节点和草稿，零答题。首轮整体incomplete，因为左线的百分比高度把反馈卡撑出屏幕，保留该结果。改用分边框后，[续跑](../artifacts/validation/ui-gameplay-feedback-20261106/native-02.json)沿用同一个入场凭证，8项检查及6项清理通过。空答零POST，错答保持草稿且零EXP，两种红卡均实际消退，正答显示绿卡。 |
| 提交和响应恢复 | 原生填空在真实上游答复延迟期间观察到输入和提交动作实际禁用。故意丢失真实正确答题的回复后，「留在当前页面」和系统返回均保持原草稿及恢复入口。用户显式重连中两个动作均禁用，系统返回不能关闭。请求ID、请求体、账号和关卡的四项匹配，服务端只有一错一对及一次50 EXP结算。原生三次答题请求包含一条同命令回放，回放未新增提交或经验记录。 |
| 同数据视觉 | [Web十六态](../artifacts/validation/ui-gameplay-feedback-20261106/web-reference-01.json)以同题活跃、错答及完成DTO本地重放，真实后端和外部请求放行0。[原图复核](../artifacts/validation/ui-gameplay-feedback-20261106/delegated-original-visual-review-01.json)逐图看16张Web和11张原生。反馈实测314.29×75.71vp，重连弹层336×438vp，两者无可见裁切。原生提示触达高度44vp，重连用系统全模态纯色遮罩并保留显式恢复入口。非提示的原生原图为日间。 |

设备采集使用 `scripts/device-gameplay-feedback.py run --resume-report`，浏览器使用 `scripts/capture-web-gameplay-feedback.py run`。报告分别绑定首轮与修正包、原始节点和同数据私有图，构建与视觉状态分别记录。

[历史重进](../artifacts/validation/ui-gameplay-feedback-20261106/native-feedback-history-01.json)在同一修正包与已结算隔离场次上实测。两次详情GET 200 后输入只读，成功状态卡和重连弹层均不重放。原入场、答题凭证与经验保持，退出清理通过。

[选择题冷却](../artifacts/validation/ui-gameplay-feedback-20261106/native-choice-cooldown-02.json)使用另一个专用玩家及相同修正包。首轮误用选中态会平移的卡片坐标作按钮对齐参照，止于提交前，原[未完成报告](../artifacts/validation/ui-gameplay-feedback-20261106/native-choice-cooldown-01.json)保留。改以稳定的选项组左缘核对后，沿用原入场凭证续验，4项检查通过。上游回复延迟期间实见可见 Radio 和46vp提交按钮禁用，唯一错答进入真实30秒冷却。倒计时在选项后、按钮前持续展示，期满恢复交互，服务端零经验和零新增入场。选择题短错答卡未采到，永久锁定和夜间非提示原生图仍按各自状态分开记录。

[固定预览交还](../artifacts/validation/ui-gameplay-feedback-20261106/fixed-preview-restored-feedback-20261106-02.json)通过。精确清除一次性故障并确认无待发响应后切换回固定预览，修正版应用代码与隔离包相同。原预览账号、数据库及CA保留，实际直接登录读取列表并留在首页。

### 2026-11-06 多题导航和答题顶栏实施前

题号沿用冻结 Web `4b7d1a0…` 的横轨与双行状态。顶栏使用原生 Navigation 标题，按用户确认的滚动阈值独立控制。

| 范围 | 验收目标 |
| --- | --- |
| 题号和几何 | 多题显示横向题号轨，普通题、已完成题、当前题及未解锁题分别核对。手机参考94×63、间距6、左对齐、方角，当前上移2和主题底线。题号无障碍状态与按钮实际禁用分别记录。 |
| 切题和草稿 | 真机进入真实隔离多题场次，未来题按钮实际禁用，完成第一题后由服务端解锁下一题。按题号来回切换和点击当前题，核对正确题面、完成题只读和同题草稿。切题清理旧判题反馈，回看和切换均零业务写入。 |
| 纵向阈值 | 首屏原生顶栏与题面留白保持。题卡上缘滑至顶栏下缘时收起，轻微反向和触底仍收起，真正回到纵向零位才恢复。系统状态栏始终保留，题面不因显隐跳位。使用实际视口、题号或题卡锚点与绝对滚动量验证。 |
| 状态与环境 | 短题滚不到阈值时保持顶栏，横向题号和纵向滚动分开。回到页顶后原下拉刷新仍可用。用两题隔离场次与真实长题验证交互，滚动超出一屏的题号需要独立场次证据。 |

展示与交互逐项记录。题内媒体、折叠和玩法后续模块继续独立验收。

### 2026-11-06 多题导航与顶栏真机验收

| 范围 | 实际结果 |
| --- | --- |
| 构建和窗口 | `17422c36…` 通过官方 `scripts/hm.sh run` 构建、签名、安装及启动。[实际窗口与 TLS](../artifacts/validation/ui-gameplay-question-nav-20261106/runtime-02.json) 5 项通过。[答题 ViewModel](../artifacts/validation/ui-gameplay-question-nav-20261106/answer-view-model-02/local-test-summary.json) 12 项通过，失败和忽略均为 0。[codelinter](../artifacts/validation/ui-gameplay-question-nav-20261106/lint-02/lint.json) 退出 0，报告零问题，`filesChecked=0`。 |
| 两题导航 | [直板机隔离 HTTPS](../artifacts/validation/ui-gameplay-question-nav-20261106/native-navigation-01.json) 5 项及清理均通过。未来题实际禁用，第一题答对后解锁第二题；点击当前题保留未提交选择，来回切题、完成题权威答案只读、返回重进读到服务端当前题均实测。11 个快照均在官方布局树观察到当前标记。测试准备总计一次入场、一次答题和 50 EXP，导航无额外写入。 |
| 同数据视觉 | [冻结 Web 回放](../artifacts/validation/ui-gameplay-question-nav-20261106/web-01.json) 使用真机报告中的两份 DTO 在 376px 内容窗口生成日夜共 10 张原图，实际后端和外部网络放行均为 0。原生与 Web 日间的当前、未解锁、完成和普通状态已看原图。真机题号 94×63.14vp、间距 6vp、当前上移 2vp，轨道高约多 2.14vp 以完整显示选中描边；未解锁采用原生 Button 的禁用样式。 |
| 顶栏首轮 | [长选择题原生交互](../artifacts/validation/ui-gameplay-question-nav-20261106/native-header-03.json) 5 项通过。卡片离顶栏下缘 57px，实测 16.0vp 收起，轻微回滑和触底保持收起，滚回页顶恢复到原始布局。仅显式下拉刷新发出一次详情 GET，场次进度、写入凭证及经验保持。原图复核发现触底时题面画到状态栏区域，另开修正。 |

题号点击沿用原生页面的纵向位置。冻结 Web 切题时会聚焦并滚到题卡。题卡横滑未接入，横轨超出单屏和夜间真机题号视觉未实测。本轮覆盖 376vp 直板机，折叠和窗口变化按后续设备阶段验证。

状态栏修正版 `18b8cb47…` 通过官方构建、签名、安装及启动。[窗口与 TLS](../artifacts/validation/ui-gameplay-question-nav-20261106/runtime-06.json) 5 项通过。[答题 ViewModel](../artifacts/validation/ui-gameplay-question-nav-20261106/answer-view-model-06/local-test-summary.json) 12 项通过，失败和忽略均为 0。[codelinter](../artifacts/validation/ui-gameplay-question-nav-20261106/lint-06/lint.json) 退出 0，报告零问题，`filesChecked=0`。

[同包顶栏复验](../artifacts/validation/ui-gameplay-question-nav-20261106/native-header-07.json) 5 项及清理均通过，保持视口和首屏位置，16.0vp 收起，回到页顶原像素位置恢复。普通滚动不回源，显式下拉仅发一次真实详情 GET。前序包只通过显隐交互，原图仍有状态栏遮挡。最终包按系统避让距离裁剪答题前景，页面背景继续绘制到屏幕边缘。[同一长题的触底原图复核](../artifacts/validation/ui-gameplay-question-nav-20261106/status-bar-original-review-01.json) 验证前景从 136px 避让边界开始绘制，系统图标清楚，没有独立占位块。裁剪使用官方 `clipShape` 与 `RectShape`。[HarmonyOS 裁剪属性](https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-universal-attributes-sharp-clipping/)

[同包导航只读复验](../artifacts/validation/ui-gameplay-question-nav-20261106/native-navigation-recheck-01.json) 使用原两题场次，实测进到服务端当前题、双向点击题号、完成答案只读和干净登出。原有入场、答题凭证及 50 EXP 保持，新增业务写入为零。日间最终原图中的当前与完成题状态重新与同数据 Web 对照。

复现入口为 `scripts/device-gameplay-question-nav.py run`、`scripts/device-gameplay-header.py run --refresh` 和 `scripts/capture-web-gameplay-navigation.py run`。两种原生采集需显式提供隔离场次引用、设备引用、签名 HAP 和匹配的运行时报告。

[固定预览交还](../artifacts/validation/ui-gameplay-question-nav-20261106/fixed-preview-restored-nav-20261106-02.json) 已通过，绑定修正版的顶栏与只读导航报告。预览包应用代码与隔离测试包一致，固定预览数据库、CA 和账号保留，手机已用固定账号直接登录并读到首页列表。

### 题卡自动定位与原生左右滑动实施前

| 范围 | 验收目标 |
| --- | --- |
| 初次进题与重进 | 首个服务端可读题布局完成后，自动滚到系统安全区下沿，实际越过已有顶栏收起阈值。滚回顶部能看到原布局，定位不抢输入焦点。冻结 Web 在首次挂载不主动定位，首次进题是用户本轮新增行为。 |
| 题号与前进 | 点未解锁题不切题。点可读题或当前题，以及自动或手动下一题后，定位到对应题卡。检查短题、长题、草稿和完成题只读。普通同步和题图高度变化不重复定位。 |
| 原生左右滑动 | 使用 ArkUI Swiper，实际只在相邻的服务端可读题之间切换。未解锁、首尾及提交恢复状态不切换。观察纵向阅读、键盘、题号横轨和弹层交互，滑动和定位零额外答题写入。 |

验收使用独立隔离真实 HTTPS 账号及直板机。可用现有两场预览进行人工审查，自动验收使用独立数据。按同宽度核对题卡、题号和系统避让。

#### 实现与主机侧准备

首个有效题、点击题号、左右滑动及自动或手动下一题共用定位入口。短题的外层容器保留达到安全区所需的滚动范围，题卡本身用自然高度。普通刷新、同题图片尺寸变化和键盘避让不重新排队。顶栏仍由实测滚动阈值决定。ArkUI Swiper 只包含当前题所属的连续可读区段，只有落定的相邻手势可发起切题。当前题继续使用原答题表单，手势过渡中的相邻页只展示题面预览。[HarmonyOS Swiper API](https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-container-swiper/)

固定工具链构建通过并生成本地签名 HAP `4f43f9ce…`，未在本轮安装。Hypium 的[入场](../artifacts/validation/ui-gameplay-question-swipe-20261106/GameplayViewModel/local-test-summary.json)、[答题](../artifacts/validation/ui-gameplay-question-swipe-20261106/GameplayAnswerViewModel/local-test-summary.json)、[同步](../artifacts/validation/ui-gameplay-question-swipe-20261106/GameplayRefreshViewModel/local-test-summary.json)合计 29 项通过，0 失败、0 忽略。[codelinter](../artifacts/validation/ui-gameplay-question-swipe-20261106/lint-01/lint.json) 退出 0、报告零问题、`filesChecked=0`。

冻结 Web `4b7d1a0…` 使用上一轮两份 DTO 做 376px 宽、742px 高的本地日夜回放。浏览器触摸验证锁题不切换，以及解锁后两向切换与聚焦。短题的 Web 页面没有可滚动距离，首次进题不聚焦。回放零真实后端与外部网络放行，20 张原图保留在私有目录。当前包尚待直板机交互与同数据原图复核。

独立两题场次已准备，入场、答题及经验初始为零。真机驱动为 `scripts/device-gameplay-question-swipe.py run`，验证无辅助操作的进题定位、锁题、真实解锁、自动下一题、双向滑动、点题号、回访及零额外业务写入。手机暂未连接，直板模拟器启动因许可尚未接受而未执行。实际手势、键盘及短长题过渡待手机复验。

#### 直板机隔离 HTTPS 验收

手机重新连接后，通过 `scripts/hm.sh run` 为隔离环境生成并安装签名 HAP `410dfbab…`。[运行时](../artifacts/validation/ui-gameplay-question-swipe-20261106/runtime-01.json)五项通过。[真机两题主流程](../artifacts/validation/ui-gameplay-question-swipe-20261106/native-swipe-01.json)六项及退出清理通过。初次进题没有辅助滑动，题卡自动定位。滚回页顶后，实滑锁题保持原题。唯一一次正确答题解锁第二题并自动定位。两题可双向横滑，已完成题答案只读，未提交选择草稿保留。点击当前或另一题号均定位，退出重进经真实 GET 定位服务端当前题。服务端记录一次入场、一次答题和 50 EXP，导航没有新增写入。

[同数据日间原图复核](../artifacts/validation/ui-gameplay-question-swipe-20261106/same-data-visual-review-01.json)绑定该包、两份 DTO、7 张原生和 20 张 Web 原图。原生各定位态题卡上缘为 137px，首行描边完整，系统图标清楚，题卡宽度 352vp。冻结 Web 同数据短题页面没有纵向滚动空间，只更新焦点。原生按本轮要求主动定位并收起顶栏。夜间真机图未纳入本轮。

[同包长短题与键盘补验](../artifacts/validation/ui-gameplay-question-swipe-20261106/native-long-short-01.json)使用另一个专用隔离账号，主机先通过真实 HTTPS 为十段长填空结算一次，以便短填空可编辑且相邻长题已解锁。实际键盘出现时应用可用区域为 y=137–1733px，在题面同一位置横滑仍留在当前题，草稿保持。键盘收起后同手势切到长题，可以纵向滚到末尾的只读答案。滑回短题重新定位到 137px，题卡恢复其自然高度和原草稿。复核原图无状态栏遮挡，手机阶段新增业务写入为零。

[固定预览交还](../artifacts/validation/ui-gameplay-question-swipe-20261106/fixed-preview-restored-swipe-20261106-02.json)通过。首轮交还已安装启动并通过运行时检查，逐卡遍历超时。随后保留同一安装包，通过固定预览 HTTPS 核对全部六场，在原生列表确认《清宫那点事》和《关于初见的故事》可见。预览包应用代码和隔离测试包一致。手机留在已登录的「待赴之约」。
### C01a 普通文字与图片线索（2026-11-11，实施前）

冻结 Web `4b7d1a0` 的手机题卡为参照。首轮只做普通线索列表、手动打开文字弹层和图片查看器；自动演出、组合线索、视频、链接、信纸、祝福、BGM 与旅程出口另拆。不用原占位文案或假可点卡片表示尚未迁移的内容。

同数据 Web 原图中，含正文图片的线索卡可能露出被裁掉的图片边缘。2026-11-11 用户确认原生卡片只预览文字，完整图片留在弹层。线索正文里的链接保留可读文字，不提供跳转；视频及海报不加载。

| 状态 | 本轮验收要求 |
| --- | --- |
| 未解锁或当前题未完成 | 不显示线索区。只使用服务端已发放的线索，已发放的全场线索不提前出现在未完成题下。 |
| 当前题已完成 | 按 Web 筛选、排序和编号：全场线索或本场绑定到本题的线索，题目来源必须绑定本关；排除多题场次的无绑定完成文字组合线索。按场次来源、题目来源、位置、定义 ID、线索 ID 排序。列表位于题卡内反馈下方；无普通可用项不占位。 |
| 手动打开、返回与重开 | 文字保留原有标题、正文层次、换行、标记和正文嵌入图片，使用 ArkUI 居中弹层；关闭按钮、蒙层和系统返回均返回同题、同滚动位置。图片按后端图集顺序从第一张打开，正文图片放大后返回原弹层。复用原生查看器与原有加载、重试。返回或重开不提交答案，不改进度。 |
| 授权与状态变化 | 当前题、账号或服务端授权变化后，旧线索和查看器不能继续显示；刷新与回访只按最新快照。未迁移类型不自动弹出或发送业务请求。 |
| 真机与视觉 | 新直板机重新签名安装、隔离真实 HTTPS 与账号回收单独记录。用相同 DTO、设备实际内容宽度和主题对照 Web 原图。已有入场/答题只运行生成本轮状态所需的最短路径。 |

#### C01a 重新安装与主机检查

新直板机识别为 HarmonyOS API 26。第一次官方 `scripts/hm.sh run` 已编译和签名，但因旧调试描述文件未授权新设备而拒绝安装。使用 DevEco Studio 项目结构的自动签名后，官方构建、安装、启动成功。[预览基线运行时](../artifacts/validation/ui-gameplay-clues-20261111/new-phone-runtime-01.json) 的 5 项检查均通过；窗口为 1260×2720 物理像素、密度 3.25、387.692 vp 宽，扣除系统区后的内容高度为 771.077 vp。

普通线索仅使用当前服务端快照。线索卡通过 ArkUI Button 封装；文字使用 [ArkUI PromptAction 居中模态弹层](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-uicontext-promptaction)，读完回到原题，正文图片和独立图集都复用现有加载与查看器。未引入新网络写入、存储或生产联调。

[最终单测](../artifacts/validation/ui-gameplay-clues-20261111/polish-unit/local-test-summary.json) 6/6、失败 0、忽略 0；[codelinter](../artifacts/validation/ui-gameplay-clues-20261111/polish-lint/lint.json) 命令成功，问题 0，报告的 `filesChecked=0` 如实保留。首轮一次性代理中途离线，出现[可信 CA 请求未收到 200](../artifacts/validation/ui-gameplay-clues-20261111/disposable-native-runtime-01.json)；恢复隔离 PocketBase 和同一 USB TLS 网关后，[隔离安装包](../artifacts/validation/ui-gameplay-clues-20261111/disposable-native-runtime-02.json) 和[图片间距修正版](../artifacts/validation/ui-gameplay-clues-20261111/disposable-polish-runtime-01.json) 均由官方工具重新签名、安装、启动，真机运行时检查各 5 项通过，包括严格 HTTPS 可信 CA、未知 CA 和错误主机名的正反结果。固定预览数据库和账号未用作验收写入。

[首阶段真机记录](../artifacts/validation/ui-gameplay-clues-20261111/native-02.json) 实测未答无占位、首次正确提交后普通线索筛选与排序、文字通过按钮/系统返回/蒙层关闭、两类图集、正文图片退出回原弹层和失败项可重试。失败项使用保留的 `.invalid` 地址验证错误分支，不代表已验证可控的远端断网或恢复。脚本原误用 48 vp 高度门槛，未找到实际 46 vp 的「前往下一题」，本报告保留未完成状态；[独立 SQLite 快照](../artifacts/validation/ui-gameplay-clues-20261111/native-sqlite-settlement-02.json) 确认此时恰好一次入场、一次正确提交、50 XP、未提交第二题。

[同账号续验](../artifacts/validation/ui-gameplay-clues-20261111/native-04.json) 从服务端已保存的第一题继续。第二题未答时不显示此前已发放的线索；答对后显示全场及本题的两条普通线索，排除第一题专属线索和未迁移类型。完成后从历史页夜间回访可重新读取第一题线索，正文图退出回原文字弹层；退出账号后表单为空，题卡和弹层均不再出现。中间一次[题号控件测量失败](../artifacts/validation/ui-gameplay-clues-20261111/native-03.json) 未写入第二题，续验改按官方 UiTest 给出的可见区域点击。最终[独立 SQLite 核验](../artifacts/validation/ui-gameplay-clues-20261111/native-sqlite-settlement-04.json) 与真机记录一致：1 次入场、2 次正确提交、2/2、100 XP，无其他玩法写入。弹层打开时的服务端撤销授权未做强制注入；旧授权清理为代码约束，退出边界已有真机记录。

[同账号和场次 DTO 的 Web 重放](../artifacts/validation/ui-gameplay-clues-20261111/web-reference-phone-01.json) 使用真机四个阶段快照，388×771 逻辑内容视口，26 张日夜及字体对照原图；Web 业务和外部请求均未放行。已阅真机列表、文字弹层和图片查看原图。列表宽约 326，卡间距约 11；[间距实测](../artifacts/validation/ui-gameplay-clues-20261111/visual-comparison-01.json) 显示去掉图块两侧多出的文字行后，弹层由 480.92 vp 降至 420.00 vp；用已完成 DTO 回访、点击第一题后，[Web 夜间同状态原图](../artifacts/validation/ui-gameplay-clues-20261111/web-reference-phone-completed-night-01.json) 为 420.92 CSS px。按用户确认，卡片仅预览文字，完整图片放在弹层；弹层采用 ArkUI 系统遮罩。折叠屏、生产写入和其他玩法未复验。

固定预览已切回原本机数据库与账号。官方签名安装后的[真机运行时](../artifacts/validation/ui-gameplay-clues-20261111/preview-restored-runtime-01.json) 5 项通过，[交付包的 ArkTS 字节码](../artifacts/validation/ui-gameplay-clues-20261111/preview-package-equivalence-01.json) 与间距修正版验收包一致。[固定预览交接](../artifacts/validation/ui-gameplay-clues-20261111/fixed-preview-restored-01.json) 7 项通过：无需改密、两场既有多题场次可见、进度未改，手机留在已登录首页。[一次性环境清理](../artifacts/validation/ui-gameplay-clues-20261111/disposable-cleanup-01.json) 核验原预览容器、数据库和登录配置保持原样。

复验入口：`scripts/hm.sh run`（官方构建、签名、安装、启动）；`scripts/hm.sh test GameplayClues`；`scripts/hm.sh lint`；`scripts/capture-window-evidence.py --font-scale 1 --require-tls --output <报告>`。普通线索真机驱动为 `scripts/device-gameplay-ordinary-clues.py run`，需要新的一次性玩家、精确签名包、媒体清单和设备回执；已结算夹具不能再次执行入场或答题。Web 同数据原图由 `scripts/capture-web-gameplay-ordinary-clues.py` 在冻结 checkout 重放，禁止转发业务 API，并核对登记的图片字节。

### C01b 组合线索（2026-11-12）

以冻结 Web `4b7d1a0` 手机行为为准。组合线索是多题场次中服务端已发放、没有绑定关卡的场次来源 `session_completed` 文字；普通线索继续留在原题卡。仅迁移阅读及入口，不接入普通线索自动演出、视频、BGM、终章和旅程出口。2026-11-12 用户确认正文保留链接文字，点按跳转另拆。

| 状态 | 验收要求 |
| --- | --- |
| 未完成、已撤回、无合格线索 | 不出现组合入口和弹层；不从题目完成数或 XP 推断授权。 |
| 本次正确提交完成 | 先完成提示，再按 Web 顺序打开本次新发放的组合线索。显式效果列表（含空列表）优先；未返回才比较授权差值。无合格线索沿用普通完成提示。 |
| 弹层 | 保留正文、可用正文图、标题、说明、确认按钮和默认文案。正文滚动，确认按钮保持可达。点蒙层不关闭，系统返回和确认按 Web 收起或继续下一条。 |
| 收起、拖动、回访 | 完成后通过浮动「查看本场线索」只重开排序最后一条。入口遵守安全区，可拖动、贴边、保存坐标；历史回访与刷新不重播，不改变进度。 |
| 账号、退出与真机 | 弹层和待展示队列只归属当前授权与页面；离开后清理。验证隔离 HTTPS 授权及写入台账，按同主题、同数据、同宽度对照 Web 原图。 |

[新签名包的真机运行时](../artifacts/validation/ui-gameplay-combination-20261112/runtime-01.json) 5 项通过，含可信 CA、未知 CA 和错误主机名。隔离 HTTPS 夹具包含同场次真机账号、单独 Web 参考账号及完成但无组合线索的反例；[Host 证据](../artifacts/validation/ui-gameplay-combination-20261112/host-fixture-01.json) 验证了真实效果列表和授权差异。

[正例真机](../artifacts/validation/ui-gameplay-combination-20261112/native-01.json) 7 项及退出清理通过。未完成时无入口；最后一题答对先显示「查看组合结果」，系统返回不能跳过。两条线索按排序自动打开，第一条使用自定义文案，最后一条使用默认文案；蒙层不关闭，确认/返回按顺序推进或收起。完成后仍能读两条普通线索；组合入口只打开最后一条。拖动贴边没有误点，从历史页通过真实 GET 回访时保留位置、不重播。台账只有 1 次入场和 2 次不同题目的正确提交。

[同场次 Web 真响应重放](../artifacts/validation/ui-gameplay-combination-clues-20261112/web-reference-01.json) 用 388×771 逻辑内容视口采集 20 张日夜与反例原图，业务与外部请求转发均为零。首条弹层原生 339.69×419.69 vp，Web 340×418.95 CSS px；确认按钮分别约 292×46，换行、高亮、说明及页脚对齐。原生采用系统遮罩，Web 使用较强模糊。首包原图发现入口边框覆盖圆角、图标描边在夜间发黑；该问题进入交付包修正及窄复核。

[真机账号 Web 只读重放](../artifacts/validation/ui-gameplay-combination-clues-20261112/web-reference-phone-01.json) 以该账号的 4 个实际 HTTPS 快照采集 8 张日夜原图；验证回访、手动重开、拖动、位置恢复，不伪造答题响应。Web 自动顺序另由上面的隔离参考账号真实答题响应证明。[独立 SQLite 核验](../artifacts/validation/ui-gameplay-combination-20261112/native-sqlite-settlement-01.json) 将真机 4 个快照、两次提交、100 XP、两条普通授权及两条组合授权和写入回执对应起来，无额外玩法写入。

[交付修正版运行时](../artifacts/validation/ui-gameplay-combination-20261112/runtime-02.json) 5 项通过。[真机只读复核](../artifacts/validation/ui-gameplay-combination-20261112/native-final-reentry-01.json) 通过，实测重新安装及冷启动仍保留拖动位置，手动只打开最后一条，未新增入场或答题。实际检查了夜间入口圆角与图标颜色，确认箭头清楚可见；验收拖动已移回初始位置。修正版同时限制后台迟到响应自动开窗、隐藏显式空效果情形下完成提示后方的入口，以及收敛不可打开弹层的窗口边界；这些额外边界未单独注入真机场景。

[无组合授权反例](../artifacts/validation/ui-gameplay-combination-20261112/native-negative-01.json) 使用同一个修正版安装包。真实已完成场次仍可读普通线索，滚动至题卡末尾均未见组合入口或弹层；业务写入为零，退出清理通过。

[GameplayClues](../artifacts/validation/ui-gameplay-combination-20261112/unit-clues-final/local-test-summary.json) 8/8、[GameplayAnswerViewModel](../artifacts/validation/ui-gameplay-combination-20261112/unit-answer-final/local-test-summary.json) 12/12，均无失败、无忽略。[codelinter](../artifacts/validation/ui-gameplay-combination-20261112/lint-02/lint.json) 命令成功，报告 0 问题，`filesChecked=0`。组合线索真机夹具覆盖纯文字、高亮和分段；内嵌图片复用现有图片查看器，组合正文长图及查看器未单独做真机专项。折叠屏、外接键盘和生产写入未执行。

已按原账号切回固定预览。[官方签名安装后的预览运行时](../artifacts/validation/ui-gameplay-combination-20261112/preview-restored-runtime-01.json) 5 项通过，[预览包 ArkTS 字节码](../artifacts/validation/ui-gameplay-combination-20261112/preview-package-equivalence-01.json) 与隔离修正版一致。[固定预览交接](../artifacts/validation/ui-gameplay-combination-20261112/fixed-preview-restored-01.json) 7 项通过，无需改密，两场多题场次仍可见，进度保持，手机留在已登录首页。[一次性环境清理](../artifacts/validation/ui-gameplay-combination-20261112/disposable-cleanup-01.json) 确认临时后端及凭据已移除，固定预览原数据库与登录配置未改动。

复现入口：`scripts/hm.sh run`、`scripts/hm.sh test GameplayClues`、`scripts/hm.sh test GameplayAnswerViewModel`、`scripts/hm.sh lint`；`scripts/device-gameplay-combination-clues.py run` 只用于新的正例隔离账号，`run-negative` 只读取已结算无授权夹具。Web 使用 `scripts/capture-web-gameplay-combination-clues.py` 绑定冻结源码和相应隔离 DTO，不转发实际业务请求。

### C01c 线索正文外链（2026-11-12）

冻结 Web `4b7d1a0` 在正文里用行内锚点打开外链。正式只读快照含三条已发布正文链接，均为组合线索内的 HTTPS 外链。快照中普通文字线索没有正文外链，站内相对链接也未出现。独立 `kind=link` 卡使用另一条业务入口。

| 状态 | 本轮验收目标 |
| --- | --- |
| 正文中有有效 HTTP(S) 地址 | 普通及组合弹层原位置显示行内链接，保留文案、上下文和换行。普通卡片预览仍只预览文字。以隔离接口下发的正式 HTTPS 链接做同数据、同宽、日夜对照。 |
| 点按与返回 | 当前授权线索由用户主动点开时，交给系统关联应用或浏览器。系统返回后同一弹层、滚动位置、组合阅读顺序和未提交草稿保留。允许正常只读同步，链接交互不产生入场或答题写入。 |
| 畸形、非 HTTP(S) 或暂未支持的站内地址 | 保留标签为普通文字。打开失败时留在原弹层，显示原生简短提示，可再次点按。 |
| 普通后台、授权失效、账号或场次切换 | 保留既有后台中断规则。只有明确的外链切换保留弹层，并按当前快照重新确认线索授权。离开场次或退出后清除旧弹层和待处理的返回状态。 |

官方工具已构建、签名并安装最终隔离包。[真机运行时](../artifacts/validation/ui-gameplay-links-20261112/runtime-02.json) 5 项通过，包含可信 CA、未知 CA、错误主机名。相关单测为 [GameplayClues 9/9](../artifacts/validation/ui-gameplay-links-20261112/unit-clues/local-test-summary.json) 和 [GameplayAnswerViewModel 12/12](../artifacts/validation/ui-gameplay-links-20261112/unit-answer-02/local-test-summary.json)，失败与忽略均为 0。[codelinter](../artifacts/validation/ui-gameplay-links-20261112/lint-01/lint.json) 命令成功，报告 `filesChecked=0`、问题 0。[隔离夹具核验](../artifacts/validation/ui-gameplay-links-20261112/host-fixtures-01.json) 以真实接口和 SQLite 对账确认三个独立账号的初始进度、授权和经验。

[普通线索真机](../artifacts/validation/ui-gameplay-clue-links-20261112/native-ordinary-light-01.json) 日间 5 项通过。进入系统浏览器后用系统返回，同一弹层、正文控件身份及可见位置保留，回前台收到一次授权详情 GET；第二题未提交草稿保留。普通正文与禁用协议标签点按均不启动其他应用、不发业务请求。另一次从 Home 正常离开仍关闭弹层，回到原题。全轮零新增入场和答题，退出清理通过。

[组合回访真机](../artifacts/validation/ui-gameplay-clue-links-20261112/native-combination-dark-01.json) 夜间以完成场次的手动入口读取，点开隔离接口下发的正式地图链接，观察到系统浏览器接管。系统返回后原弹层和可见位置保留，并可确认收起。普通和组合两次外跳分别使用了三次和两次系统返回，浏览器页面内部加载及浏览器导航栈未纳入本轮验收。组合回访零新增玩法写入，退出清理通过。

[自动组合队列真机](../artifacts/validation/ui-gameplay-clue-links-20261112/native-queue-01.json) 从独立账号的第二题单次正确提交触发。第一条组合线索外跳并返回后，仍在同一弹层，确认才推进到第二条。第二条确认后回到已完成场次的手动入口。真实台账与只读 SQLite 对账确认本轮零新增入场、仅一次预期答题，最终 2/2、100 XP、两条组合授权，退出清理通过。

[冻结 Web 重放](../artifacts/validation/ui-gameplay-links-20261112/web-reference-05.json) 同数据的普通和组合弹层各有日夜原图，388×771 CSS px 对应真机 387.692×771.077 vp 内容视口。链接在原行内位置带下划线。浏览器使用默认链接色，原生沿用对应主题的品牌文字色。Web 的外部新页只由本地测试接管，无业务及外部请求转发。

[输入逐值核验](../artifacts/validation/ui-gameplay-links-20261112/web-native-input-binding-01.json) 确认两组只读快照仅 `assignment.serverTime` 不同。[原图复核](../artifacts/validation/ui-gameplay-links-20261112/visual-review-01.json) 实际对照普通日间及组合夜间两组。普通正文宽 281.85 vp 对 282 CSS px，组合 278.15 vp 对 278 CSS px，均在相同字符处换行。原生日间青绿、夜间金色，链接下划线和高亮底色区分清楚。两种弹层的其余主题为 Web 参考。

无可用处理应用、系统选择器取消、外跳期间服务端撤销线索、已滚动长正文及普通外链与自动前进计时重叠没有单独在真机触发。失败提示、取消及授权清理由代码处理。正式快照未出现站内正文链接，本轮保留相对地址标签为文字。

[固定预览运行时](../artifacts/validation/ui-gameplay-links-20261112/preview-restored-runtime-01.json) 5 项通过。[交付包字节码](../artifacts/validation/ui-gameplay-links-20261112/preview-package-equivalence-01.json) 与隔离验收包相同。[固定预览交接](../artifacts/validation/ui-gameplay-links-20261112/fixed-preview-restored-01.json) 7 项通过，手机留在原账号的已登录首页。[清理记录](../artifacts/validation/ui-gameplay-links-20261112/disposable-cleanup-01.json) 确认一次性后端、数据库和凭据已移除。

真机复验使用 `scripts/hm.sh run`、`scripts/capture-window-evidence.py --font-scale 1 --require-tls` 和 `scripts/device-gameplay-clue-links.py run`，要求签名包、运行时和专用已预置账号对应。Web 用 `scripts/capture-web-gameplay-clue-links.py` 重放冻结源码与真实快照。

### C01d 组合线索长正文的确认按钮（2026-11-12）

用户截图显示组合线索达到弹层高度上限后，底部确认按钮被边框裁掉。冻结 Web `4b7d1a0` 的正文是独立滚动区，底部说明和确认按钮占用独立的自然高度。

| 状态 | 验收目标 |
| --- | --- |
| 长正文及内嵌图片 | 弹层遵守可用高度，完整露出底部说明、按钮及下方内距。图片解码前后按实际内容重新布局。 |
| 正文从顶部滚到底部 | 可看到图后末段，底部确认按钮的完整可见范围和位置保持，能正常点按关闭。 |
| 短正文 | 弹层随内容收紧，维持原有标题、正文和底部间距。 |

验收使用无个人信息的隔离 HTTPS 夹具。布局检查与收起均从已完成场次进入，记录零玩法写入。

[旧包真机](../artifacts/validation/ui-gameplay-combination-overflow-20261112/native-baseline-01.json) 复现裁切。按钮自身高 46.15 vp，弹层内只露出 33.54 vp，下沿超出 12.62 vp。修正后由纵向 Flex 保持底部说明和按钮的自然高度，达到上限时只缩减正文 Scroll 的视口。短文仍按内容决定弹层高度。[ArkUI Flex](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-container-flex/)

[同数据 Web 原图](../artifacts/validation/ui-gameplay-combination-overflow-20261112/web-reference-01.json) 使用 388×771 CSS px 日间视口和已登记的图片。正文从 0 滚到 229 px，46 px 按钮与底部说明的坐标保持，确认可关闭弹层。Web 回放没有转发业务或外部请求。

[修正版长文真机](../artifacts/validation/ui-gameplay-combination-overflow-20261112/native-fixed-long-01.json) 实测首屏、图片完整进入视口和末段三个状态，按钮始终完整露出 46.15 vp，底部留白 17.85 vp，位置和控件实例一致。点按按钮后正常收起，零新增玩法写入。[原图复核](../artifacts/validation/ui-gameplay-combination-overflow-20261112/visual-review-01.json) 对照真机与 Web 的顶部、底部两组，逐值核对同一隔离账号的输入仅 `assignment.serverTime` 不同。原生沿用既有窗口避让和弹层高度上限。

[修正版短文真机](../artifacts/validation/ui-gameplay-combination-overflow-20261112/native-fixed-short-01.json) 弹层自然高度约 328.31 vp，正文无须滚动，按钮完整显示并可正常收起。长文与短文均通过测试账号退出清理。

[修正版真机运行时](../artifacts/validation/ui-gameplay-combination-overflow-20261112/runtime-fixed-01.json) 5 项通过，含严格 HTTPS 正反例。[GameplayClues 单测](../artifacts/validation/ui-gameplay-combination-overflow-20261112/unit-clues/local-test-summary.json) 9/9 通过。[codelinter](../artifacts/validation/ui-gameplay-combination-overflow-20261112/lint-01/lint.json) 命令成功，报告 `filesChecked=0`、问题 0。未单独注入延迟解码或修改设备字体缩放。

用 `scripts/hm.sh run` 构建安装，`scripts/capture-window-evidence.py --font-scale 1 --require-tls` 核验运行时。`scripts/device-gameplay-combination-overflow.py run` 通过 `--probe fixed` 或 `--probe short` 复验对应的只读夹具。

[固定预览交接](../artifacts/validation/ui-gameplay-combination-overflow-20261112/fixed-preview-restored-01.json) 7 项通过，手机留在原账号的已登录首页。[交付包字节码](../artifacts/validation/ui-gameplay-combination-overflow-20261112/preview-package-equivalence-01.json) 与隔离验收包相同。[清理记录](../artifacts/validation/ui-gameplay-combination-overflow-20261112/disposable-cleanup-01.json) 核验一次性后端、数据库和凭据已移除。

### C01e 组合谜题完成提示的主题样式（2026-11-12）

冻结 Web `4b7d1a0` 使用居中方角弹层，依次显示完成题数圆章、`QUEST SET COMPLETE`、衬线标题、说明和实底胶囊按钮。原生用官方模态容器、按钮与转场定制内容和主题资源。

| 状态 | 验收目标 |
| --- | --- |
| 本次提交最后一题并产生组合线索 | 同数据、同宽对照 Web 日夜原图。核对圆章、标题换行、说明、留白及日间青绿和夜间金色按钮。 |
| 查看组合结果 | 系统返回和点蒙层不跳过提示。确认后等提示消失，依次展示本次授权的组合线索，只结算本次答题。 |
| 完成但本次没有可展示的组合线索 | 同一套主题样式，保留既有「知晓了」和关闭行为。已授权手动入口只在提示关闭后可用。 |
| 回访及页面失效 | 回访不重播。离开账号、场次或应用前台时，旧提示和队列不再推进。 |

本轮以完成提示为范围，后续组合正文继续使用现有弹层。以隔离真机提交与本地冻结 Web 重放分别记录交互和视觉结果。

面板宽度取窗口减去两侧各 24 vp 并以 680 vp 为上限。数字章、细双框和胶囊按钮按 Web 层级绘制，遮罩与淡入淡出由原生容器承担。Web 的外围星轨和粒子在原图中保留为视觉参考。

[冻结 Web 日夜参照](../artifacts/validation/ui-gameplay-combination-notice-20261112/web-reference-02.json) 使用独立隔离账号的真实末题请求与响应离线重放。388×771 CSS px 下，面板为 340×435.38 CSS px，圆章直径 82 px，按钮为 138×46 px。外部点按和 Escape 保持提示，确认后进入第一条组合线索。业务及外网转发为零。

[首轮日间](../artifacts/validation/ui-gameplay-combination-notice-20261112/native-light-01.json) 的末题已结算，采集器把无障碍树中有边界但无文字的两个装饰节点误判为内容缺失，报告保留 `incomplete`。日间复验使用同场次的新隔离账号，标题、说明及按钮仍通过原始控件校验，装饰文字由实际原图核对。

[日间真机复验](../artifacts/validation/ui-gameplay-combination-notice-20261112/native-light-02.json) 5 项通过。系统返回和点遮罩后原弹层仍在。按一次「查看组合结果」依次读到两条授权组合线索，最后回到答题页。请求台账及 SQLite 对账只有本轮一次末题提交，最终 2/2、100 XP，退出清理通过。

[夜间真机](../artifacts/validation/ui-gameplay-combination-notice-20261112/native-dark-01.json) 使用另一隔离账号，同样通过 5 项。夜间面板、浅色衬线标题、青色圆章和金色按钮均见真机原图。系统返回及点遮罩均无法跳过，有且仅有一次末题提交，两条授权线索按顺序接续。

[同数据日夜原图复核](../artifacts/validation/ui-gameplay-combination-notice-20261112/visual-review-01.json) 绑定冻结 Web、真机签名包及两组等价完成响应。388 CSS px Web 与 387.69 vp 真机宽度下，面板高分别为 435.38 CSS px 与 434.77 vp，数字章顶部、标题换行、按钮位置和主题配色逐项核对。系统栏保留，外围效果使用原生主题遮罩与转场。

[无组合线索真机](../artifacts/validation/ui-gameplay-combination-notice-20261112/native-no-results-01.json) 3 项通过。末题只结算一次，最终 2/2、100 XP，组合解锁记录为零。「知晓了」完整可见，系统返回关闭提示后没有打开组合线索或显示入口。

[签名包真机运行时](../artifacts/validation/ui-gameplay-combination-notice-20261112/runtime-01.json) 5 项通过，含隔离 HTTPS 可信 CA、未知 CA、错误主机名。[GameplayClues](../artifacts/validation/ui-gameplay-combination-notice-20261112/unit-clues/local-test-summary.json) 9/9 及 [GameplayAnswerViewModel](../artifacts/validation/ui-gameplay-combination-notice-20261112/unit-answer/local-test-summary.json) 12/12 通过。[codelinter](../artifacts/validation/ui-gameplay-combination-notice-20261112/lint-01/lint.json) 命令成功，报告 `filesChecked=0`、问题 0。

复验使用 `scripts/hm.sh run` 安装签名包，并用 `scripts/capture-window-evidence.py --font-scale 1 --require-tls` 核对运行时。每个真机分支使用独立隔离账号和预先完成第一题的场次，末题由真机提交。弹层显示时应用退到后台、账号授权失效、1.3 倍字号及折叠屏未单独做真机验收。

[固定预览交接](../artifacts/validation/ui-gameplay-combination-notice-20261112/fixed-preview-restored-01.json) 7 项通过，手机已登录原预览账号并停在首页。安装包与隔离真机包的 [ArkTS 字节码一致](../artifacts/validation/ui-gameplay-combination-notice-20261112/preview-package-equivalence-01.json)。[清理记录](../artifacts/validation/ui-gameplay-combination-notice-20261112/disposable-cleanup-01.json) 核验一次性 TLS、后端、数据库和凭据已清理，固定预览数据库保留。

### C01f 普通视频线索手动播放（2026-11-12）

冻结 Web `4b7d1a0` 的普通线索卡片以服务端授权、当前完成题与原有顺序为准。`kind=video` 有独立卡片入口。手机播放器使用暗色遮罩、居中等比画面、圆形关闭按钮和播放器控制，主动点开即播放，结束自动回原题。已有卡片仅预览文字的决定适用于视频卡片。

| 状态 | 验收目标 |
| --- | --- |
| 未完成、切题、缺少来源 | 当前题已完成才展示服务端已发放且有视频来源的卡片，沿用档案编号和文案。无法接受的来源进入本地错误反馈。 |
| 加载、播放、暂停、跳转 | 已授权卡片主动点开后加载并自动播放，使用官方原生控件。等待时可关闭，网络错误可手动重试。复验真实 HTTPS、实际画面及时间变化。 |
| 播完、关闭、系统返回 | 回到同一题和同一档案，回访可手动重播。点遮罩、主动关闭或自然播放结束均不写玩法、不自动切题。 |
| 后台、账号或授权变化 | 立即停止播放并撤销播放源。旧准备、失败或结束事件不能接管新播放或恢复私密内容。 |
| 视觉 | 同数据、同媒体字节、同宽度核对卡片及播放器原图。暗色播放器保留系统栏对比度，记录官方控件差异。 |

本切片限定普通视频卡片的手动查看。题面及选项视频、正文内嵌视频、答后演出、BGM 和终章各自独立验收。平台取流、临时文件和播放器的职责见 [ADR-022](architecture-decisions.md#adr-022普通视频线索的播放与临时文件)。

[隔离主机夹具](../artifacts/validation/ui-gameplay-video-20261112/host-fixtures-01.json) 用真实 PocketBase 核对三个专用账号的 1/2 进度、50 XP 及两条已发放普通视频。严格 HTTPS 媒体端点使用同一份 640×360、28 秒的合成 MP4，覆盖完整读取、Range、缺少 Referer、凭据拒绝、503 恢复和延迟取消。正式发布样本另做只读头部及少量字节检查，正式业务写入为零。

[冻结 Web 日夜回放](../artifacts/validation/ui-gameplay-video-20261112/web-reference-01.json) 使用 [与真机夹具等价的场次快照及相同 MP4](../artifacts/validation/ui-gameplay-video-20261112/web-input-binding-01.json)。388×771 CSS px 下测得播放画面 360×202.5 CSS px、两侧各 14 CSS px、关闭按钮 46 CSS px。实际播放画面、主动关闭与真实播放结束均有证据，点开前媒体请求为零，外部及业务请求未转发。

[GameplayClues 单测](../artifacts/validation/ui-gameplay-video-20261112/unit-clues-01/local-test-summary.json) 10/10 通过。[codelinter](../artifacts/validation/ui-gameplay-video-20261112/lint-01/lint.json) 命令成功，报告 `filesChecked=0`、问题 0。[最终直板机运行时](../artifacts/validation/ui-gameplay-video-20261112/runtime-02.json) 5 项通过，含已签名包安装启动、窗口尺寸及隔离 HTTPS 三种证书结果。真机媒体操作另记。

[日间真机原始记录](../artifacts/validation/ui-gameplay-video-20261112/native-light-01.json) 的 8 项交互均通过。首次渲染视频为 0:07，暂停两次采样均为 0:09，拖动后为 0:18，继续播放到 0:23。自然结束、关闭按钮、系统返回和点遮罩均回到同一题。隔离端点实际返回 503，点「重新加载」后真实返回 200 并恢复播放。播放中退到后台再进入，播放器保持关闭，原题和未提交草稿可继续使用。玩法台账与只读 SQLite 对账均无新增入场或答题。

日间原始报告保留 `incomplete`。受控慢请求在用户关闭播放器后仍由网关于约 10 秒发出完整 HTTP 200，原驱动要求连接提前中断。[独立复核](../artifacts/validation/ui-gameplay-video-20261112/native-light-ui-review-01.json) 确认真机已在响应前完成关闭，并在响应后复查没有播放器重开。实际传输中断未证实。

[夜间真机](../artifacts/validation/ui-gameplay-video-20261112/native-dark-01.json) 3 项通过。已完成题的两张视频卡片正确显示，未完成题无入口。官方全屏控件扩大播放区，第一次系统返回恢复原内嵌播放器和尺寸，第二次返回同一张线索卡。媒体只发一次 GET，草稿和玩法结算未变。

[同数据日夜原图复核](../artifacts/validation/ui-gameplay-video-20261112/visual-review-01.json) 将两份真机报告、同一测试媒体、安装包和冻结 Web 原图绑定。真机视频区域 359.69×202.46 vp，Web 360×202.50 CSS px，中心位置和关闭按钮相符。视频区采用近黑原生底和 ArkUI 控件，Web 参考图使用带星轨的半透明暗底。两张卡片的标题、编号、预览换行与主题分别核对。

复验通过 `scripts/hm.sh run` 安装，`scripts/capture-window-evidence.py --font-scale 1 --require-tls` 记录实际视口及 HTTPS，`scripts/hm.sh test GameplayClues` 验证授权投影。`scripts/capture-web-gameplay-clue-video.py` 对冻结 Web 做独立重放。直板机播放、故障及双返回驱动在 `artifacts/private/gameplay-video-20261112/`，使用预结算的独立账号、精确签名包和固定媒体哈希。播放中授权撤回、1.3 倍字号及折叠屏未单独做真机验证。

[固定预览交接](../artifacts/validation/ui-gameplay-video-20261112/fixed-preview-restored-01.json) 7 项通过，手机已留在原账号的已登录首页。交付包与隔离真机包的 [ArkTS 字节码一致](../artifacts/validation/ui-gameplay-video-20261112/preview-package-equivalence-01.json)。[清理记录](../artifacts/validation/ui-gameplay-video-20261112/disposable-cleanup-01.json) 核验三个一次性账号的结算与验收前相同，专用后端、数据库和 TLS 已移除。

### C01g 题图和线索查看器回看缓存（2026-11-12）

| 场景 | 验收目标 |
| --- | --- |
| 题目 A → B → A | 当前场次内回到已成功显示的题图时直接绘制。普通题图、选项图和正文线索图使用同一缓存范围。 |
| 查看器 A → B → A | 同一图集横向滑回已解码的图片时直接绘制。索引、缩放复位和退出行为按现有规则。 |
| 首次加载、失败、淘汰 | 使用现有 HTTPS 校验、下载、解码和重试。缓存只收录成功解码的图片。 |
| 离开、账号或场次失效 | 清除该场次缓存，丢弃迟到结果。淘汰仅移除缓存持有的引用，仍在显示的图片由组件释放。 |

验收使用直板机和隔离后端。回看以实际画面和缓存命中记录确认，内存上限、逐出、活动引用及迟到结果另由针对性测试核对。

[直板机验收](../artifacts/validation/ui-gameplay-image-cache-20261112/native-cache-01.json) 使用已完成的隔离预览场次「清宫那点事」。题号按 6 → 5 → 6 切换，两题首次各完成一次 HTTP 200 和解码。第 6 题回看只记录缓存命中及 `ready`。打开组合线索并在查看器实际横滑 1 → 2 → 1，三次均直接使用正文已解码的图片，无 `loading`。复核了回看题图和查看器原图。验收前后的服务端进度相同，手机留在已登录的预览首页。

`scripts/hm.sh run` 完成构建、签名、安装和启动。[运行时与 HTTPS](../artifacts/validation/ui-gameplay-image-cache-20261112/runtime-01.json) 5 项通过。`scripts/hm.sh test QuestionImageCacheTests` [4/4 通过](../artifacts/validation/ui-gameplay-image-cache-20261112/QuestionImageCacheTests/local-test-summary.json)，覆盖字节和条数上限、逐出与显示引用、场次失效和迟到结果。`scripts/hm.sh test QuestionImageLoaderTests` [4/4 通过](../artifacts/validation/ui-gameplay-image-cache-20261112/QuestionImageLoaderTests/local-test-summary.json)。`scripts/hm.sh lint` 成功执行，报告扫描文件数为 0。[lint 报告](../artifacts/validation/ui-gameplay-image-cache-20261112/lint-01/lint.json)

### C01h 横滑中的相邻题图

| 场景 | 验收目标 |
| --- | --- |
| 横向拖回已看题目 | 两张题卡仍同时可见时，进入视口的题图已画出。切题落定后同一图片继续显示。 |
| 横滑到没有缓存的可读题 | 图片下载、加载反馈及失败重试从切题落定后开始。拖动期间相邻题卡只使用已解码的图片。 |
| 相邻题授权和交互 | 图像跟随已授权题卡。答题、提示、线索和图片点击使用现有当前题门控。 |

以同设备拖动中的原图和落定后的图片为证据。单看切题完成后的缓存命中不足以证明过渡连续。

[直板机验收](../artifacts/validation/ui-gameplay-swiper-images-20261112/native-swiper-03.json) 使用固定隔离预览场次「清宫那点事」。先读第 6 题，再切到第 5 题，用官方保持触点手势往回拖。松手前的原图同时显示两张题图，与两张停稳原图分别匹配。实测两图横向位移之差为 1185 px，Swiper 宽 1182 px，纵向位移均为 0。松手后回到第 6 题，图片已显示，期间没有新的 `loading`。服务端进度一致，手机回到已登录首页。[uinput 官方文档](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/uinput/)

[短时间窗口尝试](../artifacts/validation/ui-gameplay-swiper-images-20261112/native-swiper-01.json) 未抓到滑动中的原图。[第一次保持触点尝试](../artifacts/validation/ui-gameplay-swiper-images-20261112/native-swiper-02.json) 的采集脚本在截图前缺少 `time` 导入。保留两份原报告，修正采集后用同一签名包重新验证。冷图的加载时点由代码审查核对，真机中途截图覆盖已经显示过的两张题图。

`scripts/hm.sh run` 构建、签名、安装和启动成功。[运行时与 HTTPS](../artifacts/validation/ui-gameplay-swiper-images-20261112/runtime-01.json) 5 项通过。图片缓存、加载器及玩法 ViewModel 的相关单测分别为 4/4、4/4、10/10。`scripts/hm.sh lint` 成功执行，报告扫描文件数为 0。[缓存测试](../artifacts/validation/ui-gameplay-swiper-images-20261112/QuestionImageCacheTests/local-test-summary.json) · [加载器测试](../artifacts/validation/ui-gameplay-swiper-images-20261112/QuestionImageLoaderTests/local-test-summary.json) · [玩法测试](../artifacts/validation/ui-gameplay-swiper-images-20261112/GameplayViewModel/local-test-summary.json) · [lint 报告](../artifacts/validation/ui-gameplay-swiper-images-20261112/lint-01/lint.json)

### C01i 答对后自动播放视频线索

| 场景 | 验收目标 |
| --- | --- |
| 非末题答对并解锁 | 从本次答题响应与授权快照选取自动播放的视频线索。显式空效果及显式关闭自动播放有效；效果字段缺失时才比较新增授权。 |
| 自然播完 | 沿用 ArkUI 视频查看器。视频全部播完且浮层关闭后，按题目配置进入后端当前题；未配置则保留原题。 |
| 提前关闭与失败 | 关闭或系统返回取消自动前进。加载或播放失败保留已结算进度，可重试视频；重试仅请求媒体。 |
| 回访与离开 | GET、刷新及回访静默，已发放线索可手动重看。退后台、离开场次、切换账号或授权失效时取消当前自动播放和前进。 |

本片验证非末题视频，沿用已有题卡、播放界面及访问权限。验收以隔离 HTTPS 答题结果、直板机播放器状态和服务端写入记录为准。

[隔离主机](../artifacts/validation/ui-gameplay-auto-video-20261112/host-fixtures-01.json) 通过严格 HTTPS 验证首题答对只结算一次，新增一条视频授权与 50 XP。答题响应中的线索效果与新增授权一致，后续 GET 无过渡效果。视频使用带时间戳的 28 秒合成 MP4。

[真机自然结束](../artifacts/validation/ui-gameplay-auto-video-20261112/native-natural-01.json) 3 项通过。首题答对后无额外触摸自动播放，采集到第 6 秒和第 25 秒的画面，播完进入可编辑的第 2 题。回访产生真实 GET，仍停在第 2 题，期间没有额外媒体请求或玩法写入。

[真机提前关闭](../artifacts/validation/ui-gameplay-auto-video-20261112/native-early-01.json) 3 项通过。用关闭按钮结束播放，超过原播放时长后仍显示只读的第 1 题和已授权线索。手动点「下一题」才进入第 2 题，回访静默。

[真机媒体失败和重试](../artifacts/validation/ui-gameplay-auto-video-20261112/native-failure-01.json) 3 项通过。夜间实际收到 503，居中的错误文案、重新加载和关闭按钮清晰可见。点「重新加载」后只新增一条返回 200 的媒体 GET，播放器实际到第 5 秒和第 25 秒，自然结束后进入第 2 题。三组分别只记录一次入场和一次正确答题，各有一条题目进度、视频授权及 50 XP。

[同数据日间对照](../artifacts/validation/ui-gameplay-auto-video-20261112/visual-review-01.json) 绑定冻结 Web、真机包及同一 MP4 第 6 秒的原图。以各自可用内容区计，真机画面 359.69×202.46 vp，Web 360×202.50 CSS px，居中位置与关闭按钮差异均小于 1 个逻辑像素。两端均进入同内容第 2 题，原生沿用已确认的滚动定位及收起顶栏。[冻结 Web 日夜行为](../artifacts/validation/ui-gameplay-auto-video-20261112/web-reference-01.json)使用隔离响应重放。

复验使用 `scripts/hm.sh build`、`scripts/hm.sh run`、`scripts/capture-window-evidence.py --font-scale 1 --require-tls` 与私有目录 `artifacts/private/gameplay-auto-video-20261112/` 下的 `device-auto-video.py`。编译、签名、安装和启动成功，绑定该签名包的[实际窗口及 HTTPS 记录](../artifacts/validation/ui-gameplay-auto-video-20261112/runtime-01.json) 5 项通过。

`scripts/hm.sh test GameplayClues` [11/11](../artifacts/validation/ui-gameplay-auto-video-20261112/GameplayClues/local-test-summary.json)，`scripts/hm.sh test GameplayAnswerViewModel` [16/16](../artifacts/validation/ui-gameplay-auto-video-20261112/GameplayAnswerViewModel/local-test-summary.json)。显式空效果、同题授权、多个视频的顺序、关闭后的重复回调、后台期间迟到的结算及关闭自动前进的场景由单测覆盖。ETS 目录及单文件 codelinter 均返回扫描文件数 0，项目级增量报告只列出原启动图标的一条尺寸建议。[目录](../artifacts/validation/ui-gameplay-auto-video-20261112/lint-01/lint.json) · [单文件](../artifacts/validation/ui-gameplay-auto-video-20261112/lint-01/targeted.json) · [项目增量](../artifacts/validation/ui-gameplay-auto-video-20261112/lint-01/incremental.json)

本轮三组真机均是单个视频且题目开启自动前进。多个视频、关闭自动前进及答题响应在后台迟到由单测验证。视频播放中系统返回、前后台切换、账号变化、授权撤回、1.3 倍字号与折叠屏未单独重验。

[固定预览交接](../artifacts/validation/ui-gameplay-auto-video-20261112/fixed-preview-restored-01.json) 确认手机已留在原账号的已登录首页，交付包与真机验收包的 [ArkTS 字节码一致](../artifacts/validation/ui-gameplay-auto-video-20261112/preview-package-equivalence-01.json)。[清理回执](../artifacts/validation/ui-gameplay-auto-video-20261112/disposable-cleanup-01.json) 核验 5 个一次性账号各结算一次，并移除专用后端、数据库及 TLS。

### C01j 答对后的文字与图片线索演出

| 场景 | 验收目标 |
| --- | --- |
| 非末题答对解锁混合线索 | 按冻结 Web 的授权及线索顺序展示文字、图集和视频。显式不自动播放的线索留在档案，旧响应兼容仍使用同题新增授权。 |
| 文字、图集与视频收起 | 文字和图集关闭后继续演出。图集换图或关闭文字内嵌图只影响当前阅读。视频提前关闭后仍展示余下线索，并取消自动切题。 |
| 最后一项结束 | 全部自动线索关闭后按题目配置进入服务端当前题。图片加载失败可使用原有重试，媒体读取不重复写入答题。 |
| 返回与回访 | 普通退后台、场次或账号失效取消演出。明确的正文外链交接保留当前阅读和余下线索，回前台校验授权，沿用取消自动前进的规则。刷新和回访不创建演出。 |

沿用现有原生阅读弹层、图片查看器和播放器。以同数据 Web、直板机、隔离真实 HTTPS 与服务端写入记录分别验收。

[隔离主机](../artifacts/validation/ui-gameplay-auto-clues-20261112/host-fixtures-01.json) 核对真实答题响应依序发放文字、手动文字、视频、图集四条线索。自动演出顺序为文字、视频、图集，GET 不返回演出效果。两张合成 PNG 分别绑定哈希，第一张受控返回 503 后可恢复，第二张读取不受影响。

[冻结 Web 回放](../artifacts/validation/ui-gameplay-auto-clues-20261112/web-reference-01.json) 共四组，覆盖日夜主题和视频自然或提前关闭。浏览器使用同一隔离场次的响应、合成双图和视频。文字收起后播放视频，自然结束或提前关闭均进入双图查看器。只有自然结束分支在关闭图集后自动切题，回访静默。

官方工具构建、签名、安装及启动成功。[真机运行时](../artifacts/validation/ui-gameplay-auto-clues-20261112/runtime-01.json) 5 项通过。单测为 [GameplayClues 11/11](../artifacts/validation/ui-gameplay-auto-clues-20261112/GameplayClues/local-test-summary.json)、[GameplayAnswerViewModel 17/17](../artifacts/validation/ui-gameplay-auto-clues-20261112/GameplayAnswerViewModel/local-test-summary.json)、[QuestionImageLoaderTests 4/4](../artifacts/validation/ui-gameplay-auto-clues-20261112/QuestionImageLoaderTests/local-test-summary.json)。[ETS 目录 codelinter](../artifacts/validation/ui-gameplay-auto-clues-20261112/lint-01/lint.json) 报告扫描文件数 0。

[首次采集](../artifacts/validation/ui-gameplay-auto-clues-20261112/native-natural-01.json) 在入场前停止。采集器原先把有换行的富文本按多个 ArkUI 节点验证，随后改用原始文本与同一段内的 Span。隔离账号入场、答题和经验台账仍为零，继续使用相同签名包复验。

[直板机自然分支](../artifacts/validation/ui-gameplay-auto-clues-20261112/native-natural-02.json) 4 项通过。首题只结算一次，先显示带高亮及换行的授权文字，关闭后才请求视频。自然结束后图集首图实际收到 503，点重试收到 200，成功显示横图及竖图。关闭图集才进入可编辑的第 2 题。回访产生授权 GET，媒体和答题台账无新增。

[直板机夜间提前关闭分支](../artifacts/validation/ui-gameplay-auto-clues-20261112/native-early-01.json) 4 项通过。系统返回收起文字，提前结束视频仍显示双图，关闭图集回到第 1 题。手动线索可从档案打开，点「下一题」才切题，回访未再演出。

[直板机后台中断分支](../artifacts/validation/ui-gameplay-auto-clues-20261112/native-interrupt-01.json) 4 项通过。自动文字出现时按 Home，系统桌面取得焦点。返回应用后通过授权 HTTPS GET 恢复已结算的第 1 题，视频及图片请求均为零，手动线索仍能查看。三组各有一次入场、一次正确答题、一次经验结算及四条授权。

[日间同数据原图对照](../artifacts/validation/ui-gameplay-auto-clues-20261112/visual-review-02.json) 绑定同场次真实结算、图像哈希、签名包、原图及布局树。原生文字弹层约 339.69×260.00 vp，Web 为 340.00×261.56 CSS px。原生系统居中比 Web 约高 5.04，关闭按钮 44 vp 对 42 CSS px。图库的舞台、两张图的尺寸及定位误差均小于 0.4 个逻辑像素，图集索引与横竖比例一致。

[夜间同数据原图对照](../artifacts/validation/ui-gameplay-auto-clues-20261112/visual-review-early-01.json) 使用 Web 入场动画结束后的[补采原图](../artifacts/validation/ui-gameplay-auto-clues-20261112/web-reference-02.json)，核对文字高亮、段落、两图索引及位置。日夜共核对六组原图。

[项目增量 codelinter](../artifacts/validation/ui-gameplay-auto-clues-20261112/lint-01/incremental.json) 仅列出已有启动图标的尺寸建议。

自动文字中的外链回源及保留队列由本轮单测覆盖。正文内嵌图和外链仍沿用此前的阅读流程，本轮真机夹具覆盖独立图集。折叠屏和 1.3 倍字号留在专项验收。

[固定预览交接](../artifacts/validation/ui-gameplay-auto-clues-20261112/fixed-preview-restored-01.json) 确认手机留在原账号的已登录首页，[预览包的 ArkTS 字节码](../artifacts/validation/ui-gameplay-auto-clues-20261112/preview-package-equivalence-01.json) 与隔离验收包一致。[清理回执](../artifacts/validation/ui-gameplay-auto-clues-20261112/disposable-cleanup-01.json) 确认五个一次性账号各结算一次，专用后端、数据库和 TLS 已移除。

### C01k 末题普通线索、完成提示与组合线索

| 场景 | 验收目标 |
| --- | --- |
| 普通多题场次末题答对 | 按本次响应依序展示已授权自动普通线索。最后一个浮层关闭后，才打开既有完成提示。 |
| 提前关闭视频与确认提示 | 提前关闭视频后继续余下普通线索，随后仍出现完成提示。确认完成提示后按既有顺序展示本次解锁的组合线索。 |
| 空效果与回访 | 显式空效果保留普通完成提示，缺失效果沿用新增授权兼容规则。刷新、回访和重复回调不重播、不重复结算。 |
| 退出及单题 | 离开场次、普通退后台或账号失效取消待显示演出。普通单题沿用内联完成状态，可展示末题普通线索。 |

使用冻结 Web 的普通完成样式、同数据和真实隔离 HTTPS 验证。终章顺序另有独立切片。

[隔离主机](../artifacts/validation/ui-gameplay-final-clues-20261112/host-fixtures-01.json) 核对一场两题、独立账号的真实 PocketBase 结算及同一组 PNG/MP4。两组真机账号预先各完成首题，均为 1/2、50 XP、零线索。主机走完两题后为 2/2、100 XP，新增三条普通线索和两条组合线索。GET 无过渡效果。

[冻结 Web 回放](../artifacts/validation/ui-gameplay-final-clues-20261112/web-reference-01.json) 日夜两种主题、自然结束及提前关闭共四组通过。确认普通文字、视频、两张图、完成提示及两条组合线索的先后顺序。已完成场次回访静默，仍可手动打开组合档案。

官方构建、签名、安装及启动成功。[实际窗口和严格 HTTPS](../artifacts/validation/ui-gameplay-final-clues-20261112/runtime-01.json) 5 项通过。[GameplayClues 12/12](../artifacts/validation/ui-gameplay-final-clues-20261112/GameplayClues/local-test-summary.json) 与 [GameplayAnswerViewModel 19/19](../artifacts/validation/ui-gameplay-final-clues-20261112/GameplayAnswerViewModel/local-test-summary.json) 包含跨题绑定的显式末题授权、提前关闭、重复消失回调与中断后回访。[ETS 目录 codelinter](../artifacts/validation/ui-gameplay-final-clues-20261112/lint-01/lint.json) 报告扫描文件数 0，[增量检查](../artifacts/validation/ui-gameplay-final-clues-20261112/lint-01/incremental.json) 仅列出已有启动图标的尺寸建议。

[日间直板机自然结束](../artifacts/validation/ui-gameplay-final-clues-20261112/native-normal-01.json) 5 项通过。末题答对后依次打开普通文字、视频、两张图，关闭图集才出现完成提示。确认后依序展示两条组合线索，系统返回收起最后一条，回到 2/2 只读答题页。历史回访通过严格 HTTPS GET 同步，无新增媒体或答题请求。

[夜间直板机提前关闭](../artifacts/validation/ui-gameplay-final-clues-20261112/native-early-01.json) 5 项通过。记录到视频第 6 秒的实际画面后点关闭，仍依序显示两张图、完成提示及两条组合线索，历史回访静默。每组真机各新增一次末题提交及一次 50 XP 结算，最终均为 2/2、100 XP，授权及回执与 SQLite 一致。

[日夜同数据原图](../artifacts/validation/ui-gameplay-final-clues-20261112/visual-review-01.json) 逐张复核十四个配对状态。原生完成面板 339.69×434.77 vp，Web 为 340×435.38 CSS px。视频和图集舞台尺寸及位置差最大 0.31 个逻辑像素。文字和组合弹层的原生系统居中约高 4–5 个逻辑像素。对照记录了系统遮罩、平台播控及组合标题的 Web 回退字体。

真机夹具为普通两题，跨题绑定的显式末题授权由单测核对。Web 夹具同时跨等级阈值，回放在组合线索之后收起独立的等级提升提示再采集回访。独立等级演出和终章顺序留在对应切片。

[固定预览交接](../artifacts/validation/ui-gameplay-final-clues-20261112/fixed-preview-restored-01.json) 验证原账号已登录并停在首页，[预览包 ArkTS 字节码](../artifacts/validation/ui-gameplay-final-clues-20261112/preview-package-equivalence-01.json) 与隔离验收包一致。[环境清理](../artifacts/validation/ui-gameplay-final-clues-20261112/disposable-cleanup-01.json) 确认四个隔离账号各完成一次末题结算，专用后端、数据库和 TLS 已移除。

### C01l 题卡、组合线索浮标与完成弹窗动效

| 状态 | 验收目标 |
| --- | --- |
| 当前答题卡 | 前台活动题卡的内容背后有低对比度斜向扫光，保留冻结 Web 的周期和停顿。扫光裁在卡内，题面、输入、滑动和点击照常。 |
| 组合线索浮标 | 归档入口轻量入场，外沿呼吸、内圈缓慢旋转。按钮仍可点击和拖动，光效不改变点击区域。 |
| 组合完成提示 | 保留原生模态与原有确认顺序，恢复边沿扫亮、底纹、徽记起伏和装饰粒子。正文及确认键不跟随装饰缩放，仍可正常操作。 |
| 减少动画、失焦和退出 | 系统减少动画时显示静态布局，退出前台、切换题卡或关闭弹层时停止相关装饰。以同状态连续画面及控件操作核验。 |

[冻结 Web 动效](../artifacts/validation/ui-gameplay-motion-20261112/web-motion-01.json) 在 388×771 视口核对日夜及减少动画，共保存 33 张原始渲染帧。[同数据绑定](../artifacts/validation/ui-gameplay-motion-20261112/web-motion-input-binding-01.json) 核对第二题、末题响应、授权关系和三份媒体字节。

[首轮直板机](../artifacts/validation/ui-gameplay-motion-20261112/native-motion-01.json) 在无触摸且控件坐标固定时，分别取得题卡 24 帧、完成提示 8 帧、浮标 8 帧。完成提示和浮标的对应区域有连续变化，题卡样本静止。该轮同时验证确认完成提示、点浮标再次查看、历史回访与末题单次结算。

题卡扫光接入 ArkUI V2 同步刷新后，[直板机历史场次只读补拍](../artifacts/validation/ui-gameplay-motion-20261112/native-card-motion-02.json) 取得 26 帧，原图显示斜向光带。单独检查卡片上半部，取样区域位于浮标上方，连续帧最大平均 RGB 差为 4.6423（每通道 0–255）。补拍前后的入场、答题、授权及经验记录一致。[动态原图复核](../artifacts/validation/ui-gameplay-motion-20261112/visual-review-01.json) 关联两轮报告并核对浮标、弹窗和页面源码一致。真机覆盖日间效果与点击。夜间及减少动画仅有 Web 对照，弹窗进出场时长及浮标拖动未另做本轮实测。

编译、签名、安装及[最终直板机窗口与 TLS](../artifacts/validation/ui-gameplay-motion-20261112/runtime-03.json) 5 项通过。[GameplayClues 12/12](../artifacts/validation/ui-gameplay-motion-20261112/GameplayClues/local-test-summary.json) 与 [GameplayAnswerViewModel 19/19](../artifacts/validation/ui-gameplay-motion-20261112/GameplayAnswerViewModel/local-test-summary.json) 通过。[ETS 目录 codelinter](../artifacts/validation/ui-gameplay-motion-20261112/lint-01/lint.json) 报告扫描文件数 0，[增量检查](../artifacts/validation/ui-gameplay-motion-20261112/lint-01/incremental.json) 仅列出已有启动图标的尺寸建议。

[固定预览恢复](../artifacts/validation/ui-gameplay-motion-20261112/fixed-preview-restored-01.json) 已登录并保留在手机，[包内容核对](../artifacts/validation/ui-gameplay-motion-20261112/preview-package-equivalence-01.json) 确认预览版与隔离版的 ArkTS 字节码一致。[隔离环境清理](../artifacts/validation/ui-gameplay-motion-20261112/disposable-cleanup-01.json) 记录两个专用账号均只提交一次末题。

### C01m 已迁移答题与线索动效复查（2026-11-13）

| 小点 | 验收目标 |
| --- | --- |
| 答题顶栏 | 左上头像恢复主题色外圈和轻微起伏，44vp 按钮、菜单方向及顶栏显隐规则保持。核对进场和已完成计数变化时的动效，以及回顶、返回和菜单命中。 |
| 题面与反馈 | 按冻结 Web 核对初次出现、切题、答案输入与选项、答错或答对及下一题。补齐可见缺漏，保留已确认的 Swiper、滚动定位及服务端状态。 |
| 线索弹层 | 核对手动及自动线索出现和关闭、读图与组合线索。使用 ArkUI 还原适用的内容转场及反馈，验证关闭中断、队列顺序和回访无自动演出。 |
| 动效边界 | 日夜对照，系统减少动画时装饰静止且操作可达。直板按小点采原图及连续帧，使用隔离真实 HTTPS，分别登记实际结果。 |

冻结 Web `4b7d1a0` 的实测分为[头像和线索](../artifacts/validation/ui-gameplay-motion-audit-20261113/web-header-motion-02.json)、[答题反馈和选题](../artifacts/validation/ui-gameplay-motion-audit-20261113/web-answer-motion-03.json)及[下一题和手动关窗](../artifacts/validation/ui-gameplay-motion-audit-20261113/web-followup-motion-01.json)。头像按 44px 内容、5px 淡色带和外描边对照，减少动画静止时保留双圈。正式 Web 的图片查看器缩放模式不动图像本体，原生图库继续保留稳定像素和手势，新增边框与背景效果。弹窗遮罩沿用 ArkUI，Web 的全屏放射纹和遮罩呼吸留待独立复核，场次全屏氛围及尚未迁移的奖励和终章另记。

| 小点 | 直板真机与验收证据 |
| --- | --- |
| 头像和答错 | 日间青绿、夜间金色各 6 张原图。头像外圈跟随头像起伏，菜单徽记原位，按钮固定且可打开和关闭左侧栏。原图看到错误粒子、反馈边线收短和消退后原答案仍在。在一次点击与截图并发的测试中观察到两条隔离错误记录，原因未确认，经验仍为 0。该轮单次提交断言保留为未通过，另一隔离场次只记录一条错误请求。[原图复核](../artifacts/validation/ui-gameplay-motion-audit-20261113/native-header-incorrect-visual-01.json) |
| 答对和进度 | 最终包原图显示 1/2 计数淡入、「验证通过」、只读答案和「前往下一题」。将连续截屏留在手机并在动作结束后统一拉取，补拍到青绿光晕和粒子扩散、消退。SQLite 核对一次正确答题和一笔 50 XP。原测试等待旧控件标识的超时保留为 incomplete。[快速补拍](../artifacts/validation/ui-gameplay-motion-audit-20261113/native-success-visual-01.json) · [实测与对账](../artifacts/validation/ui-gameplay-motion-audit-20261113/native-success-impact-01.json) |
| 选题和选项 | 当前题号按钮的底部亮线在固定范围内连续变化。点击「前往下一题」进入选择题，真机原图显示选项的着色、横移和字母块轻倾，UiTest 读取选中 Radio。回访及本次切题未新增答题或经验。切题动画的精确时长未测。[导航实测](../artifacts/validation/ui-gameplay-motion-audit-20261113/native-navigation-motion-01.json) |
| 重连 | 专用场次首个请求注入 503，确认重连弹层的双圈脉冲。点击后拍到「正在重新连接…」左侧图标旋转，待原请求重试成功后弹层关闭，SQLite 只写入一条答题及一笔 50 XP。[重连动效与对账](../artifacts/validation/ui-gameplay-motion-audit-20261113/native-recovery-motion-01.json) |
| 自动线索与媒体 | 普通文字和组合文字面板的底纹随帧变化，视频播放和图集切到第 2 张均为真实授权，完成提示确认后才进入组合线索。初次驱动在档案内关闭弹层后直接等待屏幕外题名，报告保留为 incomplete。SQLite 记录一条原生末题提交、2/2、100 XP 和准确线索授权。[首轮](../artifacts/validation/ui-gameplay-motion-audit-20261113/native-clue-motion-01.json) |
| 归档回访 | 首轮原图发现装饰撑高档案标题区，修正后标题到第一张卡实测 20vp，标题范围内连续帧有轨道变化。已完成场次只读回访、点击第一条再关闭均实测，SQLite 台账一致。[修正版补拍](../artifacts/validation/ui-gameplay-motion-audit-20261113/native-archive-motion-02.json) |

[最终隔离安装及窗口/TLS](../artifacts/validation/ui-gameplay-motion-audit-20261113/runtime-06.json) 5 项通过，真实直板 1260×2720、density 3.25、字号 1。[GameplayClues 12/12](../artifacts/validation/ui-gameplay-motion-audit-20261113/GameplayClues-final/local-test-summary.json) 和 [GameplayAnswerViewModel 19/19](../artifacts/validation/ui-gameplay-motion-audit-20261113/GameplayAnswerViewModel-final/local-test-summary.json) 通过。[codelinter](../artifacts/validation/ui-gameplay-motion-audit-20261113/lint-final/lint.json) 退出 0、`filesChecked=0`。源代码仍含两处 ArkTS 对同步动画工具的异常提示。夜间真机覆盖头像，线索和答题真机采样为日间。减少动画已做 Web 回放及原生策略审查，未切换手机系统开关实测。短时 ArkUI 入退场的精确时长不由逐帧截屏推定。

[固定预览](../artifacts/validation/ui-gameplay-motion-audit-20261113/fixed-preview-restored-01.json) 已恢复登录，验证包和预览包的 [ArkTS 字节码一致](../artifacts/validation/ui-gameplay-motion-audit-20261113/preview-package-equivalence-01.json)。[隔离环境](../artifacts/validation/ui-gameplay-motion-audit-20261113/disposable-cleanup-01.json) 已移除，固定预览数据库及凭据文件通过身份核验。

### Q04a 答题后的等级提升演出

| 场景 | 验收目标 |
| --- | --- |
| 普通多题末题正确并跨级 | 用服务端新旧等级比较触发一次，依次结束普通线索、完成提示及组合线索后展示升级弹窗。弹窗显示新等级编号和名称，确认或系统返回后回到已完成场次。 |
| 非末题跨级 | 有自动下一题时沿用 Web 的顺序，先结束线索与自动切题，再展示升级。提前关闭视频仍取消自动切题，升级提示仍可展示。 |
| 未跨级、回访与中断 | 同级或错误结果、已完成响应、刷新和历史回访不展示升级。离场、退后台或账号失效清除本次演出，回源仍读到实际等级和进度。 |
| 外观与动态验收 | 用同一隔离服务端快照对照冻结 Web，核对徽章、名称、状态、按钮与生效的进退场、光环和粒子。直板机核对正常动画及系统「减少动画」下的操作可达性，逐项记录实际证据。 |

本片范围为普通场次的新答题结果。使用专用隔离真实 HTTPS 场次验证跨级与未跨级；检查答题回执、经验账本和只读回访。终章、剧情、奖励和 BGM 属于各自切片。

同一普通双题场次的隔离数据用于原生和冻结 Web `4b7d1a0` 对照。[Web 原图与动作记录](../artifacts/validation/ui-gameplay-rank-20261113/web-reference-05.json) 覆盖日夜主题、减少动画及未跨级；页面重放来自 [严格 HTTPS 准备的真实 DTO](../artifacts/validation/ui-gameplay-rank-20261113/host-fixtures-02.json)，浏览器不回写。Web 外层独立环形光与背景模糊保留为视觉差异；原生用官方模态遮罩，面板内用 ArkUI 实现徽章轨道、呼吸、扫光和粒子。

- [最终直板安装与 HTTPS](../artifacts/validation/ui-gameplay-rank-20261113/runtime-02.json) 的窗口和证书 5 项通过，1260×2720，density 3.25，字号 1。[跨级原生验证](../artifacts/validation/ui-gameplay-rank-20261113/native-crossing-02.json) 在 100 XP 时显示「旅行者 2」，且只在普通线索、完成提示和两条组合线索全部结束后展示。点外不关闭，确认后回到已完成题；历史回访不重播。SQLite 核实一次原生末题 POST、该题一笔经验。
- [未跨级原生验证](../artifacts/validation/ui-gameplay-rank-20261113/native-noncrossing-01.json) 在 90 XP 时仍为等级 1，原有线索照常显示，未出现升级弹窗。两类场次的 [独立 HTTPS 与 SQLite 对账](../artifacts/validation/ui-gameplay-rank-20261113/host-ledger-01.json) 核实收据、写入次数、经验、线索授权及只读回访。
- [原图复核](../artifacts/validation/ui-gameplay-rank-20261113/visual-review-01.json) 实测原生面板 359.7×468.9vp、按钮 180×46.2vp，Web 360×470.2 CSS px、按钮 180×46 CSS px。日夜原图中布局、文字及点击区可读可达，连续画面可见动效变化；未用截屏序列推定原生动画精确时长。
- [夜间真机](../artifacts/validation/ui-gameplay-rank-20261113/native-reduced-01.json) 在系统「过渡动画」关闭时可用系统返回关闭且不重播；面板内仍可见动效。[诊断](../artifacts/validation/ui-gameplay-rank-20261113/system-motion-probe-01.json) 证实切换该选项前后 [AccessibilityKit 减弱动效状态](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-accessibility/) 均为 false，系统选项已恢复。应用收到减弱动效为 true 时不挂载持续动画；该系统分支未在本机触发，保留待验。
- [答题 20/20](../artifacts/validation/ui-gameplay-rank-20261113/GameplayAnswerViewModel/local-test-summary.json) 与 [线索 12/12](../artifacts/validation/ui-gameplay-rank-20261113/GameplayClues/local-test-summary.json) 通过。非末题自动切题、提前关闭视频、历史回访和取消只使用相应本地用例覆盖的范围。未为这些分支新增真机场次。[codelinter](../artifacts/validation/ui-gameplay-rank-20261113/lint/lint.json) 退出 0、`filesChecked=0`，不计为实际源码静态检查覆盖。

已恢复[固定预览登录](../artifacts/validation/ui-gameplay-rank-20261113/fixed-preview-restored-01.json)，隔离包与预览包的 [ArkTS 字节码一致](../artifacts/validation/ui-gameplay-rank-20261113/preview-package-equivalence-01.json)。本轮[临时环境已移除](../artifacts/validation/ui-gameplay-rank-20261113/disposable-cleanup-01.json)，固定预览资料和进度保留。

### T02a 答题页背景音乐与视频互斥

以冻结 Web `4b7d1a0` 的正式玩法页为参照。先迁移答题页的播放与悬浮播控；拖动与位置记忆、剧情配乐与配音另验。

| 场景 | 验收目标 |
| --- | --- |
| 播放、暂停、恢复 | 有有效曲目才显示悬浮按钮。跟随 Web 默认尝试低音量循环，实际播放器状态决定按钮的播放状态和动效。主动暂停后切题或返回答题页不擅自播放；偏好按账号隔离，不持久化凭据或曲目。 |
| 关卡配置 | 默认继承场次音乐；同曲目切题不重建，`custom` 换曲，`silent` 停止并隐藏控件，自定义缺少地址不回退。已完成场次回访按当前题配置。 |
| 视频和生命周期 | 已有视频查看器打开前静音 BGM，关闭后只恢复之前想播放的有效曲目。离场、退后台、终态失权和切换账号清理或暂停；系统音频焦点中断不覆盖用户选择。旧网络或播放器回调不能复活音乐。 |
| 失败与视觉 | 真实 HTTPS 媒体失败后按钮允许手动重试，答题正常，不发答题或经验写入。直板机对照同数据日夜播放/暂停和无曲目状态，核对安全区、键盘、组合线索入口与播放状态动效。 |

[隔离场次](../artifacts/validation/ui-gameplay-bgm-20261113/host-fixtures-01.json) 的有效曲目顺序为 A → A → B → 静音。三个专用账号由服务端预先结算前三题，真机验收仅登录、读取、切题和播放；[媒体 HTTPS 验收](../artifacts/validation/ui-gameplay-bgm-20261113/host-media-01.json) 独立核对证书、资源字节与故障路径。冻结题库的 [CDN 单字节只读探测](../artifacts/validation/ui-gameplay-bgm-20261113/cdn-source-probe-01.json) 发现 5 首已发布内容使用的曲目带 Web 来源返回 206，1 首仅归档场次使用的曲目返回 404；不算生产播放验收。

- [主轮直板交互](../artifacts/validation/ui-gameplay-bgm-20261113/native-bgm-02.json) 与 [AVPlayer 状态和进度](../artifacts/validation/ui-gameplay-bgm-20261113/audio-state-review-02.json) 证实真实 MP3 解码、循环、同曲切题复用、切换曲目失败 503 后手动重试、静音题释放旧曲；视频打开暂停、关闭后按原意图恢复。主动暂停跨题与重新进入仍有效；退后台释放、回前台重新核验并恢复，登出释放，第二个账号不继承上个账号的暂停偏好。该轮真实进度和经验账本未变化。
- [同数据 Web 重放](../artifacts/validation/ui-gameplay-bgm-20261113/web-reference-04.json) 和 [日夜原图复核](../artifacts/validation/ui-gameplay-bgm-20261113/visual-review-01.json) 覆盖播放、暂停、静音和视频。原生浮标实测 56×56vp，距安全区右边和下边各 12vp；播放波形的连续帧有可见变化。官方全屏视频层打开时隐藏音乐控件。题卡允许向下滚出浮标覆盖区域，组合线索浮标接近右下角时避让。未验带曲可编辑题的实机键盘状态、组合线索与 BGM 浮标同时出现的真机交互，也未触发系统减弱动效和其他应用的音频焦点中断。原生测试以 AVPlayer 日志和实际界面为据，没有做扬声器录音或耳机切换验收。
- [最终包安装和窗口/TLS](../artifacts/validation/ui-gameplay-bgm-20261113/runtime-03.json) 的 5 项检查通过。[最终包补验](../artifacts/validation/ui-gameplay-bgm-20261113/native-bgm-final-02.json) 和 [播放器时序](../artifacts/validation/ui-gameplay-bgm-20261113/audio-state-final-01.json) 复核循环、视频等待静音及关闭恢复，慢请求开始约 4.4 秒点取消后该播放代次立即释放。约 10 秒后隔离网关仍完成 200，旧代次没有初始化或播放；再次点播走新读取并实际播放，不据此宣称转发链路已断开连接。
- [曲目规则 2/2](../artifacts/validation/ui-gameplay-bgm-20261113/GameplayBgm-final/local-test-summary.json) 与 [线索 12/12](../artifacts/validation/ui-gameplay-bgm-20261113/GameplayClues-final/local-test-summary.json) 通过。[codelinter](../artifacts/validation/ui-gameplay-bgm-20261113/lint-final/lint.json) 命令退出 0、`filesChecked=0`，不算源码静态检查覆盖。

已恢复[固定预览登录](../artifacts/validation/ui-gameplay-bgm-20261113/fixed-preview-restored-01.json)，[预览与最终隔离包的 ArkTS 字节码一致](../artifacts/validation/ui-gameplay-bgm-20261113/preview-package-equivalence-01.json)。[临时环境已移除](../artifacts/validation/ui-gameplay-bgm-20261113/disposable-cleanup-01.json)，独立对账确认三个专用账号没有新增入场、答题或经验写入，固定预览进度未变。

### T02b 背景音乐浮标拖动与位置记忆

按冻结 Web `4b7d1a0` 核对默认右下、跟手拖动、松手吸附最近的左右边、保留纵向位置及账号内恢复。

| 场景 | 验收目标 |
| --- | --- |
| 拖动与点击 | 使用原生单指拖动，约 5vp 起拖，保留 Web 的按压反馈和松手贴边。成功拖动和取消手势均不触发播放、暂停或重试，拖动结束后正常点击仍可切换。 |
| 窗口与布局 | 浮标限制在页面实际安全区内，滚动题卡时固定于窗口。键盘及媒体关闭后恢复位置。减少动画时保留贴边结果。 |
| 位置恢复 | 初次使用默认右下角，松手后保存边与纵向比例，切题、重进场次及重启应用后恢复。按账号和后端隔离，取消拖动不保存。 |
| 直板验收 | 同数据 Web 对照左右贴边。用隔离账号核对拖动前后播放态、点按、返回和位置恢复。 |

- [同数据 Web 触摸回放](../artifacts/validation/ui-gameplay-bgm-drag-20261113/web-reference-03.json) 覆盖日夜和减少动画。原生使用 ArkUI 的 [PanGesture](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-gestures-pangesture/) 和 Button 点击距离阈值。Chrome 触摸回放中 Web 会吞掉拖动后的首次主动点按，原生实测第一次点按就能切换。
- [直板首轮](../artifacts/validation/ui-gameplay-bgm-drag-20261113/native-drag-01.json) 已实测播放中左贴边并限制顶部、暂停中右贴边并限制底部、暂停中左贴边且保持松手高度。三次拖动前后均无播放器状态切换或媒体读取。浮标实测 56vp，安全区边距 12vp。首轮滚动取样未得到位移证据，独立补验。
- [同数据原图对照](../artifacts/validation/ui-gameplay-bgm-drag-20261113/visual-drag-01.json) 对照右下默认、左上、右下及左侧中段。相同的松手比例下，左侧中段纵向比例差约 0.0004。
- [直板补验](../artifacts/validation/ui-gameplay-bgm-drag-20261113/native-drag-02.json) 覆盖真实键盘弹出隐藏、键盘收起恢复、滚动时窗口坐标固定、切回有音乐题、重进场次及杀进程重新登录恢复。另一个隔离账号使用自己的默认右下位置。[恢复状态原图](../artifacts/validation/ui-gameplay-bgm-drag-20261113/visual-drag-02.json) 已逐张与同数据 Web 对照。
- [短拖补验](../artifacts/validation/ui-gameplay-bgm-drag-20261113/native-drag-near-01.json) 中，手指纵向拖约 12vp 后仍在按钮原本范围内松手。浮标移动，播放器无状态变化，无新媒体请求。随后首次正常点击暂停。系统中途取消、原生减少动画及两个浮标同时避让的场景本轮未在真机触发。
- [签名安装与窗口/TLS](../artifacts/validation/ui-gameplay-bgm-drag-20261113/runtime-01.json) 5 项通过。[BGM 用例 3/3](../artifacts/validation/ui-gameplay-bgm-drag-20261113/GameplayBgm/local-test-summary.json) 通过，增加位置适配断言。[codelinter](../artifacts/validation/ui-gameplay-bgm-drag-20261113/lint/lint.json) 退出 0、`filesChecked=0`，不计源码静态检查覆盖。

[固定预览](../artifacts/validation/ui-gameplay-bgm-drag-20261113/fixed-preview-restored-01.json) 已恢复登录，隔离验收包和预览包的 [ArkTS 字节码一致](../artifacts/validation/ui-gameplay-bgm-drag-20261113/preview-package-equivalence-01.json)。[临时环境已移除](../artifacts/validation/ui-gameplay-bgm-drag-20261113/disposable-cleanup-01.json)，三个隔离账号均无新增玩法写入，固定预览资料和进度保留。
