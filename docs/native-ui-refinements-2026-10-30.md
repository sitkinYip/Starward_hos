# 直板机底栏与账户菜单调整计划

记录日期：2026-10-30（Asia/Shanghai）。本文件记录用户新增要求、固定API26官方能力、版本来源和逐状态结果。**本文件保留冻结草案、首次真实编译失败、后续独立证据及最终菜单图标快照；各版本的构建、安装和功能验收分别记录。** 实际执行结果另见[任务1验证记录](slice-02-profile-validation.md)。首份底栏补丁保留原字节，第二份合并草案增加官方左右账户面板；首次编译问题另建 compiler-fix 草案，菜单图标双态另建 final-nav 草案，均不覆盖此前来源。不修改既有验收表的历史结果，不把 1a40 基础包的报告归给这些补丁。

本轮要求是：输入时底栏不随键盘顶起；四个底栏图标按 Web 使用未选中 regular、选中 fill；优先接入官方触摸流光及可能存在的松手选项切换；账户菜单如能直接使用官方能力保留材质并按头像位置从左右出现则接入，否则保留现有效果。固定预览账号属于隔离环境工作，不在这个 UI 补丁内。

当前final-nav HAP `6a5232af434e2fed8d6d56b50e25f7bf86b7cf24de22bd6523bdc79f23d5ad90` 的新主轮 `profile/device-native-ui-refinements.json` 已实际passed/count39，SHA `67f2c8d7a2deb0d2cd6f2bf42d7a1da50c6be1be01fad8755d292e245fa5e1ba`，绑定runtime-ui-final-nav六项与final-nav manifest `830e4aa0…`。本次driver为 `a90202ddf49f69d42538b2cc73c1e601981944c35b1340aff7e6e71fee6b00ad`；六项cleanup全true，真实profilePatch/passwordPost增量各0，旧UI检查未继承。覆盖正常登录、启程/护照及未开放入口保留原页、首页右/详情左官方面板的关闭/Back/可见蒙层与返回、主题/退出，以及昵称和密码键盘、草稿与Back行为。该主轮不保存资料、不改密、不入场答题。 独立 `profile/native-ui-root-visual-review.json` 为reviewed_static_with_explicit_limits，SHA `32725c37417962cbe7403c0a5c4b99f95c6f74fcab4b3dae74c133d8e37abb51`，严格绑定本轮39项报告。Root亲看13张原图：12张可观察；密码焦点1张App内容黑，不计像素、布局或主题目视通过。两主题底栏及菜单的regular/fill选中态、首页右/详情左最终位置、官方玻璃与原内容、昵称键盘下浮栏隐藏/完整保存及收起后草稿均已静态核实。静态图不证明跟手流光、松手跨项选择、入退场方向在运动中正确或中断/减少动画行为；松手选择由后续独立官方注入记录承接，其余动态范围继续单列。1a40的24图保持其基线，不替代本轮，也不反向改写旧报告。 官方注入松手选择的独立结果见下节；跟手光感/触感及入退场等动态未知。crop-cancel独立10项及两原图review已完成，见下节；媒体与旧环境精准清理已有独立通过报告，预览状态修复、Host、新包runtime六项与独立直接登录13项/3原图审阅已完成，可直接审查；服务运行依赖电脑/Docker/USB。

当前用户手验补充（2026-10-30）：用户在最终交付的 `c2fdc343…` 固定预览中，手动拖动浮栏启程↔护照并松手切换、打开头像侧栏，对“跟手光感、松手选中和侧栏进出方向是否符合预期”明确回复“符合预期”。来源见 `artifacts/validation/profile/native-ui-user-confirmation.json`。这三项从当前待验中移除；6a历史采集、静态及官方注入报告的原限制保留，不反向改写。此次没有新增自动化或Root动态目视，不扩展为触感、取消/中断、减少动画、双主题全覆盖、折叠、重启或主动改密通过。

## 基线与资料

- 固定 Studio 26.0.0.851、SDK 26.0.0.105、compile/target/min API26。本次只读核对其 SDK 声明和官方知识 MCP；未升级工具。
- Web 冻结提交为 `4b7d1a0a00051ac630e459b0fd6c074f821d7455`。本次核对前原仓库 clean，未修改原 Web 或后端。
- 草案准备阶段未改应用源码或 HAP；Root 后续已应用第二份并执行真实构建，其失败和修正见下文。补丁准备时 HAP 为 `1a40c0caffc46d64e0b81e9ccb92f2c7d6b69830bb73bf1f2ed5f02651a761cb`。基础包和独立超时变体的证据分别记录，不能被这些 UI 草案继承。
- 官方知识均先使用包含 API26 的查询搜索，再读取命中文档全文。SDK 接口见 `openharmony/ets/component/tabs.d.ts`、`tab_content.d.ts`、`common.d.ts`、`sidebar.d.ts`，以及 `api/@ohos.arkui.uiMaterial.d.ts`、`@ohos.arkui.StateManagement.d.ts`、`@ohos.window.d.ts`。文档解释行为，可编译与真机表现依各版本真实报告分别记录。

