# 首切片原生视觉对齐修改

2026-10-27。依据冻结 Web `4b7d1a0a00051ac630e459b0fd6c074f821d7455`，将已有原生示范布局调整为手机正式页的信息结构。本文是修改目标，真实构建、真机和配对结论由主验收记录填写，不把静态实现当作视觉通过。

## 已调整结构

- 登录与强制改密共享 AuthLayout：84vp 顶栏、原品牌与 tagline、故事标题和星图、正文入口、底部原文案。恢复强制改密页缺失的故事区。
- 登录字段改为 13fp 标签、8vp 标签间距、52vp 控件高、10vp 圆角；浅色输入背景恢复白色，边框使用 border-strong。主按钮 16fp/600；帮助区保留可展开账号说明。
- 手机主页去掉 Web 隐藏的独立护照卡，恢复 84vp 顶栏头像入口、28fp 标题、下划线分类 tabs、58vp 编号栏的 chapter card、进度条和原状态/action 文案；刷新入口附在原同步说明，不再新增大按钮。
- 恢复底部四入口的图标、文字和圆角容器。收藏/来信/护照为后续切片，当前明确禁用；没有假页面或伪成功。头像菜单可查看当前玩家/等级/经验、切主题与退出。
- 场次详情使用原 Session Header（QUEST SESSION、昵称、Rank、进度）；原生默认标题栏隐藏。开始前正文恢复 18vp 圆角边框卡、24vp 内边距、双列 facts；空 endsAt 不显示截止，不重复加进度/ready 标签。入场仍禁用并有明确只读说明。
- 星图使用原生 Circle/Rect/Line 和同源 StarFour SVG 重建，按 Web 比例排布；不使用 WebView。

## Web 390×844 的坐标目标

坐标来自本轮 Playwright DOM 测量，实际原生截图应先扣除系统状态栏、导航安全区并记录实际 vp 后再比较。

| 状态 | Web 目标（CSS px） |
| --- | --- |
| 通用 auth | gutter20、header84；eyebrow y116/h12；故事 h1 y144/h95.19（34px，47.6行高）；描述 y252.19/h23.39 |
| 登录 | h2 y308.58/h33.59；账号框 y385.17/h52；密码框 y480.17/h52；CTA y548.17/h52 |
| 强制改密 | 标题 x56/y308.58/h36；描述 y356.58/h23.39；当前密码框 y430.97/h52；保存按钮 y688.97/h52 |
| 主页 | header84；eyebrow y100；h1 y118/h40.59；描述 y164.59；tabs y207.19/h53；trigger 宽76.95，间距24；chapter x26/y288.19/w338/h296.05 |
| 空历史 | 空态 x26/y288.19/w338/h280；图标64；h2 21/31.5；说明13/24.7；居中间距16 |
| 详情 | header x12/y24/w366/h68.58；card x12/y108.58/w366/h419.38；内文 x37；facts 两列各148、间距20；CTA y409.16/h52 |

## 字体、图标及已知平台差异

显示字体注册 `StarwardSerif`，来源为 root 获取的官方 Google Fonts Noto Serif SC OFL 字体；不复制 Mac 专有宋体。原 Web 系统字体截图和固定同一 Noto 字体的控制截图分别保存在 `artifacts/web-baseline/` 与 `artifacts/web-baseline-font-controlled/`，不能把两个系统的字栅格差异当作布局一致的证据。

20 个 SVG 来自原项目已使用的 `@phosphor-icons/react`，使用同一组件通过静态 SVG 导出，不改变图标系统。许可为 `licenses/Phosphor-Icons-LICENSE.txt`。应用品牌仍复用原位图。

字体 OFL 与图标 MIT 许可还逐字复制到 `entry/src/main/resources/rawfile/licenses/`，随 HAP 中的字体和图标资源一起打包。Noto 字体字节 SHA-256 为 `050080d9255a86808f2945bffac582b31ef32bc36411ce29563b4961670c66f9`；配对控制组使用同一文件。

已知刻意保留的差异：环境标识，未开放功能的禁用状态，只读详情的提示，以及系统状态栏/安全区。开始按钮不会为了截图一致而伪装可用。设备原生密码显隐、键盘、焦点与系统 Sheet 行为需单独验收。

## 自动化定位

