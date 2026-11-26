# 原生迁移基线与功能验收对照表

## 2026-11-25：极光玻璃 v2 实施前对照

Web 对照 checkout 为 `feat/ui-glass-v2` 的 `46188fc585026066bd1e92d52ce162c3bb827cde`，原生起点为 `4c9d2888da0a6727e26289eaff5d0bbc7ba294fa`。本节记录预期状态。上线状态、同数据参照模式及设备证据随实际执行记录。参见[原生设计规范](design-system-aurora-glass-v2.md)。

### 答题交互补齐

按同一 Web 提交中的实际移动端源码验收。对照 `3f3aae6` 的题卡、作答栏、线索胶囊与信笺提示变更，规范与组件/样式同时核查。提示唯一入口使用 Web 对应的灯泡语义，选项浮层紧贴作答栏，读屏及媒体保持可用。提示与选项轮测深浅、短长内容、关闭、只读及真实键盘。

自动下一题时星芒显示「正在跳转下一题」，按既有 1500ms 流程切题。手动模式保留按钮，点蒙层关闭留题，空闲 3000ms 收起。核对有下一题、末题、等级和线索队列、离页以及系统减少动画。查看本场线索使用 Web v2 的 46vp 冰蓝胶囊，核对打开与真实拖拽贴边。移到其他题时提示尚未打开的已授权剧情线索，点击进入对应信笺或祝福后按账号与场次记忆，回原题、重新切换、回访及账号隔离分别核对。保持 Web 为只读参考。