## 官方能力与边界

| 能力 | 固定声明 / 官方行为 | 当前决定 |
| --- | --- | --- |
| 浮动 TabBar | `barFloatingStyle` 自 26.0.0，Stage，`SystemCapability.ArkUI.ArkUI.Full`；需横向、底部、`barOverlap(true)`。配置含尺寸、边距、蒙层、操作手及材质，没有单独的跨项拖动选中开关。 | 保留现有官方 Tabs、BottomTabBarStyle 和输入事务。 |
| 光感交互 | `ImmersiveOptions.interactive`、`lightEffect` 自 26.0.0，Stage，ArkUI.Full，无新增权限。前者默认 false，承诺按压形变及松手恢复；后者有效对象开启触摸流光跟随。 | 仅底栏显式启用，并服从现有减少动画设置及材质支持/禁用判断。其他材质调用保持原有默认。 |
| TabBar 局部显隐 | `TabsOptions.barModifier` 自 API15，`CommonModifier` 自 API12，通用 `visibility` 自 API7。`CommonModifier` 动态更新在 V2 通过 `UIUtils.makeObserved`（API12，Stage，ArkUI.Full）观测。 | 隐藏实际 TabBar，保持 Tabs 与页面挂载；隐藏时撤销待提交选择。不能仅透明化留下命中区域。 |
| 键盘可用区 | 已有 `UIEnvWindowAvoidAreaInfoVP.keyboard` 的类型为 `window.UIEnvAvoidAreaVP`，自 API23，`SystemCapability.Window.SessionManager`；页面现有 `KeyboardAvoidMode.RESIZE` 保留。 | 依据真实可见且正面积的键盘避让矩形隐藏底栏，不用页面全屏尺寸推算 IME。 |
| 底栏图标 | `BottomTabBarStyle.iconStyle` 自 API12，只配置选中/未选中颜色；不会把 regular 的路径自动变为 fill。SVG 不设置内置 width/height，交给原生图标布局。 | 继续用官方 BottomTabBarStyle，以父批准的索引选择两组矢量。 |
| 官方侧边 Sheet | `SheetType.SIDE` 自 API20；官方文档限定窗口宽度至少 600vp 才支持。默认右入、镜像左入，不能按头像指定转场方向。手机窄窗口支持底部或全屏类型。 | 这个限制只适用于现有 Sheet 参数，不能扩大为所有官方弹层无法实现。第二草案改用下面的 PromptAction。 |
| SideBarContainer | `sideBarPosition` 自 API9，可左右布局；普通内容区不在通用沉浸材质生效范围。官方弹层和指定控件另有全页面材质支持。 | 本轮不采用这个普通侧栏容器，不添加自制模糊。 |
| PromptAction 官方 Dialog | `UIContext.getPromptAction().openCustomDialog(CustomDialogOptions)` 自 API12；alignment 在 BaseDialogOptions 自 API11、transition 自 API12；实际草案使用的 dialogTransition / maskTransition 自 API19，systemMaterial 自 26.0.0，Stage、ArkUI.Full，无新增权限。options-builder 重载保留官方容器，可组合左右对齐和官方 TransitionEffect。 | 第二合并草案使用官方 THICK 材质、实际头像位置和官方 move 转场，保留用户认可的材质；当前6a已独立验证左右最终位置、关闭、Back与原页返回；入退运动方向、中断和减少动画仍待专项观察。 |

官方来源：[Tabs](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-container-tabs)、[TabContent](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-container-tabcontent)、[沉浸材质通用能力](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-immersive-light-sense-common-capability)、[沉浸光感典型场景](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-immersive-light-sample)、[V1/V2 内置对象迁移](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-v1-v2-migration-inner-object)、[半模态转场](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-attributes-sheet-transition)、[SideBarContainer](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-container-sidebarcontainer)、[材质生效范围](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-immersive-light-sense-faq)、[UIContext PromptAction](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-uicontext-promptaction)、[PromptAction 对话框选项](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-promptaction)。

### 侧栏能力补查更正

最初调研仅核对现有 `bindSheet` 与 SideBarContainer，据此决定保留底部 Sheet。随后独立补查确认官方 PromptAction 的 options-builder Dialog 具有所需位置、材质和转场配置；用户已授权“能做出来就做”，因此第二合并草案采用该路径。此前 Sheet 的窄屏限制不是跳过官方 Dialog 的依据。

