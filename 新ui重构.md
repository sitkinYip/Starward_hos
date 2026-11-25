# 任务：将 Starward 鸿蒙原生端（starward_hm）整体重构至「极光玻璃 v2（Aurora Glass v2）」设计系统

## 一、背景与只读参考基线

`questions-web` 已完成从旧版（日间墨绿 / 夜间古金 / 侧栏抽屉 / 魔法阵加载）到 **极光玻璃 v2（Aurora Glass v2）** 的完整视觉、布局与交互重构。本次任务是在本仓库（`/Users/sitkin/my_code/starward_hm`）将鸿蒙原生端的 UI、动效与交互升级对齐到新版 Web 设计基线，同时**充分使用华为官方 ArkUI / UIDesignKit 自带组件与鸿蒙原生沉浸光感能力**，打造高质感原生体验。

**只读参考资料（严禁修改其他仓库）**：

1. 新版设计规范：`/Users/sitkin/my_code/questions-web/docs/design-system-aurora-glass-v2.md`
2. 新版 UI 约束 Skill：`/Users/sitkin/my_code/questions-web/.agents/skills/starward-aurora-glass-ui/SKILL.md`
3. 颜色与材质令牌源：`/Users/sitkin/my_code/questions-web/src/styles/foundation/tokens.css`
4. 品牌图标资源：`/Users/sitkin/my_code/questions-web/public/branding/starward-icon-*.png` 与 `starward-mark-*.png`
5. 可运行交互参照：可在 Web 仓库查看对应正式组件源码，或通过其本地全链路 Mock 沙盒（`pnpm dev:mock`）对照每一页与每个动效状态。

---

## 二、本次正式批准的规范变更（先更新 ADR 与 `starward-ui-parity`，再写代码）

以下条目属于**用户已明确确认的产品与视觉升级**，覆盖 2026-11-04 旧版基线中的冲突约束；请在开工前先更新 `docs/architecture-decisions.md`、`docs/feature-acceptance-matrix.md` 与 `.agents/skills/starward-ui-parity/SKILL.md`：

1. **主题色与字体切换**：
   - 废弃旧版日间墨绿（`#187B69`）、夜间古金（`#D4BC7D`）主色及来信旧紫色（`journey_notification_color.json`），全面切换至品牌冰蓝极光色板：
     - Dark（深空）：`canvas #070A12`、`surface_raised #141D34`、`text_strong #EEF3FF`、`text #DCE6FA`、`muted #8A94AD`、`accent #8DB4FF`、`accent_strong #B5D0FF`、`accent_text #9EC0FF`、`on_accent #07101F`、`reward #E3C27A`、`success #7CD4C0`、`danger #E28B8B`
     - Light（雾白高对比）：`canvas #F3F6FB`、`surface_raised #FFFFFF`、`text_strong #0E1424`、`text #1B253A`、`muted #5A6478`、`accent #2F6BDB`、`accent_strong #1F56BE`、`accent_text #2258BF`、`on_accent #FFFFFF`、`reward #B5832A`、`success #1F8A70`、`danger #C94A54`
   - 常规业务界面统一采用系统原生无衬线字体（HarmonyOS Sans SC）并开启等宽数字（`fontFeature: "'tnum' 1"`）；不再把 `NotoSerifSC` 用在普通标题/按钮上（`Letter` / `Bless` 沉浸剧情页保持自身阅读氛围，不强行破坏）。
   - `--color-reward` 荣耀金**严格仅用于奖品/成就/升级礼赞/终章徽章**，严禁回流到普通按钮、导航、提示条或 BGM 控件。
   - 清理全部装饰性英文 eyebrow（如 `CHAPTER`、`QUEST SESSION`、`UNLOCKED ARCHIVE`、`IMPORTANT SIGNAL`、`RANK`）与冗余副标题。
2. **移除旧侧栏抽屉（`StarwardSidePanel`）**：
   - 不再保留头像弹出的左右侧栏抽屉。
   - 仅「启程」页顶部展示双行身份极光顶栏（左：带经验进度环的头像 + 大字昵称 + 小字 `Lv.x · 等级名` + 轻右箭头，点击直达「护照」页；右：`44vp` 星标玻璃徽章承接 5 连击版本彩蛋「星图档案」）。
   - 「收藏」「来信」「护照」页从安全区大标题起排；底部保留 4 键官方悬浮底栏（启程 / 收藏 / 来信 / 护照）。
