# 原生迁移基线与功能验收对照表

核验日期：2026-10-27；2026-10-28追加系统区沉浸、空详情进度及键盘避让修复（Asia/Shanghai）。本表把功能存在、代码实现、实际运行和视觉对照分开记录；列出验收项不等于通过。修复后最新源码37/37业务测试及lint（0 issues、filesChecked=0）已实际复跑通过；迁移前真实HTTPS49项和沉浸调整前官方UI17项保留各自版本归属。独立1.3字号构建已42/42通过；正常字号HTTPS构建22/22系统UI与6项运行时检查通过，认证4图及主视觉18图captured且清理完成。最终默认mock另有13/13冒烟与4项运行时检查通过，已恢复设备；Web20与原生22图已逐图对照，保留两项非官方细节待调，不标逐字逐像素全过。旧正常字号22项UI与22图已归档为修复前证据，不借旧计数推定新HAP通过。完整结果见 [首切片验收记录](slice-01-validation.md)、[HTTPS及视觉复核](slice-01-https-and-visual-validation.md) 与 [官方ArkUI验证](arkui-system-validation.md)。

## 本轮补充验收计划（2026-10-30，实施前）

用户要求继续任务1，并在收尾后处理预览账号及底栏体验。以下仅列计划，不代表已实现或验收通过；1a40/runtime09及既有报告继续保留原版本归属。

| 编号 | 小功能与逐状态验收 | 当前状态 |
| --- | --- | --- |
| PVIEW | 独立持久隔离PB/HTTPS；固定专用预览账号登录直接进入；重启保留数据；用户自行改密后不静默重置；预览不暴露故障控制，不使用生产账号 | 准备中；尚未启动、安装或手机登录验收 |
| NAV-IME | 真实键盘出现时隐藏浮栏及其命中区域；保留页面/表单实例与草稿；输入、滚动及主要动作可达；键盘关闭后浮栏恢复，返回不误切页 | 待实现及直板机实测 |
| NAV-ICON | 四个页签使用Web正式regular/fill矢量；未选中空心、选中实心；深浅色均清楚，暂未开放入口保持原页 | 待实现及深浅色目视 |
| NAV-LIGHT | 使用官方ImmersiveMaterial交互和触摸流光；先保留输入守卫，实测点击、拖动、松手及取消；没有官方跨项选择事件时不得自制坐标手势冒充系统能力 | 官方能力调研完成，未实现或实测 |
| MENU-SIDE | 保留官方沉浸玻璃材质，按头像实际位置左右侧入；Back/关闭/蒙层/菜单路由、滚动及账号退出逐项验证 | 补查确认官方PromptAction options-builder Dialog支持同材质及官方move转场；原Sheet SIDE的600vp限制不代表所有官方弹层都不支持。组合原型待应用、构建及手机验证，不自制模糊或手势 |

## 当前业务完成度与推进顺序（2026-10-28）

当前只完成第一个基础切片，尚不能在原生端完成一次冒险。下述范围来自实际页面及Repository接口，不以通过的测试数量折算整体迁移百分比。

| 业务部分 | 当前实际状态 |
| --- | --- |
| 登录、首次强制改密、退出及门禁 | 已实现并验证；凭据仅内存，尚不支持重启恢复登录 |
| 首页场次列表 | 当前/历史分类、状态展示、空态、错误/重试、刷新已实现并验证 |
| 场次页 | 仅开始前只读详情及状态/返回；开始按钮禁用，无入场或答题 |
| 侧栏/账户菜单与底栏 | 部分实现：账户Sheet仅昵称、等级、经验、主题和退出；没有完整侧栏导航/资料能力。底栏仅“启程”可用，“收藏”“来信”“护照”尚未接通 |
| 个人资料 | 昵称编辑保存、头像选图裁剪上传、资料页及后续改密入口均未实现；首次强制改密不代表完整资料模块已完成 |
| 入场与答题 | 入场、取题、填空/选择、多题导航、判题/冷却/锁定、进度和完成结算均未实现 |
| 线索、剧情与媒体 | 文本/图片/视频线索、信纸/祝福、BGM/配音/视频、完整演出与中断恢复均未实现 |
| 奖品与来信 | 奖品列表/领取信息、通知列表/未读弹窗/已读写入、星海信笺均未实现 |
| 后续原生能力 | 安全持久登录、桌面卡片、Push未实现；不计为已迁移的Web业务 |