必须区分两个重载：`openCustomDialog(ComponentContent, BaseDialogOptions)` 在固定 SDK 中明确等同 customStyle=true，可能失去官方材质；第二草案使用返回 numeric dialog id 的 `openCustomDialog({ builder: () => ..., systemMaterial, alignment, dialogTransition, maskTransition, ... })`。`promptAction.CustomDialogOptions` 本身没有 customStyle 字段，不能移入 Controller 选项中的同名字段。

面板仍使用系统对话框背板、模态遮罩、按键关闭和官方转场，不模拟手势、模糊或玻璃。宽高遵循该容器的系统限制与真实避让区，不把它称为没有安全区限制的全屏 Web 侧栏。开启方向取实际头像中心相对实际窗口中线的位置，首页和详情共用头像入口，不硬编码页面方向。减少动画、重复打开、宿主消失、退出以及异步打开完成后已失效的请求由封装分别处理；源码设计不是这些竞态已经通过实测的证明。

### 跨页签拖动需要单独观察

官方文档对流光跟随和按压形变的承诺，不证明拖到另一页签后松手一定产生路由选择。`scrollable(false)` 只关闭内容页翻页，不能为启用底栏流光而打开它。`barModifier` 文档中的底部样式不支持拖拽位于通用属性语境，也不能单独当作触摸滑选一定不存在的证明。

`onContentWillChange` 可能由内容滑动、控制器、索引更新、点击和键盘引发；`onChange` 也包含程序更新。官方未约定这两个回调、`onTabBarClick` 与通用 Touch Up 的相互顺序。因此先保留当前仅实际 TabBar Touch 开始输入事务、最终原生索引排队提交、父路由再次门控的实现，不移除其为已确认跳回首页问题设置的保护，不放宽为接受任意迟到回调。

补丁只先开启原生材质交互。随后以真机记录按下、跨项移动、松手、取消时的官方回调，核对最后索引和实际页面。若平台不产生跨项选择事件，不能通过自己按坐标选项和自制光效将其记为官方能力已接入；该项保持未支持或待确认。

## 补丁内容

首份待审补丁位于 gitignore 的 `artifacts/private/ui-refinements.patch`（SHA `904bdeda5544355ba7f383cc257de69aae7b6f86ec3e44f90d816070f8d55fc2`），保留原字节和原 manifest。第二份在新的私有 proposed 目录叠加官方侧面板，使用独立 `artifacts/private/ui-refinements-sidepanel-draft-20261030T025200018012Z/manifest.json` 及其 rootRelativePatch，不覆盖首份；最终摘要以 Root 审阅冻结的该清单为准。统一 diff 路径为仓库相对路径，可以在完成不可变基线验收后由 Root 审阅应用。准备阶段仅复制到私有临时目录编辑和生成 diff；研究任务不改当前 `entry/src/main` 或 HAP。

第二份冻结清单 SHA 为 `68760d680be38cfc1c9ce5dad942b60eff6197f2c638dcccac7f096582a8b7f4`，同目录 `merged.patch` SHA 为 `217a1892b041e623219f5704f77ffdc015e66dfbe3003116933e6ed281834677`，唯一新增的 SidePanel 源 SHA 为 `dc4236aa5ba376b79cd9d16ff8110040dce86c7f2a6c1b100119b805728a4d8e`。其宽度采用实际窗口扣除横向安全区后再减 48vp、最多 400vp，避免占满默认双侧 16vp 边距而无法区分左右对齐。以上为准备来源，不是该面板已编译或真机通过的证据。

1. `StarwardBottomTabs` 新增 `hideBar` 和 `materialInteractionEnabled` 输入。稳定 CommonModifier 使用 V2 可观察包装；键盘状态改变时仅设 TabBar 的 `Visibility.None/Visible`。进入隐藏状态即清理 pending、timer 和输入接受状态；定时提交前再查显隐。保留现有路由守卫、BottomTabBarStyle、材质、命中和系统动画。
2. `Index` 继续使用同一个 Tabs 和 ProfilePage，不以条件渲染重建页面。真实 IME 占用视口时传入 hideBar，滚动末尾余量从浮栏的 `84 + safeBottom` 改为普通内容余量 20vp，键盘消失后恢复。现有 RESIZE 和返回时先收键盘的行为不变。该判断覆盖有实际避让面积的键盘；真正悬浮且不占系统避让区的 IME 仍须单独观察，不预先宣称已覆盖。
3. `StarwardMaterial.create` 新增可选交互参数；未传时保留其他组件原默认，仅底栏传入 `!StarwardMotion.reduced`。减少动画时对底栏显式关闭形变和流光，未减少时显式启用。能力不支持或系统禁用时沿用真实降级。没有自制流光、手势、转场或业务动画回调。
4. 新增 8 个导航 SVG，底栏按父 `selectedIndex` 选择 regular / fill；最终菜单草案在原四个入口复用同一组资源，按原背景及无障碍选中条件 `paths.size() === 0 && mainIndex === index` 选择 regular / fill。保留菜单文案、顺序、尺寸、间距与路由事件；未开放的收藏与来信仍保持现有未开放反馈，不因资源准备而声称业务页完成。
5. 第二合并草案仅额外增加 `ui/StarwardSidePanel.ets`，Index 接入该官方面板。保留原菜单内容顺序、menu-* / theme-* / logout 等业务节点；使用 `account-side-panel`、`account-close`、`account-panel-title` 和 `account-menu-scroll` 观察面板、原生关闭动作、标题与内容滚动区。保留头像/退出/路由状态所有权及原生 Back 语义，不更改业务层。