3. **护照与设置合并重组（同时保留鸿蒙原生专属能力）**：
   - 护照页改为清爽设置页结构：上方居中大头像星环身份卡（头像 + 昵称 + `Lv.x · EXP / next EXP` + 三列统计 `已解开 / 场次 / 收藏`），下方分组设置卡（`修改资料`、`修改密码`、`外观`、**保留鸿蒙原生「旅途通知与订阅设置」入口**、`退出登录`），各子项用官方 `bindSheet` 底部半模态 Sheet（或受控子页）承接，不破坏表单草稿、独立头像裁剪弹窗与退出清理。
4. **答题页布局与顶栏显隐规则升级**：
   - **悬浮顶栏**：改为 L2 沉浸玻璃胶囊顶栏，左返回、中场次标题、右对称空位；交互升级为**下滑自动隐藏、轻微上滑立即展示**（页顶与输入聚焦常显，系统状态栏始终保留）。
   - **进度导航**：改为顶栏下方居中的**四角星状态点**（已完成/当前/待解，可点击切题，保留读屏文本）。
   - **纯净题卡与唯一提示入口**：24vp 圆角玻璃题卡，顶行仅展示 `第 N 题` + 右上角**唯一灯泡图标按钮**（点击弹出官方 `bindSheet` 提示面板，彻底删除题干下方重复的提示按钮）；排版固定为**题干文字在上、16vp 圆角透明底配图在下**。
   - **底部独立悬浮作答栏**：完全脱离题卡固定在视口底部（L2 沉浸玻璃材质），并让 `StarwardBgmControl`、`StarwardJourneyLauncher`、`StarwardCombinationLauncher` 默认停靠在作答栏上方安全区避免遮挡：
     - 填空题：胶囊 `TextInput` + 50vp 发光冰蓝圆形 `→` 提交钮。
     - 选择题：**悬浮折叠选择栏**（默认收起显示「选择答案」或已选序号徽章+文案 + 右侧提交钮；点击弹出自适应高度 L2 沉浸玻璃选项浮层 / `bindSheet`，常规选项完整展示无滚动条、超出可用高度上限再内部滚动；选完自动收起；**已作答/只读态仍可点开只读查看全部选项与选项图/视频，但 `Radio` 禁用不可改选**；修复旧 `StarwardChoiceOption` 选中态右偏 `6vp` 导致的右侧凸出，改为原地微弹对齐）。
5. **星环加载页与登录页动态星环**：
   - 废弃旧版 `StarwardAtlas` 魔法阵加载图形，抽离共享矢量组件 `StarwardStarRingEmblem`（四芒星 + `-14°` 前后纵深双弧斜环 + 外圈流光公转星点 + 反向内虚轨），同时用于全屏加载页与登录页主视觉（登录页舒缓公转，保持 1:1 正方形且键盘/帮助展开不偏移）。
6. **答对星芒爆发与「星穹加冕」升级特效**：
   - 新增无阻断弹窗时的答对星芒爆发覆盖层（四芒星蓄力回弹 + 双星环 + 射线 + `Particle` + `+XX EXP` 递增落位 + `下一题 / 继续`）。
   - 重构 `StarwardRankUpDialog`：废弃旧双翼/四角/古金边框，改为冰蓝极光 × 荣耀暖金「星穹加冕」礼赞（双冲击波 + 12 交错射线 + `Particle` 放射星尘 + 三层立体星环与八芒星冕 + 深空蓝宝石/亮白星核 `Lv.x` 徽章 + 荣耀金斜向扫光 + `等级突破` 胶囊 + `继续冒险` 主按钮）。

---

## 三、华为官方 ArkUI 组件与鸿蒙原生沉浸光感硬约束（核心要求）

**所有界面容器、材质、光感、分段、弹层、刷新、反馈、动画，必须优先采用固定 API 26 SDK 下的华为官方 ArkUI / `@kit.UIDesignKit` 原生能力并薄封装在 `entry/src/main/ets/ui/` 中。**

写代码前必须先用官方知识 MCP / `devecocli` 核对 API 26 文档与本机 SDK `.d.ts` 声明（`@since`、SysCap、权限与生命周期），禁止猜测 API，禁止自制伪模糊、假手势或 WebView 替代：