Web 提示及带图选项按 388×771 双主题同数据对照。真机使用历史 DTO 隔离回放，已核查深浅提示与选项、图片原色及返回层级、已答禁用 Radio、组合弹窗和信笺打开前后的指引。深色提示另用最终主题色复验。选项视频、当前版本的组合浮标拖拽和系统减少动画开关未在此轮真机独立复测。 [构建与验收证据](native-build-research.md#2026-11-25-答题整页源码复核)

### 入场前场次简介

对照 Web `3f3aae6` 的 `game-chapters.css` 简介卡变化，核查冻结 `46188fc` 的 `AssignmentBrief.tsx`、`GameHeaderView.tsx` 与路由。简介使用玻璃顶栏，左侧返回，居中显示场次名，右侧对称留位，与启程和答题复用原生头部能力。2026-11-25 用户确认保留原生宽卡，手机上与顶栏左右对齐。场次条件每行左侧为标签，右侧为条件值，长值可折行。保留标题、描述、开始按钮和进度保存提示。核对普通、等级受限、待开放、过期、撤回及返回。只有尚未入场的场次显示简介，已开始和已完成仍按服务端授权快照直接恢复。配乐、来信、轮询与入场幂等沿用既有所有者。

同一隔离过期场次深浅真机确认宽卡与条件两端对齐、开始禁用、过期提示、顶部和卡内返回及系统返回；进行中和已完成场次直接恢复内容。可入场浅色已目视核对，固定样本随后转为进行中。其余状态与入场写链路未在本轮真机复测。 [构建与验收证据](native-build-research.md#2026-11-25-入场前场次简介)

### 启程头部页签切换

从收藏、来信或护照回到启程时，身份、品牌星标和玻璃头部在启程页内一起淡入。头部的高度和安全区在启程页呈现时即预留。核对来回快切、同页签重复点击、头像进入护照，以及减少动画时直接到达最终状态。切换的布局终态按各页原来的安全区核对。

### 原生转场补齐

答题页使用同一个原生 Swiper 完成手势、星点选题及继续到下一题。核对不同题高、长题滚动、快切、输入草稿、已答只读和浮层打开期间的手势。作答业务按原有规则推进，动画负责呈现。主底栏和二级分类沿用原生 Tabs 转场与原有选中状态。场次、设置、剧情采用系统导航转场，场次简介卡在数据到达时单次入场。已有原生 Sheet 接管滑动与关闭，仅在应用自管的弹层补齐转场和减少动画分支。主要场景分别核对减少动画、连续返回和安全区。

最终签名包真机覆盖答题左右滑与星点、提示和只读选项返回、三组分类点选与横滑、设置、全屏视频返回。相邻切题样本中正文连续跟手，目标落定后才滚回需要复位的题首。快速反选和迟到结束信号由 Hypium 覆盖。减少动画开关、大字号与自动下一题本轮未在真机复验。 [构建与验收证据](native-build-research.md#2026-11-25-原生转场补齐)

### 答题横滑落定闪屏

2026-11-26 的真机录屏在「关于初见的故事」第 4 题滑向第 5 题时出现三帧近全屏闪白。复验同一场次与方向，检查横滑落定时题卡、进度星及场次背景持续绘制，并核对反向横滑、纵向滚动进入状态栏下方和返回。状态栏边缘渐隐使用单独的原生渐变，保留答题安全区与手势边界。

同场次浅色真机完成六次双向交替横滑。48 张分时采样均显示正文，纵向滚动、顶栏隐藏与恢复、返回启程均通过。 [构建与验收证据](native-build-research.md#2026-11-26-答题横滑落定闪屏)

### 答题横滑题图与线索过渡

相邻可读题滑入时，随题卡展示该题已获授权的线索和题图预览。线索的顺序、未读状态及显示条件继续使用现有快照规则，只有选中的题开放线索操作与读屏。缓存题图直接显示。冷加载时题图预留主题色媒体区域，就绪后使用 ArkUI 淡入并平滑调整至实际尺寸；加载失败保留重试。减少动画时直接显示最终状态。核对有图与无图、有线索与无线索、正反滑动、快速切回、触摸与读屏隔离、慢加载、失败重试及返回。

固定隔离预览直板机验证第 4、5 题双向横滑、各题图片和线索数量、题图与图片线索打开及系统返回。受控弱网、读屏、减少动画开关和失败重试待专项复测。 [构建与验收证据](native-build-research.md#2026-11-26-答题横滑题图与线索过渡)

### 看图器双击缩放

图片就绪后双击从 100% 放大至 200%，以点按处为中心，超出图片的点按位置按图片边缘处理。任意放大状态再双击回到 100% 和居中位置。原生双击与捏合、单指拖动并行识别，图集复用现有切图复位。启用系统减少动画时直接应用缩放结果。

隔离预览直板机的题图通过单击、偏心双击、放大后拖动、再次双击还原、按钮复位及关闭返回六项检查。双指捏合、图集切换和系统减少动画未在本轮真机复测。 [构建与验收证据](native-build-research.md#2026-11-26-看图器双击缩放)

### 填空作答栏编辑材质

填空输入进入编辑态后在同一个 50vp 胶囊内模糊背后的题面，并使用深浅主题底色保证输入对比度。退出编辑后恢复空闲外观。核对同题深浅两色、有题文或配图穿过胶囊的可读性、同一草稿在键盘收起及再次唤起后的保留、作答栏避让与只读状态。

固定隔离预览真机同题对照通过。两主题下胶囊背后的题图细节被柔化，胶囊外题图保持清晰，收起键盘恢复空闲材质。浅色验证再次唤起仍保留本地草稿，实测结束清除测试草稿。 [真机和构建证据](native-build-research.md#2026-11-26-填空作答栏编辑材质)

### 作答栏空闲玻璃

用同一 ArkUI 背景玻璃胶囊承接未编辑的填空输入和折叠选择栏。API 26 的系统折射材质只在指定组件和区域生效，答题胶囊使用主题浮层底色和 UIDesignKit 静态边缘光。核对深浅模式下胶囊后方图文可透出轮廓，输入提示和选择项清晰可读，轻触输入与打开选项仍走原生交互。失去窗口激活或应用关闭材质时使用主题抬升面。键盘打开、回落与已确认的编辑态独立核对。

固定预览直板机实测深浅主题的空闲只读填空、折叠选择和可编辑填空。线索被实时柔化，胶囊外文字清晰。只读选项浮层可展开及返回，原生键盘起落后恢复空闲玻璃，编辑态采样与上一版一致。 [真机对照](../artifacts/validation/aurora-glass-v2-20261125/gameplay-idle-glass-20261126/device.json)

### 原生标题、选项与作答栏的光感宿主

启程身份和答题返回胶囊进入官方标题栏宿主。核对启程页签切入淡入、身份点按、品牌标记位置及其它页签无空位，答题页题面从标题与状态栏背后通过、滚动显隐、输入常显和返回分派。选择浮层优先采用与历史侧栏相同的原生沉浸材质能力，保留锚点、内容高度、关闭、只读、选项媒体及返回顺序。独立试验将同一真实输入组件放入浮动 TabBar，按焦点、键盘避让、草稿、手势和辅助功能语义验证是否可用于正式作答栏。

用户补充只在标题的实际胶囊内使用 `THICK`。原生标题宿主保持透明，关闭宿主模糊与胶囊外部的大面积材质阴影，核对标题下沿和两枚启程胶囊之间的背景连续性。设备材质不支持时采用原有主题底色。

最终包浅色真机复核两个顶栏的背景连续性、启程页签切换、身份进护照和返回、答题滚动显隐、IME 常显及返回。选择浮层保持同题锚定，首个整合包四个只读 Radio 禁用及三种关闭方式均通过，最终包复核打开与返回。独立 TabBar 试验两种宿主都能启用折射和输入，HdsTabs 触控无额外页签回调，生产联动及读屏未纳入试验。 [验收记录](native-build-research.md#2026-11-26-原生光感宿主)

### 正式作答栏浮动页签

用户批准在已推送的版本上试用 HdsTabs。核对原生折射、输入和主操作的实际命中、高度和屏幕边缘间距、编辑态模糊、键盘避让及收起时保留草稿。真机核对题面上下滚动、原生横滑和星点切题、只读填空、选项浮层开关及返回顺序。无作答内容时隐藏页签栏。材质不支持时沿用原生基础容器。分开记录触控和读屏、外接键盘的覆盖范围。

隔离预览直板机浅色主题通过触控检查。最终包复核了 IME 起落、上下滚动时作答栏固定及星点切题。同一实现的前一签名包通过草稿、横滑、只读选项与两种关闭路径。深色主题、无材质设备、无作答内容状态、读屏和外接键盘未单独实测。 [真机记录](native-build-research.md#2026-11-26-正式作答栏浮动页签)

### 判题反馈与交互圆角

长题在当前视口显示答错全屏反馈，与答对共用高斯蒙层和居中舞台。暖玫瑰色星环、提示图标和说明直接置于蒙层之上。底部进度条随剩余时间缩短，到零自动关闭。点「知道了」、点外侧和系统返回也只关闭浮层。留在当前题并保留草稿、滚动位置和服务端惩罚状态。冷却和锁定仍在题面持续可见。真实正确与错误回执分别触发一次系统成功与失败振动，验证重试和回执消重。空提交、网络失败、账号或场次失效允许原有提示且不触发判题振动。减少动画时使用分步进度，可立即阅读和关闭浮层。保持星芒及终章、线索、升级礼赞顺序。

审查浅色和深色主要状态的错误重试按钮、确认和取消按钮、媒体和表单控件、弹窗与抽屉。按共享的 10vp、16vp、24vp 与胶囊资源核对圆角、描边、裁切及命中。叙事专属画面和系统组件自身结构沿用已定样式。

最终实现通过一次性隔离 HTTPS 的真机浅色检查。答错覆满答题视口，蒙层模糊题卡和作答栏，倒计时变短后自动关闭。点按钮及点蒙层回到同一选择题。注入单次 503 后，胶囊重试按钮成功恢复题面。两种预设已接入系统触感，实际马达振感和关闭系统触感未人工核对，深色及减少动画未单独实测。 [真机记录](../artifacts/validation/aurora-glass-v2-20261125/answer-judgment-20261126/countdown-device.json)

### 答题振动开关与切题过渡

设置页提供本机持久化的「答题振动」，默认开启，并提供系统声音和振动入口。仅有效正确和错误回执触发各自振动效果。核对系统授权类型、预设回退、开关关闭与重启恢复，区分系统接受请求和人工感知实际振动。

切换已答与待答、选择与填空时，作答栏内容跟随题目收尾做短过渡，原生浮动玻璃底板位置稳定。核对撤销手势、快速反向、星点跳题、焦点、草稿、选择浮层和减少动画，切换期间不会误提交旧题。

隔离直板机观察到系统触感关闭期间返回 `14600101`。临时开启后，正确及错误预设均获得系统成功回执，单次选择提交复测对应一次失败振动。应用开关关闭状态跨冷启动保留，系统设置入口可达，手机系统开关已恢复原值。验证只读填空与待答选择双向切换、短滑取消、浮层点击、选项草稿与固定底板坐标。动效逐帧和减少动画专项未实测。 [验证记录](native-build-research.md#2026-11-26-答题触感与作答栏切题过渡)

### 清空作答草稿

复现服务端有上次错误答案时清空后退出再进入同一场次。检查清空覆盖同一条历史答案，切题和只读同步不恢复旧内容，明确提交新答案后按真实回执更新。未确认请求与已完成题目的权威答案仍可恢复。清空状态仅在同登录会话有效，退出或账号切换清除。

隔离真机确认已提交过的错误文本清空后，离开场次并重新进入保持空白，清空及重进无额外答题请求，随后可提交正确答案。单测覆盖服务端历史变化、只读同步及账号清理。 [真机记录](../artifacts/validation/aurora-glass-v2-20261125/answer-judgment-20261126/isolated-device.json)

### 答题视频全屏方向

点 ArkUI Video 的全屏按钮时，按计入视频旋转元数据后的显示比例选择主窗口方向。横向视频进入横屏，竖向视频进入竖屏，方形或未知尺寸沿用当前方向。普通视频预览及自动线索播放保持当前方向。核对全屏内退出、系统返回、播放结束、媒体失败与离开页面时恢复进全屏前的窗口方向策略。验证画面完整、控件可达、播放位置和 BGM 恢复。

固定隔离预览真机通过普通预览仍竖屏、点原生全屏横屏、第一次返回恢复原方向并保留预览、第二次返回原题。单测覆盖竖版、方形、未知尺寸及在途旋转切换。竖版实播、原生全屏内自然结束、快进和 BGM 未单独复验。 [设备与构建](native-build-research.md#2026-11-26-答题视频全屏方向)

| 切片 | 实施与逐状态核对 | 当前证据 |
| --- | --- | --- |
| 0 规范与资源 | API 26 启动窗资源与系统栏。应用图标、透明标志与冻结 PNG 绑定；深浅令牌、通知从紫色迁出、独立全屏媒体底色。冷启动、跟随系统及手动主题。 | 已实现。编译、验签、lint、300 测试、直板机安装启动、隔离 TLS、真实登录和 10 条场次核对通过。登录深浅配色原图逐张核对。系统瞬时起窗画面未单独捕获。 |
| 1 壳层与星环 | 官方材质能力与回退、四键浮栏键盘避让、启程身份入口、移除旧侧栏、星环加载与登录。键盘收起时完整表单贴底且首屏可见。登录帮助由官方底部 Sheet 承接，关闭后仍保留表单和星环。核对密码保险箱、登录失败与退出清理。 | 已实现。最新包有签名、构建、安装、lint、305 项本地测试及隔离 HTTPS 证据。新增 8 项真机检查通过，两主题验底部 16vp、说明间距 12vp、Sheet 返回、草稿与键盘。系统密码保险箱、无材质设备、减少动画及精确时长待真机复验。 |
| 2 启程 | 待赴／回响、空与错误重试、进行中主卡及主题呼吸光、等级锁、滚动与浮栏安全区、同步末项与官方 Refresh。 | 固定预览签名包、305 项测试、10 张卡、两栏同步末项、深浅原图与官方横滑通过。一次性玩家 4 项实测覆盖锁定、首载 503 重试、回响空态、下拉触发真实 GET。最新包真机深浅原图和取样均显示主题呼吸光；系统减少动画实测待补。 |
| 3 答题 | 进入与返回、上下滚动和输入焦点、进度星切题、唯一提示 Sheet、透明图及失败重试。填空、选择、一键只读查看、选项媒体、IME、浮标避让、跨题草稿、请求幂等与账号代次。 | 已实现。编译、签名、lint、305 项本地测试通过。隔离 HTTPS 直板机分别验证首载星环、取消迟到读取、填空提示、保留草稿及真 IME；长题上下滚动与固定作答栏；短选项选择后收起和原位对齐；深浅主题只读选项及图片查看与返回。隔离 MP4 路由已恢复并完成主机文件与 Range 核对，真机实播另测。 |
| 4 庆祝 | 普通正确回执显示权威 EXP 与下一题／继续；关闭留在本题，已有 autoNext 到期可切题。线索、终章优先。同次普通正确升级先星芒再礼赞，移动后仍保有同场次已获升级，旧账号/离场无迟到演出。深浅星核、双环、射线、有限粒子、计数和礼赞金扫光；减少动画时直接展示静态最终值。 | 已实现。隔离 HTTPS 三账号完成手动正确 50 EXP、星芒期间自动推进、100 EXP 升 Lv.2 后依次显示星芒与礼赞，三轮均核权威台账和安全退出。构建、签名、lint 和 308 项本地测试通过。系统减少动画开关、礼赞浅色原图与线索／终章的新包真机回归仍待专项。 |
| 5 护照、收藏及来信 | 护照三项统计从当前账号场次与收藏快照派生，未取得响应显示占位；资料／密码／外观为原生半模态，独立头像裁剪保留编辑会话。护照设置卡内整行「设置」紧跟「外观」，隐私政策保留在页尾。保留原生通知、设置页真实版本、退出和迟到响应清理。收藏待领／已领使用与启程、来信一致的官方 `Tabs` 横滑，和分段选中双向同步，核对双列、各空态、刷新、主题及详情隐私。来信两类分段，主页／答题共享阅读和媒体层级，关闭保留未读，确认以服务端已读回执为准；剧情页保留阅读风格。 | 已实现。真机验证护照三项统计、资料与密码草稿、真实键盘、设置行与版本；收藏双列、双向横滑、点按同步、详情与领取指引权限；来信双向横滑、深浅阅读返回保留未读、明确确认仅写一次。可发布包的隐私页和 Push 路由、独立头像裁剪专项仍待复验。 |

架构修复验收覆盖权限查询期间到达 Push token 更新（强制同步一次）、同步请求期间的新更新（保留后续同步）、账号和卸载失效、演示 Repository 明确注入。答题等级弹层拆分、信函分页拆分、共享媒体选项与弹层动效在所属片核对现有行为。

用户补充统一蒙层及沉浸边界。固定 SDK 官网说明核对 `backdropBlur` 的系统适配、`SheetOptions.maskColor` 和自定义弹窗的 `BaseDialogOptions.maskColor`。核对来信深浅主题底层仍可辨，蒙层连续铺到状态栏和手势区，保留图标可读性、确认按钮、普通关闭无已读、嵌套返回及底层交互遮断。答题内容滚动到顶部时进入胶囊及状态栏背后，页顶静止与键盘时交互控件仍按原安全区布局。

来信深浅主题实测均可辨底层，蒙层连续覆盖状态栏与手势区。点击外部和系统返回收起阅读，服务端已读数据一致。护照外观 Sheet 透出底层，隔离账号已退出。答题断线恢复的蒙层共用同一实现，断线重试与来信嵌套媒体返回的新包真机覆盖另记。 [蒙层真机报告](../artifacts/validation/aurora-glass-v2-20261125/modal-mask/disposable/device-visual-06.json)

护照资料、密码及外观 Sheet 复用答题提示与来信的窗口玻璃蒙层。深浅两色核对护照页内容的实际模糊、状态栏连续性和面板内文字清晰度；分别实点蒙层、系统返回、重新打开及输入键盘，检查收起后移除模糊且外观切换仍可用。编辑会话退出或账号变更时释放自己的蒙层。

固定隔离预览真机通过三张抽屉的深浅主题复测。背景在状态栏下连续，点击蒙层及系统返回收起后页面恢复清晰，昵称输入先收键盘再关闭抽屉，外观可切换并已恢复原偏好。 [真机对照](../artifacts/validation/aurora-glass-v2-20261125/passport-sheet-backdrop-20261126/device.json)

同一隔离长题实测滚入透明状态栏与悬浮胶囊背后。页首位置、两枚进度星、固定作答栏及回滑、输入聚焦显隐均通过；实际键盘原图确认作答栏在键盘上方。原生边缘渐隐保留系统区域下的题面，回源无入场或答题变更。 [答题真机报告](../artifacts/validation/aurora-glass-v2-20261125/modal-mask/disposable/gameplay-immersive-07.json)

切片 0 可复现命令、包指纹和目视记录见[构建验证](native-build-research.md#2026-11-25-极光玻璃-v2-资源基线)。采用同宽 388px Web 空登录 Mock 参照及原生 387.69vp 空登录，同为初态空字段、深浅两色。结构与星环列入切片 1。

切片 1 核查固定 SDK：ArkUI `uiMaterial.ImmersiveMaterial` 支持 API 26 Stage 原生光感及 `getMaterialInfo`，UIDesignKit `HdsTabs.barFloatingStyle`、`lightColor` 和材质级别为 API 23 起原生能力。无沉浸能力时用 HdsTabs 原生背景色。SDK 的 HDS `pointLight` 自 API 20 支持且不推荐用于滚动组件，长列表用 L1 轻量表面。包指纹、双主题原图及实机范围见[壳层与登录记录](native-build-research.md#2026-11-25-极光玻璃-v2-壳层与登录)。

切片 2 实施前核查：官方 `CapsuleSegmentButtonV2` 与 `SegmentButtonV2Items` 自 API 18 可使用，`enableStateAnimation` 自 API 24。固定 SDK 下继续用官方 Tabs 控制横滑和页面寿命，分段与内容共用一个选中状态。紧凑横向场次卡只呈现服务端状态、等级限制与进度，通过选中意图打开详情，L1 使用轻量主题面，扫光随可见性和 `StarwardMotion`。保留原有 Refresh、顺序、错误与重试、空态和滚动末项同步说明。冻结 Web 同数据 388×771 待赴与回响原图各深浅两张已采集。

切片 2 呼吸光补验：复用深浅主题 `glow_accent` 资源，原生 `radialGradient` 加 `animateTo` 的交替透明度改变亮度。光晕与描边位置固定。切到其它页签、进入后台或启用减少动画时停止持续动效。

切片 3 实施前核查：固定 SDK 提供 `Scroll.onDidScroll` 与 `Scroller.currentOffset`，按冻结 Web 的 16vp 页顶、56vp 隐藏阈值、下行 10vp 和上行 6vp 触发复现，输入聚焦和页顶常显。页面协调 Navigation 返回栈，标题与作答栏使用薄封装原生材质，`SheetOptions.systemMaterial` 在 API 26 可用，提示/选项复用 `bindSheet`、`SheetType.BOTTOM` 和 `SheetSize.FIT_CONTENT`。分离题卡、进度星与作答栏，组件持展示状态和上抛意图；ViewModel 保留服务端权威的提交、准入、草稿、重试与账号边界。媒体的原生 Radio 禁用和预览可用独立建模，查看器回收带固定会话 ID。首载复用星环舞台，回源 Refresh 保留当前快照。浮标按实际 RESIZE 视口与作答栏占位避让。

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
| 线索/媒体/终章/出口/奖励领取 | 普通文字和图片线索见 [C01a](#c01a-普通文字与图片线索2026-11-11实施前)，组合线索的解锁、顺序、入口和回访见 [C01b](#c01b-组合线索2026-11-12)。正文外链见 [C01c](#c01c-线索正文外链2026-11-12)，普通视频手动播放及答后自动播放见 [C01f](#c01f-普通视频线索手动播放2026-11-12)、[C01i](#c01i-答对后自动播放视频线索)。非末题演出见 [C01j](#c01j-答对后的文字与图片线索演出)，普通末题完成演出见 [C01k](#c01k-末题普通线索完成提示与组合线索)。终章及系统浏览器出口见 [Q04b](#q04b-终章演出与旅程出口)。独立链接卡、开场演出、题面及选项视频、BGM 和奖励领取另列。 |

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
| F02 | Push Kit：token 注册/轮换/解绑、消息/点击、去重 | 后端绑定和发信；收到消息回源；推送不成为事实源；统一鉴权路由 | [F02 隔离真机联调](#f02-首个-push-切片2026-11-18)、[F02a 正式范围与部署](#f02a-正式-push-发送范围) |

### F02 首个 Push 切片（2026-11-18）

| 验收点 | 预期 |
| --- | --- |
| 关闭或拒绝通知、未登录或待改密 | 不登记 Push Token，应用内来信和列表同步仍可用；通知入口迁入设置，见 F02b。 |
| 已同意隐私、已登录并授权 | 冷启动获取并登记当前安装的令牌；轮换后更新，不跨测试和正式环境 |
| 退出、账号切换、授权撤回 | 解绑华为匿名账号与后端设备绑定；离线时保留仅可撤回原绑定的凭据，恢复网络重试 |
| 新场次、旅途来信、公告 | 业务写入成功后才入队；去重、重试和无效 token 处理不产生额外业务写入；通用锁屏文案 |
| 通知点击 | 冷启、热启走同一登录和改密门禁；场次和来信回源，禁止任意路由；重复事件只处理一次 |
| 云端与设备 | 专用测试玩家、小范围测试凭据、独立签名包；分别记录 Push Cloud 接收、系统通知显示、点击回源和账号切换 |

本地原生构建、236 项 Hypium 与隔离 PocketBase 125 项已通过。正式应用已开通推送服务，新签名 Debug HAP 在直板机通过拒绝授权不登记、允许后登记、华为 V3 三类业务测试消息、前后台与公告冷启点击、退出解绑。三个通知回源均未产生入场、答题或已读写入。Token 轮换、断网补解绑和旧路由拦截有本地用例，尚未做对应真机专项。0.1.1（3）发布签名、「仅测试」上传及平台软件包合法性已核验，独立新版隐私声明已核对并关联邀请草稿。生产后端部署见 F02a；正式消息分类、邀请分发及生产真机推送待验。[联调手册与证据](push-integration-2026-11-18.md)

### F02b 设置入口和首次通知授权（实施前）

| 状态 | 验收目标 |
| --- | --- |
| 头像侧栏与护照 | 在「旅途光线」一行提供设置入口，仍可直接切主题。护照不再内嵌通知卡；退出登录动作仍可触达。 |
| 设置页 | 显示使用与侧栏相同的主题状态。支持 Push 的包显示「旅途通知」，区分系统许可状态和同步失败；点按进入系统设置，失败有明确重试，返回保留原来所在页面。 |
| 首次进入、拒绝与回访 | 已同意隐私、完成登录或改密，并进入普通主页面时，本次安装至多主动尝试一次系统通知授权。已授权不弹，拒绝不阻断使用，切账号和冷启不再自动弹；手动仍可打开系统通知设置。 |
| 隔离和安全边界 | 未同意隐私、登录/改密未完成、后台、Push 未启用的包不自动申请；保留原账号代次及注册、解绑保护。生产发送开关、白名单及当前已上传邀请包不由本轮调整。 |
| 注册服务暂不可用（2026-11-19 已完成直板机真实 HTTPS 验证） | 已区分后端合法 `registered:false` 与网络、SDK、非法回执失败；保留系统通知许可，同一卡增加弱提示和「重新检查」，不新增错误卡。续期缓存仅用于有成功票据的绑定，拒绝或失败后不可假报就绪；复用解绑流程保留旧撤销票据及真实重试。本地 267 项通过，其中注册/回执 16 项覆盖拒绝、恢复、缓存、退出和迟到响应；构建及 lint 通过。随后使用同身份签名的生产 HTTPS Debug 体验包覆盖安装，直板机通过关闭服务时弱提示/重新检查、开启后错误消失。生产正式 MARKETING 公告已获华为 `80000000`，用户确认另一台邀请测试手机收到；本轮邀请包点击回源及 USB 设备通知展示未验。见[修复证据](../artifacts/validation/push-registration-availability-20261119/implementation.json)和[独立运行启用记录](push-production-activation-2026-11-19.md)。 |
| 环境文字 | 本机调试包保留环境标签；Release 和邀请测试分发包的页头、登录页脚和侧栏不展示「隔离测试环境」「邀请测试」等调试标记。隐私政策与实际故障反馈保留。 |

2026-11-18 执行：官方 SDK 26 Debug、隔离签名 Debug 和独立邀请标记 Release（未签名、未提交）均构建成功，[236 项 Hypium](../artifacts/validation/settings-privacy-polish/local-test-summary.json) 全部通过。[Code Linter 报告](../artifacts/validation/settings-privacy-polish/lint.json) 无错误或告警，只有原信纸模糊建议。Release 包模块的 `debug=false`，仅含正式邀请标记，无测试 CA；尚未安装新版 AppGallery 邀请包复看。

API 26 直板机通过隔离真实 HTTPS 登录。侧栏齿轮与主题选择在同一行，退出按钮可触达；设置页白天和夜间原图已审查。护照没有旧通知卡；通过设置打开系统通知半模态、关闭回原页、系统返回保留当前 Tab。设备此前已授权，页面显示「已开启」，隔离绑定从登录后的 1 条在退出后回到 0 条；没有已读或答题提交。Debug 实机仍显示「隔离测试环境」。首次系统通知提示、拒绝后冷启不重复弹窗及全新安装后的正式隐私签署尚未重验。

2026-11-19 后续运行启用：生产发送总开关、正式模式和只读服务账号已配置，用户保存的 `all` / revision 2 不变。定向公告首次尝试获华为成功码，用户确认邀请测试手机收到；当前只证实 MARKETING 收发，SUBSCRIPTION 仍审核中、权益开关保持关闭，通知点击待本轮验收。0.1.3 邀请已从下文记录的“预审中”进入“测试中”，不是分类审核通过。见[逐状态运行结果](push-production-activation-2026-11-19.md)。

#### 设置页通知图标居中修正（2026-11-19，已验）

仅将官方 19vp 铃铛放入 36×36vp 的居中 Stack，保留底色、圆角、字号、文案和整行点击范围。固定 SDK 26 构建、签名核验及覆盖安装通过；目录 lint 无错误或警告，仅有信纸模块既有建议。正式 HTTPS 调试体验包在直板机完成日夜原图审查：背景实测 117×117px，字形 62×62px，中心偏差各 0.5px，为物理像素取整，无裁切；通知设置可打开，系统返回仍在原设置页。已恢复原跟随系统主题，用户手动确认“已登录验视 没问题”。未重跑无关业务链，未上传新的 AppGallery 包。见[小点记录](settings-push-icon-2026-11-19.md)与[证据摘要](../artifacts/validation/settings-push-icon-20261119/summary.json)。

### F02d 登录后的主动授权询问（2026-11-19）

用户本轮先做授权主动询问，公告展示、关闭与恢复留待下一轮讨论；不修改 Web 或后端公告契约。

| 状态 | 验收要求 |
| --- | --- |
| 登录与续登 | 通过隐私、登录和密码安全门禁后，在前台普通首页按顺序完成安装级系统通知询问，再询问新账号的旅途订阅及独立通知确认。设置保留独立操作。 |
| 已有选择 | 系统许可已申请则不反复请求；服务端已有订阅或取消决定不再次主动询问。应用自己的展示历史按账号、端点、CA 和订阅范围本机保存，不保存凭据。 |
| 同意和拒绝 | 两阶段均需明确同意；暂不、返回或遮罩关闭不自动开启通知。只在明确提交和回源确认后显示成功。系统拒绝后保留手动设置入口，不循环弹系统许可。 |
| 失败与重试 | 写失败留在当前询问，可使用同 requestId、请求体和预期版本重试；读取失败不强弹错误或误写。持久标记失败则不展示自动询问。 |
| 中断和账号 | 导航、已有弹层、后台、隐私失效、强制改密与退出时收起，迟到响应不恢复旧账号弹层。冷启和重登不重问已展示的决定；设置仍可继续。 |
| 原生 UI | 官方 ArkUI 弹窗二次封装，使用既有日夜令牌；标题、说明、主次动作清晰，短窗口可滚动。不得与隐私、系统许可或现有侧栏叠弹。 |

当前已实现并完成本轮隔离验收：固定 API 26 构建通过，新增 23 个引导用例，完整业务测试 290/290、失败/忽略 0；lint 错误/警告 0、1 条既有信纸建议，工具 `filesChecked=1` 照实记录。独立代码审查无阻塞问题。服务器与原有安装级系统许可逻辑未改，设置独立入口保留。

中间隔离包完成 7 组真机／真实 HTTPS 检查后，导航专项发现切路由期间过早消耗询问记录，已修复。最终同源签名包另完成 3 组复验：延迟初始 GET 不覆盖设置且返回首页仍可询问；两阶段独立选择、拒绝通知无第二笔写入及冷启不重问；提交前 503 同命令重试、提交后丢响应重放只结算一次及日夜可读。最终日间短说明已实际看图，无多余断行。最终 HAP 验签、安装和 131 个运行时 ETS 同源通过；不把中间 7 组相加记为最终包 10 组。详见 [本轮记录](push-onboarding-2026-11-19.md)、[测试](../artifacts/validation/push-onboarding-20261119/local-test-summary.json)、[lint](../artifacts/validation/push-onboarding-20261119/lint.json)与[设备／HTTPS 证据](../artifacts/validation/push-onboarding-20261119/device-ui-https.json)。

本次设备已有系统通知许可，全新系统通知拒绝及正式分发首次询问未重验；迟到换账号、持久化失败与明确 4xx／409 等边界为业务测试，不冒称均已实机执行。实际 Huawei 投递、大字号与跨设备专项不在本轮完成范围。公告仍待讨论，新邀请包未修改、未提交，计划讨论后合包。

### F02c 账号级旅途订阅与消息分类（2026-11-19）

2026-11-19 补充切片已完成隔离验证和后端／运营台发布：后台新增「定向旅途消息（无需关联场次）」；仅用于现有同意范围内的个人剧情来信与旅途动态，仅指定玩家。138 项后端测试通过（0 失败、0 跳过），覆盖无场次收件、账号双阶段授权、权益关闭不降级、取消/已读/撤回/过期和旧上下文恢复副本迁移；管理端 48 项测试、构建与本机浏览器 3 次真实发送通过，切换用途清理旧接收人/场次，收件由真实玩家 API 核对。专属迁移 verifier 已补齐：发布工具 51 项、真实 Docker 迁移 1 项通过，保留 1 条历史 context、拒绝 11 类 SQLite 副本漂移；独立 runner 变异成功捕获。较早的运行时变异实验因初始化 socket 中断未到断言，仍不计通过。生产后端于 16:40:05 进入 recorded/rev15，18 条迁移、41 集合、46 表，context 私有且 0 行；healthy、零重启、三次不同健康成功，HTTPS 200 和四项未认证接口 401。运营台随 `7184170e97babe0e2074e08305b3b41261408695` 发布，Deploy `44490560634` 与 backend CI `44490560636` 成功，线上 JS/CSS 与最终本地构建逐字一致。原生代码、路由和同意范围未变，本切片未重做原生构建、装机或华为实际投递；正式发送保留开启，SUBSCRIPTION 权益仍为 0，定向旅途未批准时停发，不声称已送达。见[后端与迁移证据](../artifacts/validation/push-personal-journey-20261119/backend-summary.json)、[浏览器与清理证据](../artifacts/validation/push-personal-journey-20261119/ui-summary.json)、[发布验证器证据](../artifacts/validation/push-personal-journey-20261119/release-verifier-r2-summary.json)、[生产与静态产物摘要](../artifacts/validation/push-personal-journey-20261119/production-summary.json)及[后台发布记录](../../sitkin-pb-backend-management/docs/harmony-push-personal-journey-deployment-20261119.md)。

用户于 2026-11-19 纠正目标：玩家只需一次订阅并确认接收“分配给我的新场次、剧情来信与关卡动态”，后续新增场次不再逐场操作。新账号级流程已实现，并完成直板真机、隔离真实 HTTPS 与 PocketBase 验证。新场次通知至少每日每设备 20 次仍是业务要求，尚未由平台权益或真实投递证据证明达成；不能以代码分类或隔离测试承诺额度。官方要求订阅范围具体，但没有明确要求逐场订阅，仍需匹配本范围的 SUBSCRIPTION 申请结果。

| 修正后的验收点 | 目标与当前状态 |
| --- | --- |
| 一次订阅 | 已实现固定账号范围 `personal_journey_v1`，默认 false / false；设置先保存订阅，再独立确认通知。真机验证默认、拒绝/返回/后台不误开、显式接收、设置回访和官方冷启保留。原生 257 项测试通过；不是逐场列表合并。 |
| 新场次与来信 | 新分配场次、关联场次的剧情来信/关卡动态均按账号授权判断，不再要求逐场订阅，也无应用自加的每日两条业务限制。隔离真实后端验证一次同意覆盖未来场次和来信；真机采集了订阅后的合成场次及新来信。当前权益门关闭，因此不入队，不代表真实 Push 已送达。 |
| 分类与额度 | 获批并启用后，个人旅途范围使用 SUBSCRIPTION；未批或未启用时不发送、不降级消耗 MARKETING 额度。公告和推广保持 MARKETING。134 项后端测试及 5 项定向复验通过，provider 为合成实现；华为新范围资格、实际频控和至少 20 次/日需求仍待申请与真实投递验收。 |
| 授权与取消 | 新迁移增加两个空私有集合，不转换旧逐场同意；无新范围授权即停发，旧 API 返回 409 提示升级。取消事务丢弃新旧旅途队列，重新订阅不复活；发送前检查当前版本与权益。已由隔离真实后端验证。真机通过取消、PUT 503 原命令重试、提交后丢响应同命令重放且只递增一次、GET 局部失败恢复，以及退出后私密状态清除。 |
| 发布材料 | 六张新账号级流程 JPEG 已采集：默认关闭、独立确认、已接收可取消、场次列表、来信列表、具体内容；全屏原图仅重编码，均 1260×2720、未裁切/覆盖，见素材清单。新账号范围带六图重新提交后为「订阅／审核中」，不是获批。匹配的账号 API 已完成生产 recorded，正式发送仍关闭；0.1.3（5）通过云签、完整验包及平台合法性，11 月 19 日至 12 月 19 日的原单人邀请已提交，平台为「预审中」，不代表已审核通过或实际分发。见 [邀请记录](invite-candidate-0.1.3-2026-11-19.md)。 |

依据：[华为分类与订阅流程要求](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-apply-right/)、[频控 FAQ](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-faq-5)。本轮 9 组真机检查全部通过，使用新独立 CA、专用合成玩家与真实隔离库；入场和答题始终为 0，阅读素材没有提交已读。订阅保存期间及素材新增场次/来信后均无实际云端投递。见 [设备 UI/HTTPS 证据](../artifacts/validation/push-account-subscription-20261119/device-ui-https.json)、[原生测试](../artifacts/validation/push-journey-subscription-20261119/local-test-summary.json)、[后端测试与迁移摘要](../artifacts/validation/push-account-subscription-20261119/backend-summary.json)、[六张素材及原图对应清单](../artifacts/validation/push-account-subscription-20261119/material-manifest.json)。完整实现和当前生产边界见 [本轮记录](push-subscription-2026-11-19.md)。

新范围重新提交后仍沿用原申请记录的创建时间 `2026-11-19 11:43:36`，不把该时间误记为本次重新提交时间；见 [新申请平台事实](../artifacts/validation/push-account-subscription-20261119/huawei-application.json)。真机退出后绑定为 0，专用隔离服务已停止，临时账号凭据、CA/私钥及临时库已删除，持久预览和生产未动；最终 9 笔订阅 PUT 含 7 个 200、2 个故障注入 503（其中 1 个提交后丢响应），入场/答题仍为 0、已读 1，素材额外新信使未读由 2 增至 3。见 [隔离收尾](../artifacts/validation/push-account-subscription-20261119/isolated-cleanup.json)。

以下保留较早逐场实现、旧申请和旧候选的历史验收记录，不作为新账号范围已获批、已部署或已送达的证据：

| 状态 | 验收目标 |
| --- | --- |
| 首次访问与独立同意 | 系统通知许可不等于场次订阅。每个具体场次默认不订阅、不接收订阅通知；点击订阅后，单独确认是否接收该场次剧情来信与关卡动态。拒绝推送不阻断场次使用。 |
| 保存与重试 | 订阅和推送选项以后端回执为准，写入失败保留原状态和原请求重试；冲突重新读取，不覆盖另一端的新选择。 |
| 取消与账号边界 | 设置页可取消具体场次；发送前重新检查订阅和版本，取消前排队的订阅消息不得在重新订阅后补发。退出、换账号后旧响应不恢复订阅内容。 |
| 分类 | 具体场次关联的剧情来信、关卡动态，在用户订阅且允许推送、并获华为自分类权益后使用 SUBSCRIPTION。平台公告、运营推广继续 MARKETING；不把剧情来信当作 MAIL 或 IM。新场次首次下发发生在订阅之前，仍为 MARKETING。 |
| 权益门槛 | 未取得权益不宣称突破每日营销额度；部署配置明确标记实际权益状态。准备真实订阅、独立确认、取消的原图和消息样例供申请。 |
| 隔离验证 | 直板真机验证订阅、拒绝、开启、取消、失败重试、返回和日夜主题；隔离真实后端校验分类、发送前取消、幂等、账号边界及无额外入场/答题写入。 |
| 邀请候选 | 本轮目标 0.1.2（4），沿用正式包名、项目和发布身份。构建、测试、签名、平台检测、提交邀请及实际收发分别记录，未执行不标通过。 |

2026-11-19，最终无诊断日志、与根目录运行源码一致的 Debug HAP 已在直板真机通过 17 项真实 UI/隔离 HTTPS 检查：默认双关闭、先订阅再独立确认、暂不接收/返回键/蒙层关闭无第二笔写入、显式接收、设置回访、官方 force-stop/start 后保留、取消双关闭、PUT 503 同 requestId/请求体重试后回源读取、GET 503 局部反馈与重新读取/离开重进、后台关闭确认及退出账号清理。日夜主题均采原图，App 内主题已恢复初始跟随系统，未改变系统设置。[逐项状态与脱敏 HTTP 证据](../artifacts/validation/push-subscription-20261119/device-ui-https-main.json)记录 5 笔 PUT（包括一次 503 和同请求的成功重试），入场/答题写入始终为 0，已读数保持 1、未读数保持 2，没有打开来信。

真机 503 在提交前注入，不是服务端已提交后的失响应；“失响应后另一设备修改、原请求再回放”、版本冲突及迟到旧账号响应等边界由原生 255 项/后端 133 项真实测试报告覆盖，不混写为已执行的真机场景。后端 provider 为合成实现，分类、取消及排队失效测试通过不代表真实华为 SUBSCRIPTION 已获批或已送达。[原生测试](../artifacts/validation/push-subscription-20261119/local-test-summary.json) · [后端摘要](../artifacts/validation/push-subscription-20261119/backend-summary.json)

隐私排障中，补官方侧载调试元数据后仍曾出现打开失败；私有数值诊断期间实际出现华为系统隐私弹窗，由用户阅读并同意。之后移除诊断、覆盖安装最终同源 HAP，重启见登录表单，后续登录、冷启和回访均可用。原失败码及根因未确定，不宣称已彻底修复正式包隐私。[最终无诊断包证据](../artifacts/validation/push-subscription-20261119/debug-final-no-probe.json)

0.1.2（4）已由主任务云签上传；官方 SDK 验证 APP/Profile 签名、有效期、原发布身份及 Push 能力通过。云签仅在 `module.json` 增加 `app.buildVersion`、在 `pack.info` 增加 `summary.app.version.build`，值为 `1`，其余 HAP 内容与 unsigned 完全一致。[严格签名验包](../artifacts/validation/push-subscription-20261119/release-signed-strict-verification.json)与平台检测分开：主任务已确认 build=`1` 合法性「已达标」，选择既有单人组并提交邀请，平台实际显示「0.1.2测试版本 - 预审中」；窗口为 11 月 19–30 日。这不是预审通过、实际分发或装机收发通过，见 [平台事实与私有原图摘要](../artifacts/validation/push-subscription-20261119/huawei-invitation-platform.json)。

隔离附加代理保留原库、控制记录与 CA，放行现有登记/注销/撤销接口后，真实隔离 PocketBase 登记返回 200、`registered=true`，设置页同步错误消失。申请用未订阅、独立确认、已接收可取消三态已用同一最终 HAP 重拍并自审，官方全屏 PNG 仅重新编码 JPEG，三张均 1260×2720 且小于 1 MB；无裁切、合成 UI 或生产连接。该独立素材阶段新增三笔成功隔离 PUT，主验证五笔 PUT 基线保留，玩法及已读计数不变。见 [素材与接口证据](../artifacts/validation/push-subscription-20261119/application-screenshots.json)。

主任务已实际独立查看三张干净 JPEG，品牌、可读性、独立确认及取消入口均通过。三张已上传用于华为「订阅」分类申请，2026-11-19 11:43:36 提交成功，官方申请记录为「审核中」，尚未获批，未遇到新的法务确认。见 [申请事实](../artifacts/validation/push-subscription-20261119/huawei-subscription-application.json)及[平台事实与原图摘要](../artifacts/validation/push-subscription-20261119/huawei-invitation-platform.json)。

生产本轮发布已完成 `recorded`、revision 15，迁移恰好一次，三个新增私有集合为空，历史结构和迁移保留；备份恢复、新镜像健康及匿名拒绝通过，见 [生产发布事实](../artifacts/validation/push-subscription-20261119/production-deployment.json)。发送器仍关闭、Push 环境变量为空、分类权益未启用，本轮未配置正式凭据或实际投递。管理前端已由 CI 部署，主任务真实浏览器刷新确认新用途选择、场次范围约束及关闭状态提示，未提交生产配置或发送表单；首次后端 CI 的 Linux 清理权限错误已修复，重跑为 132 通过、0 失败、1 个合成 RSA / OpenSSL 条件用例跳过（该项本机已通过），实际华为投递仍未执行。正式候选隐私、邀请审核通过和真实投递仍待各自证据，折叠屏及大字号未在本轮验收。详见 [本轮实施记录](push-subscription-2026-11-19.md)。

独立代码复核发现一处非阻断的后台省流边界：保存期间进入后台，PUT 随后成功仍会发起两次回源 GET；账号代次、后台不弹确认和不自动开启通知仍保持。当前提审包保留此行为，后续可延至前台读取。


管理端发布、首次 Linux CI 清理失败及修复后的最终双工作流结果，见 [部署与 CI 收尾证据](../artifacts/validation/push-subscription-20261119/admin-deployment.json)。这些检查没有开启正式 Push 或验证真实华为投递。

### F02e 推送展示业务标题（2026-11-20）

用户已确认复用现有通知／场次标题，允许它显示在系统通知和锁屏，并经现有华为 Push 通道传输。正文继续保留订阅提示；本轮不显示通知正文、题面、答案或奖励。原生点击路由和账号安全门禁沿用现状，不新增客户端或后台表单。

| 状态或边界 | 验收目标 | 当前证据 |
| --- | --- | --- |
| 定向／场次来信、普通公告 | 通知标题来自当前有效收件对应的通知标题；订阅与营销分类保持原有用途 | 通过：真实隔离 PB 载荷检查 |
| 新场次分配 | 标题来自该玩家实际分配所属场次，点击仍回源检查权限 | 通过：真实隔离 PB 载荷检查；未生产下发新场次 |
| 空、长、中文、emoji及控制字符 | 空标题回退品牌名，纯文本单行及长度处理不会截断代理对 | 通过：5项纯边界及真实 Goja Unicode 验证 |
| 已读／撤回／过期／取消／失效账号或绑定 | 发送前保留全部既有门禁，不因标题提取外发失效内容；不补发旧事件 | 通过：目标21/21、完整154/154，无失败或跳过 |
| 云端请求与旧 App | title 之外的分类、正文、点击数据、TTL 及账号隔离不变，旧 App 无需更新 | 通过：静态路由与实际载荷断言；生产既有包显示标题已由用户确认 |
| 生产发布 | 发布程序明确保留既有 APPROVED=1、正式模式及只读凭据；无数据库迁移，备份恢复与切换分别留证 | 通过：工具58/58，完整备份与恢复、migration-not-required、切换及recorded revision14；APPROVED=1保持 |
| 新单人生产事件 | 分开记录华为接受、手机实际标题和点击回源；仅用已授权操作者账号 | 通过：单人SUBSCRIPTION首次accepted / 80000000，用户确认收到且标题正确；点击回源未重验 |

实施和逐阶段事实见 [本轮标题迁移记录](push-titles-2026-11-20.md)。准备、编译或替身载荷成功不表示生产通知已展示正确标题。

### F02a 正式 Push 发送范围

| 验收点 | 预期 |
| --- | --- |
| 初次部署或未保存设置 | 默认仅白名单且为空，正式消息不允许注册、入队或发送；应用内业务不受影响 |
| 后台权限和保存 | 只允许启用的运营管理员读写；选取现有玩家并填写修改理由，检查无效输入、重复保存和并发版本冲突；重新打开显示已保存的配置，审计差异不含名单或设备凭据 |
| 仅白名单 | 只允许名单内玩家登记并接收符合条件的新事件；名单外账号的场次下发和来信照常 |
| 全部开放 | 扩大范围前确认；只给已授权、绑定有效且有资格接收对应新事件的设备发送，不补发历史场次和来信 |
| 缩小范围 | 由全部开放切回保留的名单；发送前复查范围，范围外尚未开始发送的任务丢弃，重新纳入也不补发已丢弃的任务；已提交的消息不可撤回 |
| 总开关、开发测试 | 总开关关闭时后台仍可保存正式范围，但不会登记或发送；开发测试仍仅限部署侧指定的专用玩家，后台切换不起作用 |

本切片在独立 PocketBase 0.40.1 容器通过后端全量 129 项（含旧库恢复副本、权限、正式与开发消息参数、范围内新消息、不补发及收窄后不恢复旧任务），使用替身发送器，未向华为发送。运营端通过 48 项测试、类型检查、构建和协议检查；Chromium 对真实隔离 API 验证了初始状态、名单保存、开放二次确认、并发编辑、提交成功但响应丢失后的原请求重试，以及深浅色和五档视口，无横向溢出。见 [后台浏览器验收](../artifacts/validation/push-audience-20261118/admin-browser-summary.json) 和 [后端运行命令](/Users/sitkin/my_code/sitkin-pb-backend-management/docs/harmony-push.md)。

2026-11-18 生产后端 `harmony-push-20261118` 已到 `recorded`、revision 15，无活动发布标记或阻塞。仅新增三个空集合，现有业务服务已恢复；切换与 finalize 的生产 HTTPS 健康检查均为 200，未认证管理端 `/me`、场次和管理端 `/push-settings` 均为 401。同一容器零重启，连续三个健康探针通过是发布程序放行条件。

运营后台提交 `3c18d8a` 的 [Deploy to Server](https://github.com/sitkinYip/sitkin-pb-backend-management/actions/runs/44271575294) 已通过后台兼容检查、构建及 SCP 上传，线上认证后的配置读写仍待验。正式华为凭据已核对项目归属并安全预置到生产主机，尚未挂载；生产 Push 保持关闭，未发送真实通知。原生界面未改；F02 的 Debug 真机开发消息不覆盖正式范围切换。0.1.1（3）沿用原发布身份，「仅测试」软件包合法性已达标，已保存关联新版隐私声明的独立邀请草稿，待补审核账号。0.1.0 邀请未改，正式白名单、邀请装机与真机收发待验。[签名与平台记录](../artifacts/validation/push-20261118/signed-invite-01.json) · [生产部署与剩余验收](push-integration-2026-11-18.md#生产部署与剩余验收)

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
| 视频和生命周期 | 已有视频查看器打开前静音 BGM，关闭后只恢复之前想播放的有效曲目。普通后台续播按 T02c；离场、终态失权和切换账号清理或暂停，系统音频焦点中断不覆盖用户选择。旧网络或播放器回调不能复活音乐。 |
| 失败与视觉 | 真实 HTTPS 媒体失败后按钮允许手动重试，答题正常，不发答题或经验写入。直板机对照同数据日夜播放/暂停和无曲目状态，核对安全区、键盘、组合线索入口与播放状态动效。 |

[隔离场次](../artifacts/validation/ui-gameplay-bgm-20261113/host-fixtures-01.json) 的有效曲目顺序为 A → A → B → 静音。三个专用账号由服务端预先结算前三题，真机验收仅登录、读取、切题和播放；[媒体 HTTPS 验收](../artifacts/validation/ui-gameplay-bgm-20261113/host-media-01.json) 独立核对证书、资源字节与故障路径。冻结题库的 [CDN 单字节只读探测](../artifacts/validation/ui-gameplay-bgm-20261113/cdn-source-probe-01.json) 发现 5 首已发布内容使用的曲目带 Web 来源返回 206，1 首仅归档场次使用的曲目返回 404；不算生产播放验收。

- [主轮直板交互](../artifacts/validation/ui-gameplay-bgm-20261113/native-bgm-02.json) 与 [AVPlayer 状态和进度](../artifacts/validation/ui-gameplay-bgm-20261113/audio-state-review-02.json) 证实真实 MP3 解码、循环、同曲切题复用、切换曲目失败 503 后手动重试、静音题释放旧曲；视频打开暂停、关闭后按原意图恢复。主动暂停跨题与重新进入仍有效；退后台释放、回前台重新核验并恢复，登出释放，第二个账号不继承上个账号的暂停偏好。该轮真实进度和经验账本未变化。
- [同数据 Web 重放](../artifacts/validation/ui-gameplay-bgm-20261113/web-reference-04.json) 和 [日夜原图复核](../artifacts/validation/ui-gameplay-bgm-20261113/visual-review-01.json) 覆盖播放、暂停、静音和视频。原生浮标实测 56×56vp，距安全区右边和下边各 12vp；播放波形的连续帧有可见变化。官方全屏视频层打开时隐藏音乐控件。题卡允许向下滚出浮标覆盖区域，组合线索浮标接近右下角时避让。未验带曲可编辑题的实机键盘状态、组合线索与 BGM 浮标同时出现的真机交互，也未触发系统减弱动效和其他应用的音频焦点中断。原生测试以 AVPlayer 日志和实际界面为据，没有做扬声器录音或耳机切换验收。
- [最终包安装和窗口/TLS](../artifacts/validation/ui-gameplay-bgm-20261113/runtime-03.json) 的 5 项检查通过。[最终包补验](../artifacts/validation/ui-gameplay-bgm-20261113/native-bgm-final-02.json) 和 [播放器时序](../artifacts/validation/ui-gameplay-bgm-20261113/audio-state-final-01.json) 复核循环、视频等待静音及关闭恢复，慢请求开始约 4.4 秒点取消后该播放代次立即释放。约 10 秒后隔离网关仍完成 200，旧代次没有初始化或播放；再次点播走新读取并实际播放，不据此宣称转发链路已断开连接。
- [曲目规则 2/2](../artifacts/validation/ui-gameplay-bgm-20261113/GameplayBgm-final/local-test-summary.json) 与 [线索 12/12](../artifacts/validation/ui-gameplay-bgm-20261113/GameplayClues-final/local-test-summary.json) 通过。[codelinter](../artifacts/validation/ui-gameplay-bgm-20261113/lint-final/lint.json) 命令退出 0、`filesChecked=0`，不算源码静态检查覆盖。

已恢复[固定预览登录](../artifacts/validation/ui-gameplay-bgm-20261113/fixed-preview-restored-01.json)，[预览与最终隔离包的 ArkTS 字节码一致](../artifacts/validation/ui-gameplay-bgm-20261113/preview-package-equivalence-01.json)。[临时环境已移除](../artifacts/validation/ui-gameplay-bgm-20261113/disposable-cleanup-01.json)，独立对账确认三个专用账号没有新增入场、答题或经验写入，固定预览进度未变。

### T02c 答题 BGM 后台续播（2026-11-20）

用户本轮明确要求：仍在答题场次、仅将应用挂后台时，正在播放的 BGM 继续播放。此要求替代 T02a 中普通退后台释放答题 BGM 的历史规则；入场说明、信纸配音和视频保持各自既有生命周期。

| 场景 | 验收目标 |
| --- | --- |
| 正在播放时挂后台 | 使用官方 AVSession 与 AUDIO_PLAYBACK 长时任务保留同一 AVPlayer，连续播放和循环；不重新下载、不从头重播。后台仍停止业务轮询和页面动画。 |
| 回前台 | 只读确认账号与场次后继续同一曲目；草稿保留。同曲不重建，后端变更为静音、撤回或失权时停止。 |
| 暂停、加载和视频 | 主动暂停不因切后台恢复。尚未播放的加载不在后台自动启动；视频/信纸覆盖已暂停的 BGM 不因切后台或关闭媒体而自行开始。用户明确按系统播放键可恢复已准备好的曲目。 |
| 系统与退出 | 系统播放/暂停控制与真实状态一致，焦点抢占、耳机拔出继续服从原规则。离场、登出、切号及 Ability 销毁释放播放器、会话和长时任务；迟到的申请/播放回调不能恢复旧账号音频。 |
| 失败和验证 | 后台能力申请失败时前台仍可播放，挂后台安全暂停且可回前台重试。分开记录构建、lint、业务测试、签名安装、隔离 HTTPS、真机后台连续播放及系统控制。 |

已实现并在 API 26 直板机通过隔离真实 HTTPS 验证：初轮后台 35 秒、最终包另验约 20 秒，保持同进程与同播放代次；回前台无重新下载。系统暂停/后台显式继续、视频互斥、慢加载切后台及离场释放均有真实日志。后台请求窗口 41.368 秒内新增业务读取和写入均为 0。完整 Hypium 299/299，含 9 项新增资源竞态；lint 错误及告警为 0，保留一项既有建议。没有声学录音、长时间锁屏、真实来电或耳机专项，不扩大为这些场景通过。官方能力、账号/进程边界与结果见 [后台 BGM 验证记录](bgm-background-verification-2026-11-20.md)。

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

### C01n 独立外链线索卡

以冻结 Web `4b7d1a0` 的手机线索档案为参照。使用真实 HTTPS 隔离后端下发的 `kind=link` 授权，在原生档案内沿用同一张卡的序号、状态、标题、文字预览和交互反馈，右侧使用 Web 的斜向外链箭头。

| 场景 | 验收目标 |
| --- | --- |
| 未授权、末题答对与完成回访 | 未发放时卡片不可见。仅按服务端授权和当前已完成题目的归属显示，保持 Web 顺序及计数。末题结算后和只读回访均可主动打开，入场、答题、只读回源均不自动外跳。 |
| 系统打开与返回 | 复用系统 HTTP(S) 打开能力。从已发放卡片点按进入处理应用，系统返回保留同一题、滚动位置和交互状态，并以只读 GET 重新确认权限。 |
| 失败、取消和重复点按 | 系统打开失败时就地显示主题反馈，再点原卡可重试。系统取消后可再次点按。无效地址和过期授权不能启动外部应用，在途回调不影响已离开的题目、场次或账号。 |
| 同数据对照与写入 | 日夜对照卡片样式、命中和交互反馈。直板真机验证解锁、外跳、返回、失败重试、历史回访；后端台账核对本轮只有预期的末题提交和结算。 |

[隔离 HTTPS 夹具](../artifacts/validation/ui-gameplay-standalone-link-20261113/host-fixtures-01.json) 含一张绑定首题的链接卡和一张完成场次才解锁的全场链接卡，二者使用专用示例地址。固定预览及生产场次不参与写入。[Web 同数据回放](../artifacts/validation/ui-gameplay-standalone-link-20261113/web-reference-03.json) 覆盖日间、夜间和减少动画，拦截到主动点按打开新页，业务及外部流量均未转发。卡片的入场和斜箭头圆环沿用共享档案动效。

[正常签名包直板安装与窗口/TLS](../artifacts/validation/ui-gameplay-standalone-link-20261113/runtime-01.json) 5 项通过，内容视口约 387.69 × 771.08 vp，字号 1。[线索测试 13/13](../artifacts/validation/ui-gameplay-standalone-link-20261113/GameplayClues/local-test-summary.json) 包含链接授权、按题筛选、全场归属与禁止自动外跳；[答题 ViewModel 20/20](../artifacts/validation/ui-gameplay-standalone-link-20261113/GameplayAnswerViewModel/local-test-summary.json) 通过。[codelinter](../artifacts/validation/ui-gameplay-standalone-link-20261113/lint/lint.json) 退出 0、`filesChecked=0`，不计源码静态检查覆盖。

[正常包直板主轮](../artifacts/validation/ui-gameplay-standalone-link-20261113/native-standalone-03.json) 确认首题仅显示其已授权卡片，末题作答前两张链接卡均不可见。原生提交末题一次，正常结算到 2/2 后显示全场链接，回访可再次打开且无完成演出重播。两次实际进入系统浏览器，按返回后由测试工具唤回同一运行中的 Ability，原题与可见控件实例及像素坐标一致，各只新增一次授权场次 GET。两轮早期报告保留未通过，首次浏览器返回未能在限时内重新聚焦 App，第二次 UiTest 一度未暴露应用树，均无新增玩法写入。 [首轮](../artifacts/validation/ui-gameplay-standalone-link-20261113/native-standalone-01.json) · [第二轮](../artifacts/validation/ui-gameplay-standalone-link-20261113/native-standalone-02.json)

[日间同数据原图](../artifacts/validation/ui-gameplay-standalone-link-20261113/visual-review-01.json) 对照首题、未完成末题、末题解锁、浏览器返回与历史回访。原生链接卡为 326.15 × 80.62 vp，Web 约 326 × 81 CSS px，标题距卡左缘均为 72。原生沿用现有档案卡边框，省略 Web 淡色内描边，斜箭头略粗。当前设备已保存的组合线索浮标位置与 Web 默认位置不同，浮标可遮住卡片一角，卡片中心及外链箭头仍可点。

[夜间失败与重试](../artifacts/validation/ui-gameplay-standalone-link-20261113/native-standalone-failure-02.json) 使用独立签名故障包，只在另一隔离账号的同一示例地址首次点按开启系统 `appLinkingOnly`，使系统真实返回无匹配处理方式。正式源码和预览包没有故障注入。原图可见「暂时无法打开链接，请重试。」，点同一张卡即由系统浏览器打开，回 App 后题目和像素坐标保持一致。失败与重试均无玩法或经验写入。[故障包与运行时绑定](../artifacts/validation/ui-gameplay-standalone-link-20261113/failure-variant-01.json) · [夜间原图对照](../artifacts/validation/ui-gameplay-standalone-link-20261113/visual-review-02.json)

办公设备策略阻止了本地 OCR 辅助程序。现用驱动只采集原图，提示文案以人工原图复核为准。原验收报告的 OCR 字段保留当时的记录。

本轮未单独触发系统选择器取消、外跳期间撤销线索和原生系统减少动画设置。普通正文外链使用同一系统交接，原有专项记录见 C01c。

[固定预览已恢复登录](../artifacts/validation/ui-gameplay-standalone-link-20261113/fixed-preview-restored-01.json)，[预览包与正常隔离包的 ArkTS 字节码一致](../artifacts/validation/ui-gameplay-standalone-link-20261113/preview-package-equivalence-01.json)。[隔离环境已清理](../artifacts/validation/ui-gameplay-standalone-link-20261113/disposable-cleanup-01.json)，独立 HTTPS 台账及 SQLite 核实真机仅提交一次预期末题，故障验证与 Web 对照均无新增玩法写入。

### Q03a 答题页前台自动同步与场次撤回

| 场景 | 验收目标 |
| --- | --- |
| 正常前台同步 | 按冻结 Web `4b7d1a0` 每隔约 5 秒只读获取当前场次。当前题、输入草稿、键盘焦点和滚动保留，正常轮询无转圈、不锁定作答；授权和进度变化以服务端为准。GET 不产生答对、升级、切题或线索演出。 |
| 下拉刷新和写命令 | 官方下拉刷新接管同步，取消当前轮询请求或计时，优先处理本次 GET。即使旧响应迟到也不得覆盖新结果。下拉完成后重新计满 5 秒再轮询。提交及结果待确认期间不轮询，不自动重试入场或答题。 |
| 短时故障与恢复 | 有旧快照时保留题面和草稿。顶部以 Web 文案显示可关闭的「同步暂时中断」，超时或主动关闭后，同一次故障不重复打扰。健康 GET 自动清除故障状态，下一次独立故障可再次提示。 |
| 撤回、下线和权限失效 | 后端撤回时显示撤回页，场次下线或不可访问时显示服务端错误及可用的恢复动作。清除旧题面、草稿、授权、私密图集、打开的线索及媒体，停止对终态页面轮询。退出场次、退后台和切换账号后停止轮询，在途结果不落地。 |
| 验证范围 | 同数据 Web 回放与直板机隔离真实 HTTPS 分开记录。专用场次核对授权状态、GET 序列、轮询与下拉冲突、出错及恢复，并确认无新增玩家玩法写入。 |

[同数据 Web 回放](../artifacts/validation/ui-gameplay-polling-20261113/web-reference-06.json) 覆盖日夜、提示关闭、自动消失及独立故障再次提示。下线场景以隔离后端实际归档返回的 `409 SESSION_OFFLINE` 为输入，记录题面、草稿与打开线索退出。系统普通 Toast 无法容纳双行说明及关闭动作，因此原生用 ArkUI 非模态提示承载 Web 文案和动效。主动下拉失败仍保留现有的行内重试入口。

[签名包安装、窗口与 TLS](../artifacts/validation/ui-gameplay-polling-20261113/runtime-01.json) 5 项通过。[刷新状态 8/8](../artifacts/validation/ui-gameplay-polling-20261113/GameplayRefreshViewModel/local-test-summary.json) 验证下拉取代旧轮询、忽略迟到失败并保留最新草稿。[玩法数据 10/10](../artifacts/validation/ui-gameplay-polling-20261113/GameplayData/local-test-summary.json) 验证取消后的迟到 401 不能让当前账号失效。[答题 20/20](../artifacts/validation/ui-gameplay-polling-20261113/GameplayAnswerViewModel/local-test-summary.json) 和 [线索 13/13](../artifacts/validation/ui-gameplay-polling-20261113/GameplayClues/local-test-summary.json) 通过。[codelinter](../artifacts/validation/ui-gameplay-polling-20261113/lint/lint.json) 退出 0、`filesChecked=0`，不计源码静态检查覆盖。

- [直板首轮](../artifacts/validation/ui-gameplay-polling-20261113/native-polling-main-01.json) 观察到 5 项实测结果。静默 GET 与刻意延迟的 GET 均保留题目、焦点、真实键盘、草稿和可见控件实例。重复 503 时可关闭提示，直到实际 200 恢复才重新允许提示下一次故障，下一轮 200 自动移除未关闭的提示。首轮下拉手势起于沉浸顶栏，未触发 Refresh，后用同包独立补验。[日间原图对照](../artifacts/validation/ui-gameplay-polling-20261113/visual-review-outage-01.json)
- [下拉与迟到结果补验](../artifacts/validation/ui-gameplay-polling-20261113/native-polling-race-02.json) 将真实旧 GET 留在网关 12 秒。管理员在隔离场次隐藏题名后，直板下拉在旧响应结束前应用新快照。下一次轮询距下拉请求 5.049 秒，旧响应结束后题名仍隐藏，草稿保留。另一次延迟轮询期间按返回，旧响应结束后仍在首页，未恢复私密题面或继续轮询。两项均无玩法写入。
- [前后台补验](../artifacts/validation/ui-gameplay-polling-20261113/native-polling-background-01.json) 在旧 GET 仍挂起时使用系统 Home。网关结束该请求后继续观察 5.6 秒，后台没有再读场次，唤回同一进程即有一次新授权 GET。网关记录的是旧响应结束，未推定服务端计算被取消。
- [真实场次下线](../artifacts/validation/ui-gameplay-polling-20261113/native-polling-revocation-01.json) 在直板机打开文字线索时通过隔离后端归档其场次。轮询收到真实 `409 SESSION_OFFLINE`，关闭线索弹层并移除题面、输入和旧进度，展示「该场次已下线」、重试和回首页，继续观察一个轮询间隔无新场次 GET。[同数据终态原图](../artifacts/validation/ui-gameplay-polling-20261113/visual-review-terminal-01.json) 对照文字线索与错误布局。原生沿用主题错误组件与安全区内边距。主轮四次短时故障及后续读均无玩法写入。

原生提示超时、上滑关闭、视频正在播放时下线及真机切换账号的迟到响应未单独触发。超时与减少动画有 Web 对照，迟到账号及权限失败有本地用例。终态页面保留显式重试；自动同步止于场次下线。

[固定预览](../artifacts/validation/ui-gameplay-polling-20261113/fixed-preview-restored-01.json) 已恢复登录，正常验收包和预览包的 [ArkTS 字节码一致](../artifacts/validation/ui-gameplay-polling-20261113/preview-package-equivalence-01.json)。[隔离环境已清理](../artifacts/validation/ui-gameplay-polling-20261113/disposable-cleanup-01.json)，SQLite 与严格 HTTPS 台账核对无新增入场、答题或经验结算。

### Q01a 首次多题答题引导

| 场景 | 验收目标 |
| --- | --- |
| 首次展示与排版 | 按冻结 Web `4b7d1a0` 手机布局，仅在进行中的多题场次显示「答案在题目下方」「知道了」「定位答题区」。单题、已完成、不可读题和未入场详情不展示。逐图对照内容、底部安全区和入场动效。 |
| 定位答题区 | 滚到当前题的实际表单，在可用范围内居中并短暂高亮。无焦点抢占、无主动弹键盘、无自动答题；减少动画时即时滚动。切题、离场和旧授权失效时清理待执行定位。 |
| 关闭与按账号记忆 | 点「知道了」、定位或实际编辑填空、选择答案后记为已见。仅聚焦和取消键盘不计已见。不同账号独立，重进场次和重启 App 后仍记住。 |
| 浮标与验收 | 直板机同时操作 BGM 和引导，键盘收起后可继续尚未完成的引导。用隔离真实 HTTPS 对账，无新增入场或答题写入。 |

[冻结 Web 回放](../artifacts/validation/ui-gameplay-answer-guide-20261113/web-answer-guide-02.json) 使用同款长题快照和 388 × 771 CSS px 视口。分别核对日夜、定位与高亮、独立账号、实际编辑及不展示条件。[选择题](../artifacts/validation/ui-gameplay-answer-guide-20261113/web-answer-guide-choice-03.json) 补验实际点选。直板原生保留已确认的题卡自动落位，并按实际系统手势区避让。引导显示时暂时让 BGM 浮标停在面板上方，关闭后回到原停靠位置。Web 在默认停靠位会被面板遮住。

[首轮原生](../artifacts/validation/ui-gameplay-answer-guide-20261113/native-answer-guide-01.json) 观察到定位、BGM 播放暂停、同账号重进与冷启动后记忆、键盘取消、填空编辑、单题与完成态排除、夜间原位关闭等交互。采集中补建隔离账号改变了夹具脚本哈希，报告保留 incomplete。[独立台账复核](../artifacts/validation/ui-gameplay-answer-guide-20261113/native-answer-guide-initial-ledger-01.json) 核对首轮三个专用账号无新增入场、答题或经验变化。[首轮原图](../artifacts/validation/ui-gameplay-answer-guide-20261113/visual-review-initial-01.json) 可见表单完整滚入，未能看到预期高亮。后续使用 ArkUI 外描边及主题底色补验。

[修正版签名安装、窗口及 TLS](../artifacts/validation/ui-gameplay-answer-guide-20261113/runtime-02.json) 5 项通过。[答题 20/20](../artifacts/validation/ui-gameplay-answer-guide-20261113/GameplayAnswerViewModel/local-test-summary.json)、[刷新 8/8](../artifacts/validation/ui-gameplay-answer-guide-20261113/GameplayRefreshViewModel/local-test-summary.json) 和 [BGM 3/3](../artifacts/validation/ui-gameplay-answer-guide-20261113/GameplayBgm/local-test-summary.json) 通过。[codelinter](../artifacts/validation/ui-gameplay-answer-guide-20261113/lint-final/lint.json) 返回 `filesChecked=0`。DevEco ArkTS 检查对答题页、引导和新偏好文件未返回诊断，BGM 偏好工厂保留原有异常提示。

[修正版直板复验](../artifacts/validation/ui-gameplay-answer-guide-20261113/native-answer-guide-final-01.json) 在两个全新隔离玩家上通过。日间定位让当前表单上移约 108 vp，输入和提交完整可见。原图有两张高亮帧和一张退去后的帧，退去后表单位置一致，未出现焦点或键盘。引导显示时实点暂停及恢复 BGM，关闭引导恢复停靠位，定位未额外读取音频。夜间实际点选 Radio 后引导关闭，回访不再出现。严格 HTTPS 记录及 SQLite 对账无新增玩法写入。

[日夜原图对照](../artifacts/validation/ui-gameplay-answer-guide-20261113/visual-review-final-01.json) 包含最终版首次引导、定位、退去和实际点选。定位描边沿 ArkUI 表单外缘绘制，保持表单几何。Web 轮廓额外外扩 12 CSS px。减少动画使用系统设置，原生即时定位，Web 减少动画已重放。当前直板机未取得该设置生效的独立证据，也未录制连续入场动效。

[固定预览账号](../artifacts/validation/ui-gameplay-answer-guide-20261113/fixed-preview-restored-01.json) 已恢复并停留在首页。预览包与修正版验收包的 [ArkTS 字节码一致](../artifacts/validation/ui-gameplay-answer-guide-20261113/preview-package-equivalence-01.json)。[临时验收环境已清理](../artifacts/validation/ui-gameplay-answer-guide-20261113/disposable-cleanup-01.json)，六个隔离账号的八个场次台账保持准备后的原值。

### T03a 答题场次与逐题背景图

| 场景 | 验收目标 |
| --- | --- |
| 配置优先级 | 对照冻结 Web `4b7d1a0`。当前关卡可继承场次、覆盖自定义图或显式关闭。保留旧数据中的关卡 URL 覆盖和空自定义含义。未获授权的关卡不触发读取。 |
| 日夜与布局 | 使用 ArkUI 固定铺底、居中裁切和主题渐变。按同数据、同内容宽度对照日夜题面及系统栏，验证滚动、输入、切题与浮动控件的命中和可读性。 |
| 加载、失败与切换 | 等待图片、缺图或失败期间显示主题底色，不新增装饰层交互。切题、退出、后台或授权失效后，迟到图片不得恢复旧题背景。手动刷新后可重新请求失败的当前图。 |
| 网络与范围 | 直板机使用隔离真实 HTTPS，背景图读取不发送业务鉴权或额外入场、答题写入。默认全屏氛围动效属于下一视觉切片。 |

[冻结 Web 回放](../artifacts/validation/ui-gameplay-background-20261113/web-background-03.json) 覆盖继承、覆盖、显式关闭、真实失败输入和迟到资源。Web 在独立背景层上还有默认动态氛围。原生本轮覆盖已经进入的可读答题页面，未入场详情继续沿用当前主题底色。

[首轮日间原图](../artifacts/validation/ui-gameplay-background-20261113/visual-review-initial-01.json) 观察到两种图片及主题回退。顶部渐变用透明黑作为结束色，日间画面出现灰带。修正版使用同主题的透明色。首轮采集器在写报告时被前一切片的路径校验拒绝，原始画面保留为观察记录。

[最终包签名安装、窗口和 TLS](../artifacts/validation/ui-gameplay-background-20261113/runtime-02.json) 5 项通过。[背景规则 3/3](../artifacts/validation/ui-gameplay-background-20261113/GameplayBackground/local-test-summary.json)、[图片加载 4/4](../artifacts/validation/ui-gameplay-background-20261113/QuestionImageLoaderTests/local-test-summary.json)、[缓存 4/4](../artifacts/validation/ui-gameplay-background-20261113/QuestionImageCacheTests/local-test-summary.json) 和 [刷新 8/8](../artifacts/validation/ui-gameplay-background-20261113/GameplayRefreshViewModel/local-test-summary.json) 通过。DevEco ArkTS 检查对新增及相关源码无诊断。[codelinter](../artifacts/validation/ui-gameplay-background-20261113/lint/lint.json) 返回 `filesChecked=0`。

[修正版直板主轮](../artifacts/validation/ui-gameplay-background-20261113/native-background-final-01.json) 验证日间的背景继承、覆盖和关闭，答题输入实例与草稿在键盘开合时保持一致，返回首页清除背景。切回原题的手势用时约 1.4 秒，旧图随后完成 12.006 秒的 HTTPS 200，当前画面边缘像素与原场次图一致。主轮执行回到页顶的手势后发现一次额外的 503 请求，无法单独归因于自动轮询，原报告保留 incomplete。

[同包直板补验](../artifacts/validation/ui-gameplay-background-20261113/native-background-supplement-01.json) 先等待一次无操作的真实详情 GET 200，失败图片请求数维持 1。单独手动下拉后只多一次图片 GET，仍为 503 时保持主题底色与可读题面。夜间的继承、覆盖和无图状态均实际拍摄。主轮及补验的图片请求没有鉴权凭据，隔离台账无新增玩法写入。

[同数据日夜视觉对照](../artifacts/validation/ui-gameplay-background-20261113/visual-review-final-01.json) 确认顶部灰带已去除，状态栏、题目和答题控件可读。原生保留官方顶栏材质与已有题卡表面，Web 仍有单独的全屏氛围。测试覆盖普通字号直板机。配置了 BGM 的场次与后台后授权变化未在该切片单独触发。

[固定预览账号](../artifacts/validation/ui-gameplay-background-20261113/fixed-preview-restored-01.json) 已恢复登录。预览包与最终验收包的 [ArkTS 字节码一致](../artifacts/validation/ui-gameplay-background-20261113/preview-package-equivalence-01.json)，[临时隔离环境已清理](../artifacts/validation/ui-gameplay-background-20261113/disposable-cleanup-01.json)。

### T03b 答题页默认氛围

| 场景 | 验收目标 |
| --- | --- |
| 日夜和层级 | 对照冻结 Web `4b7d1a0` 的极光、光隙、椭圆光环、旋转轨道、细光束与微粒。装饰固定在视口，位于配置背景图之上、题卡及交互之下。有图和显式无图都显示，系统栏保持可读。 |
| 运动与静态 | 对照持续的呼吸、漂移、旋转与错峰微粒。跟随系统「减少动画」，保留静态光晕、轨道和光束，停用微粒。退出答题页、退后台或失去授权时释放动画，回到前台恢复。 |
| 交互 | 切题和只读刷新不重启动画，背景图变化不替换装饰层。直板机验证滚动、键盘、草稿、切题与返回，装饰层无触点和读屏节点。 |
| 证据 | 同宽同数据日夜原图和可核实的运动帧，分别记录真实系统减少动画与受控分支证据。隔离真实 HTTPS 对账无新增入场、答题或经验写入。 |

[冻结 Web 回放](../artifacts/validation/ui-gameplay-atmosphere-20261113/web-atmosphere-04.json) 覆盖有图与无图、日夜及减少动画。移动端实测有 8 个错峰微粒，减少动画时隐藏微粒，光晕和轨道保留为静态。由有图切到无图再切回，装饰层保持同一实例。

[首轮真机记录](../artifacts/validation/ui-gameplay-atmosphere-20261113/native-atmosphere-01.json) 保留 incomplete。键盘及运动像素检查通过，采集器用循环日志总数计算游标，Home 后漏读新行。独立官方日志确认原机进后台时装饰停止，回到前台重新运行，后续使用连续日志流复验。[首轮日间原图](../artifacts/validation/ui-gameplay-atmosphere-20261113/visual-review-initial-01.json) 还发现旋转轨道在某些角度过于直立。修正版先旋转，再压扁轨道投影。

[修正版签名安装、窗口和 TLS](../artifacts/validation/ui-gameplay-atmosphere-20261113/runtime-02.json) 5 项通过。[刷新 8/8](../artifacts/validation/ui-gameplay-atmosphere-20261113/GameplayRefreshViewModel/local-test-summary.json)、[背景规则 3/3](../artifacts/validation/ui-gameplay-atmosphere-20261113/GameplayBackground/local-test-summary.json) 和 [答题 20/20](../artifacts/validation/ui-gameplay-atmosphere-20261113/GameplayAnswerViewModel/local-test-summary.json) 通过。[codelinter](../artifacts/validation/ui-gameplay-atmosphere-20261113/lint/lint.json) 返回 `filesChecked=0`。DevEco ArkTS 检查对答题页未返回诊断，对氛围组件的同步更新 API 提示异常处理。

[修正版直板交互](../artifacts/validation/ui-gameplay-atmosphere-20261113/native-atmosphere-final-01.json) 6 项通过。日夜各验证有图和无图，三个分时原图均保持控件位置，轨道附近像素随时间变化。切题沿用同一动画实例。滚动、键盘开合、按 Home 及回前台均保留输入草稿，Home 停止动画，回到原页恢复，离开答题页停止动画。隔离真实 HTTPS 和 SQLite 对账确认入场、答题及经验写入均为零。

[最终同数据原图对照](../artifacts/validation/ui-gameplay-atmosphere-20261113/visual-review-final-01.json) 覆盖 8 组页首与题卡顶部。日间青绿、夜间暖金，旋转轨道保持横向投影，状态栏与控件清晰。原生题卡沿用较不透明的表面，Web 题卡透出的光色更多。授权撤销时的氛围卸载完成代码核查，直板机未单独注入该场景。

[直板下拉刷新](../artifacts/validation/ui-gameplay-atmosphere-20261113/native-atmosphere-refresh-01.json) 通过。手势触发授权详情读取，1.75 秒收到 200，早于下一次 5 秒轮询。仍停留在同一题，氛围未重挂，隔离库无新增玩法写入。

[真机静态诊断](../artifacts/validation/ui-gameplay-atmosphere-20261113/native-atmosphere-static-01.json) 与 [夜间静态原图对照](../artifacts/validation/ui-gameplay-atmosphere-20261113/visual-review-static-01.json) 确认，强制氛围进入减少动画分支后，有图和无图都保留静态装饰，微粒为零，切题保持同一实例，离场释放。间隔原图的三个取样区均无达到 2 RGB 通道值的像素变化。正式包继续读取系统设置。本次正常包观测到系统设置为关闭，手机系统打开该选项的生效结果待验。

[固定预览恢复](../artifacts/validation/ui-gameplay-atmosphere-20261113/fixed-preview-restored-01.json) 7 项通过，手机停在原固定预览账号首页，答题进度保留。[预览包字节码核对](../artifacts/validation/ui-gameplay-atmosphere-20261113/preview-package-equivalence-01.json) 确认与正常验收包一致。[隔离环境清理](../artifacts/validation/ui-gameplay-atmosphere-20261113/disposable-cleanup-01.json) 确认专用 TLS、数据库、容器和控制入口已停用。[公开产物扫描](../artifacts/validation/ui-gameplay-atmosphere-20261113/public-artifact-scan-01.json) 无敏感发现。

### C01o 首次入场后的普通线索演出

| 场景 | 验收目标 |
| --- | --- |
| 首次入场 | 成功入场回执返回后，按冻结 Web 顺序展示当前账号已授权并启用自动播放的文字、图片及视频。显式空效果保持静默，只有缺少效果字段的旧响应才与入场前授权比较。入场回执的自动播放标记优先。 |
| 展示和关闭 | 复用已有 ArkUI 阅读、图集与播放器。视频提前关闭仍接续余下线索，最后回到首题并正常显示首次答题引导。手动线索不自动弹出，保留 Web 已完成题卡的档案规则。 |
| 丢失响应与重试 | 隔离后端首次入场已成功、客户端未收到响应。显式重试沿用同一 requestId 和请求体，恢复原演出，账本仅有一次入场及一组授权，零答题和经验写入。 |
| 刷新与回访 | 下拉、前台轮询、回访和重启的 GET 不触发演出。退后台或离场、退出账号、撤回授权时清理自动队列和对应媒体，旧响应不得恢复浮层。 |

业务契约、直板真机和同数据 Web 对照分别记录。此小片覆盖普通开场线索。

[隔离真实后端夹具](../artifacts/validation/ui-gameplay-entry-clues-20261113/host-fixtures-01.json) 建立独立正常入场、丢响应重试与 Web 回放账号，使用同一两题内容及 [PNG／MP4 媒体](../artifacts/validation/ui-gameplay-entry-clues-20261113/host-media-01.json)。[冻结 Web 回放](../artifacts/validation/ui-gameplay-entry-clues-20261113/web-entry-clues-01.json) 核对日夜、文字→图集→视频→尾声文字、提前关闭接续、显式空效果和 GET 回访静默。

[签名安装、窗口及严格 HTTPS](../artifacts/validation/ui-gameplay-entry-clues-20261113/runtime-02.json) 5 项通过。相关测试共 77 项通过，覆盖效果字段缺失和空数组、授权交集、顺序、视频早关、同键重试、迟到入场响应以及已有答题与刷新行为。DevEco ArkTS 对 9 个修改过的生产文件未返回诊断。[codelinter](../artifacts/validation/ui-gameplay-entry-clues-20261113/lint/lint.json) 退出 0，报告 `filesChecked=0`。

[日间直板正常入场](../artifacts/validation/ui-gameplay-entry-clues-20261113/native-normal-02.json) 7 项通过。依序展示文字、两张图和视频，提前关闭视频后继续显示尾声文字，关闭后才出现首答引导。真机控件树确认首题输入与提交可用。下拉触发真实授权 GET，退出回访和冷启动重新登录后仍停在未答首题，均无自动重播及新增媒体请求。隔离库只有一次入场、五条线索授权、零答题和经验写入。

[日间同数据原图对照](../artifacts/validation/ui-gameplay-entry-clues-20261113/visual-review-normal-01.json) 逐张核对 7 组原图，确认两段文字换行、题图与视频尺寸和关闭控件。原生保留 ArkUI 遮罩、播放控件及系统栏，首答引导在队列结束后单独出现，Web 会先将引导挂在浮层下方。[Web 夜间自然结束](../artifacts/validation/ui-gameplay-entry-clues-20261113/web-entry-clues-natural-01.json) 另验证自然播完同样进入尾声文字。

[夜间丢响应真机](../artifacts/validation/ui-gameplay-entry-clues-20261113/native-lost-01.json) 完成 6 项业务及交互检查。专用网关在后端成功返回 200 后丢弃响应，手机显示错误和显式重试。两次 POST 的 requestId、请求体与账号一致，SQLite 仅有一条入场回执、两条初始化进度、五条线索授权，答题与经验写入为零。重试收到成功回执后按同一顺序播放，视频自然结束接尾声文字，回访静默。[夜间同数据原图](../artifacts/validation/ui-gameplay-entry-clues-20261113/visual-review-lost-01.json) 核对 7 组。该真机报告保留 incomplete，旧采集器的只读守卫在复位故障时提前终止收尾。

[丢响应专项收尾](../artifacts/validation/ui-gameplay-entry-clues-20261113/native-lost-cleanup-01.json) 在同一账号完成故障复位、主题还原、退出清空及重新对账。仍为两次请求、一条入场回执，收尾无新增玩法写入。后台迟到入场回执的静默行为由单测覆盖，本轮未在真机播放中主动撤回授权。

[固定预览恢复](../artifacts/validation/ui-gameplay-entry-clues-20261113/fixed-preview-restored-01.json) 7 项通过，手机留在原固定预览账号首页。[交付包字节码](../artifacts/validation/ui-gameplay-entry-clues-20261113/preview-package-equivalence-01.json) 与本轮验收包一致。[隔离环境清理](../artifacts/validation/ui-gameplay-entry-clues-20261113/disposable-cleanup-01.json) 核对三组隔离账号各结算一次，专用后端、数据库和 TLS 已移除。[公开产物扫描](../artifacts/validation/ui-gameplay-entry-clues-20261113/public-artifact-scan-01.json) 无敏感发现。

### C01p 题面视频

| 场景 | 验收目标 |
| --- | --- |
| 可读题目 | 有封面用原图及播放标志，无封面显示「影像记录」。同一内容块配置视频时以视频入口替代图集，正文与提示保留。已完成但可读的题面仍可播放，未解锁题不加载素材。 |
| 播放与中断 | 点击后复用原生播放器，播放期间暂停 BGM，关闭后按原偏好恢复。关闭、系统返回或播放结束回原题，保留滚动位置和草稿。播放失效、离开、后台或账号变化时释放媒体。 |
| 失败与重试 | 直板机通过隔离真实 HTTPS 验证加载、播放、受控失败及重试。重试只读媒体，不写入入场、答题或经验。日夜使用同数据对照封面、无封面及播放。 |

用户确认无封面入口的「影像记录／播放影像」放在播放标志下方，保留原入口的尺寸、位置和点击范围。

[隔离真实后端夹具](../artifacts/validation/ui-gameplay-question-video-20261113/host-fixtures-01.json) 和 [严格 HTTPS 媒体](../artifacts/validation/ui-gameplay-question-video-20261113/host-media-01.json) 绑定同一两题场次、独立账号、四条视频及两张封面。正常、已完成、锁定三个状态均以隔离真实 DTO 为准。[冻结 Web 回放](../artifacts/validation/ui-gameplay-question-video-20261113/web-question-video-03.json) 实测两种主题播放、BGM 暂停恢复和题卡滚动位置保留。浏览器只重放隔离 DTO 和相同媒体字节，未向后端转发请求。[题面初包签名、安装、窗口与 TLS](../artifacts/validation/ui-gameplay-question-video-20261113/runtime-body-01.json) 5 项通过。

[题面初包直板](../artifacts/validation/ui-gameplay-question-video-20261113/native-body-normal-02.json) 4 项通过。题图、正文及提示保留，点播放前视频请求为零。两条视频均采到第 5 秒实播画面。无封面视频收到 503，点击重新加载后收到 200。返回时播放入口位置与选中项 C 保持，BGM 在同一 AVPlayer 实例暂停和恢复。44 次授权详情 GET，隔离库零新增业务写入。[首轮采集](../artifacts/validation/ui-gameplay-question-video-20261113/native-body-normal-01.json) 在触碰界面前因采集器调用授权辅助函数的命名空间错误停止，原报告留存。

[题面首包原图对照](../artifacts/validation/ui-gameplay-question-video-20261113/visual-review-body-initial-01.json) 核对日间封面、无封面、播放及错误。主题图标首包误渲染为蓝色表情，选项接入包改用 API 26 系统单色 `play_fill`。题面封面高度沿同数据比例，出于点按可达性原生题内提示沿用 44 vp 命中区。

### C01q 选项视频

| 场景 | 验收目标 |
| --- | --- |
| 有封面与无封面 | 点击选项下方播放区使用同一播放器，保留原有选项样式与独立命中区。无封面沿用「播放影像」。播放、退出及重试均不改变选中项和草稿。 |
| 禁用边界 | 提交中、冷却、锁定或题目已完成时随选项禁用播放入口，保留海报原色。题面视频按自身可读权限处理。 |
| 直板机与隔离后端 | 核对实际画面、独立命中、BGM、回原题位置、已完成题和锁定题的禁用以及零新增玩法写入。 |

[题面与选项定版签名安装、窗口及 TLS](../artifacts/validation/ui-gameplay-question-video-20261113/runtime-final-01.json) 5 项通过。玩法解码、答题、刷新、BGM、图片加载及缓存 49 项相关测试通过。[codelinter](../artifacts/validation/ui-gameplay-question-video-20261113/lint/lint.json) 退出 0，报告 `filesChecked=0`。DevEco ArkTS 对视频入口、播放器和答题页未返回诊断，对选项已有同步动画更新提示异常处理。

[正常场次直板定版](../artifacts/validation/ui-gameplay-question-video-20261113/native-final-normal-01.json) 3 项通过。封面和无封面两个选项均实播，后者 503 后点击重新加载成功。三次读取严格 HTTPS、无玩家凭据。关窗后每个入口保持原始坐标，BGM 同一会话暂停后恢复。点播放键、重试和系统返回始终保留选项 C，SQLite 零新增玩法写入。[定版日间同数据原图](../artifacts/validation/ui-gameplay-question-video-20261113/visual-review-final-normal-01.json) 复核两种题面、两种选项入口、实播及返回状态，并独立核对错误与重试控件。

[已完成题直板](../artifacts/validation/ui-gameplay-question-video-20261113/native-final-completed-01.json) 3 项通过。回看已答首题可打开题面视频并实际播放，系统返回保持原位置。带封面和无封面的选项按钮均为原生禁用，实点无播放和媒体请求，保留服务端答案选择。

[锁定题直板](../artifacts/validation/ui-gameplay-question-video-20261113/native-final-locked-01.json) 2 项通过。实点两个原生禁用按钮均无播放和视频请求，SQLite 与准备阶段一致。[夜间同数据原图](../artifacts/validation/ui-gameplay-question-video-20261113/visual-review-final-dark-01.json) 核对已完成题面和两组禁用状态，共 6 对。提交中和冷却沿用同一个答题可编辑门槛，相关答题测试已运行，本轮未在真机单独触发这两个状态。

[固定预览恢复](../artifacts/validation/ui-gameplay-question-video-20261113/fixed-preview-restored-01.json) 7 项通过，手机停在原账号首页。[预览包字节码](../artifacts/validation/ui-gameplay-question-video-20261113/preview-package-equivalence-01.json) 与定版隔离包一致。[隔离环境清理](../artifacts/validation/ui-gameplay-question-video-20261113/disposable-cleanup-01.json) 核对四个隔离账号台账无变化，专用 TLS、数据库、容器和控制入口均已关闭。[公开产物扫描](../artifacts/validation/ui-gameplay-question-video-20261113/public-artifact-scan-01.json) 无敏感发现。

### Q04b 终章演出与旅程出口

用户确认本轮迁移终章和外链，站内剧情接续留到下一小片。场次状态、发放线索、出口地址与等级均取自当前服务端授权。主动外跳由 ArkUI 应用交接，原题和滚动位置留在本地，外部地址保留服务端提供的查询参数。

| 场景 | 验收目标 |
| --- | --- |
| 正确结算 | 首次正确完成终章场次时先显示「所有迷雾已经消散」。只能通过「揭示最终线索」继续，返回与点遮罩不跳过。日夜按 Web 对照星纹、金色装饰、文案、尺寸和动效。 |
| 顺序及空效果 | 确认后依次展示本次普通自动线索、组合线索、有效出口。视频提前关闭仍继续。无出口则直接走到符合条件的等级提升，显式空效果不重放旧线索。 |
| 外链 | 显示底部「最终旅程入口已经开启」。点「继续旅程」才交给系统打开，返回保留提示与题卡，「稍后前往」收起并继续等级提升。系统打开失败允许再次点按。 |
| 回访与中断 | 下拉、轮询、退出回访不新建演出。普通后台、离场、失去授权与账号更换清理未展示步骤。隔离真实 HTTPS 与 SQLite 确认末题只结算一次，全部展示和外跳没有附加玩法写入。 |

[隔离真实 HTTPS 夹具](../artifacts/validation/ui-gameplay-finale-20261113/host-fixtures-03.json) 覆盖双题、文本普通线索、组合线索、有无外链及跨级。冻结 Web `4b7d1a0` 在 388×771 内容区重放同数据，覆盖日间、夜间、减少动画、外链打开后保留原页、无目标和历史回访。[Web 回放](../artifacts/validation/ui-gameplay-finale-20261113/web-finale-01.json)

首包确认真实末题结算和终章遮罩约束，原图显示非模态旅程条被顶栏遮住，首包判为不完整。修复沿用原生 Stack/Column，按实际安全区底部放置入口，并保持页面可滚动；终章在官方弹层内添加淡金环纹及减少动画下的静态装饰。[首包真机记录](../artifacts/validation/ui-gameplay-finale-20261113/native-finale-light-01.json)

第二包确认浏览器真实接管和返回同一 App 进程、题卡位置与底部旅程条，期间有三次有效 GET，用户主动回源及后台轮询均可产生读取。驱动原先将这一期间限制为一次读取，导致提前结束；写台账复核无附加玩法写入。第二包系统弹层外框出现色带，定版把外环、光晕及主题遮罩移至根页面的无交互装饰层，官方居中弹窗继续管理焦点、遮罩命中、系统返回和退场。夜间第二包采集因测试夹具追加期间触发隔离账本保护，在提交末题前终止。[浏览器证据](../artifacts/validation/ui-gameplay-finale-20261113/native-finale-browser-02.json) · [夜间中止记录](../artifacts/validation/ui-gameplay-finale-20261113/native-finale-dark-01.json) · [官方弹窗](https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-uicontext-custom-dialog/)

定版执行 `scripts/hm.sh run`，官方 ArkTS 构建、调试签名、安装和启动成功。`python3 scripts/capture-window-evidence.py --font-scale 1 --require-tls --output artifacts/validation/ui-gameplay-finale-20261113/runtime-03.json` 的 5 项窗口和独立 TLS 检查通过。`scripts/hm.sh test` 全量 164 项通过。`scripts/hm.sh lint` 报告 `filesChecked=0`，未作 lint 覆盖凭据。DevEco LSP 逐文件分析 6 个 ArkTS 文件，0 错误、2 条原有动效 API 异常处理提示。[安装和窗口报告](../artifacts/validation/ui-gameplay-finale-20261113/runtime-03.json) · [全量测试](../artifacts/validation/ui-gameplay-finale-20261113/unit-release/local-test-summary.json) · [codelinter](../artifacts/validation/ui-gameplay-finale-20261113/lint-release/lint.json) · [LSP](../artifacts/validation/ui-gameplay-finale-20261113/lsp-release.json)

日间定版在直板机与隔离真实 HTTPS 完成 6 项。正确答复只新增一次答题、一次 50 XP 记账和两条线索发放，进度由 1/2 变为 2/2。确认终章后先读普通线索，再读组合线索。浏览器由「继续旅程」打开，返回后原任务进程、题卡和旅程条坐标一致，期间三次授权详情读取均为 200。「稍后前往」关闭旅程条后才显示等级提升。回访保留已提交答案和组合线索入口，无演出重放。新增入场写入为零，其余玩家的业务账本无变化。[日间直板机](../artifacts/validation/ui-gameplay-finale-20261113/native-finale-final-light-01.json)

夜间定版 5 项通过。系统返回和点遮罩都保留终章，用户确认后依次阅读普通线索和组合线索。空目标跳过底部旅程条并直接展示待发的等级提升。回访保持权威完成态和只读答案。隔离账本同样只新增一次答题和一次 50 XP 记账。[夜间直板机](../artifacts/validation/ui-gameplay-finale-20261113/native-finale-final-dark-01.json)

日夜同内容宽度核对 10 对原图，定版金色星纹、两行标题和正文、可点按钮与底部旅程条完整显示，原生面板相对 Web 内容区中心高约 4.5 vp，外环柔光较轻。浏览器返回配对保留题卡和旅程条。原生静态截图可确认装饰呈现和动作结果，尚未采集连续动画时序或真机减少动画设置的专项结果。终章队列含视频且提前关闭时仍接下一条，由本地 ViewModel 用例覆盖；本轮真机终章场次使用文字普通线索。[同数据原图对照](../artifacts/validation/ui-gameplay-finale-20261113/visual-review-final-01.json)

预览程序沿用独立外链的系统错误提示和显式重试。单独调试包仅对隔离目标第一次调用官方 `appLinkingOnly`；已到达旅程条并核对一次末题结算，但 HDC 在失败采集阶段报错。失败提示、重试和普通后台中断专项待真机确认，定版日夜正常分支已独立通过。临时变体源码已恢复。[故障变体审计](../artifacts/validation/ui-gameplay-finale-20261113/failure-variant-01.json) · [故障中止记录](../artifacts/validation/ui-gameplay-finale-20261113/native-finale-failure-01.json)

固定预览以定版 ArkTS 字节码重新签名安装并恢复登录，原预览场次进度经读回核对保持原样。临时 HTTPS 和 PocketBase 资源已清理。安装日志采集曾在工具记录显示 USB 设备标识，公开证据已按已知标识和敏感字段扫描。[固定预览](../artifacts/validation/ui-gameplay-finale-20261113/fixed-preview-restored-01.json) · [字节码对照](../artifacts/validation/ui-gameplay-finale-20261113/preview-package-equivalence-01.json) · [临时环境清理](../artifacts/validation/ui-gameplay-finale-20261113/disposable-cleanup-01.json) · [公开产物扫描](../artifacts/validation/ui-gameplay-finale-20261113/public-artifact-scan-final-01.json)

### N01a 终章接续与原生信纸

2026-11-16。冻结 Web `4b7d1a0` 的 `/play/:id/content/:contentId`、`GameNarrativePage` 和 `LetterExperience` 为基准。先完成终章站内路由和信纸阅读，信件配音、配乐及祝福场景按独立小片验收。用户确认保留魔法信封的浅金折面，并加深说明和开信提示文字。

| 场景 | 验收目标 |
| --- | --- |
| 入口和权限 | 仅当前终章回执及最新授权快照中一致的站内目标出现「继续旅程」，由主动点按进入原生路由。剧情 GET 绑定玩家和场次，未解锁、其他玩家和失效场次返回错误，旧账号或旧页面的迟到响应不能展示内容。 |
| 加载和恢复 | 加载中不显示旧信件。真实失败后留在当前剧情路径，可重试当前 GET。返回场次不再发送入场、答题、领取或已读命令。 |
| 信封和信纸 | 同数据与同内容宽度对照日夜信封、信纸与控件。验收入场与开合转场、逐字显示、跳过到全文、分页及按信纸样式滑动。系统减少动画后正文及按钮可用。 |
| 返回和资源 | 关信后可重新打开，从信封返回保留原题与滚动位置。系统返回退出剧情，停止演出并清理已取回的信件内容，回到场次时保持已完成状态。 |

隔离夹具复用正式 PocketBase 路由，四个独立玩家共用同一份原始魔法信纸。未结算及跨账号读取均为 404，匿名为 401，结算后的本人读取为 200。代理只给本轮登记的只读路径注入一次 503，原路线再次读取为 200。Web 回放和真机验收取同一信件内容，未使用生产账号。[隔离后端证据](../artifacts/validation/ui-gameplay-narrative-letter-20261116/host-fixtures-01.json)

冻结 Web 在 388×771 内容区重放同一真实 DTO，覆盖日夜、减少动画、拆封、逐字显示、跳过、纵向滑动、收信重开和返回。Web 查询库先自动重试读请求，原生沿用原有网络错误处理，显示明确的重试按钮。拒绝和错误状态的 Web 画面另取证。[同数据 Web 回放](../artifacts/validation/ui-gameplay-narrative-letter-20261116/web-letter-02.json) · [Web 错误画面](../artifacts/validation/ui-gameplay-narrative-letter-20261116/web-letter-errors-01.json)

验收命令使用 `scripts/hm.sh run`、`scripts/hm.sh test`、`scripts/hm.sh lint` 及 `python3 scripts/capture-window-evidence.py --font-scale 1 --require-tls`。首个真机候选签名、安装启动和窗口/TLS 五项通过。本地全量重跑 173 项均通过，前一次 Hypium 原始报告的总计虽写 173 项通过，逐用例少一条结果，因此保留为不完整。codelinter 报告检查 1 个文件。0 个错误、0 个警告、1 条可选模糊实现建议。[真机窗口与 TLS](../artifacts/validation/ui-gameplay-narrative-letter-20261116/runtime-01.json) · [本地测试重跑](../artifacts/validation/ui-gameplay-narrative-letter-20261116/unit-final-retry/local-test-summary.json) · [codelinter](../artifacts/validation/ui-gameplay-narrative-letter-20261116/lint/lint.json)

日间首包证明站内路线只在末题结算后出现，点按后原生页面取得唯一授权剧情 GET。一次自动翻页尚未结束时采集器试图点上一页，首包未完成。第二包确认前后翻页可改变页码，也发现 ArkUI 私有构建器按值捕获页索引，导致两页正文一致。修复后验收逐页比对真实正文及末页落款。[首包运行](../artifacts/validation/ui-gameplay-narrative-letter-20261116/native-letter-day-01.json) · [第二包页码与正文证据](../artifacts/validation/ui-gameplay-narrative-letter-20261116/native-letter-page-stale-02.json)

定版重新执行官方构建、签名、安装启动和 5 项窗口/TLS 检查。`scripts/hm.sh test` 173 项全部通过，官方 lint 报告同一条模糊实现建议，已有 DevEco LSP 对 8 个相关 ArkTS 文件逐文件检查无诊断。[定版窗口与 TLS](../artifacts/validation/ui-gameplay-narrative-letter-20261116/runtime-03.json) · [定版测试](../artifacts/validation/ui-gameplay-narrative-letter-20261116/unit-release/local-test-summary.json) · [定版 lint](../artifacts/validation/ui-gameplay-narrative-letter-20261116/lint-release/lint.json) · [LSP](../artifacts/validation/ui-gameplay-narrative-letter-20261116/lsp-release.json)

夜间直板机用同一条已获授权的剧情请求重现 503。点按重试后可见加载，随后收到真实 HTTP 200 并到达信封。上一页、下一页及纵向滑动的 5 页正文拼接后等于整封信，收信、重开和系统返回均已实测。退出信纸回到同一进程、原题和控件位置，无终章或等级提示重播。真实 SQLite 新增一次末题答题和一次 50 XP 结算，读取、重试和返回未新增其他玩法写入。[夜间直板机与故障恢复](../artifacts/validation/ui-gameplay-narrative-letter-20261116/native-letter-night-01.json)

日间在同一定版上用独立玩家完成 7 项，与夜间逐页核对方式相同。剧情只有一次授权 GET 200，从信封点「返回冒险」后保留原题及滚动位置。真实 SQLite 同样只新增一次末题答题和一次经验结算。设备交互使用 `python3 -B artifacts/private/gameplay-narrative-letter-20261116/device-letter.py --runtime <定版报告> --device-ref <专用设备引用> --output <新报告> --expected-hap <签名包 SHA256> --usage <已登记角色> --theme <日夜>`，同版使用 `release-day/light` 和 `night-fault/dark` 两组，角色账本分别收尾。[日间直板机](../artifacts/validation/ui-gameplay-narrative-letter-20261116/native-letter-release-day-01.json)

本轮真机夹具使用无媒体的魔法信纸，现代、古典、背景图和系统「减少动画」尚无独立真机证据。翻页使用 ArkUI 纸面旋转、位移和淡出，对应 Web 的方向、时长配置和触发条件。连续录屏时序尚未核验。配乐、配音、祝福和星海信笺入口留待各自切片。

定版日夜共核对 14 对同宽原图。魔法信封保留浅金折面和深色说明，暗青折面交界处的提示字对比度仍低于金色区域。纸面同为约 360 vp 宽，原生因 44 vp 按钮略缩短信纸高度。前两页断行与 Web 一致，夜间原生英文小标固定为青色，Web 为金色。读时截图确认了正文递进和页面切换，独立截图与布局树时间点略有间隔。[定版同数据原图对照](../artifacts/validation/ui-gameplay-narrative-letter-20261116/visual-review-final-01.json) · [冻结 Web 最终回放](../artifacts/validation/ui-gameplay-narrative-letter-20261116/web-letter-03.json)

固定预览已恢复登录到首页，原有记录经读回保持一致。预览包的 ArkTS 字节码与隔离定版一致，临时测试后端和设备映射已清理。[固定预览](../artifacts/validation/ui-gameplay-narrative-letter-20261116/fixed-preview-restored-01.json) · [字节码对照](../artifacts/validation/ui-gameplay-narrative-letter-20261116/preview-package-equivalence-01.json) · [临时环境清理](../artifacts/validation/ui-gameplay-narrative-letter-20261116/disposable-cleanup-01.json)

### N01b 三种信纸的版式与媒体

2026-11-16。按冻结 Web `4b7d1a0` 对照古风、现代和魔法信纸。使用已有正式信件内容，在隔离后端以专用测试玩家验证。

| 状态 | 直板机与隔离后端验收项 |
| --- | --- |
| 三种信封与信纸 | 同数据、同宽度对照封面、纸面、正文及控件。古风字符自上而下、列从右向左，按 Web 方向横向翻页。现代和魔法横排、纵向翻页。打字、全文、手势和按钮翻页保留正文顺序。 |
| 场景与纸面背景 | 页面背景覆盖信封和读信状态。读信从首张纸面开始，每五秒循环切换。检查加载、已缓存的切换、纸面回退和背景失败。减少动画时检查内容及切换仍可用。 |
| 信件配乐 | 开信后自动循环，控件可暂停、继续和重试。与答题页配乐互斥。收起、返回与账号切换释放播放器，前后台切换只恢复当前阅读会话的播放意图。 |
| 段落配音 | 按该段延迟进入，打字和配音并行。配音期间降低配乐音量，当前段需等读音结束才自动进入下一段。配音失败后继续打字与后续配音。显示全文时允许当前读音结束，手动翻页不补播。 |
| 阅读会话与后端 | 开合、翻页、音频切换及媒体失败只改变阅读状态。通过隔离真实 HTTPS 读取已授权信件和媒体，区分后端授权、原生行为和同数据视觉证据。 |

三封信来自已授权的正式内容快照。古风有 3 张轮播图和 10 段配音，现代有 4 张和 10 段，魔法有 4 张和 8 段。每封各有配乐，古风与现代另外各有独立的封面背景。原图和原音频用严格 HTTPS 验证，测试口令与媒体地址留在私有目录。[正式素材校验](../artifacts/validation/ui-gameplay-letter-media-20261116/original-media-01.json)

独立 PocketBase 上，未结算或非本人读信为 404，匿名为 401，本人结算后为 200。同一登记读路线的 503 一次故障可重试恢复。Web 回放采用相同的授权剧情 DTO 和同字节图片、音频，视口 388 × 771 CSS px。三版日夜均观察到背景轮换、播放暂停和恢复。古风减少动画时仍能翻页、切图和播放，浏览器不再播放卷页、光标和配乐光圈动效。[隔离后端](../artifacts/validation/ui-gameplay-letter-media-20261116/host-fixtures-01.json) · [古风 Web](../artifacts/validation/ui-gameplay-letter-media-20261116/web-classical-03.json) · [现代 Web](../artifacts/validation/ui-gameplay-letter-media-20261116/web-modern-03.json) · [魔法 Web](../artifacts/validation/ui-gameplay-letter-media-20261116/web-magic-03.json) · [古风 Web 减少动画](../artifacts/validation/ui-gameplay-letter-media-20261116/web-classical-reduced-01.json)

定版直板机实测三封信均从真实隔离末题进入。同宽原图核对封面、正在打字、全文及翻页，三版真机首张和切换后的第二张纸面图与对应原图匹配。古风右起竖排、左滑下一页，6 页正文顺序与完整原信一致。现代及魔法按 Web 纵向翻页，魔法 4 页正文拼接与完整原信一致。现代原生为 5 页，Web 为 6 页。原生页脚给收起和配乐各自留出点击区，场景照模糊和卷边曲面与浏览器有可见差异。[真机古风](../artifacts/validation/ui-gameplay-letter-media-20261116/classical-native-r2-01.json) · [真机现代](../artifacts/validation/ui-gameplay-letter-media-20261116/modern-native-01.json) · [真机魔法](../artifacts/validation/ui-gameplay-letter-media-20261116/magic-native-01.json) · [同数据原图复核](../artifacts/validation/ui-gameplay-letter-media-20261116/visual-review-final-01.json)

三版开信启动原配乐和段落配音，配音期间 AVPlayer 实报配乐音量为 0.18。现代信件验证了第一段自然结束、配乐恢复 0.5、下一段开始，以及退到桌面暂停两路后回来恢复同一段。显示全文与手动翻页没有发起新配音，收起释放播放器并可回到原题。三版各收到一次末题提交成功和一次授权剧情 GET。真机减少动画、背景加载故障、完整轮播时序与长配乐播到曲尾尚未单独采集。[真机音频事件与业务请求](../artifacts/validation/ui-gameplay-letter-media-20261116/modern-native-01.json)

现代独立故障场次的首段配音真实返回 HTTP 404。真机保持信纸可读，后续段落用原音频成功播放。原始三封正式信纸的媒体地址保持不变。[首段配音故障](../artifacts/validation/ui-gameplay-letter-media-20261116/modern-fault-01.json)

隔离 SQLite 确认每位定版测试玩家只新增一次末题答题，未新增入场或额外经验。四位玩家的累计记录分别为一次入场、两次正确答案和两笔 50 XP。读信、切页、配乐操作及故障恢复期间未调用其他玩法写入。[真机后端台账](../artifacts/validation/ui-gameplay-letter-media-20261116/native-settlement-01.json)

临时真机 TLS 映射和隔离后端已停止。固定预览重新安装同版代码并登录首页，已保存的场次进度一致。应用包中的 ArkTS 字节码与定版验收包一致。[固定预览](../artifacts/validation/ui-gameplay-letter-media-20261116/fixed-preview-restored-01.json) · [字节码对照](../artifacts/validation/ui-gameplay-letter-media-20261116/preview-package-equivalence-01.json)

### M02a 星海信笺的信纸回访

沿用冻结 Web `4b7d1a0` 的「来信 → 星海信笺」标题、卡片内容层级和顺序，复用原生信纸阅读器。首片覆盖信纸，祝福播放和旅途来信后续接入。

| 状态 | 验收目标 |
| --- | --- |
| 首次打开、加载和空态 | 底栏和账号菜单可进入星海信笺。列表以真实归属和授权为准。加载、空态、局部读取失败和重试显示与回源一致。 |
| 信件来源和次序 | 已发放的信纸线索、已完成且授权的信纸终章都可打开。按 Web 的解锁或完成时间倒序排列，同一场次同一内容去重。未授权、已取消或已失效的内容不展示。 |
| 阅读和返回 | 点卡片回源授权读取正文，沿用开信、配乐和阅读控件。系统返回和信封返回按钮都回到原列表与滚动位置，回访不启动答题相关演出。 |
| 同步与隔离 | 手动刷新、短暂错误、重试、离开和换账号均不暴露过期或其他玩家的内容。固定预览既有三封信保持原进度，独立账号验收零新增入场、答题和经验。 |

星海信笺使用既有「来信」底栏和账号菜单入口。页面只呈现已接通的「星海信笺」子页。进入列表、回前台和下拉时回源，覆盖为阅读页时取消尚未完成的列表读请求，返回时续取。冻结 Web 每五秒轮询场次详情，原生首片按上述时机更新。已确认授权的行在短暂网络错误时仍能展示。再次打开正文仍由正式接口校验授权。

独立 PocketBase 准备出八张信笺，其中有一张来自尚未完成场次中已发放的线索，同场次同剧情的线索和终章去重。匿名读为 401，未解锁及跨账号读为 404，自己的已授权剧情为 200。冻结 Web 在同数据的 388 × 771 视口对照列表、滚动、空态、局部读取错误和阅读。浏览器实测从阅读页返回会重新显示列表顶部，原生保持用户要求的返回位置。[隔离 HTTPS](../artifacts/validation/ui-gameplay-star-letters-20261116/host-fixtures-01.json) · [冻结 Web 原图](../artifacts/validation/ui-gameplay-star-letters-20261116/web-mailbox-02.json)

定版直板机验证了两处入口、八张卡片的次序和去重、详情局部失败、下拉刷新失败，以及读取正文后手动重试。三种故障均由隔离真实 HTTPS 返回 503，相关路线重试返回 200。已有卡片在暂时失败时仍保留。滚动后开信，从信封或系统返回均回到原卡片位置。换到独立未解锁账号后列表为空。真机请求和 SQLite 前后对账均无新增的入场、答题和经验。[真机定版](../artifacts/validation/ui-gameplay-star-letters-20261116/native-02.json) · [隔离 SQLite](../artifacts/validation/ui-gameplay-star-letters-20261116/device-settlement-01.json)

同数据日间原图中，定版列表左缘约 25.85 vp、宽 336 vp，Web 分别为 26 和 336 CSS px。日期按 Web 的 24 小时格式。原生保留官方悬浮底栏，只显示已接通的页签，图标笔画稍厚。原生夜间同数据截图和系统减少动画连续录屏待专项复核。[定版同数据对照](../artifacts/validation/ui-gameplay-star-letters-20261116/visual-review-final-01.json)

固定预览三封均已由用户完成。隔离验收结束后恢复原固定预览服务，安装相同 ArkTS 字节码。真机从「星海信笺」逐封打开正确的原信封，返回后三次保持列表位置，场次进度与经验前后相同。手机留在星海信笺列表供本人继续阅读。[固定预览回访](../artifacts/validation/ui-gameplay-star-letters-20261116/fixed-preview-archive-01.json) · [验收包与预览包字节码](../artifacts/validation/ui-gameplay-star-letters-20261116/preview-package-equivalence-01.json)

### 星海信笺列表样式复核

按用户要求采用原生独立信笺卡片。验收关注短列表和连续滚动时的卡片间距、同名终章的场次辨识、日夜可读性、整卡点击和阅读返回的位置。新版用固定预览既有信件做只读对照。

同机、同账号的三封信做了改版前后原图复核。新版在日夜两种主题的卡片宽均为 336 vp，高约 72.62 vp，两个间距分别实测 10.15 和 9.85 vp。终章卡以场次名为主标题，普通信件仍以信名为主标题。有独立内容的摘要继续显示。点击中间卡打开对应原信封，返回后卡片位置一致，固定预览进度经真实 HTTPS 读回无变化。手机恢复跟随系统主题并停在星海信笺。182 项 Hypium 测试通过。本轮的真机视觉样本为现有三封信。[直板机复核](../artifacts/validation/ui-gameplay-star-letters-card-20261116/preview-cards-01.json)

### N02 原生祝福演出与星海信笺回访

2026-11-16，实施前验收计划。参照冻结 Web `4b7d1a0` 的 `BlessExperience`、`canvas-engine` 与 `BlessClosingCredits`。同一份现成祝福数据用于 Web 对照与隔离 HTTPS 真机。

同数据 Web 手机原图显示，十行片尾会将当前行推入底部渐隐区。用户确认原生将当前行保留在下半屏的可读区域，保持滚动、渐隐和相邻行的层级。

| 状态 | 验收要求 |
| --- | --- |
| 授权读取与开场 | 已解锁线索或已完成终章经正式剧情读接口打开。开场标题和按钮沿用暗色星空版式。点击开始前无配音或 BGM。 |
| 正常播放 | 保留 Web 等待、逐句聚字、按配置停留、散开和最后一句留场。BGM 独立循环、可暂停，逐句配音按 Web 节奏切换。片尾有配音时由用户点播，按音频结束或故障时按配置时长推进。 |
| 退出与中断 | 前台变化时暂停演出时钟和音频。返回立即清理绘制、时钟和两路音频。失败不阻塞后续文案。系统减少动画时保留顺序、文字和可操作控件。 |
| 星海信笺 | 同场次同剧情去重，已授权祝福可打开与重播，返回保留原列表。锁定及跨账号返回权威拒绝。完成、退出、回访前后核对隔离台账，仅原答题触发一次结算。 |

冻结 Web 以已授权的同一剧情 DTO 和 15 个原始音频文件重放。388 × 771 视口核对开场、四次聚字、三次散开、十句片尾、两路音频停止和回访重播。独立 PocketBase 的正式接口返回未授权 404、匿名 401 和本人完成后 200。Web 浏览器参考使用本地拦截和合成认证驱动，原生使用直板机真实隔离 HTTPS。

直板机以相同内容核对开场、聚字、散开、首末片尾原图。调整后的渐隐只作用于片尾文字，保留最后一句粒子字。最终包从已结算的星海信笺完整播放，14 段配音均有实际播放进度，末段自然结束，BGM 暂停和恢复通过。再次打开时从静音开场重播，中途返回后两路播放器释放，随后七秒没有继续启动播放。首次末题实测与定版回访的答题及经验台账见 [构建与真机验收](slice-03-gameplay-validation.md#原生祝福演出与星海信笺2026-11-16)。本轮真机减少动画和媒体故障注入未单独验收。

### C01r 题内信纸与祝福线索及待开启提醒

2026-11-16，实施前对照冻结 Web `4b7d1a0` 的 `CluePanel`、`NarrativeAttentionBeacon` 与 `GamePlayPage`。先接入题内剧情线索卡，再补此前题目尚未打开的剧情提醒。两者复用正式剧情 GET 和现有信纸、祝福页面。

| 状态 | 本轮核对 |
| --- | --- |
| 线索未发放、已撤回或账号切换 | 仅使用当前账号的服务器快照。无授权时入口隐藏，正式剧情读取仍由后端核验。 |
| 非末题解锁，主动点开 | 已完成题目内呈现该题及全场已发放的信纸、祝福卡。已发放的剧情由玩家点开，仍按现有顺序展示其他自动线索。 |
| 切题后的待开启提醒 | 当前看不到的未打开剧情按 Web 顺序显示一个待开启入口。玩家主动打开后，记忆按后端、账号、场次和线索隔离。返回后仍可在原题打开。 |
| 返回与对账 | 从卡与提醒分别进入并返回，当前题、滚动位置和未提交草稿保留。读取失败可在剧情页重试。除实际解锁答题外，两种打开、返回及回看均无玩法写入。 |

隔离真实后端在首题完成前拒绝两种剧情读取。直板机首题答对后解锁两张卡，手动重试信纸、从下一题的提醒打开祝福、返回保留原题和草稿、原题回看、退出重进不再提醒均有实测。换到独立账号后，同场次的待开启状态仍独立。答题前后的真实 SQLite 结算与 HTTPS 对账见 [验收记录](slice-03-gameplay-validation.md#题内信纸祝福与跨题提醒2026-11-16)。

### Q01b 场次公告与关卡提示

实施前按冻结 Web `4b7d1a0` 的 `GamePlayScene` 和 `ExtraMessages` 核对。场次公告位于页头后，关卡提示位于题号后、题卡前。展示现有接口解析后的 `extraDisplay` 纯文本。

| 状态 | 验收要求 |
| --- | --- |
| 入场前与空内容 | 已获授权的场次公告可读。未入场或未解锁的题不显示关卡提示。无有效条目时不占位。 |
| 进入与切题 | 从入场、题号、前往下一题及已解锁题左右滑动进入时，当前题提示跟着切换。定位有提示的题时，从提示首行开始读。 |
| 样式与长文 | 正文按原有换行显示，连续长文本在边界折行。核对日夜对照及题卡、表单可滚动到达。 |
| 刷新、退出与对账 | 刷新采用最新公告和提示，删去已撤除内容。保留当前题和草稿。退出后清掉旧账号展示。读取和切题沿用原有接口，按隔离台账核对玩法写入。 |

直板真机以隔离真实 HTTPS 验证上述两题流程及日夜样式。正常入场和答题后各仅一条结算回执。切题、重复下拉、移除撤销文案及退出均无新增玩法写入。读屏、折叠屏和大字号属于尚未单独测试的配置。[逐项证据](slice-03-gameplay-validation.md#场次公告与关卡提示2026-11-16)

### M01a 旅途来信收件箱与答题浮标

本节保留首次迁移的历史验收。浮标范围、已读确认和跨页面提醒由 2026-11-19 的 M01b 更新。

列表参照已确认卡片布局的 Web `7f7c789`，答题浮标的功能和阅读队列参照冻结 `4b7d1a0`。用户指定浮标按原生答题页重新设计，沿用答题页的主题、细线和罗盘意象。各状态使用当前账号的正式 `/notifications` 结果，使用隔离真实 HTTPS 与直板机逐项核对。

| 状态 | 验收要求 |
| --- | --- |
| 收件箱 | 默认进入旅途来信，支持切换至原有星海信笺。检查加载、空、错误/重试、多封信、日期和未读数。打开及关闭手动阅读保留未读。明确收下或标为已读后更新，写失败保留状态、可重试。 |
| 正文 | 检查长文、强调、段落、图片、视频和实际链接类型。退出媒体返回原信件，关闭信件返回原列表或题目。 |
| 沉浸弹窗 | 遮罩覆盖顶部状态栏和底部手势区，系统图标与手势条保持显示。正文、滚动区和确认按钮按实际避让区布局。 |
| 答题浮标 | 有信件才显示，默认左下，显示未读数并以 `9+` 封顶。支持拖动、松手贴边、位置记忆和误触抑制。点开查看最新五封，点选归档项尝试标为已读并可回访。 |
| 自动来信 | 答题页可见、前台才定时同步。最早未读先展示，答题演出、媒体与其他模态期间避让。自动信件关闭或确认进入同一已读请求，成功后继续队列，失败允许重试。 |
| 中断与账号 | 刷新、切题和关闭信件保留现有答题状态。后台、离开和账号更换终止读取，忽略迟到结果；不产生入场、答题或结算写入。 |

原生浮标及自动来信覆盖入场前说明页和已进入的答题目的页。来信内的奖品链接待 R01，星海信笺子标签深链还待补齐。

隔离真实 HTTPS 和直板真机已核对列表请求失败与重试、普通阅读返回保留未读、确认成功收下、空账号、答题页自动队列、最近五封、拖动与位置记忆、前后台轮询、自动线索期间避让及答题草稿保留。长信图片和视频可打开及关闭，返回同一封信并保留未读，确认按钮始终完整可见。日夜弹窗原图均核对顶部和底部背景连续、系统图标与手势条可见。[逐项验收](slice-03-gameplay-validation.md#旅途来信收件箱答题浮标与沉浸弹窗2026-11-16)

2026-11-16 浮标手势补验范围包含从信封正中心直接拖动和停留后再拖动。两种操作都应通过原生 PanGesture 移动浮标，松手贴边，页面内容不滚动，系统图片拖放不介入，也不打开归档。单击仍打开归档，重新进入答题页保留位置。

直板真机复现旧版信封中心停留后再拖时浮标无位移。新版已验证按住再拖和直接拖均能移到另一侧并贴边，题目保持稳定，轻点打开归档，回访保留位置。[手势补验](slice-03-gameplay-validation.md#来信浮标长按拖动补验2026-11-16)

### 2026-11-16 答题模块补漏复查

入场、取题、输入与判题、关卡进度、完成结算有直板真机和隔离后端的验收记录。逐题背景、BGM、普通及组合线索、终章、信纸和祝福按各自切片的覆盖范围记录。此次复查以正式 Web 路由 `4b7d1a0` 和迁移留项前的原生实现为准。

| 发现 | 当前范围 |
| --- | --- |
| 题面与题内提示的旧富文本 | Web `QuestContent` 对题面及提示内容调用 `RichContent`，支持行内强调、链接及带查看器的媒体。原生已接结构化题图、题面及选项视频，题面或提示字符串中的旧标记仍按普通文字显示。初次内容普查未覆盖含这些标记的已发布题面样本。 |
| 普通文字与组合线索正文里的内嵌视频 | Web 两种阅读弹层都支持正文视频段。原生已接独立视频线索及正文图片，旧格式的正文视频段尚待迁移。 |
| 原地停留答题时的玩家同步 | Web 同时轮询 `/me` 和场次，并为临时读取错误显示非模态同步反馈。原生定时读取场次，回前台时读取 `/me`，答题回执也可更新玩家资料。持续停留期间单独的玩家资料变化及 `/me` 失败反馈还有差异。 |

折叠屏、分栏、桌面悬停和专属布局沿用既定的后续设备验收顺序。Web 完成后的奖品结算仍由后端负责，奖品列表与领取信息另见 R01。

### 2026-11-16 答题留项迁移

| 切片 | 冻结 Web 对照与逐状态验收 |
| --- | --- |
| 题面和提示富文本 | `QuestContent` 与 `RichContent`。使用同一内容验证普通行、空行、高亮、链接、内嵌图和视频的先后顺序。提示初始折叠。展开、查看、关闭及切题保留原有答题草稿和解锁条件。媒体失败可重试，无效地址不可点击。 |
| 普通与组合线索内嵌视频 | `ClueTextDialog` 与 `MultiQuestClueDialog`。核对正文顺序、封面、有无视频、正文内播、独立展开与失败重试。关闭回到同一线索，继续遵循普通、完成、组合的既定演出顺序和 BGM 音频优先级。卡片继续仅预览文字。 |
| 前台玩家资料同步 | `GameContext` 的 `/me` 前台间隔。验证正常昵称和等级回源、瞬时故障期间同一个非模态提示、自动恢复以及关闭后同一次故障不重复提示。同时核对场次同步、下拉刷新、答题回执、改密和账号切换的并发边界，保留草稿和场次实例。 |
| 入场前说明页来信 | `GamePlayScene` 的说明页通知中心。验证五秒后按服务端顺序展示未读、失败和重试、最近五封与同一可拖动浮标。保留原始准入及入场意图，入场线索和来信互不叠放。进入答题后不重复确认已收下的信，后台、离场、失权时清理本页展示。 |

说明页的直板测试中，收到两封信，已读接口一次 503 后重试成功。随后拖动浮标贴边，归档可打开，入场后两封已读信均未重播，台账只记录一次显式入场。资料同步中，两路 503 共用一个提示，后台停止定时读取。隔离后端更改昵称后留在原答题页即可显示新昵称，草稿与玩法台账保持一致。[说明页来信](../artifacts/validation/ui-gameplay-parity-completion-20261116/native-briefing-01.json) · [玩家同步](../artifacts/validation/ui-gameplay-parity-completion-20261116/native-profile-01.json)

题面、提示及两类线索的直板机测试覆盖正文内播、独立展开和返回，题面视频一次 503 后重试成功。原位视频恢复为暂停，答题草稿保持。两类线索均可在原弹层继续阅读，组合确认按钮保持完整。实际两次正确答题对应两条进度和 20 XP。[逐项验收](slice-03-gameplay-validation.md#旧富文本玩家同步与入场前来信2026-11-16) · [直板媒体报告](../artifacts/validation/ui-gameplay-parity-completion-20261116/native-rich-media-01.json)

定版夜间补验中，入场自动线索先打开，刚发来的信等线索关闭后才出现。三封信以独立账号对账为一次入场、零次答题，测试后恢复原主题。[夜间说明与入场](../artifacts/validation/ui-gameplay-parity-completion-20261116/native-briefing-night-01.json)

### Q01c 入场说明页状态同步与撤回

实施前对照冻结 Web `4b7d1a0` 的 `GamePlayPage`、`GamePlayScene` 和 `GameContext`。本次范围为入场前说明、当前玩家和场次状态的读取。

| 状态 | 验收要求 |
| --- | --- |
| 首次进入与前台停留 | 首次读取显示加载及错误重试。说明页保有有效场次时，每约五秒重新读取场次及当前玩家。服务器改公告、时间窗或等级后，原页跟进可见状态和入场按钮。 |
| 临时失败 | 之前成功的内容仍可读，场次及玩家读取共用一个可关闭的非模态提示。两路恢复后清除，下一次失败再提示。校验读取、已有来信和入场请求各自的边界。 |
| 场次撤回 | 保留当前有效标题区与服务端仍发布的公告，显示 Web 撤回文案及返回首页按钮。原说明、入场动作、待展示来信停止呈现。失权错误清除旧场次数据。 |
| 另一端入场 | 由当前账号、场次的真实启动快照进入题面，保持权威进度。只读恢复不发送入场或答题请求，不重播开场线索。 |
| 本机入场与离开 | 显式入场及结果不确定期间保留原命令和 requestId。切换、后台和账号失效取消在途说明读取，忽略迟到响应。 |

状态、返回、写入台账用隔离真实 HTTPS 和直板机核对。撤回和同步提示使用同内容宽度的 Web 原图复核。

直板与隔离真实 HTTPS 实测等级达标、说明文案更新、首次读取失败重试、两路临时失败和后台暂停。撤回会结束入场说明并关掉当前来信，台账保留原未读状态。另一端入场只对应主机的一次写入，手机恢复首题并保持开场线索静默。通过来信切换时，释放的前一场次响应未覆盖新说明页。定版同步提示已用两张原图和实际关闭动作复核。时间窗判定复用既有准入逻辑。[逐项验收](slice-03-gameplay-validation.md#入场说明页状态同步与撤回2026-11-16)

### T03c 入场说明页的氛围与配乐

实施前对照冻结 Web `4b7d1a0` 的 `GamePlayScene`、逐题配置和 BGM 控件。说明页用已授权的场次配置，进入答题后使用当前可读关卡覆盖。原生沿用已有的背景处理、减少动画分支及官方音频优先级。

| 场景 | 验收要求 |
| --- | --- |
| 说明页 | 同数据核对日夜有图、无图、动态氛围和浮标。显式静音时隐藏音乐控件。无图时仍保留主题氛围，不遮挡来信、说明及入场动作。 |
| 入场和回源 | 同曲跨入场保持同一播放器及进度，首题覆盖时只切一次，静音覆盖释放旧曲。只读刷新不重复取曲或重启氛围。 |
| 来信媒体 | 来信与音乐浮标避让。视频开播前等待 BGM 停音，关闭后按原偏好恢复，主动暂停保持。 |
| 生命周期和失败 | 退出、后台、撤回、账号变化时停止。背景读取失败保留可读底色，BGM 失败沿用手动重试。媒体及展示不新增入场、已读或答题写入。 |

隔离 HTTPS 与直板分别记录实际播放时序、页面层级、前后台及 SQLite 回执。Web 与原生同宽度图像对照独立记录。

直板和隔离真实 HTTPS 已验同曲续播、首题替换图与配乐、静音无图、只读轮询、视频停音及恢复、媒体失败与重试、退后台及离场。四个账号各有一次主动入场，答题及经验写入均为零。日夜原图已对照，系统减弱动效的开启分支留待对应真机复验。[逐项验收](slice-03-gameplay-validation.md#入场说明页的氛围与配乐2026-11-17)

### R01a 奇遇收藏的奖品列表与详情

参照冻结 Web `4b7d1a0` 的 `/rewards`、`GameRewardsPage` 和 `RewardCard`。底栏和头像侧栏进入同一页面，服务器发放的奖品按接口顺序显示。直板使用一列卡片及原生底部详情弹层。开启系统减弱动效时，关闭可选的卡片与详情内容动效。

| 场景 | 验收要求 |
| --- | --- |
| 入口、加载、空态 | 底栏与头像侧栏均可进入。首次读取显示加载反馈。成功且无奖品时按 Web 显示空态，去探索返回启程。 |
| 列表和返回 | 核对可领取、已领取、已失效的真实奖品、封面或星标、数量、标题及两行摘要。关闭详情保持列表位置和所选 Tab，蒙层随弹层消失。 |
| 奖品详情 | 展示奖品快照、公开领取说明、可领取状态的专属领取信息以及服务端返回的已领取时间。复用原生富文本与媒体边界。详情仅阅读。手势区延续详情底色，安全间距位于滚动内容末尾。 |
| 刷新、失败及账号 | 下拉刷新和显式重试回源。临时失败保留同账号已确认的列表并展示反馈。换账号、退出或强制改密清除私密内容，迟到结果不回填。 |
| 服务端对账和视觉 | 使用直板与隔离真实 `GET /rewards`，核对不同账号、空列表、失败与重试。交互期间无入场、答题或领取写入。日夜使用同宽度和同数据对照。 |

直板、隔离真实 HTTPS 和同数据日夜对照通过。向下滚动时手势区延续详情底色。关闭按钮、系统返回、点遮罩和下滑均在一次动作后清除蒙层，图片查看器返回保留详情。两账号台账一致，收藏交互无业务写入。真机的系统减少动画开启和详情内嵌视频未在本轮独立复测。[逐项验收](slice-04-rewards-validation.md)

### V04a 四页签浮动底栏的拖动选择

2026-11-17 用户反馈四项均可点按，部分跨项拖动无法在松手处选中。基准包用官方直板机 `drag` 从收藏中心拖到护照中心，实际落在来信。修复接入 API 26 的官方 `HdsTabs` 悬浮样式，由系统完成拖动选择与动画，应用同步实际选中的目的地。

| 场景 | 验收要求 |
| --- | --- |
| 跨页签拖动 | 四个源页与其余三个终点共 12 个有向组合，沿实际 TabBar 范围松手选择目标。单次注入后同时核对选中索引、页面与回调。 |
| 其他导航 | 保留四项点按、同项松手和菜单主动导航。页签内容区的横向拖动不切换底栏，取消和无效输入不触发业务导航。 |
| 门禁与系统行为 | 保留登录、路径与安全限制以及键盘避让。保持官方沉浸材质、命中与动画，拖动不发起业务写入。 |

直板固定预览验证 12 个有向拖动及 8 个补充输入，全数通过。另验侧栏进入收藏、日夜选中态、真实键盘避让及系统返回。主题流程首次偶发跳回启程，两次复测未重现。系统取消手势、密码结果未确认的准入限制及系统减少动画开启分支待专项验证。[底栏验收记录](native-tab-drag-validation-2026-11-17.md)

### V04c 底栏松手后页面与图标同步

用户反馈从来信拖到收藏、仍在移动时松手，内容已切换，收藏图标可能没有变成选中态。沿用官方 HdsTabs 的悬浮效果、手势与命中，检查手势接受和动画完成的事件顺序。主导航的活动项同时是页面生命周期、菜单、返回及品牌图标的依据。

| 场景 | 验收要求 |
| --- | --- |
| 快速松手与连续拖动 | 直板机从来信到收藏及反向，以不同速度松手，连续切换后以最后接受的目标为准。逐次核对页面、原生事件和实际填充图标。 |
| 正常导航 | 点击、从未选中项起手、同项或无效松手，以及侧栏／返回的程序切换保持原行为。离开主页面时门禁仍约束跳转。 |
| 视觉及影响 | 原图确认同一时刻仅当前项使用主题色填充；检查日夜对比与浮栏材质，所有底栏输入不产生额外业务写入。 |

旧包真机反向复现从收藏切到了来信、收藏仍显示填充图标，记录有准入回调且缺少 `onChange`。新包用 `onSelected` 更新当前主项。日间同一候选包的六种官方输入覆盖来信与收藏双向快滑及四个主项，逐次核对实际页面与唯一填充图标。[选择态真机记录](../artifacts/validation/ui-tab-selection-20261117/selection-visual-01.json)

### A10 冷启动安全续登

冻结 Web `4b7d1a0` 的认证客户端保存有效令牌，重开时通过 `GameGate` 请求 `/me` 并执行首次强制改密。原生使用系统关键资产存储保存登录凭据，继续依赖真实 HTTPS 与服务端玩家状态。

| 场景 | 验收要求 |
| --- | --- |
| 正常启动 | 没有凭据时显示原登录表单。正确登录后结束 App 进程，再启动时先验证 `/me` 和玩家归属，成功进入首页，无需填写密码。 |
| 恢复失败 | 临时断网、网络超时或服务不可用时进入可重试状态。此前凭据保留，私人内容在恢复成功前不展示。会话明确失效时清掉旧凭据，回到登录；账号与后端环境隔离。 |
| 改密与退出 | 服务端要求改密时只能继续到该页面或退出。改密成功保存新令牌，失败不自动重发。用户退出后清理会话，进程重启不恢复旧账号；旧请求晚到也不能恢复原账号。 |
| 受保护内容与路由 | 启动恢复不保存密码、临时头像令牌或私密业务内容。未确认登录与强改密时屏蔽受保护目的地，后续由相同业务门禁处理。恢复只读回源，不重放入场、答题或已读命令。 |

验收使用单独账号和隔离真实 HTTPS，记录真机进程切换、恢复读请求、改密次数及退出换号。固定预览仅用于最终正常使用路径。

直板和隔离真实 HTTPS 完成 17 项验收。强制改密只提交一次，重开使用新令牌。503 及连接中断可原位重试，服务端 401 及退出后重启会重新要求登录。另核对换号、等待期间屏蔽私密页面和无额外业务写入。恢复固定预览时未重输密码，预览会话和一次性验收会话保持隔离。资产删除失败为单测范围，锁屏和系统减少动画开启留待对应专项。[续登逐项验收](slice-05-secure-session-validation.md)

2026-11-17 冷启动接入系统增强启动窗。日间直板实际从桌面点开，分别采到系统静态星图和后续 ArkUI 转环与续登文案；真实 `/me` 返回后恢复首页。夜间资源已核对打包，相关真机专项见[冷启星图验收](cold-launch-star-atlas-validation-2026-11-17.md)。

### A11 「启程」停留时自动同步

冻结 Web `4b7d1a0` 的 `useAssignments` 和 `GameGate` 分别以五秒间隔读取场次列表和玩家资料。原生保留官方下拉刷新和现在的页面布局，复用既有同步提示及动效。

| 状态 | 实施前验收要求 |
| --- | --- |
| 正常停留 | 已登录、前台且停在根页「启程」时约每五秒读取 `/assignments` 和 `/me`。远端场次新增、进度和玩家等级按服务端结果更新，保留当前/历史分类、列表位置及现有内容；定时读取不触发转圈或入场、答题、领取等写入。 |
| 下拉或导航中断 | 下拉取消在途自动读取及原计时；手动回源结束后重新计时。切离「启程」、打开场次、进入后台和退出时停止自动轮询；在途旧结果即使迟到也不展示。恢复页面后可以继续同步。 |
| 短时与终态失败 | 旧列表或已有空态保持可读，暂时性故障沿用非模态同步提示，可关闭，恢复后自动消失；无列表快照时保留现有失败与重试。会话失效清理私有状态与续登凭据，服务端返回强制改密时重新门禁。 |
| 证据 | 单测分别验证取消、恢复和失权。直板机与独立隔离 HTTPS 核对服务端变化、请求顺序、滚动保持及没有新增游戏写入。 |

直板机与隔离 HTTPS 已观察到场次派发、进度和玩家等级变化自动显示，更新前后可见列表锚点偏移 0 px。503 保留列表，日间原图已目视，点按关闭先于下一次健康读取。下拉先于真实挂起的旧读取取得新数据，下一次自动读取在下拉结束约 5 秒后发出，旧响应完成后仍为新数据。切到护照超过一个轮询间隔，未发启程场次或玩家读取；留在答题页超过一轮，未发启程列表读取。两份前轮驱动中止保留原状态，其余场景用同一签名包单独补验。三轮沿用同一真机测试登录，退出和无额外业务写入已核对。[派发、进度、等级和提示](../artifacts/validation/release-prep-20261117/native-lobby-01.json) · [关闭提示、切页和下拉竞态](../artifacts/validation/release-prep-20261117/native-lobby-02.json) · [答题路由、退出与台账](../artifacts/validation/release-prep-20261117/native-lobby-03.json)

会话失权、强制改密、网络失败时保留空态及与本地资料保存的竞态已用 Hypium 验证。启程退到系统后台、当前轮询实收 401、夜间和开启系统减少动画未独立真机触发。[业务测试](../artifacts/validation/release-prep-20261117/local-test-summary.json)

### V04b 来信与护照的子页签横滑

2026-11-17，用户要求沿用「启程」页签的原生横滑。「旅途来信／星海信笺」和「我的名片／账号安全」保持既有标题、选中态、点按和安全区，用 ArkUI Tabs 原生内容区手势切换。画面层级仍由外层 HdsTabs 承载。

| 场景 | 验收要求 |
| --- | --- |
| 横滑与点按 | 两组子页签分别向左、向右滑动后选中相应目标，标题与页面状态一致。点按仍可切换。 |
| 手势竞争 | 正常竖滑继续滚动原页面。来信单封侧滑的「收下」继续可用，切换子页签本身不标已读。横滑不会切换主导航。 |
| 护照表单 | 切到账号安全显示原字段，离开安全页仍按既有行为清除密码草稿。来回切换保留未提交昵称。 |

同一签名候选包通过直板机双向横滑和点按。单封未读来信仍能侧滑露出「收下」，点击才产生一次已读写入。昵称草稿保留，离开账号安全后再次进入时密码草稿为空。[真机交互记录](../artifacts/validation/release-prep-20261117/native-subtabs-01.json)

### R01b 直板隔离发奖与核销闭环

使用同一个签名候选包、一次性 PocketBase 和配置了完成发奖规则的专用场次。由真机正确答题触发真实奖品规则。末题响应丢失后核对重试仍使用原请求，且同一发放规则只有一笔奖品发放，进度、经验和请求回执对应服务端事务。收藏读取实际奖品、状态、数量及授权领取信息。使用隔离管理员核销，观察原生收藏在停留期间自动回源，已领取时间可见，旧专属信息消失。台账区分原生玩家请求与主机管理员请求。

同一签名候选已经直板真机和隔离 HTTPS 验证。首次答题的真实 200 响应被故障网关断开，原生没有第二次点按，网关随后记录原请求 ID、请求体、玩家及题目均一致的第二次请求。服务端只有一条提交、一条答题回执、一笔经验和一份规则发放的奖品。收藏详情读取到可领取状态和专属指引。隔离管理端核销一次后，打开的详情通过真实轮询显示已领取时间并隐藏私密指引，玩家接口也不再返回私密指引内容。原生没有领取或核销写入。[同一候选包发放与核销报告](../artifacts/validation/release-prep-20261117/native-reward-loop-01.json)

### P01 公网生产 HTTPS 登录与只读联调

| 场景 | 验收要求 |
| --- | --- |
| 构建和信任 | 单独构建标为「生产联调 · 只读」的调试签名包。生产模式固定使用正式 Web 的 API origin 和系统证书校验，HAP 中无隔离配置、私有 CA 或登录材料。生产模式与隔离配置冲突时无法登录。 |
| 公网可达性 | 以同一签名包在直板分别使用 Wi‑Fi 和蜂窝。先发无凭据 `/me` 读取并确认鉴权拒绝来自正式 API，再凭专用玩家登录。系统证书失败、域名不可达和服务端错误各自记录。 |
| 已授权读取 | 专用生产玩家能登录、结束进程后续登、打开自己的场次列表及详情；用已存在的头像验证短期文件 Token 和授权文件读取。记录各 API 状态和真机行为，不公开账号标识、私有素材、Token 或口令。 |
| 写入及环境隔离 | 这一候选包在请求层放行登录、读取和只用于授权头像的临时文件 Token；拦截入场、答题、改密、资料及来信已读等变更。生产与固定隔离的安全续登存储对应各自端点与 CA。测试后可重新安装同签名的隔离预览包。 |

已完成签名包检查、安装、直板生产 HTTPS 连通性和匿名 `/me` 的 401。同一包用 Wi-Fi 通过专用玩家登录、冷启动续登、列表和用户指定的授权场次详情，仍为入场前的零进度。测试机没有 SIM，用户将在个人手机另验蜂窝。受保护头像待测试数据。设备已退出生产专用玩家并恢复原固定预览会话。配置、业务测试及现场记录见[生产 HTTPS 只读联调](production-https-smoke-2026-11-17.md)。

### P02 首版生产候选与真实答题闭环

| 场景 | 验收要求 |
| --- | --- |
| 生产候选 | 仅显式选择生产写入模式的候选包使用固定生产域名和系统信任。包内无隔离配置、私有 CA 或账号信息。隔离预览和生产只读构建仍可独立生成。发行包名、签名和测试分发分别确认。 |
| 专用玩家与场次 | 核对专用生产玩家和明确用于写入验收的场次。记录入场前零进度和玩家总经验，按正常入口完成入场、答题和结算。 |
| 生产回源对账 | 核对本次入场和答题的实际成功请求、已完成状态以及服务端回源的进度和经验。重新打开场次并冷启续登，确认完成状态与经验保持，不产生更多答题请求。保持业务与敏感日志最小化。 |
| 分发和恢复 | 调试包、待发行签名及已发的测试版本分别记录。实际接收对象和渠道明确后进行小范围分发。测试设备可恢复固定预览。 |

0.1.0 调试签名候选已在直板机通过 Wi-Fi 生产闭环。专用玩家从「清宫那点事 V2」0/6 完成至 6/6，收到 1 次入场和 6 次答题的 200。生产后台核对正好 6 条答对记录，玩家资料回源显示增加 120 EXP。回访与冷启动续登保留完成状态和经验，均无新增写入。测试机已退出该生产会话并回到固定隔离预览。生产蜂窝仍按 P01 处理，邀请测试待正式应用身份与发布签名。[首版生产写入候选](production-write-candidate-2026-11-17.md)

### U01 日夜主题冷启恢复

| 场景 | 验收要求 |
| --- | --- |
| 显式浅色或深色 | 在「旅途光线」即时切换。结束进程、启动同一安装包后，页面、系统栏前景及选择器恢复上次选择。 |
| 跟随系统 | 从手动主题切回「跟随系统」。冷启后保留此项，页面按系统当前主题显示。缺少有效首选项时默认跟随系统。 |
| 范围 | 设置保存在应用本地，登录前和侧栏读取同一项。固定隔离预览的续登可继续使用，本轮不需要生产或玩法写入。 |

冻结 Web `4b7d1a0` 保存 `system`、`light`、`dark` 三态。旧包直板实测选中深色后冷启会回到跟随系统。修复包经官方 DevEco 签名安装，同一固定隔离账号下逐一点击深色、浅色、跟随系统，并分别结束进程再启动。三次均从官方 UiTest 原始布局读到正确的唯一选中项，首页原图采样和沉浸系统栏前景与对应主题一致。设备本轮系统配色为浅色，收尾仍在固定预览首页并设为跟随系统。登录页共用同一选择器，通过源码核对。Hypium 226 项通过，codelinter 无错误和警告。[旧包复现](../artifacts/validation/theme-persistence-20261117/baseline-theme-01.json) · [签名安装](../artifacts/validation/theme-persistence-20261117/signed-preview-01.json) · [真机冷启恢复](../artifacts/validation/theme-persistence-20261117/fixed-theme-01.json) · [业务测试](../artifacts/validation/theme-persistence-20261117/local-test-summary.json) · [代码检查](../artifacts/validation/theme-persistence-20261117/lint.json)

### P03 发布签名与首轮邀请测试

| 阶段 | 验收要求 |
| --- | --- |
| 应用身份 | 在 HarmonyOS 开发者中心核对团队、项目、应用分类、包名、支持设备与 APP ID。包名与签名包一致，首轮覆盖手机。 |
| 正式包构建和签名 | 从已验证源码构建 Release `.app`，检查版本、固定生产 HTTPS 配置、调试标志和本地隔离资源排除。核验实际分发签名以及开发者中心的上传检测结果。 |
| 指定范围邀请 | 明确具名测试群组、测试时段和渠道。平台要求时通过官方表单提供专用审核账号和本版本材料。记录提审、实际可安装及首台邀请设备的结果。 |

已登记「赴星之约」，正式包名 `com.sitkin.starward`，APP ID `6917622040781575732`，归 sitkin 主账号同名项目，分类「应用」，首轮支持手机。源码 `be08996` 经 DevEco CLI 项目级 Release 构建得到 0.1.0（1）`.app`，包内为已联调的生产 HTTPS 模式，无隔离配置或隔离 CA。DevEco Studio 使用云管理发布签名，官方 SDK 核验外层签名及 release Profile 成功，签名前后应用 HAP 内容逐字节一致。[签名与上传回执](../artifacts/validation/release-invite-20261117/signed-release-01.json)

开发者中心显示该包为「仅测试」，软件包合法性「已达标」，上架自检尚未执行。首份邀请草稿保存了图标、应用介绍和测试说明。邀请包随后更新至接入隐私签署检查的 0.1.0（2），见 P04。[首版生产调试联调](production-write-candidate-2026-11-17.md) · [华为邀请测试流程](https://developer.huawei.com/consumer/cn/doc/app/agc-help-invite-test-0000002270829393/)

### P04 首轮邀请的隐私政策和签署检查

| 场景 | 验收要求 |
| --- | --- |
| 托管声明 | 根据鸿蒙版实际数据编写，核实运营者、公开联系渠道、保留期限、实际存放地和行权方式。开发者中心生成后关联到邀请草稿。 |
| 首次启动及续登 | 邀请包先查 AppGallery Kit 当前签署结果，再调用玩家接口。未同意、签署服务不可用或更新声明时，保持登录和续登入口关闭，可用官方弹窗继续。 |
| 首启隐私抽屉 | 未确认时，由品牌底图承托按内容收拢的 ArkUI 底部抽屉；遮罩点击、下滑及返回不放行，登录表单也不在抽屉后方加载。大字号或短窗口可滚动到达两个动作。 |
| 系统确认、拒绝和失败 | 「继续」只启动 AppGallery 官方确认。系统取消或拒绝后抽屉仍在；打开失败显示错误并可重试；确认签署后才收起抽屉、进入登录或续登。 |
| 政策入口 | 签署前、登录页及账号侧栏能从官方服务读取并打开对应隐私政策。市场托管处理确认弹窗。 |
| 首轮范围 | 测试组只有用户确认的一个账号。补齐测试时段及审核资料后再提交，实际分发与真机安装单独验证。 |

2026-11-18 在 API 26 直板机以独立 Debug 样包重放「签署状态不可用」，保留设备原有签署记录。抽屉按内容占屏幕下方约 28%，日间实际原图中标题、政策和继续按钮均可见；点遮罩、向下拖动、系统返回后抽屉仍在，登录表单始终未加载。新版未重测真实首次系统签署、跳转政策、短窗口、大字号和夜间隐私抽屉；下方历史签署报告适用于旧页面。

华为托管政策已生成，公开链接已打开验证，并已关联到「0.1.0 首轮手机邀请测试」草稿。政策采用实名登记主体和经确认的公开邮箱。生产数据库与备份位于阿里云河源，应用面向受邀成年人。[华为托管政策](https://agreement-drcn.hispace.dbankcloud.cn/index.html?lang=zh&agreementId=2085666010223924480)

0.1.0（2）由 DevEco CLI 构建，DevEco Studio 云签并上传到「仅测试」。SDK 验证外层 App 签名及 release Profile。云签前后 ArkTS 载荷及生产标记相同，只更新了分发构建元数据。开发者中心检测合法性已达标，新包已替换草稿中的 0.1.0（1）。Hypium 228 项通过，含保留及撤销续登记录的回归，codelinter 无错误或告警，保留一项既有信纸模糊性能建议。[云签与上传](../artifacts/validation/privacy-invite-20261117/signed-release-02.json) · [Hypium](../artifacts/validation/privacy-invite-20261117/local-test-summary.json) · [代码检查](../artifacts/validation/privacy-invite-20261117/lint.json)

在直板机上用官方 AppGallery 调试元数据模拟托管。测试辅助按钮调用官方 SDK 重置签署，应用隐藏登录表单并可打开系统弹窗。取消后再启动，登录仍被挡住。同意后进入登录页，冷启保留签署状态，从登录页打开了托管政策。完成后重新安装原固定隔离预览包并确认恢复到首页。隔离调试包未验证市场分发后的首次安装和正式续登。[真机签署验证](../artifacts/validation/privacy-invite-20261117/device-privacy-simulation.json)

应用分类设为「应用 / 休闲娱乐」，主标签为「休闲益智」。负责人手机已通过官方验证。生产后台只给新建的专用审核玩家分配一场虚构样例，含一题，无经验、奖品或私有内容。用户完成专用玩家首次改密，并通过开发者中心保存审核凭据。

2026 年 11 月 17 日，构建号 2 的邀请测试已提交，华为显示「预审中」。测试窗口为北京时间 11 月 17 日 17:10 至 11 月 30 日 16:30:58。选择用户确认的一个群组、一位测试用户，开启平台测试通知。等待平台通过预审及正式审核后核验邀请实际送达、市场安装和正式签署。[提交回执](../artifacts/validation/privacy-invite-20261117/invitation-submitted-01.json) · [华为邀请测试流程](https://developer.huawei.com/consumer/cn/doc/app/agc-help-appgallery-release-testapp-0000002258174266)

### P05 AppGallery 审核用多题样例

| 用途 | 审核样例 |
| --- | --- |
| 查阅与入场 | 「启程」打开「星港启航 · AppGallery 审核样例」v2。说明列出审核速览，入场后显示普通自动线索。 |
| 答题与续接 | 两道单选、两道填空，答案依次为绿灯、北星、两闪、启航。核对题内提示、错答反馈、逐题解锁和途中继续。 |
| 媒体与剧情 | 第 2 题解锁六秒信标视频，第 3 题有灯塔图。终章接一组带两张合成图的组合线索与现代风格值班室信笺。 |
| 来信与收藏 | 首题发放虚构纪念章，通关发放虚构兑换券。两份奖品无实际价值，玩家可在收藏查看状态与说明。审核导览通过站内来信只发至审核专用账号。 |

后台确认只向审核专用玩家下发一个 v2，初始进度为 `0/4`；原 `0/1` 待开始分配已撤回。使用现有生产 OSS 媒体分发，将五个合成资源放入独立前缀。按客户端既有 Referer 实测五份文件的 GET 内容均与原件一致，视频字节范围请求返回 206。交付保留未开始状态供审核员走完整流程。此记录验证后台配置、定向下发和媒体传输，审核端播放与结算留在实际邀请包验收。[配置与下发回执](../artifacts/validation/appgallery-review-expanded-20261117/fixture-assignment.json)

AList `/alisoss` 原挂载因旧 OSS AccessKey 已禁用，列目录返回 `403 InvalidAccessKeyId`。新专用 RAM 用户只获得 `sitkin-cdn` 媒体目录所需的列举、读取和上传权限。更换密钥及重新连接运营台后，图片、视频、音频列表均已回读。通过运营台实际上传一张合成 PNG，OSS 返回的内容与原文件哈希一致。RAM 显示旧钥在 4 月 8 日有最后一次 OSS 使用记录，操作审计可查询窗口内未发现可归因的状态变更。[恢复回执](../artifacts/validation/appgallery-review-expanded-20261117/alist-repair.json)

### U02 低干扰的网络与操作反馈

| 场景 | 验收要求 |
| --- | --- |
| 登录网络失败 | 断网、超时、安全连接失败、限流或服务暂不可用显示可关闭、自动消失的鸿蒙浮层；日夜可读，不挤动表单，键盘不遮住关闭键。关闭、后台切换不提交，原输入保留，手动重试可再次提示或正常登录。 |
| 登录与账号门槛 | 缺少输入、凭据错误等在表单内简短提示；登录和首次改密均不出现「回到首页」。续登失败仍有重试和返回登录，改密结果未确认的指引持续可见。 |
| 启程与收藏已有内容 | 同步失败时继续展示上一份成功结果（包括有效空列表）；手动下拉和后台轮询不堆叠大错误块，单次中断可关闭，恢复后再次故障可提示。 |
| 星海信笺已有内容 | 手动刷新遇到暂时故障时，保留同账号可读信笺，用可关闭浮层提示；部分来源一直未读到时，在已有信件后保留来源重试。 |
| 内容不可用 | 启程和收藏首次读取失败保留常驻重试，不渲染假空态；来信分来源读失败、剧情打不开、终态场次以及答题关键失败保留可达的恢复动作。 |

冻结 Web `4b7d1a0` 的登录和收藏默认在内容中插入错误区，也有独立的可关闭 Toast。原生按本轮确认的方向改为轻提示：登录的暂时故障和星海信笺手动刷新的暂时故障使用官方浮层；已有内容的启程和收藏沿用同步中断提示。答题同步、判题写入反馈、首次加载及账号门槛仍有对应的恢复入口。媒体重试、通知已读写入失败留在原操作旁，避免误以为已经成功。

API 26 直板机在真实隔离 HTTPS 登录与断网切换下验证了日夜浮层、输入与表单位置保留、手动和自动关闭、键盘避让以及原输入重试登录。启程、收藏、星海信笺实测有效空列表保留；每种失败文案、首次读取阻断和关键答题错误未在本次逐项重走。Hypium 238 项通过。[验证记录](error-feedback-verification-2026-11-18.md)

### M01b 未读来信入口与全局轻提醒（2026-11-19）

本轮用户同时授权原生与 Web 调整。沿用现有信件列表与答题主题，新增入口状态、角标和可操作的轻提醒；完整「旅途来信」页仍保留已读历史。用户确认保留答题时自动弹出未读来信。普通关闭不标已读，该封本次答题期间不重复自动弹出，仍可从未读浮标点开；确认成功后继续队列。

| 状态 | 验收要求 |
| --- | --- |
| 无未读与初次同步 | 无未读不显示答题浮标；首次读取已有未读只更新入口数量，不将历史积压当成本次新来信反复提示。不把加载失败当作已读清空。 |
| 有未读与打开 | 入场前和答题页的浮标仅在有未读时出现；点开仅列未读，未读较多可滚动。保持拖动、贴边、位置记忆和误触抑制。 |
| 阅读与失败 | 以明确确认后的服务端已读回执移除该项；普通返回保留未读。写失败原信仍在、错误和重试可达，不重复提交已确认记录。 |
| 读完与回访 | 最后一封确认后列表清空、浮标收起，显示“已阅读的来信可在「来信」中查看”的轻提示；提示可关闭，点查看进入「来信 → 旅途来信」，已读历史可回访。 |
| 首页等页面新来信 | 已登录、前台且在答题流程以外时，用同账号轮询发现新增未读；同一批只提示一次，关闭后不随轮询重播；来信页本身不重复提示。点提醒进入来信页。 |
| 底栏 | 「来信」显示实时未读数字角标，无未读隐藏，超过上限有明确封顶；选中态、原生拖动切换和日夜对比保持可用。 |
| 中断与账号 | 后台停轮询，恢复重新取权威列表；切号、退出、强制改密、已读取消/错误均不串旧提示、角标或导航。只增加必要来信读取和确认，不产生入场、答题、领奖写入。 |

底栏角标位置已由用户明确为信封图标右上角，去掉默认红色描边；原生使用官方渲染后节点坐标定位，避免浮动底栏的布局坐标与实际绘制位置不同。首批历史未读只显示角标；首页新到来信的提醒正文和「查看」均可点按，关闭键不产生已读写入。具体原生及 Web 的执行结果见本轮验证记录。

API 26 直板真机已通过隔离真实 HTTPS 下的初始角标、新来信提示与跳转、保留自动弹出、普通关闭不写已读、未读列表、503 后重试、读完收起及历史引导、题目输入保留、夜间可读性、底栏拖选和浮标拖动。后台与退出停止查询。Hypium 245 项通过，账号切换和迟到响应另有业务测试。Web 最终 `pnpm verify:release` 通过，含 333 项单测、132 项 Chromium、28 项移动 WebKit、两种构建及只读后端探测；尚未推送部署。详见[本轮验证记录](journey-unread-verification-2026-11-19.md)。

### U02a 打开答题旅程时的加载与恢复（2026-11-20）

范围：从首页开启、继续或重温旅程的场次读取，以及答题页阻断错误后的重新读取。不改变入场 POST 的按钮反馈、已有题面时的同步提示或判题恢复弹窗。

冻结 Web `4b7d1a0` 的 `GameLoadingScreen(scene="journey")` 是独立整页，使用星图、七秒轨迹、状态与短句；`GameFailure` 在内容区保留错误原因和两个恢复动作。按本次要求，原生保留当前官方标题栏，复用本项目冷启动星图的图形和轨迹，缩为标题下方的局部内容；去掉整页框、重复标题、飘星和宣传短句。加载只留一条状态文案。失败单独用浅边框、警示标记及日夜语义色，优先「重新尝试」，其次「回到首页」，不套用模态层。

| 状态 | 验收要求 |
| --- | --- |
| 慢速首次读取 / 完成后重温 | 标题栏保留；居中星图和状态字在标题下方、不占全屏，不展示未收到的题目或进度。真实响应到达后立即呈现原说明或题面，不等待动画。 |
| 失败 / 重试 | 仍显示实际错误说明，两项原生操作可达且主次清楚。重试复用原 GET 与并发门控，过渡回星图而非叠加错误；有题时的非阻断错误不替换题面。 |
| 返回 / 账号切换 | 保留原系统返回及已有回首页动作。离场或退出后，迟到响应不能恢复场次、动画或私密内容，不产生入场、答题、领取写入。 |
| 外观 / 动效 | 用同一场次和手机内容宽度核日夜原图，检查字色和触点；系统减少动画或页面被覆盖、切后台时，星图静止但状态可读，返回前台仍待请求才恢复。 |

API 26 直板真机隔离验证了慢速首次打开、重温、503/404 后重试、系统返回及「回到首页」，另确认退出后迟到响应不恢复页面或账号。已对照日夜原图和星图位移；本轮未在真机切换系统「减少动画」或逐项验证覆盖、前后台暂停。详见[答题页验证记录](slice-03-gameplay-validation.md)。

### A11 系统密码保险箱（2026-11-20）

冻结 Web `4b7d1a0` 的登录表单声明 `username` 和 `current-password`。原生在同一卡片内用 ArkUI 登录账号和密码输入类型启用系统填充，沿用现有表单、遮蔽和键盘避让。

| 场景 | 验收要求 |
| --- | --- |
| 首次保存 | 手输账号密码，服务端确认通过且无需首次改密后，系统才可提示保存。跳过保存或系统功能不可用时仍能登录。 |
| 返回登录后填充 | 显式退出清除应用会话及输入；用户聚焦登录框、选择系统建议并通过设备认证后回填两项，继续点「进入冒险」走服务端验证。 |
| 失败与中断 | 错误凭据、网络失败、首次改密、废弃的登录请求与返回离开均不能触发保存。取消填充之后可手输，保留原错误和重试体验。 |
| 范围 | 正式服务的登录表单启用。预览、普通隔离测试与正式包使用同一应用身份，默认关闭密码保险箱。改密、资料和答题维持现有输入行为。 |

API 26 直板机以一次性隔离账号验证错误口令、成功后系统保存、冷启续登、退出清空、两项回填和主动提交后重新登录。具体构建、测试范围及指纹和人脸方案见[登录自动填充与生物认证](login-autofill-and-biometrics-2026-11-20.md)。