| 正式 Web 图标 | 补丁新增资源前缀 | 两个权重 |
| --- | --- | --- |
| CompassIcon | `icon_nav_compass_` | regular / fill |
| SparkleIcon | `icon_nav_sparkle_` | regular / fill |
| EnvelopeSimpleIcon | `icon_nav_envelope_` | regular / fill |
| IdentificationCardIcon | `icon_nav_passport_` | regular / fill |

矢量路径来自只读 Web 依赖 `@phosphor-icons/react` 2.1.10 的 `dist/defs/*.es.js`，仅提取相应权重的 path，不迁入 React 或浏览器依赖。每个 SVG 记录许可位置。现有 [MIT 许可](../licenses/Phosphor-Icons-LICENSE.txt) 及随包的 `entry/src/main/resources/rawfile/licenses/Phosphor-Icons-LICENSE.txt` 均保留；两份字节 SHA-256 为 `6918b72504641180600cbbd4a86b0dfa9dfccf788775694325b71b9a029f6eb4`，与来源许可正文一致。每个来源文件、SVG 与当前应用原始文件摘要保存在私有草案清单，不包含账号或签名信息。

## 首次真实编译失败与独立修正快照

Root 应用第二份冻结 merged 草案后，通过官方 `scripts/hm.sh run` 真实执行 ArkTS/Hvigor，返回唯一错误 `10505001`：`StarwardSidePanel` 的 `@Param enabled: boolean` 覆盖了 `CustomComponent.enabled(value: boolean)` 方法。私有日志为 `artifacts/private/profile-validation/install-ui-refinements-20261030.log`。此前 MCP `check` 虽返回无诊断，未发现这个继承名称冲突；实际固定编译器的失败结果具有权威性，不能写成已构建通过。

Root 在实际源码将该所有权字段改为 `ownerActive`，同步 `@Param`、`@Monitor`、控制器引用和 Index 传参 key；其它系统 `.enabled(...)` 不变。新的 `artifacts/private/ui-refinements-compiler-fix-draft-20261030T030900474474Z/manifest.json` 只快照这些已修字节，再从固定 1a40 源档案生成完整 `merged.patch`，供后续新包验收绑定。原第二份 manifest、补丁、MCP 结果和离线报告保持原字节，不改写失败来源。业务及平台的 31 个文件仍与原基线相同，新增 UI 仍仅为 SidePanel；验证脚本不扩大业务源白名单。

修正 manifest SHA 为 `927ae25e29befcaee4bf5cfe3465ea265b8e60caf72e2e56f1b8c654b17c61b6`，该目录 `merged.patch` SHA 为 `27c1a323cbfe6c000f677d90e6a60f44a0e452ce1921d33d0231b606befb0b4a`，SidePanel SHA 为 `84d2a8858a568f31bf480c2f6fe2746e2c93b8466fbb945fb5edc4232ee45f16`；新的离线报告为同目录 `controller-check.json`（SHA `e259a181db33a4ea111b532f651eee45f2991f871752a3c533b31ed8b2ec5b39`）。独立只读复核确认补丁只修改 3 个旧 UI 源、新增 1 个 UI 源和 8 个图标，逆向重建的旧源恰好回到固定 1a40 摘要。

修正快照中的控制器夹具已同步 `ownerActive`，固定 Studio Node 再执行真实提取的控制器方法，10 个离线用例通过；内存中移除异步失败守卫的故障变异仍被两个竞态用例发现。原生 Dialog、生命周期与渲染均在这个离线测试中模拟，因此该结果只证明控制器回归，不能替代 ArkTS/Hvigor、新包安装、材质、左右动效、IME、HTTPS 或真机 UI 验收。修正包实际构建和设备结果由 Root 独立执行、另行记录，不以此处快照推定成功。

## 最终菜单图标来源与验收边界

Root 随后在 Index 的 `menuDestination` 增加 `normalIcon` / `selectedIcon` 两个资源参数，四个调用复用同一组 `icon_nav_*_regular/fill`；资源选择直接沿用现有背景和无障碍的选中条件。该增量只改 Index 的图标入参和显示资源，SidePanel、其它源码、8 个 SVG 字节及许可均不变，也没有布局、文案、菜单顺序或业务行为变更。