按用户最新优先级，后续按手机业务模块拆小片推进：补齐正式导航及账户/资料功能 → 入场与答题完整链路 → 线索、剧情、媒体、奖品与来信逐点迁移 → 直板机完整回归。每一小点先核契约和逐状态要求，再实现、构建/业务检查、真机操作及隔离真实请求验证，不把空页面或仅编译成功记为完成。

折叠、悬停、分栏及窗口变化专项（V05）放到主体功能迁移完成后再用模拟器/对应设备逐个验收；当前保留官方组件和响应式实现边界，不为这些未执行项阻塞手机业务迁移。既有测试和截图继续证明对应小切片，不能代替尚未迁移的业务。

## 任务1实施前检查点（2026-10-28）

用户已授权先执行手机导航、侧栏与账户资料模块。实现前逐点表和实际结果入口见 [任务1验收](slice-02-profile-validation.md)，边界见 [ADR-016](architecture-decisions.md#adr-016手机账户导航资料草稿与头像资源边界)。上方业务完成度表和本段标题保留开始本轮前的基线；本轮结果单独追加，不改写历史首切片证据。

小点依次核对：手机导航与侧栏/护照入口、资料加载和只读账号、昵称草稿/保存/错误重试、系统选图取消及校验、用户可调裁剪与受限输出、multipart上传及受保护头像、后续改密和不确定结果恢复、退出清理及原手机链路回归。奖品/来信业务、入场答题、剧情媒体及安全持久登录不因菜单出现而计完成。折叠/悬停/分栏专项延后，不阻塞当前直板机功能迁移。

### 任务1执行结果追加（2026-10-30）

手机账户菜单、护照资料、昵称草稿/保存、头像选图裁剪及后续改密代码已加入；当前有部分实际手机/隔离HTTPS通过证据，任务1尚未整体验收。共享 `StarwardPassport`已补齐与Web一致的护照标题、等级名/Lv、XP/RANK、进度、下一等级名及菜单紧凑经验信息；`Player.extraDisplay`兼容清洗与原文展示已实现，非空扩展已分别取得正式管理派发/严格HTTPS /me的Host证据和base30de实际截图label/text目视证据，仅覆盖本次一条扩展。ArkTS/Hvigor已实际构建成功，最新业务测试72/72、失败0、忽略0，见 `artifacts/validation/profile/local-test-summary.json`。base30de曾有Touch调试hilog高频调用1 warning/filesChecked=1，保留当时归属；新1a40候选移除后，当前 `profile/lint.json` issues/errors/warnings/suggestions均0、filesChecked=0，不以此声称非零文件扫描或交互通过。

旧演示HAP `b51702dc…` 的runtime4项、未完成mock UI，以及旧隔离HAP `090f75d0…`、`2da7204e…`、`2a52d1e3…`各自runtime/失败尝试保留，不继承到新版本。底栏“护照点击收藏跳回启程”已由日志、坐标和用户手动复现；先click0/will3→0、再click1/will0→1被拦截及迟到0回调的唯一根因仍未确认，不推广为所有API26设备行为。

按[ADR-017](architecture-decisions.md#adr-017官方浮动tabs输入事务与业务路由隔离)采用真实Touch输入事务：观察整个Tabs，只有官方页签will/click产生pending，只提交最终原生索引，取消/外部路由/销毁清待提交，根gate/返回栈再门控，保留官方命中、材质和动画。HAP `0f799c58…` 的 `profile/navigation-input-probe.json`7步触摸导航passed仅属于旧版有限探针；base30de完整core中也已实际验证收藏/来信的底栏及菜单入口不进入空页且保留资料。无Touch的外设键盘/读屏页签激活目前被明确拒绝，属于已知不支持的路径，不只是未验证，也不属于折叠专项。菜单Button有替代导航入口，不等于底栏辅助功能或正式可访问性完成；该缺口单列，不阻塞当前手机Touch业务切片，未来须实现并独立实测。

旧base官方安装的HTTPS HAP为 `30de19566545126979d3cfa2a779f2a258d17ace101bfa9be5e5f7296af58683`，`profile/runtime-08.json`6项passed，`profile/attempts/base30de-base-hap.json`冻结旧HAP/ABC/源码SHA。`profile/profile-save-probe.json`在同版4项passed，核实真实JSON保存、服务端trim、/me回源及无真实编辑时保存提示保持。`profile/ime-back-probe.json`的4项则属于旧HAP `03e562ab…`，证明先Back关闭实际IME、再Back回首页及退出空字段，不混作30de同版计数。

当前 `profile/device-profile-acceptance.json`在2026-10-29T04:22:40Z实际passed/count34，原字节SHA-256为 `9a6b2059c62e5231947d5137c4b6dd1b28ad58768a0c956c7397c93c75dc6e4b`，同30de/runtime-08。本次fresh reset完整新run确实执行首次强改密，无旧检查继承；真实覆盖菜单/底栏、P1昵称IME可达/空白校验/草稿、P2 JSON保存与回源、P3注入延迟/503及显式重试、S1错误旧密和单次普通改密200/字段清空/新密重登入，以及原详情返回关系。该core的faultNeutralised和loggedOut均true；不代表全部测试环境已清理。S2同版最新独立完整initial→new实验已13项passed，报告SHA `a578628c26ec6ced5d7dee3388993463f8210930855ee144d9e8aa835c5c9395`，明确绑定core SHA `9a6b2059…`。实际单次上游POST200后丢响应，未知结果持续可见，原始UiTest核实密码/资料写入禁用且没有重放，退出后Host及手机新认证确认目标密码、恢复资料使用，最终空登录且cleanup两true。此前incomplete3为CLI省略enabled及类型误读，独立反向实验incomplete7为离屏退出按钮驱动未seek，均归档、无checks继承；每次改密均为新的显式实验，不是自动重试。同版supplement已22项passed，报告SHA `5a65db540e7245bd634fffcb908403465e1c347e639b7625b39dbe0108d9ca9d`，明确绑定runtime-08/core34/S2-13。实际覆盖昵称40字符原生上限、未保存草稿离页无写、子页及整个护照离开清三密码、当前/历史、一次官方Refresh恰一新GET200，以及深浅主题动作后的资料数据/控件可达；恢复followSystem，logout/主题恢复/无资料改密写三项cleanup均true。CLI未暴露的菜单/主题辅助功能选中态仍not_observable，不等于正式可访问性或目视对照完成。

非空extraDisplay的 `profile/profile-extra-seed.json`已Host passed，checks数组9项、无count字段：仅唯一自有一次性容器内，经正式管理definition/preview唯一目标/dispatch/inspect，再用玩家严格HTTPS /me核exact tuple且原身份/头像/等级等事实不变，手机实际展示另见 `profile/extra-display-ui-review.json` passed（SHA `956789298399b9792fe29efc93ae80949ede2c0a1008d9d09b6153b9a3e61821`），绑定base30de和实际原图，Root核准精确label/text；不扩写全部扩展边界状态。`profile/response-gate-host.json`的29项为Node v24.14.1下的合成代理工具行为检查，不是业务或手机通过，该29项只记当时的工具准备；后续真实gate激活和独立15秒迟到结果另列，不改变此Host范围。头像base30de真实运行已到20项但incomplete（报告SHA `0f42a91a77475a2f8b2d9dadd8bffacf485b13b7c3ee71a933fa2fdaf29d8e28`）：已验Picker/裁剪取消与pending保留、真实multipart503→200、512方形JPEG≤200KiB/无EXIF/中心裁剪MAE、文件403两token且200恢复不注销、503持久错误。其后自动化请求点击头像重试却回启程且没有新GET，恢复未完成。旧事件日志仅证明index0路由，缺少点击点；旧30de缺点击坐标，唯一根因仍待确认，不能把“内容触摸触发phantom0”写成已定事实。新1a40首次probe由 `profile/avatar-retry-hit-geometry.json`仅测量passed确认：retry rect[67,2580,391,2729]px、计划点[229,2654]px落在真实NativeTabBar rect[106,2531,1214,2721]px内，旧viewport[0,415,1320,2848]px遗漏浮栏避让。测量没有发送retryclick（报告SHA `c0087e63…`、cleanup两true），只证明新probe的驱动遮挡，不倒推旧30de原因或算barModifier失败。驱动已按profile-scroll实际祖先统一避让bar，独立crop/menu保持自有viewport，修正后同1a40的 `profile/native-bar-content-probe.json`已9项passed（最新SHA `9c3a314a548fa2620f8b41b6d95f8f2a44e596da767d88a416e3f694c3160f6d`）：内容retry实际新GET200且保持资料，四次收藏/来信保留护照，启程/护照切换及内容滚动/昵称焦点正常，cleanup两true。旧S2仅提供当前密码key并经Host重新确认身份，不继承其业务checks；不扩写外设键盘/读屏或完整头像验收。该9项原字节d044另存attempts/native-bar-content-probe-09-before-provenance.json，最新仅补源SHA/命令/原mtime完成时间，并未重新执行或增加检查。core34/S2-13/supplement22仅保留各自实际覆盖，不能移到新HAP。

此前旧头像目视阶段已查看7张原图并以私有回执绑定SHA，核实profile/menu四象限头像、调整裁剪及取消保留可见pending；当时Crop Button/Slider默认蓝未接品牌token，是固定Web对照确认的真实差异，不属官方材质批准差异，保留该发现的旧版归属。新候选已修品牌token和高频debug日志，源码修正不替代新图目视。新1a40候选HAP `1a40c0caffc46d64e0b81e9ccb92f2c7d6b69830bb73bf1f2ed5f02651a761cb`已实际build/签名/安装，采用官方barModifier仅bar Touch及父索引对齐；72/72业务测试、lint零问题/filesChecked=0、runtime-09六项passed。候选初次probe遮挡定位为驱动，校正后9项Touch专项通过；新完整core已同版34项passed（SHA `ef049839ce0c0def220e901ebcdb0fb07aba5d7f63ec2a3ac4d03fd7d61ca8d1`）、新S2已13项passed（SHA `5dceb457c4e475f0c20075978d01f9dd29fcfa811ab3613a760b88320ac07407`），均绑定runtime-09并cleanup两true；core为fresh reset实际首次强改密，S2为独立initial→new一次丢响应实验，不继承30de checks。新supplement已同版22项passed（SHA `0376e3986d0e64f08c2d398a91cc05c7ba6f6e61bbce1e850a1f691ea547b880`），明确新runtime/core/S2依赖，logout/主题恢复/无profile或password写三cleanup true；三份09日志均0退出，不借旧22。1a40 Avatar新attempt已基础28项passed（SHA `5f410842bbc7953e9ca3be9ca113c25f52becac726ed751f7499adebe349c18b`）：实际Picker/可调裁剪与取消保留、multipart503→200、512方形JPEG29980bytes/无EXIF及中心裁剪MAE、403一次换token/503显式重试、真实200损坏图解码持久错误与精确恢复后手动GET200、普通退出/Back/重启，以及Root新原图SHA目视。旧30de incomplete20仍按原版归档，不继承为新检查。独立迟到文件logout已在15秒变体通过6项，实际切另一账号并行头像读取仍未验，不把基础或变体通过写成全部A4通过。同版原生逐状态Web配对已完成独立reviewed，保留NAV-ICON/NAV-IME/NAV-LIGHT待新refinement；最终环境清理仍未完成。“退出后迟到200”已完成独立private 15秒变体与真实hold/release，报告及来源工具见下表；不计base2秒通过，也不继承到新UI包。旧Web6图保留原归属；新 `profile/web-profile-visual.json`已passed共8图（identity/security/menu/crop深浅，SHA `b51d6bf904dfb6dc60085b19143e1005f8815242f0fa759ca651460cf225e10b`），Root现已逐张查看Web8/Native12/crop4共24张原图，独立结论另见下段visual-review。browserUsesRealBackend=false，使用只读快照/实际头像字节本地回放，不代替原生功能、真实写入或最终配对通过。

新run前65份旧文件/报告/私有图已按 `profile/attempts/evidence-archive-20261029T051741266386Z.json`保存original→archive和SHA映射，避免同名输出重写使旧来源失真。当前 `profile/base-hap.json`已冻结1a40 signed HAP和34份源码精确副本，旧base30de manifest另存attempts；上述旧报告SHA按档案核验，不迁移为1a40通过。首切片历史未改。

同1a40/runtime-09的真实格式补充已各8项passed：JPEG EXIF6报告SHA `f1f19918535ed60b3098b7e7ccfd51c20b0fc2e2004188db50662abc4095f844`，实际规范化顺时针90°后中心裁剪，512方形JPEG33069bytes/无EXIF，正确MAE4.870021而忽略方向84.884430；WebP RGB报告SHA `d0202724a15894dfede7c55a0881caaa589baa75b68fbbe7b9ca652c916d7942`，512方形JPEG31401bytes/无EXIF，中心裁剪MAE5.083350、错误整图拉伸23.316803。均为实际Picker→原生裁剪/唯一multipart200→新token/文件GET200→Host只读回源，依赖新core/S2/Avatar SHA且logout/空登录两true，不扩写alpha WebP或其他全部方向。

同1a40/runtime-09视觉基线现已完成：`profile/native-profile-visual.json`passed/12图，SHA `4c639ff60ccaae87a1482327161838d0eed9bde8904bb68fd8198c127455d6aa`，全部actualThemeVerified=true、三cleanup true；`profile/native-avatar-crop-visual.json`complete/4图，SHA `05ed5b63f2093ebb0d4d4e2f29e0d98361f32154cc24a579cb6b782d7437ecee`，两主题各5cleanup true、PATCH及改密写入增量0。采集层的crop themeVerified=false/visualReview=pending不改写，由独立 `profile/visual-review.json` reviewed（SHA `44fcc1457a8ae83df5fc9f7dd1c5aaa1a7a6f60df1d0ac5f24adc2866b049ca1`）绑定三份来源并承接Root亲看24原图/8组配对的结论。品牌、文案、权威资料与可达操作已核对；官方材质/手机Sheet/三Slider裁剪布局为批准差异，NAV-ICON、NAV-IME、NAV-LIGHT仍pending_new_refinement，不声称零差异、完整动效或新包通过。5180回环viewer已准备并启动24PNG，私有manifest `artifacts/private/profile-comparison/review-20261030T023133491575Z/manifest.json` SHA `3812ef0edf591f77b3070585bfc817babb03f42f9d9d761e03720ec9e130e179`，旧5179保持首切片归属。

2026-10-30恢复时，Host严格HTTPS可达而手机登录连接中断，实际官方reverse映射为空；Root仅恢复自有18443到既有TLS监听，未改其它映射、账号或配置。`profile/network-resume-20261030.json` SHA `d9bd1926fb8f4f87881205e97690c41da90e0101e7a6966189529256c997bb8c`记录phoneHttpsRecheck=passed_actual_native_login_profile_and_crop并绑定新crop SHA。旧light中断stage与网络失败已归档，新fresh light另取证，不改旧结果。

任务1当前剩余是6a UI包的NAV三项/左右菜单完整逐状态验证、最终测试媒体/旧验收环境清理，以及固定预览首次启动、初始化和手机直接登录。两类输入兜底拒绝与独立15秒迟到专项已有实际结果，原Picker搜索过滤not_observable不改。顶部实施前计划保持历史原状，实际新增结果以下表和任务1验收为准；不把完成这些证据记为全游戏迁移或任务1最终完成。

### 2026-10-30收尾证据与当前待验包

| 版本/范围 | 当前可核事实 |
| --- | --- |
| 1a40输入拒绝 | 同1a40/runtime-09的50MiB+1 PNG与GIF两轮已真实选定精确自有URI并点击官方完成，均落到原生错误Sheet：有效裁剪预览缺席、确认禁用、类型/大小文案精确对应；每轮7项cleanup true，未发资料PATCH或改密POST。`profile/avatar-input-oversize-png.json` SHA `5032ba4124f1f695209a29cce2088453bd23101681eb2f28a6a832499f8153aa`，`profile/avatar-input-unsupported-gif.json` SHA `95923a9e6a55a0be0ba3b58e8c283d828ef20a77cf415171abf3a579587577e4`，各有1个实际边界检查。Root分别亲看错误Sheet，独立review SHA为dd1ffe5f…/a166d70d…。通过的是App兜底拒绝与恢复，原Picker过滤not_observable不改。 |
| 1a40视觉基线 | Root已亲看Web8/Native12/crop4共24原图、8组配对；visual-review为reviewed并绑定1a40/runtime-09，NAV三项新refinement仍pending。不计6a新包视觉通过。 |
| d03独立15秒变体 | 独立15秒变体HAP `d03bd895ed5ef220b48126186b3502925bb9ec94f72c4aa617174b11e93f42a4`已构建签名安装，`profile/runtime-late-15s.json`六项passed（SHA cb226514…）；`profile/device-profile-avatar-late.json`实际passed/count6，SHA `44f27226a1cb1804251b355b212148e410ee2dfe085ed772d312480855655ec9`。先在同变体完成正常原生头像GET200和实际退出校准，再hold精确SHA的真实文件200，观察空登录后release，下游finish且无client abort；响应结束、Back/Ability重启及冷启动仍为空登录，旧资料/头像/菜单缺席。gate中恰1次原生受保护文件GET、0次Host文件读取，5项cleanup全true。finish仅代表TLS下游写出，不是解码回调；不覆盖真实切到另一账号，也不将2秒base或后续UI包记为同版专项通过。 |
| 来源工具 | `profile/hap-timeout-variant-host.json`实际passed/23项，SHA `81c96c7b31787aac356714020376ec27b8a7199388744cf8e8c4834c552a329f`，仅为离线来源验证工具：34份源码、ABC和CA字节一致；除integration timeout由2000改15000外，仅symbolMap的1173条完整唯一记录重排，保留所有键和值，其余打包条目一致。严格校验及反例不忽略symbolMap、不重打包signed HAP，不计业务、签名有效性或UI通过。实际变体安装/runtime来源另见 `profile/late-variant-hap.json`（SHA b762fbe4…）。 |
| 6a最终导航UI包 | 当前final-nav UI HAP为 `6a5232af434e2fed8d6d56b50e25f7bf86b7cf24de22bd6523bdc79f23d5ad90`，绑定final-nav manifest SHA `830e4aa03223c20714f9a9bcc65cb7aa7039301d81484ad15cc2cc90aa4707bd`；已真实编译签名安装及运行时检查，`profile/runtime-ui-final-nav.json`六项passed，SHA `66c45cbe66f9e525d9337e03c4c0925203ffbbca02b31b14e579eebdbd190a9d`。其图标、IME浮栏、官方流光和左右菜单完整验收仍pending。上一6a run incomplete10已独立归档且cleanup六项true，不是完整通过。新driver SHA `27ccd0f88953f12ee6a79faa5dd41ec5a3b652e845c798a61880b0e6a8ef0ce4`的最新run保留incomplete/count0：已完成Host只读身份及beforeCounts，首个官方aa命令返回失败，deviceStarted未置位，未取得UI动作或启动成功证据；Root另查HDC targets为Empty，已请用户重接USB。脚本未发业务写请求，但结束后的写入增量尚未核验，cleanup.noBusinessWrites仍false，不能记已验证零写或完整清理。该次恢复不改产品，USB恢复后先原有cleanup，再显式new-attempt。1a40的24图及193b旧包独立右面板观察均不升级为6a视觉/功能通过。 |
| 固定预览 | `scripts/preview-environment.mjs`已独立静态复核，并实际执行prepare生成独立本机私有配置；当前manifest为initialized=false、initializationStatus=prepared。尚未start服务、完成真实初始化改密、配置预览新包或手机直接登录；固定账号可用性、持久保留及用户改密后的行为未验收，不记PVIEW通过。 |
| 公开文件扫描 | `profile/public-artifact-scan-pre-ui-resume.json`本轮实际passed，973个公开候选文件、0发现、0读取错误，SHA `85f9d649242febf9c5b01a3bacd24b684a29e292ec4eb9c4803b07a5ed977744`；本次未提供known-device，不扩大为已覆盖特定设备标识的扫描，也不代替最终环境清理。 |
| 最终清理 | 媒体、旧验收DB/CA/凭据及映射尚未最终清理；精准媒体helper已有离线有效计划，未执行。预览prepare目录独立保留，不能混用旧环境清理。 |

具体逐状态结果和版本归属持续回填 [任务1验收](slice-02-profile-validation.md)。测试数、准备脚本、部分断言和截图数量均不作为整体迁移完成率。

## 冻结基线与证据边界

| 对象 | 本次实测 | 含义 |
| --- | --- | --- |
| Web 工作树 | `/Users/sitkin/my_code/questions-web`，`main`，干净；HEAD `4b7d1a0a00051ac630e459b0fd6c074f821d7455`，提交时间 `2026-10-27T09:59:24+08:00`，标题 `feat:pwa适配` | 原生首切片冻结的本地正式入口源码候选；本地跟踪的 origin/main 包含该提交，不代表刚刚查询过远端 |
| 后端契约 | `/Users/sitkin/my_code/sitkin-pb-backend-management/backend/contracts/game.ts`；HEAD `c28f488d6b682ae213713ccdd2d992595a941ae3`；该文件 SHA-256 `7264d8e16a65a64c8de8f39088327647bdfb5c1c635cb9393ebf80ae085c43bf` | DTO 权威。Web `src/api/game.contracts.ts` 为生成物，运行校验在 `src/api/game.schema.ts` |
| 本地既有 dist | `dist/version.json` 为 `0.0.0-local`、`channel: local`，commit `671c062210a3564335ad7be8f3f5a28352f573a4`，builtAt `2026-10-27T01:54:57.939Z` | 早于当前 HEAD，不能作当前视觉或正式发布证据 |
| 生产版本探测 | 无凭据 GET `https://sitkin.top/questions/version.json` 返回 HTTP 403 | 本轮未能确认线上 release commit。不得把当前 checkout 声称为线上同版；未读取私人业务数据，未执行生产写操作 |
| 视觉与交互基线 | 冻结源码390×844深浅12图、同Noto字体12图已捕获；迁移前391×777登录配对及认证4图留存 | 历史登录主要控件纵向差小于0.6vp、星中心差约0.41/0.09vp；旧主页等18项捕获仅incomplete/count5，键盘图主题校验失败。以上不是新系统UI通过证据；Web材质与动效不再是逐像素目标。详见 [视觉对照](web-native-visual-comparison.md) |

正式路由权威是 Web `src/app/App.tsx`：`/login`、`/`、`/profile`、`/rewards`、`/notifications`、`/play/:id`、`/play/:id/content/:contentId`。旧 `?qa/?qas`、独立 Letter/Bless、clearCache 和编辑器预览不属于本次玩家正式入口；正式解锁剧情中的 letter/bless 仍须迁移。PWA 安装机制由原生安装机制承接，无需复制浏览器 Service Worker。

后续发布基线确认应保存 production `version.json` 与对应 git commit 的核验结果；若与本表候选不同，明确差异清单后调整。不得静默换基线。

## 原生体验验收准则（2026-10-27、2026-10-28更新）

按 [ADR-013](architecture-decisions.md#adr-013官方-arkui-组件与沉浸光感优先)，保留品牌、文案、业务语义和既定信息布局，通用容器、材质、反馈及动效优先采用官方ArkUI并封装于 `ui/`。Web继续决定业务、布局和逐状态对照；官方沉浸光感、浮动容器及平台交互是已批准差异，分别记录实际支持、降级和设备表现。

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