原 id 保留：account、password、old-password、new-password、confirm-password、primary-action、current-tab、history-tab、assignment-{id}、theme-picker、refresh-assignments。

新增 id：theme-system/theme-light/theme-dark 明确选择主题；account-menu 打开玩家菜单，logout 在菜单退出、forced-logout 在强制改密页退出；account-close 关闭；request-retry/error-return-home；return-home；start-assignment（禁用）。旧脚本应使用三个主题 id，不再在 theme-picker 父容器上循环点击；主页退出需先打开 account-menu。

错误态也已调整为Web同源warning告警卡（红色边框/底色、16vp内边距、22vp图标、重试/回首页动作）；客户端VALIDATION_ERROR保留简洁红字。列表首次无数据时使用两张骨架卡，保留旧数据刷新时不插入骨架造成布局跳动。

## 大字体适配修正

Atlas 的零尺寸装饰父容器不再携带定位；位移通过V2参数传到实际有明确宽高的Atlas根Stack。宿主尺寸仅由自然正文决定，不受420/210vp装饰影响；默认理论高度为authStory204.6vp、lobbyIntro107.2vp，分别与Web测量仅差0.02/0.01vp的取整。显式行高使用fp单位，两处eyebrow仅保留最小高度，Session Header同样使用最小高度以容纳放大后的昵称/Rank；表单内容保持Scroll可达。默认和1.3倍字体的最终尺寸仍以本轮真机截图/树为准。

曾使用的零尺寸父position在真机出现布局树与实际绘制坐标不同、装饰命中覆盖主题按钮的问题；随后background方案仍被宿主裁切，未通过实际PNG检查，现已移除。当前onAreaChange测量宿主W/H，auth根offset为(W-270,H/2-210)、home为(W-200,-40)、detail按外边框为(W-141,-59)，待实际PNG复核。Atlas及其装饰父均不参与命中，所有装饰子节点均排除无障碍识别。391×777同Noto的Web实际SVG中心目标为auth(311,186.281)、home(276,165)、detail(338,150.578)，对应DOM证据为`artifacts/validation/web-atlas-layout.json`。修复结果须检查实际PNG绘制，不能以UI树坐标替代。

root-offset登录新PNG的完整星形中心已测为(311.4074,186.3704)vp，相对Web目标差(+0.4074,+0.0891)vp，且表单框未变化。该证据仅确认本轮登录星形位置，不泛化为整页或其它状态逐像素相等。另依据同源CSS补齐outer3/middle2/inner1共6个轨道节点，以原生Circle绘制并按轨道整体透明度0.5/0.7/0.6合成。设尺寸S、inset比例f、轨道宽O=S(1-2f)，边框内包含块起点为fS+1、宽O-2；节点坐标按CSS百分比计算，420/210/200尺寸与Chrome节点DOM的误差不超过0.024 CSS px的量化差。节点补齐的最终绘制仍待新构建截图验证。

## 动态状态刷新修正

官方本地文档`faqs-arkui-1078`说明@Builder按值传参不会随参数变化刷新。本轮真机真实400已暴露空错误消息不更新的问题；错误提示、主按钮动态文案和详情facts现改为@ComponentV2/@Param组件，保留原控件id和视觉样式。客户端校验仍使用简洁红字，服务器错误使用与冻结Web一致的GameFailure告警结构。ForEach键包含固定场次投影及顺序，使同id的新状态或进度替换旧卡片；计时字段不进入键，避免每次tick重建。

## 详情辅助文案

按冻结`AssignmentBrief.tsx:92`及`ui-copy.ts:452`补齐状态标签之后的原句：等待“，旅程开放后就能出发。”、过期“，请联系游戏管理员。”、等级受限“，请确认场次的参与等级。”；Text直接读取当前VM投影，不经字符串Builder参数。过期详情在开始按钮后恢复原`game-action-link--primary`对应的回首页入口，46vp高、12vp上间隔、原生Button可访问且整框响应，id为expired-return-home。源码CSS虽使用inline-flex，手机actions为纵列，链接实际为accent实底满宽按钮。详情卡之外既有return-home是原生额外返回控制，保留但不归为Web共有结构。ready状态及业务API不变；三变体两主题的新构建截图仍待本轮重拍验证。