最终快照为 `artifacts/private/ui-refinements-final-nav-draft-20261030T033123997976Z/manifest.json`，同目录提供从固定 1a40 基线生成的完整 `merged.patch`。清单 SHA 为 `830e4aa03223c20714f9a9bcc65cb7aa7039301d81484ad15cc2cc90aa4707bd`，补丁 SHA 为 `4b0cf5bbf0a37398181ca30ad5bc9d38cc121b99c720c39d92d6308c3fc5453d`，Index SHA 为 `792715a46b53539abdf961f1084b1cb4b0d6514bb4af15a5c95eba5c23e4d73d`。验证脚本在最终源码上必须改用此清单；旧 compiler-fix 清单绑定旧 Index，不能用于新包。31 个业务及平台源仍严格等于基线，唯一新增 UI 仍为 SidePanel。其 SHA 仍为 `84d2a8858a568f31bf480c2f6fe2746e2c93b8466fbb945fb5edc4232ee45f16`，因此仅按该源摘要引用此前实际通过的 10 个离线控制器用例与变异结果，不重新声称执行，也不继承任何旧 UI 验收。

前一 compiler-fix 包 `193b1e973c35ed1d893de32af4b3e75be30d0daca457d76b26e502505ba15fd8` 已由 Root 真实编译、签名安装，运行 72 个业务测试、lint 零错误及新包 6 项 runtime 检查。该包首次 UI 主 run 完成 10 项后因 CLI 前台瞬态识别中断，保留 incomplete；原始记录停在导航收尾，不能解释为头像面板打开失败。Root 之后用真实头像中心独立点击，bundle 范围原始布局出现四个面板 ID，并亲看 `artifacts/private/native-ui-refinements/panel-probe-20261030/panel-light-right.png`，确认浅色右侧浮动面板保留官方玻璃和内容 Scroll。这是该包的独立观察，不是其完整 UI 主 run 通过，也不归入 final-nav 新包结果。

最终菜单资源的深浅主题和选中双态已由本轮独立静态报告核对，当前39项结果单列；先前失败记录、旧清单与独立观察不改写为通过。旧193b/6a的incomplete10、首aa失败的incomplete0，以及在旧IME几何门禁中断的incomplete21均独立保留，完成cleanup不改功能状态。count0归档 `profile/attempts/device-native-ui-refinements-20261030T044247730768Z.json` SHA52d9a5e6…；count21归档 `profile/attempts/device-native-ui-refinements-20261030T050029215328Z.json` SHA `b328a858ad8cecbf657a4675466268b7feee1cd7f1411be99eb6caae96ec45e9`，二者六cleanup全true。USB重接后只恢复精确自有reverse且严格Host200，`profile/network-resume-reconnect-20261030.json` SHA c10b847b…保留该恢复事实；新的A902 run独立开始，不继承旧checks。

## 逐状态实际结果与待验范围

| 项目 | 必须观察的结果 | 当前状态 |
| --- | --- | --- |
| 构建与静态检查 | 固定配套运行时下ArkTS/Hvigor、codelinter及真实报告范围。 | 6a真实构建签名安装、72/72测试和runtime6通过；lint零缺陷，独立原日志35输入路径解释见lint-native-evidence；不是新lint |
| 昵称 IME | 键盘期间隐藏实际浮栏及命中，保留实例/草稿，主要动作可达，收起后恢复。 | 本手机6a主轮通过；实际AppRoot RESIZE、完整52vp保存、草稿恢复和原图静态均核实 |
| 改密 IME | 三字段与主要动作可达；Back先收键盘并保留草稿，离开护照清字段。 | 本手机6a原生节点/真实可用区/52vp与Back通过；该焦点截图黑，不计像素或主题目视通过 |
| 导航回归 | 启程/护照切换，收藏/来信保留原页，菜单和返回关系正常。 | 当前39项范围已通过；旧incomplete10/21/0独立保留，非触摸/读屏路径仍单列 |
| 图标 | 底栏及四菜单regular/fill，两主题选中态清晰。 | Root按6a新原图独立静态核实，未由颜色或源码推定动态通过 |
| 官方光感 | 材质支持时跟手、松手恢复；降级和减少动画按实际记录。 | 官方配置已接入，静态玻璃可见；c2fd交付预览的跟手光感与松手选中获用户手验确认，降级/触感/取消/中断/减少动画仍未验 |
| 拖动松手选择 | 实际跨项移动，以原生事件与落定页面判断；取消/中断另验，不自制坐标选择。 | 本手机官方注入swipe/预长按drag正反4次释放选中已核，未补目标点击；人工手感、取消/中断和平台全支持不宣称 |
| 账户菜单 | 实际头像侧对齐、关闭/Back/蒙层/滚动/主题/退出和返回关系。 | 6a的39项及左右最终静态位置/玻璃已核；c2fd交付预览的侧栏进出方向另获用户手验确认，中断/减少动画仍未验 |