| 业务模块 / 层级                                | 首选官方 ArkUI / UIDesignKit 能力                                                                                                                                                               | 沉浸光感与降级约束                                                                                                                                     |
| ---------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **系统栏与全屏沉浸（L0）**                     | 窗口全屏 + 透明系统栏 + `expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])`                                                                                        | 背景延伸到边缘，交互内容严格避让真实安全区；严禁实心黑/白占位块，不隐藏系统栏                                                                          |
| **底部悬浮主导航（L2）**                       | 复用并升级 `StarwardBottomTabs`：`HdsTabs` + `barFloatingStyle` + `barOverlap(true)` + `hdsMaterial.MaterialType.IMMERSIVE` + `MaterialLevel.ADAPTIVE` + `lightColor: $r('app.color.accent')`   | 保留触摸冰蓝跟手流光、拖动松手切换、regular/fill 图标与键盘弹出自动隐藏浮栏                                                                            |
| **顶部悬浮胶囊与页头（L2）**                   | `Navigation` / `NavPathStack` + `StarwardMaterial`（`uiMaterial.ImmersiveMaterial`、`ImmersiveStyle.ULTRA_THIN / THIN`、`interactive: true`、`lightEffect: { color: $r('app.color.accent') }`） | 经 `uiMaterial.isImmersiveMaterialSupported()` 与 `getMaterialInfo().state` 门控；不支持或关闭材质时回退实色抬升表面                                   |
| **内容玻璃卡片（L1）**                         | ArkUI 基础容器 + 4 档圆角（`10/16/24/999vp`）+ 半透明表面与 `1px` 细边；**核查 API 26 `pointLight`（点光源 `illuminated: IlluminatedType.BORDER_CONTENT / BORDER`）与轻量沉浸光感能力**         | **长列表卡片严禁叠加重度 `backdropBlur` / 重型 `systemMaterial` 以防掉帧**；优先用原生光感/微高光描边体现层次                                          |
| **分段切换器（启程/收藏/来信）**               | 优先核查 API 26 官方 `@kit.ArkUI` `SegmentButton`（胶囊单选滑块）或 `Tabs + SubTabBarStyle` 胶囊定制                                                                                            | 切换平滑过渡，服从系统字体缩放与无障碍读屏                                                                                                             |
| **底部提示、折叠选择面板、护照编辑、奖品详情** | 官方 `bindSheet`（`SheetType.BOTTOM`、`detents` / `SheetSize.FIT_CONTENT`、`dragBar`、原生半模态材质/背景模糊）或 `PromptAction.openCustomDialog`（`uiMaterial.ImmersiveMaterial`）             | 不手写遮罩+位移动画冒充 Sheet；尊重 `HitTestMode.BLOCK_HIERARCHY` 避免阻断子节点；裁剪独立弹层与父 Sheet 分离不嵌套                                    |
| **下拉回源刷新**                               | 复用现有 `StarwardRefresh`（官方 `Refresh`）                                                                                                                                                    | Refresh UI 态独立持有，不双向绑定 `vm.listBusy`，业务状态不由动画回调推动                                                                              |
| **选择题单选与媒体**                           | 官方 `Radio` + `ContentModifier<RadioConfiguration>` + 独立图层保护选项图片原色                                                                                                                 | 只读已完成态下选项 `Radio` 真实 `enabled(false)` 但图片/视频预览按钮保持可点击且图片不被压暗                                                           |
| **图标体系**                                   | 优先官方 `SymbolGlyph($r('sys.symbol.*'))` + 既有 Phosphor 业务矢量图标（含底栏 regular/fill 双态）                                                                                             | 统一通过主题颜色资源着色，深浅主题双测对比度                                                                                                           |
| **动效与特效演出**                             | `curves.springMotion`、`curves.cubicBezierCurve`、`keyframeAnimateTo`、`Particle`、矢量 `Path`/`Circle`/`Canvas`                                                                                | 全部接入 `StarwardMotion`（`accessibility.isAnimationReduceEnabledSync()`）；「减少动画」开启时折叠装饰动效且不阻断业务流；业务写入严禁依赖 `onFinish` |
| **键盘避让**                                   | 复用 `StarwardKeyboard`（`UIContext.setKeyboardAvoidMode(RESIZE)`）                                                                                                                             | 表单及底部悬浮作答栏按真实键盘压缩视口验证焦点与主动作可达                                                                                             |

---

## 四、架构红线与必须无损保留的现有能力

1. **严格沿用既定架构**：单 `entry` 模块、`@ComponentV2` / `@ObservedV2` / `@Trace` / `@Local` / `@Param` / `@Event` / `@Monitor`；保持 `pages`/`features`(ViewModel) → `business/` → `data/` → `platform/` 依赖方向；通用原生组件统一沉淀在 `ui/`；遵守 `codebase-design`（改前设计检查）和 `code-review-and-quality`（改后 diff 自审）。
2. **严守服务端权威与安全边界**：判题、准入、冷却、等级经验、线索、奖励、通知已读均以后端为准；保持 `Authorization: token`、账号代次隔离、幂等 `requestId`、改密单飞不重试、不打印敏感凭据或受保护 URL。
3. **严禁破坏 `starward_hm` 已验收的原生功能**（重构中必须保持链路完好）：
   - 冷启动 Asset Store Kit 续登（`CredentialStore`）与显式退出资产清理
   - 系统密码保险箱自动填充与保存（`autoFillManager`）
   - 华为 Push Kit 通知引导、权限状态与订阅管理（`SettingsPage` / `PushOnboardingViewModel` / `PushSubscriptionsViewModel`）
   - 答题页前台及后台 BGM 续播（`AVPlayer` / `AVSession` / `AUDIO_PLAYBACK`）与可拖动位置记忆浮标
   - 透明题图加载/缓存/失败小按钮重试与 `StarwardImageViewer` 查看器、受保护头像 `PhotoViewPicker` + 裁剪 + multipart 上传