以上聚焦直板机及当前业务链路。折叠、悬停、分栏和窗口专项仍遵循主体业务完成后逐项验证的既定顺序。

新面板的实际窗口、头像与最终背板矩形会分别保留。原生容器可能保留系统边距，静态最终位置不能证明进入方向；原生 move 入场/退出方向、材质和动画中断需要 Root 查看实际过程，不能因源码选择了 START/END 或一张终态截图就记为方向动效通过。

## 独立官方手势观察（已执行）

独立 `profile/native-ui-refinements-drag.json` 保持status=observed、stage=gesture-finished-root-review-pending，SHA `7918b8195b740f9f519124645bae43209fbb2720cd759c992ab9ea5594db4c70`，绑定同6a/runtime/A902。6个实际阶段正常退出，swipe与原生预长按drag各正反方向共4次观察均实际落到目标启程/护照，原生最终索引0/3并记录click→will→intent→param→change；未自制产品手势，也未补点目标。六cleanup全true，资料/改密写增量各0。Root另亲看4张终态原图，选中fill与目的地一致；独立 `profile/native-ui-root-gesture-review.json` 为automated_native_release_selection_verified，SHA `7fa8311e8715adad8660624d4eee76af41f167d134004fa7de22612a8353f731`，verifiedOutcomeCount=4，review自身newCommandsExecuted=0。结论仅为固定API26当前手机/6a的官方注入松手选中结果，不是人工操作通过、所有平台能力或回调总顺序保证；跟手移动光感、触感、未抬手/取消/中断、减少动画和入退场运动仍未目视或专项验收。

## 当前宿主裁剪预览取消回归（已执行）

当前6a独立 `profile/native-ui-crop-cancel-regression.json` 实际passed/count10，SHA `c9f8bf03aa11d5bda6dad1a27da65bdc1cf1ab00cfba1ee310e17bcce7f86fcb`，绑定39项主轮67f2…、同HAP/runtime和私有助手adf8dca9…。实际exact自有PNG选择并点击系统Complete，原生方形预览无错误，随后只取消：无pending、昵称与头像经新HTTPS读取保持不变；8项cleanup全true，资料/改密写增量0。Root亲看两张新原图，独立 `profile/native-ui-crop-cancel-root-review.json` 为reviewed，SHA `7ed3eea195b6e2837df80d11888120e73de245137077ed7240fc6b4082e199ab`；源采集报告visualReview=pending保持原样，由该独立review承接目视。范围只为当前SidePanel宿主兼容的真实Picker→裁剪预览→cancel，不确认、不上传，不扩写全部裁剪控件安全区或6a重新跑过1a40完整上传链。恢复follow-system仅记录动作/控件和无错误，选中辅助属性不可观测，不作动态跟随系统主题通过。

## 当前驱动与原lint证据

驱动的11项AST隔离检查已passed，仅验证几何拒绝边界及重复cleanup先清旧标志/写入增量：私有 `artifacts/private/ui-resize-viewport-driver-draft-20261030T045823893635Z/offline-guard-check.json` SHA `705ebfa9a47604681d0e1afbaa5d19473b23cdb25803b5bdeeb3f87f8143af1a`。它没有设备/网络/服务或业务执行，不并入39项或业务完成度。

`profile/lint-native-evidence.json`（SHA `df12779b2c2214c13ae78e5918d2454513d0ed9982164bcddba53bb7df534ca2`）解释原11:31固定工具链执行，不是新lint或新增验收：原 `lint.json` 仍0 issues/filesChecked=0。Studio先过滤无缺陷文件，CLI统计剩余报告路径，因此该字段不是输入扫描数；原ArkPerf FileCount35及HPAuditor的35条唯一路径与当前35文件集合一致，独立证明当时处理这些输入路径。报告中的当前源码SHA仅绑定本次说明时的字节，不作当时逐文件SHA的回溯证明。原日志“文件不存在”定位为扫描后临时规则文件unlink ENOENT，具体缺哪一个未记；默认配置按官方分流跳过ESLint，HPA的12项安全规则flag启用，而ArkPerf独立registry的InvalidRule不等于全局规则失效。零缺陷不作安全认证或逐规则覆盖证明；未改配置、旧日志或原结果，也未重跑。

## 准备结果

补丁静态路径检查 `git apply --check artifacts/private/ui-refinements.patch` 已通过，仅证明补丁可应用。8 个 SVG 已按 XML 解析并与来源权重路径逐项核对，MIT 许可正文已核对。这些是原准备阶段结果；Root 后续实际应用与编译失败已单列。以上均属于准备检查，不能替代本补丁的 ArkTS 构建、安装、UI 或功能验收。

## 验证脚本与执行边界

`scripts/device-native-ui-refinements.py` 是本补丁的新验证入口，已经过 Python 语法、帮助输出和纯几何/显隐辅助函数的离线检查。193b 包的首次真实 run 中断与后续独立观察已单列，后续新包须重新运行，不继承其检查数。先用官方 `scripts/hm.sh run` 构建安装新包，再单独取得实际六项通过的 runtime，不能拿基础包 `runtime-09.json` 替代新包证据。

运行时显式传入 `--runtime-report <新包报告>` 和 `--patch-manifest <对应私有草案manifest.json>`；菜单双态最终源码必须指向独立 final-nav manifest，旧 compiler-fix 及第二份 manifest 的源摘要会拒绝新的当前 Index。默认隔离超时为 2000ms；若新 UI 包明确保留独立 15000ms 配置，必须额外传入 `--expected-timeout-ms 15000`，不会静默混用。该脚本只允许原始随机生成的 S2 隔离玩家，旧 core/S2 和私有 owner 回执仅用来核对身份代次及当前密码 key，不继承旧 HAP 的 UI 通过结果。新旧业务层源码、3 个提议 UI 文件、8 个包内 SVG、CA 及配置均核对摘要；`newUiSources` 仅允许明确声明唯一的 `StarwardSidePanel.ets`，其当前源、私有 proposed 源和 SHA 必须完全相同，其余业务源仍固定为 base。

| 阶段 | 操作与结果边界 |
| --- | --- |
| `run` | 从已存在的空登录开始，核对真实 HTTPS 身份，重新执行导航、昵称与密码 IME、完整 52vp 动作、草稿和 Back；合并草案再测主页/只读详情的实际头像方向、面板原生关闭/Back/安全可见遮罩点击及返回关系。抓取深浅主题请求后的主页/资料四原图及新面板原图。恢复跟随系统、显式退出、清空登录并确认零资料/密码写入。报告为 `profile/device-native-ui-refinements.json`；本轮39项已通过，独立静态审阅另见native-ui-root-visual-review，动态不由此计通过。 |
| `drag-begin` | 要求本次新包的 `run` 已通过且完成清理，重新登录，建立独立手势观察会话。 |
| `drag --direction home-to-profile` / `profile-to-home`，配合 `--gesture-kind swipe` 或 `drag` | 正常页签点击先独立建立起始页，再于真实原生栏内分别注入官方swipe或原生默认预长按drag，保存封装回调及实际落定页；后者预长按持续时间未实测。不补点目标，观察不要求必定切换，不由注入结果判定人工手感或平台全支持。本轮四次落定结果另由独立Root复核记录。 |
| `drag-finish` | 结束观察并恢复主题、退出和核对零写入；没有执行拖动则如实记为未执行。独立报告为 `profile/native-ui-refinements-drag.json`。 |
| `cleanup` / `drag-cleanup` | 仅对同一新包中途失败的相应会话重试受守卫清理，保留 incomplete；不能用普通 cleanup 改写已通过的主报告。 |

IME测量保留官方窗口清单及各根，优先接受唯一有效的小IME根；根全屏或不明确时仍拒作IME高度，只在无IME实测基准、同页唯一AppRoot同原点/宽度且实际缩短时记录可用App视口。昵称与密码均观察到命名IME窗口，但两个IME根均为全屏矩形，已明确拒作键盘几何。可用区取同页无IME基准AppRoot `[0,132,1320,2848]` 与实际RESIZE后的根：昵称 `[0,132,1320,1788]`、密码 `[0,132,1320,1606]`，保持原点/宽度且真实缩短；报告的imeWindowBoundsPx/imeWindowHeightVp为null，缩短量不称IME高度。原始UiTest核实浮栏无可见或命中目标，完整52vp动作位于真实可用区；收键盘后浮栏四项恢复，昵称草稿及三密码保留，后续离开护照清密码，均无资料/改密写。隐藏与恢复均读取 bundle 范围原始 UiTest 属性：恢复要求原生栏和四项真实可见、启用且可点击，不能仅因 CLI 仍列出旧 ID 就判通过。隐藏状态不向键盘区域盲点，检查的是实际暴露的原生命中目标和 `Visibility.None` 语义；手动交互及原图审阅仍由 Root 完成。

所有 UI 原图、原始属性、窗口根信息和日志仅写入本项目 private 目录，权限 600；凭据明文不进入这些文件或公开报告。公开报告仅保留摘要、方法、矩形和范围。任何独立再执行都需显式 `--new-attempt`，保留旧报告及各自私有证据目录。


## 环境收尾的独立证据