---

## 五、推荐分切片推进顺序（逐片验证，不一口气大改）

请按以下顺序拆分为可独立编译、安装、真机隔离 HTTPS 验证与双主题目视对照的小切片，每完成一片更新 `docs/feature-acceptance-matrix.md` 再进入下一片：

1. **Slice 0｜规范与资源基线**：更新 ADR、验收表与 `starward-ui-parity`；迁移 `base/element/color.json`、`dark/element/color.json`、清除旧紫色 `journey_notification_color.json`、同步最新星尘图标与透明标志资源，核验深浅两套基础令牌与启动窗（`start_window`）。
2. **Slice 1｜沉浸材质底座、去侧栏壳与登录/加载星环**：
   - 升级 `StarwardMaterial`（补充 `pointLight` / L2 交互光感能力探测与降级）与 `StarwardBottomTabs` 冰蓝沉浸光感；
   - 移除 `StarwardSidePanel`，实现启程页双行身份顶栏（直达护照）与右侧 5 连击版本星标；
   - 实现共享矢量 `StarwardStarRingEmblem`，落地新版星环加载页与登录页动态旋转星环（保留 `autoFillManager` 与 `RESIZE` 键盘避让）。
3. **Slice 2｜启程大厅重构**：接入原生胶囊分段器（`待赴 / 回响`）与紧凑水平星环场次卡（进行中冰蓝高光+扫光、未达等级 `🔒 Lv.x`、列表延伸至浮栏下 + 末项同步文案 + 官方 `Refresh`）。
4. **Slice 3｜答题页深度重构**：
   - L2 沉浸玻璃悬浮顶栏（下滑隐藏、上滑即时展示）；
   - 居中四角星进度点；
   - 纯净 24vp 题卡 + 右上角唯一灯泡 `bindSheet` 提示 + 文上图下；
   - 脱离题卡的底部 L2 悬浮作答栏（填空胶囊 + 折叠式自适应高度选择题与已答只读展开、选项图原色可点、修正选中右凸对齐、重排 BGM/来信/组合浮标避让）。
5. **Slice 4｜答对星芒爆发与「星穹加冕」升级特效**：实现 `StarwardStarBurstOverlay`（`Particle` + 递增 EXP）与重构 `StarwardRankUpDialog`（冰蓝 × 荣耀金双环星冕 + 扫光 + `StarwardMotion` 折叠），确认与线索/终章队列无冲突。
6. **Slice 5｜护照设置页、收藏与来信双入口收口**：
   - 重构护照为身份统计卡 + 分组设置卡（`bindSheet` 编辑昵称/头像/改密/外观，无缝整合保留 Push 通知设置）；
   - 收藏页改为 `待领 / 已领` 胶囊分段 + 2 列极光玻璃网格（待领荣耀金高光+扫光 + `bindSheet` 详情，严守已领隐私脱敏）；
   - 来信页（`旅途来信 / 星海信笺`）与答题内 `StarwardJourneyNotificationDialog` 同步统一为极光玻璃风格；
   - 完成直板真机全链路回归与深/浅双主题目视核对（折叠屏/分栏专项按既定策略放到主体重构完成后统一验证）。

---

## 六、每切片交付与验收纪律

- 每切片开始前先列出变更清单与 API 26 官方接口核查结果；仅在需要改变既定可见布局、交互或遇到平台能力不可替代的差距时再向用户请示，常规薄封装与尺寸计算自主推进。
- 每切片必须分别给出真实证据：**Hvigor 编译 + signed 产物 + codelinter + 本地业务测试 + 直板真机安装与隔离 HTTPS 交互验证 + 深/浅双主题原图逐张目视审查**。
- 严禁把编译成功、准备步骤或静态截图写成完整业务/动态验收通过；未执行项、平台能力差距和待验边界必须如实单列记录。
- 保持固定隔离预览环境可随时供用户真机审查；不得将账号口令、签名凭据、私钥或设备标识写入版本库或公开报告。