本轮旧一次性环境清理已取得三份独立实际报告：`profile/owned-avatar-media-cleanup.json` passed（SHA `7ed276e89d9009f876cf02977b3866d4d08801e8fdc047f86f81389fe5ab9f7f`），仅5个自有测试媒体逐个新读回SHA核验后删除exact URI及各2个精确临时导出，查询均0；`profile/isolated-services-cleanup-final-complete.json` passed/9项（SHA `c4962d816368ed43fda23c8f8b462c2d318a27faf8c91b87447e0b73408ddd55`），旧TLS/gate/backend进程、监听、reverse、一次性容器/DB及运行凭据状态均已消失，其他映射保持不变；`profile/isolated-private-material-cleanup-final.json` passed（SHA `0f7ac7ad37a9ef4b073350f21f9fb0daebdf26542169c7d7b61f1f408a6f0d5a`），8份旧TLS备份材料逐SHA删除，只留非secret清单/恢复日志，持久预览目录之外的旧私钥文件为0。先前三份stop preflight均incomplete、checks为空且未请求官方stop，历史保留；最终服务报告自身不宣称备份已清，由后一份材料报告承接。没有宽泛Docker/目录删除或系统信任/签名修改，固定预览DB/CA/登录文件独立保留。

固定预览已完成真实seed、正式首次改密及显式状态修复，后续直接登录实测已通过，账号已可供审查。首次因Docker stdin缺少`-i`失败，经业务写入0核验后显式恢复prepared；第二次seed和改密成功后，PB0.40.1拒绝删除唯一superuser，保留initializing而未重放。随后 `profile/preview-initialization-reconcile.json` 实际passed，SHA `75ba302cacd5bf9fa5fca9764b92542bd8afdb961efdf12d57db9228724df5c3`：官方CLI对同一bootstrap身份换成不保留的随机密码，password hash/tokenKey均已变化，27个game表逐值与SHA一致、玩家口令/CA不变、seedReplayed=false，核验后才标complete并补回原IDs。最终runner `61059c59de2ec4fc964ee01566557dca7e31fc1535d19ae0559529f6897b0460` 的唯一记录退役及镜像immutableID/逻辑tag/arm64校验已静态复核。`profile/preview-environment.json` 已取得host_ready_native_pending（SHA `87b37b96a5f15571577b21c6d4edcd33cd26acd9f3161a205233c6bf6d7b517c`）：正式玩家直接登录verified_direct_login，独立CA可信200、不可信及错误主机名均拒绝，不开放玩家故障/重置接口；该原报告保持Host范围。新预览HAP `c2fdc34356a6176953fac806157b7c82ac513345575f8368f95524cea8b7408b` 已经官方run构建签名安装，`profile/runtime-preview-final.json` 六项实际passed（SHA `77f6f84e2894cc376594a62afc02dc43af54559bc739fd2584eb0c08612d9527`），包括真机API可信CA接受及不可信/错误主机名TLS_ERROR、系统区透明和深浅内容色。独立 `profile/runtime-preview-freshness.json` passed（SHA `eff6a1351013ebb908bebabbb8062318a0acfa7b3c48fe702d3732143c6860a2`），以当前自有进程的7条原始记录核window/material/TLS/双主题与原报告相同，不保存设备/进程标识，不改原runtime。新预览包的 `profile/preview-native-smoke.json` 已实际passed/13项（SHA `c63aed805a9c218a0589366a623fe91a8d0bfd5b9acb2da16315978307054751`）：固定普通账号从空登录直接进首页，真实四类场次、权威资料/只读账号、菜单Back、显式退出空输入及第二次直接登录均已核；四项收尾全true，第二次会话有意留在已认证首页供用户审查。独立 `profile/preview-native-root-review.json` 为reviewed_static（SHA `467dcc5b64f2a1b70b14900dfc96638e75742330adece9dcb7d29ef068d36cff`），Root逐SHA亲看3张原图，已停止手机自动化。此13项只认证/读取/导航/退出，不重跑资料、头像或密码写链，也没有服务端写台账计数结论。固定账号直接预览现已可交付，服务收口时仍运行且Host直接登录再次验证；需电脑保持唤醒、Docker运行、手机USB连接。独立 `profile/preview-package-source-binding.json` 为offline_binding_verified（SHA `19cf9511b823b3e4d19e1327dadef825ed068eda74ab7443cd3da3cade8bede8`）：35份源、8个导航SVG和包内ABC与6a逐字节相同；48个ZIP成员集合相同，45个内容字节相同，实际仅独立CA、完整1226条symbolMap记录重排及integration JSON空白/fontScale `1.0`→`1` 序列化变化，JSON值/顺序相同且timeout均15000。新signed HAP独立600归档，旧包/报告未改；不解析或归因ZIP之外的签名块。它只作离线来源绑定，不继承6a主轮39项为新包通过。停止/重启持久保留及用户改密后的行为也未因此完成实测。
