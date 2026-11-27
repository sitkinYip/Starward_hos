# 本机原生构建与测试入口核验

核验日期：2026-10-27。本文是工程创建前的工具与模板核验，不代表应用已经构建、签名或通过测试。实际执行结果以 `docs/toolchain-and-tools.md` 或首切片验收记录为准。

## 2026-11-25 极光玻璃 v2 资源基线

固定 DevEco Studio 26.0.0.851、SDK 26.0.0.105（API 26）、DevEco CLI 1.3.0-stable。启动窗配置核对 CLI 官方指南 `launch-page-config`、`launch-page-resource-config` 和 SDK `modulecheck/startWindow.json`。增强启动窗图标字段自 API 19 起可用，同进程主题选项自 API 20 起可用。

```sh
scripts/hm.sh build
STARWARD_VALIDATION_DIR=artifacts/validation/aurora-glass-v2-20261125/slice-0/final scripts/hm.sh lint
STARWARD_VALIDATION_DIR=artifacts/validation/aurora-glass-v2-20261125/slice-0/final scripts/hm.sh test
scripts/hm.sh run --skip-build
python3 scripts/capture-window-evidence.py --font-scale 1 --require-tls --themes --output artifacts/validation/profile/aurora-v2-slice-0-runtime.json
python3 -B scripts/device-aurora-preview-smoke.py --runtime-report artifacts/validation/profile/aurora-v2-slice-0-runtime.json --output artifacts/validation/aurora-glass-v2-20261125/slice-0/final/current-preview-smoke.json
```

- 构建及 SDK `verify-app`、`verify-profile` 通过。signed HAP SHA-256 为 `8502073c0247a5bd81da86bb91b80f05fe12b280d8a990a902a4f8041efec56a`。包内包含增强启动配置和与冻结 Web 字节一致的透明星标、应用图标。
- [codelinter](../artifacts/validation/aurora-glass-v2-20261125/slice-0/final/lint.json) 为 0 错误、0 警告、1 条建议。[Hypium 报告](../artifacts/validation/aurora-glass-v2-20261125/slice-0/final/local-test-summary.json) 为 300/300 通过，失败和忽略均为 0。
- 官方 CLI 在直板机确认安装及启动。[运行报告](../artifacts/validation/profile/aurora-v2-slice-0-runtime.json) 的 6 项窗口、双主题状态栏及隔离 TLS 检查通过。旧冒烟先因预览 list 比种子新增 6 条而停止，保留[失败报告](../artifacts/validation/aurora-glass-v2-20261125/slice-0/final/device-preview-smoke.json)。[当前快照冒烟](../artifacts/validation/aurora-glass-v2-20261125/slice-0/final/current-preview-smoke.json) 的 3 项检查通过，直板机直接进入首页，两栏分别 5 条，10 条均与当前 HTTPS 场次匹配。
- 原生空登录深浅原图 dpr 3.25、宽 387.69vp、字号系数 1。对应 Web 临时隔离 Mock `/login` 视口 388×771，实际主题切换待转场落稳。四张原图均已目视，配色和表单可读性在本片核对，登录结构和星环效果由切片 1 验收。暗／浅原生图 SHA-256 前缀 `79df20105d61`／`cec9fe154dce`，Web 为 `7078a2d50a18`／`10dfe8a06083`。原图位于本机私有 `artifacts/private/aurora-glass-v2-20261125/slice-0/`。启动窗资源通过 SDK 声明与包内核对，系统瞬时起窗帧未单独实拍。

## 2026-11-25 极光玻璃 v2 壳层与登录

固定 SDK 26 的 `ReadonlyEnvKey.WINDOW_SIZE` 和 `WINDOW_AVOID_AREA` 提供 vp 窗口和安全区尺寸，保持现有 `Scroll` 与 `KeyboardAvoidMode.RESIZE`。按用户确认去除 Web 冻结版带来的 380vp 主视觉下限及整窗比例留白。星环按未缩减窗口约束，表单组件使用原生自然布局，空表单首张 UI 树在任何滚动、输入或辅助定位前核查。

- [壳层及首屏报告](../artifacts/validation/aurora-glass-v2-20261125/slice-1/auth-overflow/shell-and-login.json) 的 16 项直板机检查通过。覆盖头像直达护照、设置真实版本及返回、各根页标题、四键悬浮栏拖动松手、退出空表单、双主题完整首屏、帮助与错误不移动主视觉、真实输入法缩窗与返回、隔离 HTTPS 重新登录。两主题原生安全视口均为物理像素 `[0,422,1260,2629]`，登录整卡 y=`1137–2269`，主按钮 y=`1837–2006`，帮助入口 y=`2045–2188`。HAP `3880a1a444d76a200b80776b6f89f579da48d2cf08f140eefa3d46b6c90b693b` 对应该轮证据。
- 逐图目视核对 387.69vp 深浅原生与 388px Web 原图。按用户确认的采集顺序，在冻结 Web 中先设置 388×771 手机视口，再直接访问 `/login`。全新深浅会话均在动画结清且零滚动时测得提交按钮 y=`790.09–834.09`，位于该视口首屏下方。桌面切回手机的响应式场景另行复现。原生保留星环、标题、玻璃卡和表单文案，压缩留白后显示完整表单。两张原生深色采样帧显示外轨星点与弧段旋转，内轨星点反向变化。采样图用于核对可见变化，时长和减少动画开关未真机验证。原图位于私有 `artifacts/private/aurora-glass-v2-20261125/slice-1/` 的 `auth-overflow/` 和 `web-login-mobile-first-settled-388x771/`。
- [最终间距修正套件](../artifacts/validation/aurora-glass-v2-20261125/slice-1/auth-spacing/) 对应包 `4c1dbc41fbff142b5874cb08403b50c751e0ebddfbd76234ee106bcfdffbce3c`。官方 `scripts/hm.sh run` 构建、安装及启动，SDK `verify-app` 和 `verify-profile` 均通过。`scripts/hm.sh lint` 为 0 错误、0 警告、1 条建议，`scripts/hm.sh test` 为 305/305 通过。以 `python3 scripts/capture-window-evidence.py --font-scale 1 --require-tls --output artifacts/validation/profile/aurora-v2-auth-spacing-runtime.json` 核五项窗口、系统栏和隔离 TLS 检查全部通过。[真机间距报告](../artifacts/validation/aurora-glass-v2-20261125/slice-1/auth-spacing/device.json) 记录 4 项通过，两主题上界面说明至表单下边缘均为 39 物理像素，即 12vp。两张最终深浅原图已目视核对，位于私有 `artifacts/private/aurora-glass-v2-20261125/slice-1/auth-spacing/`。
- [贴底与帮助 Sheet 补验](../artifacts/validation/aurora-glass-v2-20261125/slice-1/auth-sheet/device.json) 使用 `aff5847961e7b496d8229be2076562c81e2c78471e08bb7bd50c22c790694e71`，按固定 SDK 核对 `onAreaChange`、`bindSheet`、`SheetSize.FIT_CONTENT` 与 `SheetType.BOTTOM` 后，复用现有原生 Sheet 封装。配置实际安装并启动，SDK 应用与 Profile 双验签通过，lint 为 0 错误、0 警告、1 条建议，Hypium 305/305。[该包运行时报告](../artifacts/validation/profile/aurora-v2-auth-sheet-runtime.json) 五项通过。八项设备检查核对安全区上方 52px（16vp）、说明距卡片 39px（12vp）、深浅 Sheet 文案、系统返回、同一草稿、真实输入法和隔离登录。深浅各两张完整首屏与 Sheet 原图已逐张目视核对，位于私有 `artifacts/private/aurora-glass-v2-20261125/slice-1/auth-sheet/`。

## 2026-11-25 极光玻璃 v2 启程大厅

固定预览最终包 `b256f1ed4f38ac2c45330b881943d7ae60d1a15d7902dea1a3a4f49866a77cde`。官方 `scripts/hm.sh run` 构建、安装、启动，SDK 应用和 Profile 验签通过。[lint](../artifacts/validation/aurora-glass-v2-20261125/slice-2/rounded-preview/lint.json) 为 0 错误、0 警告、1 条建议，[Hypium](../artifacts/validation/aurora-glass-v2-20261125/slice-2/rounded-preview/local-test-summary.json) 为 305/305。早期有一轮 Hypium 报告混入 ArkCompiler GC 日志而触发解析器不完整保护，保留[当轮计数](../artifacts/validation/aurora-glass-v2-20261125/slice-2/preview/local-test-summary.json)。

```sh
python3 scripts/capture-window-evidence.py --font-scale 1 --require-tls --output artifacts/validation/profile/aurora-v2-slice-2-rounded-preview-runtime.json
python3 -B scripts/device-aurora-preview-smoke.py --runtime-report artifacts/validation/profile/aurora-v2-slice-2-rounded-preview-runtime.json --output artifacts/validation/aurora-glass-v2-20261125/slice-2/rounded-preview/device.json
```

- [固定预览跑通报告](../artifacts/validation/aurora-glass-v2-20261125/slice-2/rounded-preview/device.json) 记录 5 项通过。真实 HTTPS 有 10 张场次，原生待赴与回响各 5 张全部可达，两栏同步说明可滚到悬浮栏上方。初始[第一轮](../artifacts/validation/aurora-glass-v2-20261125/slice-2/preview/device.json)和[第二轮](../artifacts/validation/aurora-glass-v2-20261125/slice-2/final-preview/device.json)保留。复查首项与 Scroll 上缘对齐，原工具要求首项离上缘至少 8px，已调整为按真实 Scroll 和浮栏边界验完整可用空间。
- Web 使用冻结 `46188fc` 的手机优先上下文，回放同一固定预览的实际 DTO。四张 388×771 原图都有实际零滚动的 viewport 几何。按相同有效宽度逐张核对深浅主题与两个分段。四张首卡原生范围一致，实测约 340×96vp，分段约 352×54vp。旧样本发现边框调用覆盖 24vp 圆角，通用阴影描出方框。通过 ArkUI `border` 的 `radius` 及 `RingStyleOptions.shadow` 修正。[完整首卡与官方横滑报告](../artifacts/validation/aurora-glass-v2-20261125/slice-2/rounded-preview/native-visual-full-cards.json) 记录修正包、几何及原图 SHA。第一次修正包截图里待赴已向下滚动，首卡高度为 224px，该轮保留为[过程记录](../artifacts/validation/aurora-glass-v2-20261125/slice-2/rounded-preview/native-visual.json)。完整复拍验证首卡的 312px 实测高度。
- 同一修正包七张深色采样中，第五张显示进行中卡片左侧扫光带，和静态帧对照有 21,524 像素的最大 RGB 通道差至少 8。图像采样验证可见扫光。绝对节奏和系统减少动画下的胶囊默认过渡仍待实测。正式原图在私有 `artifacts/private/aurora-glass-v2-20261125/slice-2/`。
- [一次性隔离验收](../artifacts/validation/aurora-glass-v2-20261125/slice-2/disposable/lobby-device-03.json) 4 项通过，后端 `9377248537609a5bd4f4f12bca76d2040b53f956`，独立 CA 签名包 `8e74f75d3603aa2824f7f29d9fe9760291942a48addef3a14a3ae206924fcf11`。官方构建、安装和 SDK 双验签成功，[该包运行时](../artifacts/validation/aurora-glass-v2-20261125/slice-2/disposable/runtime.json) 五项通过。记录真实首载 503 及点击重试的后续成功、锁定卡打开限制说明且原始树的入场按钮禁用、真实回响空态、官方下拉后的单次真实 GET。该 GET 距上一次轮询 4219ms，早于下一轮，禁止业务写入数为 0，四场进度和经验前后相等，已退出专用玩家。[前轮](../artifacts/validation/aurora-glass-v2-20261125/slice-2/disposable/lobby-device-02.json) 的锁卡被采集器 94vp 高度断言拒绝，原始结果保留。锁卡只用等级标志，需要独立按 44vp 可达范围判定。
- 用户要求的主题呼吸光版本使用 HAP `286d8050014affdbec761aaa76accd1c041399ac9cdae97fb053b44d51cae3d0`。官方构建、安装、启动及 SDK 两项验签均通过。[运行时](../artifacts/validation/profile/aurora-v2-journey-glow-runtime.json) 的 5 项通过。[深浅固定预览报告](../artifacts/validation/aurora-glass-v2-20261125/slice-2/active-glow/native-device.json) 记录相同场次首卡的 2 张原图与每主题 5 张采样。对固定的 115×60px 光晕区域，深色平均 B 通道在 94.54 到 100.58 之间变化，浅色平均 B−R 在 28.34 到 30.33 之间变化。两主题原图目视检查描边、光晕位置和文字对比度，采样确认呼吸可见。系统减少动画仅核代码门控，设备开关仍待实测。原图位于私有 `artifacts/private/aurora-glass-v2-20261125/slice-2/native-active-glow-387.69vp/`。

## 2026-11-25 极光玻璃 v2 答题页阶段验收

答题页初始可验包 `0d80b6a4137a0c6050641e0a43790c12f593f12be2a76eddc81e1763dbcb0def`。官方编译、安装、启动、SDK 应用和 Profile 验签通过。[隔离运行时](../artifacts/validation/aurora-glass-v2-20261125/slice-3/disposable/runtime.json) 五项通过，配套[lint](../artifacts/validation/aurora-glass-v2-20261125/slice-3/final-source/lint.json) 为 0 错误、0 警告、1 条建议，[本地测试](../artifacts/validation/aurora-glass-v2-20261125/slice-3/final-source/local-test-summary.json) 为 305/305。

- [首载与取消](../artifacts/validation/aurora-glass-v2-20261125/slice-3/disposable/text-hint-device-01.json) 已观察真实延迟 10.5 秒的首个详情 GET、全屏星环与保留系统状态栏、在返回后同一路由的迟到成功未恢复场次。该轮启动实测也发生，脚本因把仅在多题显示的星点导航误作单题要求而中断，保留结果。
- [同一已入场填空夹具续验](../artifacts/validation/aurora-glass-v2-20261125/slice-3/disposable/text-hint-device-03.json) 7 项通过，覆盖单题省略分段、题干先于实际透明题图、独立悬浮作答栏、唯一提示 Sheet、草稿保留、真实输入法下控件可达及返回。真实权威台账一条入场回执、零答题和零经验，清除该隔离账号的设备登录。续验前一轮 DTO 把 `session` ID 当成对象造成脚本类型错误，保留[失败记录](../artifacts/validation/aurora-glass-v2-20261125/slice-3/disposable/text-hint-device-02.json)。
- [已答选项与图集](../artifacts/validation/aurora-glass-v2-20261125/slice-3/disposable/choice-readonly-device-02.json) 对应包 `e3e3fdd7a4e802b28174fe7d4721bb41dab68454045a2a77b2fe82912351c04a`，7 项通过。深浅主题均验证默认折叠、四个原生 Radio 禁用且服务端选中项一致、选项原图可点进并返回原 Sheet。授权选择、EXP 和回执保持一致。原生与冻结 Web 的同数据原图保存在本机私有 `slice-3/disposable/choice-with-images/`。
- [长题顶栏与键盘](../artifacts/validation/aurora-glass-v2-20261125/slice-3/disposable/long-text-scroll-device-01.json) 和[可编辑短选项](../artifacts/validation/aurora-glass-v2-20261125/slice-3/disposable/active-choice-device-01.json) 各 5 项通过，绑定包 `fa103225d46e32648ef48c527316e0992a6049fc3fbfbe07e6a6f428e2ccd524`。官方安装启动、SDK 两项签名及[隔离运行时](../artifacts/validation/aurora-glass-v2-20261125/slice-3/disposable/runtime-final.json) 五项通过。各自真机新入场且未提交答题，退出后登录已清理。长题同数据 Web 先设置 388×771 手机视口，再进入页面，捕获两主题顶栏三个状态，原生实测与对应浅色 Web 样板已目视核对。短选择 Sheet 同屏两个选项，选择后关闭，重开保持选中并与选择前水平对齐。配套 [lint](../artifacts/validation/aurora-glass-v2-20261125/slice-3/reviewed-source/lint.json) 0 错误、0 警告、1 条既有建议，[本地测试](../artifacts/validation/aurora-glass-v2-20261125/slice-3/reviewed-source/local-test-summary.json) 305/305。当前隔离端点的视频资源返回 404，未取得本片真机实播或音频播放证据。

## 2026-11-25 极光玻璃 v2 星芒与升级礼赞

- 原生星芒使用固定 SDK 的有限 `Particle`、`Shape` 和 `UIContext` 关键帧；帧回调只绘制 EXP 递增，页面和 ViewModel 决定出现、停止及导航。Rank 沿用官方自定义弹窗的所有权与进退场。HAP `b9aad48969d229b903071797831f76935ddbe2debcfa34fd6e0c008367735c99` 官方构建、安装及启动，SDK 两项签名验证通过。配套[隔离运行时](../artifacts/validation/aurora-glass-v2-20261125/slice-4/disposable/runtime.json) 五项、[本地测试](../artifacts/validation/aurora-glass-v2-20261125/slice-4/source/local-test-summary.json) 308 项通过。[lint](../artifacts/validation/aurora-glass-v2-20261125/slice-4/source/lint.json) 0 错误、0 警告、1 条既有建议。
- 三个初始未入场账号各执行一次原生入场与答题。[手动](../artifacts/validation/aurora-glass-v2-20261125/slice-4/disposable/manual-device-01.json) 5 项，[自动](../artifacts/validation/aurora-glass-v2-20261125/slice-4/disposable/auto-next-device-01.json) 3 项，[升级](../artifacts/validation/aurora-glass-v2-20261125/slice-4/disposable/rank-device-01.json) 7 项通过。每轮核对权威结算与清除登录。顺序是暗色 50 EXP 手动切题、浅色 50 EXP 有星芒时自动切题、暗色 100 EXP 先星芒再开 Lv.2 礼赞。目视核对原生星芒深浅、礼赞深色与冻结 Web 的对应状态。Web 388×771 先设手机视口，以隔离相同 DTO 的本地回放采 28 张深浅原图，无 Web 业务写入。原图保存在私有 `slice-4/disposable/`。系统减少动画、礼赞浅色以及线索／终章的新包真机回归待各自专项。

## 2026-11-25 极光玻璃 v2 护照、收藏与来信

- API 26 复用原生胶囊分段、`GridRow`、`bindSheet` 与现有媒体覆盖层。护照首访可读取真实统计，深浅统计组件显式订阅 V2 值。首轮设备见收藏接口成功而护照显示占位，改为 V2 数值子组件后以同一隔离账号核对 `已解开 0／场次 0／收藏 4`，并核对 86vp 原生经验环。昵称草稿关闭再打开仍保留，回源昵称保持原值。见[护照实机回合](../artifacts/validation/aurora-glass-v2-20261125/slice-5/disposable/populated-device-06.json)。该回合随后在旧键盘避让方式下中止，密码验证单独记录。
- 用户追加将护照「设置」移到「外观」正下方，沿用同款整行按钮。真机核对两行同宽、顺序相邻、入口唯一；点按进入原生设置、显示安装包版本并可回原 Tab。[设置行进入与返回](../artifacts/validation/aurora-glass-v2-20261125/slice-5/disposable/passport-settings-row-device.json) 绑定 HAP `1d72db30ac7e4a4b905d6d1b904deb34097283b89a096b01467f6435ab81ed24`。
- 私有 Web 回放在导航前按主题新建 388×771 手机视口。对照输入为相同 HTTPS 账号只读响应，护照 8 张、收藏 18 张、旅途来信 8 张。隔离媒体补齐三个精确本地路径，证书指纹与 USB 反向映射保持同一受控环境，PNG 和两条 MP4 的真实字节、完整读取与 Range 都经主机核验。真实设备播放与主机媒体检查分别记录。
- 收藏横滑复用启程和来信的官方 ArkUI `Tabs` 两页容器，每页保留自己的纵向滚动与刷新，胶囊与内容使用同一个选中值。组合包 `f70d99e2b2c2e18a8384762491fee4c1f5e1a47b66ba1969bcf5aeeed80fc583` 通过官方构建、安装、启动、SDK 应用和 Profile 签名验证、[隔离运行时](../artifacts/validation/aurora-glass-v2-20261125/slice-5/disposable/runtime-swipe.json) 五项、[Hypium](../artifacts/validation/aurora-glass-v2-20261125/slice-5/swipe-source/local-test-summary.json) 316 项及 [lint](../artifacts/validation/aurora-glass-v2-20261125/slice-5/swipe-source/lint.json) 零错误／零警告／一条既有建议。[收藏横滑真机](../artifacts/validation/aurora-glass-v2-20261125/slice-5/disposable/collection-swipe-device-01.json) 五项确认左滑到已领、右滑到待领、点按与横滑同步、切换后仍可打开真实奖品详情、后端奖品数据保持不变。目视核对两张分组选中原图，真实奖品图片和胶囊高亮可见。
- 同包[改密键盘与收藏综合轮](../artifacts/validation/aurora-glass-v2-20261125/slice-5/disposable/populated-device-12.json) 核实使用 `TRANSLATE_AND_SCROLL` 后，真实 IME 显示时焦点字段完整，关面板后密码草稿清空。该轮因通用测试手势未定位到详情的纵向滚动区域而中止；[详情隐私专项](../artifacts/validation/aurora-glass-v2-20261125/slice-5/disposable/reward-detail-privacy-device.json) 定位官方详情内部 Scroll，验证待领可见获授权的私密指引，已领和失效不显示私密区，三项通过并清除隔离登录。
- 来信首轮发现把自定义 Refresh 直接放在 ArkUI 内容回调由编译器作为普通构造调用，实机进入时异常。改用所属页 `@Builder` 后，[普通关闭轮](../artifacts/validation/aurora-glass-v2-20261125/slice-5/disposable/journey-device-04.json) 在深浅主题分别打开阅读并通过系统返回，服务端仍为两条未读且无回执。该轮发现单条来信页脚的弹性占位把确认按钮挤出可见区域。去掉占位，以原生 Flex 右对齐后，HAP `8249eaeb913a58de8aeadd84a9953b57494f0a9cc6fad2f2f338dc147c21e9ae` 的[来信确认轮](../artifacts/validation/aurora-glass-v2-20261125/slice-5/disposable/journey-device-05.json) 通过三项，旅途来信和星海信笺可双向横滑、确认按钮完整可达、明确点击仅产生一个成功回执且另一条仍未读。退出已清理。原始列表深浅图与同数据 Web 逐图核对。

## 2026-11-25 蒙层与系统栏连续性

- 直板机宽 387.69vp、密度 3.25。首轮 `bindContentCover` 底层在浅色成为近实色。全窗口原生弹窗曾在状态栏和手势区留下横边。改为根页面共享的 ArkUI 高斯蒙层、原生居中面板及独立安全间距后，深浅主题真机 9 项通过，绑定应用及 Profile 均验签的 HAP `ba9fef6ff73fc5d1bc7d8a4add8e4d7f6356068c09dcdacf7b7fff9cdf5d6482`。逐张核对隔离来信原图，标题、列表和底栏可辨且有高斯模糊，状态栏和手势区延续同一底景。两主题截图中的边界亮度差均小于 0.001。原生外观 Sheet 使用半透明遮罩，透出上方护照内容。点遮罩和系统返回回原列表，服务端回执保持一致，退出隔离账号。 [深浅主题真机报告](../artifacts/validation/aurora-glass-v2-20261125/modal-mask/disposable/device-visual-06.json) · [窗口与严格 TLS](../artifacts/validation/aurora-glass-v2-20261125/modal-mask/disposable/runtime-06.json)
- 答题滚动真机 7 项通过，绑定 HAP `0875b3886fc4434fbac6c1bb75ed765e8b4a64438a821241d918e68004e0d789`。在隔离只读服务重开同一已入场长题，逐图核对页首安全距离、题面滚入状态栏和胶囊背后、回滑恢复胶囊、作答栏固定及真实键盘。使用 ArkUI Scroll 原生边缘渐隐减弱状态栏图标后面的题面，同时保留连续底景。退出后核同场次答题和进度数据保持一致。最终源码 Hypium 316 项通过，lint 无错误或警告。 [答题真机报告](../artifacts/validation/aurora-glass-v2-20261125/modal-mask/disposable/gameplay-immersive-07.json) · [Hypium](../artifacts/validation/aurora-glass-v2-20261125/modal-mask/final-immersive-source/local-test-summary.json) · [lint](../artifacts/validation/aurora-glass-v2-20261125/modal-mask/final-immersive-source/lint.json)
- 重启后恢复固定隔离预览数据库和原 CA。最终 HAP `5a681af1da307820c0c3d3f79e49ddade940acf3c0ee9d4182d720f552f20027` 官方构建、安装启动和双验签成功。窗口与隔离 TLS 五项通过，固定账号真机直接登录，启程两栏 10 张场次卡及两条末尾提示可达，设备留在启程。 [最终预览窗口与 TLS](../artifacts/validation/profile/aurora-v2-final-preview-runtime.json) · [预览真机五项](../artifacts/validation/aurora-glass-v2-20261125/modal-mask/preview-smoke-verified.json)

## 2026-11-25 答题整页源码复核

- 读 `3f3aae6` 的正式手机端提交并核对冻结 `46188fc` 最终源码。题头、星点、题板、提示、作答栏、选项和反馈分别以 `GamePlayScene.tsx`、`QuestCard.tsx`、`QuestAnswerForm.tsx`、`ChoiceOptions.tsx` 和实际生效的 `quest.css`、`answer-feedback.css` 为准。通关线索、组合浮标和剧情提醒以 `CluePanel.tsx`、`MultiClueLauncher.tsx`、`NarrativeAttentionBeacon.tsx` 和 `clue-presentation.ts` 为准。
- 取得冻结 Web 真正 388×771 手机视口的深浅主题参考原图及 DOM 几何。短提示、长题提示和已完成带图选项使用历史真实 DTO 只读回放，Web 网络路由只匹配登记的同一原始图片字节。原图及几何位于本机私有 `artifacts/private/aurora-glass-v2-20261125/gameplay-parity/web-reference-388x771/`。
- 鸿蒙调试 HAP `59d4e735889c840c02877fbd161afdf09987c0ddeba98746291110703894c8e2` 在同一历史长题、已完成选择题、已完成组合线索和剧情线索四场次完成 12 项隔离真机检查。逐图核对深浅提示与选项、完整原始选项图、组合胶囊和弹窗、两题之间的信笺和祝福。长选项滚动在同一浮层内，完成态四个 Radio 使用官方 UiTest 的原始 enabled 值核实。图片仅使用本机的四条精确 HTTPS 路径，按题图和 A、B、C 原始 JPEG 校验。看图返回后保留浮层。选项视频另测。 [隔离手机报告](../artifacts/validation/aurora-glass-v2-20261125/gameplay-parity/device-parity-02.json) · [窗口和 TLS](../artifacts/validation/aurora-glass-v2-20261125/gameplay-parity/runtime-replay-02.json)
- 深色提示颜色复核使用 HAP `bb091e43510da17adfe9a1ea6d2ab1a84386454cc37f3960df3c4a0f0ebafad2`。官方 Sheet 改用与选项统一的主题色，独立 ArkUI 蒙层承担页面高斯模糊。原图核对与像素取样确认深空底色，系统返回回原题。最终源码 Hypium 318 项通过，lint 无错误或警告。 [深色提示复核](../artifacts/validation/aurora-glass-v2-20261125/gameplay-parity/device-hint-final-01.json) · [Hypium](../artifacts/validation/aurora-glass-v2-20261125/gameplay-parity/release-source/local-test-summary.json) · [lint](../artifacts/validation/aurora-glass-v2-20261125/gameplay-parity/release-source/lint.json)
- 同包使用三名本地隔离测试账号，回放历史题面和模拟正确结算。原生快速布局确认自动模式只显示「正在跳转下一题」，点击空白后进入第 2 题。手动模式有按钮，点击背景或等待自动收起后均留在第 1 题。三组各只有一次模拟入场、一次模拟答题。UI 轮询只确认结果，1500ms 和 3000ms 分别由 ViewModel 的持续计时管理。 [星芒真机分支](../artifacts/validation/aurora-glass-v2-20261125/gameplay-parity/device-burst-01.json)
- 固定隔离预览已恢复，最终 HAP `7645295dd8d8b7da5480f01dba7c57f40efd3f340f2d96149756e3e302b647c2` 官方构建、双验签、安装启动及窗口与严格 TLS 通过。真机冷启动直接登录，核过两栏 10 张场次卡和两条列表末尾提示，设备留在「启程」。 [固定预览真机](../artifacts/validation/aurora-glass-v2-20261125/gameplay-parity/preview-smoke.json) · [窗口和 TLS](../artifacts/validation/profile/aurora-gameplay-parity-preview-runtime.json)

## 2026-11-25 入场前场次简介

- 对照 Web `feat/ui-glass-v2` 冻结版本 `46188fc`、重构提交 `3f3aae6` 与实际移动端样式。固定预览同一可入场场次的 Web 快照在导航前设定 388×771，深浅两色，动效落定后卡片为 289px 宽。鸿蒙按用户确认保留宽卡和横向条件行。启程身份栏与场次标题使用共用 ArkUI 头部，简介和答题共用返回及标题槽位。
- 固定 API 26 打包 HAP `0fcbcbef9aaef574577f35c812126be1d47e91ed135d6ff3407be1cadc4b5144`。`scripts/hm.sh build` 与 `scripts/hm.sh run --skip-build` 成功，`hap-sign-tool` 验证 HAP 和签名 profile 成功。相同源码 `scripts/hm.sh test` 通过 318 项，`scripts/hm.sh lint` 零错误、零警告，有一条既有性能建议。签名包在直板机观察到 387.69vp、字号 1、透明系统栏与严格隔离 TLS。 [构建](../artifacts/validation/aurora-glass-v2-20261125/assignment-briefing/source/build.log) · [安装](../artifacts/validation/aurora-glass-v2-20261125/assignment-briefing/source/install.log) · [单测](../artifacts/validation/aurora-glass-v2-20261125/assignment-briefing/source/local-test-summary.json) · [lint](../artifacts/validation/aurora-glass-v2-20261125/assignment-briefing/source/lint.json) · [窗口和 TLS](../artifacts/validation/profile/aurora-assignment-briefing-runtime.json)
- 固定预览可入场态有浅色实机目视记录。复核期间服务端状态转为进行中，固定预览当前已无可入场样本，因此深浅主题的几何、日期及禁用实测采用同一已过期场次。等级限制、等待开放、撤回和入场失败重试未在本轮真机复测。
- 在同一过期场次的 388px Web 与 387.69vp 鸿蒙上核对两种主题。两端均显示截止时间 `2026年10月29日 14:00`、过期解释及禁用状态。两张原生原图的卡片均宽 360vp、左右各约 14vp，四行取值与标签在同一行并抵达右边缘，顶栏返回命中区为 44vp。正向手点顶栏和卡内返回，系统返回检查通过，进行中和已完成场次直接恢复内容。测试结束恢复浅色并留在启程。报告可由 `python3 artifacts/private/aurora-glass-v2-20261125/assignment-briefing-preview-native/smoke.py --expired-first` 在固定预览重跑。 [真机六项](../artifacts/validation/aurora-glass-v2-20261125/assignment-briefing/fixed-preview.json)

## 2026-11-25 启程头部页签切换

- 起初全局 Navigation 的标题栏滑动让正文和身份短暂移向状态栏。最终在启程页签内预留 `70vp + 顶部安全区`，玻璃、身份和星标使用一次 240ms ArkUI 淡入。减少动画时选用 `TransitionEffect.IDENTITY`。
- API 26 直板机固定预览采集收藏切回启程的 20 帧。启程标题首次出现时的位置与落定帧相同，期间能看到身份和星标逐步显现。原生标题、正文的落定位置与修改前一致。逐帧仅证明可见过渡与位置，时长为源码配置。实机系统减少动画开关未切换验证。 [真机切换记录](../artifacts/validation/aurora-glass-v2-20261125/lobby-header-transition/device.json)
- 最终调试包 `bb955bdb5674e41bf5f037d290c795177badbeae48e22d6679d6d8e62319011f` 构建、双验签、安装启动成功。`scripts/hm.sh test` 318 项通过。`scripts/hm.sh lint` 零错误、零警告，有一条既有性能建议。 [单测](../artifacts/validation/aurora-glass-v2-20261125/lobby-header-transition/source/local-test-summary.json) · [lint](../artifacts/validation/aurora-glass-v2-20261125/lobby-header-transition/source/lint.json)

## 2026-11-25 原生转场补齐

- 按冻结 Web `46188fc` 的动效令牌和已生效样式核对 ArkUI API 26。主、分类页签使用原生控制器，场次和剧情使用系统淡入淡出，设置使用系统横向转场。简介、信笺提示、终章入口和视频准备完毕使用一次短入场。普通原生 Sheet 继续使用系统转场，可缩放图片沿用整层过渡。
- 答题恢复按题目 ID 固定原生页节点。真机复现响应式修饰器重写声明式初始索引，会闪回初始题。最终移除 `.index`，让控制器等首次布局完成后定位。相邻题由 ArkUI 跟手和落定，远距跳题直接定位，落定后才在必要时滚回题首。手势、程序切题和迟到结束信号有独立回归断言。
- 调试包 `416fa953e6d48103344a2667c87b12d4823706315641f4e8595bd948252d4ea5` 完成构建、双验签、安装和启动。Hypium 323 项通过，lint 无错误或警告。 [单测](../artifacts/validation/aurora-glass-v2-20261125/native-transitions/source/local-test-summary.json) · [lint](../artifacts/validation/aurora-glass-v2-20261125/native-transitions/source/lint.json)
- 同一签名包在固定隔离预览直板机核对左右滑、星点远距跳题、作答栏、提示和只读选项关闭、场次返回。第一题到第二题的 8 个分时画面显示连续位移及正确题面。启程、收藏和来信分别验证胶囊点按与横滑，护照和设置验证程序跳转、原生入场与系统返回。帧耗指标和真机减少动画开关本轮未采集。 [答题真机报告](../artifacts/validation/aurora-glass-v2-20261125/native-transitions/quest-after.json) · [页签与设置真机报告](../artifacts/validation/aurora-glass-v2-20261125/native-transitions/shell-device.json)
- 固定预览的已完成场次「清宫那点事」通过通关线索打开六秒视频。真机观察到原生播放画面，复跑在播放中按系统返回，关闭全屏并保留第 1 题。设备最终回到启程。 [视频真机报告](../artifacts/validation/aurora-glass-v2-20261125/native-transitions/media-device.json)

## 2026-11-26 场次进度订阅

进度页面沿用极光玻璃 v2 的设置标题、轻量内容卡、冰蓝控制和安全区，使用同一个隔离场次和同一台直板机检查深浅主题。现有冻结 Web 仅作为版式与语义资源参考。运营台在 1440、1024、768、390 和 320 px 五种宽度下核对深浅主题和页面横向溢出，实际操作了新增授权、空字段校验、移动端调整期限抽屉及返回。

| 检查 | 结果 |
| --- | --- |
| 构建、签名、安装启动 | `scripts/hm.sh build` 和隔离副本的 `scripts/hm.sh run` 通过。直板机更新安装并成功启动 Ability。 |
| ArkTS 测试 | `scripts/hm.sh test` 335 通过、0 失败、0 忽略。覆盖旧账号异步失效、场景消息路由、两段订阅和后台恢复后的幂等重试。 |
| 代码检查 | `scripts/hm.sh lint` 0 错误、0 警告、1 条既有信笺模糊效果建议。 |
| PocketBase 与迁移 | 单独隔离的 PocketBase 0.40.1 中执行完整套件 158 通过、0 失败、0 跳过。覆盖空库、旧库副本升级与重启、真实判题事件、取消、到期、撤权、设备归属及分类准备状态。将隔离副本的通关结果改为答对后，测试会捕获两条答对任务。 |
| 运营台 | 48 项测试、TypeScript、共享协议检查和 Vite 生产构建通过。浏览器指向隔离 API，保存授权收到服务端 200。 |
| 真机业务与视觉 | 普通账号设置页无入口，授权账号用真实 HTTPS 读取「1 / 3 关」、当前第 2 关和近期答对及答错。选中答对和通关并保存，从系统返回回到设置，更换深色后重新打开，观察选项持久化并取消。最终签名包实测运营台撤权后，本机从后台恢复时清空已打开的详情，返回设置时入口消失，随后退出隔离账号。 |
| 服务端拾取时延 | 隔离 PocketBase 使用实际定时调度和替身发送器。启动时首条等待 51.29 秒，进入扫描循环后三条分别耗时 1.88、2.03、2.03 秒。该测量截至后端任务被发送器接受。 |
| 华为正式推送 | 待确认跨玩家进度提醒的场景权益，待验独立通知确认、锁屏送达、实际投递延迟和系统通知点击回源。后端投递测试使用替身。 |

原图与报告见[隔离验收证据](../artifacts/validation/progress-watches-20261126/)，授权模型见 [ADR-042](architecture-decisions.md#adr-042指定场次的进度订阅)。签名、安装和隔离业务验证分别记录，设备标识、登录凭据及生产数据留在验收范围外。

同日补充答错详情。`scripts/hm.sh build` 成功，`scripts/hm.sh test` 340 通过、0 失败、0 忽略，`scripts/hm.sh lint` 0 错误、0 警告，保留一条既有模糊效果建议。通过 `scripts/hm.sh run` 构建并安装签名 HAP `8af153bd…`。在直板机亮色主题通过隔离 HTTPS 实际读取合成玩家与场次，核对选择题作答的选项键和文案、填空长文本原始换行和自动换行、正确记录只显示判题结果，以及返回设置与退出账号。补充内容的夜间原图及华为锁屏通知送达和点击待后续验证。[测试报告](../artifacts/validation/progress-watches-followup-20261126-native/local-test-summary.json) · [真机报告](../artifacts/validation/progress-watches-followup-20261126-native/isolated-device-report.json) · [亮色原图](../artifacts/validation/progress-watches-followup-20261126-native/isolated-wrong-answers.png)

## 2026-11-26 答题横滑落定闪屏

- 用户录屏的 2.631–2.679 秒内，连续三帧显示保留下来的顶栏和底部控件。中间区域的近白像素占比约 98.6%，前后两帧约 14%。题面、进度和背景同时消失的范围支持优先处理 `Scroll.fadingEdge`。ArkUI 官方实现为整个滚动区绘制遮罩并进行离屏混合。 [ArkUI 边缘渐隐文档](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-arkui/arkui-ts/ts-container-scrollable-common.md#fadingedge14)
- 改用滚动层之外、仅覆盖状态栏边缘的主题渐变。签名包 `3bd6bf8487163a443037f2ac443e3e56111599432fb8df05588bc25d08212e6a` 构建、双验签、安装启动成功，Hypium 323 项通过，lint 无错误或警告。 [验签](../artifacts/validation/aurora-glass-v2-20261125/switch-black-flash-20261126/source/signature.json) · [单测](../artifacts/validation/aurora-glass-v2-20261125/switch-black-flash-20261126/source/local-test-summary.json)
- 固定隔离预览浅色直板机的第 4、5 题交替横滑六次，48 张分时画面中的中间区域近白比例最高 32.8%，近黑比例最高 0.8%。题目均落到对应位置。向下滚动时内容到达视口上缘，顶栏隐藏后可恢复，点返回可到启程。验证结束把应用留在第 4 题。 [真机报告](../artifacts/validation/aurora-glass-v2-20261125/switch-black-flash-20261126/device.json)

## 2026-11-26 启程、收藏与来信未读

- API 26 调试包通过 `scripts/hm.sh build` 和 SDK 双验签。`scripts/hm.sh test` 330 项通过。codelinter 零错误、零警告，保留原有模糊性能建议。 [验签](../artifacts/validation/lobby-unread-20261126/signature.json) · [单测](../artifacts/validation/lobby-unread-20261126/local-test-summary.json) · [lint](../artifacts/validation/lobby-unread-20261126/lint.json)
- 使用相同功能源码的独立测试包经 DevEco 安装，在独立 PocketBase 库中用测试账号验证。直板机首屏同时显示三个数量角标，一次空闲采样记录 1 次 `/home`、1 次 `/me`，以及 0 次独立列表请求。打开场次简介后对应未读点消失，场次继续显示待赴。清空待领奖品提示后卡片仍在。清空来信用 1 次批量回执，邮件仍可访问。冷启动保留清空结果，护照通过「设置」打开完整设置页。 [真机报告](../artifacts/validation/lobby-unread-20261126/device.json)
- 清空并重启后，隔离库为原账号各新增一个场次、一份奖品和一封来信。三栏角标分别恢复为 1。随后按用户反馈将待赴未读点改为圆角呼吸光晕，帧采样核对深浅两色的边缘明暗变化，真机确认进行中卡片的原有光晕和两张卡的进度环均可见。浏览简介后，新场次卡与进度环保留，未读光晕和底栏数字消失。最终源码再次构建并通过 330 项测试，系统减少动画开关尚待直板机操作验证。 [最终包验签](../artifacts/validation/lobby-unread-20261126/glow-signature.json) · [光晕真机报告](../artifacts/validation/lobby-unread-20261126/glow-device.json)

### 主界面切栏请求复核

- Web 正式构建经浏览器请求拦截验证。聚合模式和 404 回退模式各连续切换主栏六次，切换采样窗均为零 GET。聚合模式的空闲周期各发一次 `/home` 和 `/me`。两个可见性事件共用在途 `/home`。选择星海信笺后，原有详情查询按两个可读场次分别发出，切回旅途来信后停止详情轮询。 [浏览器请求序列](../artifacts/validation/lobby-tab-poll-20261126/web-requests.json)
- 鸿蒙独立真实 HTTPS 直板机首屏读取 `/home` 一次。七次主栏切换的采样窗只有 12 轮 `/home` 与 `/me`。主动切到星海信笺复用当前目录，只读两个场次详情各一次，随后空闲周期继续走聚合。用一次 404 `NOT_FOUND` 模拟旧服务后，七次主栏切换保留各独立轮询，旅途来信相邻请求间隔 4.989 至 5.020 秒。 [真机请求计数](../artifacts/validation/lobby-tab-poll-20261126/device-requests.json)
- DevEco 构建与 332 项本地测试通过。真机使用独立回环端口及 CA 的调试包。前后台、手动刷新及信笺正文往返本轮完成源码复核，未逐项采集真机请求。 [本地测试](../artifacts/validation/lobby-tab-poll-20261126/local-test-summary.json)

## 2026-11-26 答题横滑题图与线索过渡

- 冻结 Web `46188fc` 的 `GamePlayPage.tsx` 在切题时从已读场次数据切换题目。原生继续使用 ArkUI Swiper 跟手滑动，前后可读题的题卡同时从 `ordinaryClues` 投影各自已授权的线索与未读标记。未选中题的点击及读屏仍由 Swiper 屏蔽。真实新增的当前题线索面板复用项目的短入场。 [ArkUI Swiper](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-container-swiper/) · [ArkUI 组件内转场](https://developer.huawei.com/consumer/en/doc/HarmonyOS-Guides/arkts-enter-exit-transition/)
- 结构化题图和题干内联图片复用同一主题占位与 ArkUI 渐显。先按可用宽度和 16:9 预留空间，解码后按自然尺寸及原有高度上限布局，过渡时长复用 240ms。缓存命中直接显示，冷加载沿用选中题的下载时机和重试。减少动画时直接应用尺寸与内容。
- 调试包 `4f3e2eefa7515fd54d7cfd8db392eedd12459c5c7408b53f7114ad12403767dc` 完成 `scripts/hm.sh build`、HAP 和签名 profile 双验签及 `scripts/hm.sh run --skip-build` 安装启动。`scripts/hm.sh test` 通过 326 项，`scripts/hm.sh lint` 零错误、零警告，保留一条既有模糊性能建议。 [验签](../artifacts/validation/aurora-glass-v2-20261125/question-media-transition-20261126/signature.json) · [单测](../artifacts/validation/aurora-glass-v2-20261125/question-media-transition-20261126/local-test-summary.json) · [lint](../artifacts/validation/aurora-glass-v2-20261125/question-media-transition-20261126/lint.json)
- 固定隔离预览直板机执行 `python3 artifacts/private/aurora-glass-v2-20261125/question-media-transition-20261126/probe.py`。从第 4 题滑到第 5 题、滑回第 4 题、再滑到第 5 题。题图均显示，第 4、5 题分别显示 1、2 张对应线索卡。第 5 题题图和图片线索可打开，系统返回保留原题，再次返回启程。深色原图核对题图完整。受控弱网的动画逐帧时序、失败重试、读屏及减少动画开关待专项复测。 [真机报告](../artifacts/validation/aurora-glass-v2-20261125/question-media-transition-20261126/device.json)

## 2026-11-26 看图器双击缩放

- 共享看图器使用 ArkUI API 26 的单指 `TapGesture`，与原生拖动、双指捏合并行识别。双击在已有缩放边界内保持点按位置，放大后再次双击回到 100%。系统减少动画时直接应用缩放结果。
- 调试包 `3966e4fb76f5febcc3b187a32cf1f018787e743ddfa63e0baa6749c39a243770` 完成 `scripts/hm.sh build`、HAP 与签名 profile 双验签和 `scripts/hm.sh run --skip-build` 安装启动。`scripts/hm.sh test` 通过 323 项，`scripts/hm.sh lint` 零错误、零警告，有一条既有建议。 [验签](../artifacts/validation/aurora-glass-v2-20261125/image-viewer-double-tap-20261126/source/signature.json) · [单测](../artifacts/validation/aurora-glass-v2-20261125/image-viewer-double-tap-20261126/source/local-test-summary.json) · [lint](../artifacts/validation/aurora-glass-v2-20261125/image-viewer-double-tap-20261126/source/lint.json)
- 固定隔离预览直板机，通过 `python3 artifacts/private/aurora-glass-v2-20261125/image-viewer-double-tap-20261126/probe.py` 在第 5 题实测。偏心双击放大到 200%，偏移约 `-35.8vp / 24.1vp`，单指拖动后偏移随手势更新，再次双击恢复到 100% 和零偏移。单击、复位按钮与关闭返回通过，实机原图核对底部提示完整。双指捏合、图集切换与减少动画开关未在本轮真机复测。 [真机报告](../artifacts/validation/aurora-glass-v2-20261125/image-viewer-double-tap-20261126/device.json)

## 2026-11-26 护照抽屉玻璃蒙层

- 「修改资料」「修改密码」「外观」沿用同一个原生 `bindSheet`。此前仅设定背景蒙层颜色，面板材质只影响面板自身。现在通过现有 `StarwardModalBackdropState` 在入场时登记根窗口的 `StarwardGlassBackdrop`，关闭完成或编辑会话失效时释放。原生 Sheet 继续处理蒙层点击、手势和键盘避让。 [ArkUI 半模态参考](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-attributes-sheet-transition)
- 调试包 `a29f71d4a34e28a84eea6fa78f405d2b706488be8ed2cac48ffce7f0ed9bdb09` 完成 `scripts/hm.sh build`、HAP 和签名 profile 双验签以及 `scripts/hm.sh run --skip-build` 安装启动。`scripts/hm.sh test` 323 项通过，`scripts/hm.sh lint` 无错误和警告，保留一条既有建议。 [验签](../artifacts/validation/aurora-glass-v2-20261125/passport-sheet-backdrop-20261126/source/signature.json) · [单测](../artifacts/validation/aurora-glass-v2-20261125/passport-sheet-backdrop-20261126/source/local-test-summary.json) · [lint](../artifacts/validation/aurora-glass-v2-20261125/passport-sheet-backdrop-20261126/source/lint.json)
- 固定隔离预览直板机以 `python3 artifacts/private/aurora-glass-v2-20261125/passport-sheet-backdrop-20261126/probe.py after` 顺序核对资料、密码、外观。护照标题采样区在旧版浅色蒙层下保留 95.7% 强边缘，改后的三个抽屉在深浅两色均为 0%，关闭后的采样恢复到无抽屉基准。两主题密码抽屉原图核对状态栏背景连续，底层卡片轮廓和表单文字可辨。点遮罩、系统返回、重新打开、切换主题，以及昵称输入时先返回收键盘、再返回关闭均实测通过。未触发资料或密码保存，测试后恢复原主题。账号切换清理及关闭系统材质的回退本轮未单独注入。 [真机报告](../artifacts/validation/aurora-glass-v2-20261125/passport-sheet-backdrop-20261126/device.json)

## 2026-11-26 填空作答栏编辑材质

- 同一个 ArkUI `TextInput` 通过 `onEditChange` 切换后方的圆角背景。编辑态使用原生 `backdropBlur` 与现有深浅主题抬升底色，应用关闭材质时以实色保持对比度。胶囊高 50vp，原生键盘、焦点、输入草稿和作答栏布局沿用现有路径。该版本空闲层配置了 `THIN`，页面内生效限制及修正见后续空闲玻璃记录。 [输入编辑状态](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-textinput/) · [ArkUI 背景模糊](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-attributes-background/)
- 调试包 `161083c5023728c14ccc4b8e3f2e02a95f9debf0b7b1b79c703ee848c7ec3ed7` 完成 `scripts/hm.sh build`、HAP 和签名 profile 双验签，以及 `scripts/hm.sh run --skip-build` 安装启动。`scripts/hm.sh test` 通过 323 项，`scripts/hm.sh lint` 无错误或警告，有一条既有建议。 [验签](../artifacts/validation/aurora-glass-v2-20261125/gameplay-input-material-20261126/source/signature.json) · [单测](../artifacts/validation/aurora-glass-v2-20261125/gameplay-input-material-20261126/source/local-test-summary.json) · [lint](../artifacts/validation/aurora-glass-v2-20261125/gameplay-input-material-20261126/source/lint.json)
- 固定隔离预览直板机在「关于初见的故事」第 5 题实点输入框并按系统返回，对照深浅原图与键盘避让。编辑态胶囊位于键盘上方，输入提示与光标可辨。浅色修改前后同位置采样的平均水平灰度边缘差从 5.149 降至 1.177，胶囊外同图取样不变。两种主题收起键盘后，输入框内部采样与各自未编辑原图像素一致。实测输入、收起键盘、再次聚焦保留草稿，随后清空测试草稿、恢复原主题。使用 `devecocli ui layout --mode full --format json`、`devecocli ui screenshot --path` 和 `hdc shell uitest uiInput keyEvent Back` 采集，深色采集和对照计算见私有证据目录的 `probe.py` 和 `compare.py`。只读题和应用关闭材质后的回退未在本轮真机复测。 [真机报告](../artifacts/validation/aurora-glass-v2-20261125/gameplay-input-material-20261126/device.json)

## 2026-11-26 作答栏空闲玻璃

- API 26 的完整系统折射在指定区域和组件中生效。作答区的未编辑输入和折叠选择栏共用 `StarwardAnswerCapsuleMaterial`，用 ArkUI `backgroundEffect` 实时采样背后的题面，复用 `glass_floating` 并按能力启用 UIDesignKit 静态边缘光。窗口失活时由 ArkUI 切至主题抬升色。光效初始化失败时玻璃底板继续绘制，编辑态沿用已验证的局部模糊。 [沉浸光感生效范围](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/arkts-immersive-light-sense-faq/) · [UIDesignKit 点光源](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-references/ui-design-hdseffect/)
- 调试包 `9a15bb5bb9b2e429e8aef3188d234cc38ae9f41df3e506fe289221eee4a82ad0` 完成 `scripts/hm.sh build`、HAP 和签名 profile 双验签，以及 `scripts/hm.sh run --skip-build` 安装启动。`scripts/hm.sh test` 通过 323 项，`scripts/hm.sh lint` 无错误或警告，有一条既有建议。 [验签](../artifacts/validation/aurora-glass-v2-20261125/gameplay-idle-glass-20261126/source/signature.json) · [单测](../artifacts/validation/aurora-glass-v2-20261125/gameplay-idle-glass-20261126/source/local-test-summary.json) · [lint](../artifacts/validation/aurora-glass-v2-20261125/gameplay-idle-glass-20261126/source/lint.json)
- 固定隔离预览直板机通过私有 `gameplay-idle-glass-20261126/probe.py after --interaction --editing` 采集第 3 至 5 题。深浅原图核对填空和选择胶囊后方的线索依稀可辨，答案和操作文本可读。浅色同位置内部灰度边缘均值由 12.372 降至 1.176（只读填空），由 17.809 降至 1.164（折叠选择）。空闲胶囊几何一致，选项展开和 Back 关闭通过。填空键盘起落通过，编辑态采样与上一版一致，收键盘后回到空闲玻璃。应用材质关停和失活回退未单独注入。 [真机报告](../artifacts/validation/aurora-glass-v2-20261125/gameplay-idle-glass-20261126/device.json)

## 2026-11-26 原生光感宿主

- 独立签名包通过 `python3 artifacts/private/starward-native-tabs-probe/run-probe.py --mode arkui hds control` 对照 ArkUI Tabs、HdsTabs 与普通作答底座。明确设置页签宽高后，两种页签都显示原生折射，真机通过文本焦点、键盘避让、输入草稿、Back 后位置恢复和单独按钮。ArkUI 点击输入／按钮各额外派发一次页签点击，HdsTabs 两次均为零；两者都保留原生 `TabBar` 祖先。正式答题页的 Swiper 和锚定选项联动、读屏及外接键盘未纳入独立实验。 [试验报告](../artifacts/validation/aurora-glass-v2-20261125/native-glass-hosts-20261126/tab-host-experiment.json)
- 旧头像侧栏由官方 `PromptAction.openCustomDialog` 使用 `THICK` 沉浸材质。答题选择沿用原生 `bindPopup` 锚点并通过 `CustomPopupOptions.systemMaterial` 采用同档材质。首个整合签名包实测浮层与作答栏相距 12vp，四个 Radio 均禁用，关闭按钮、外侧点按、系统返回均回到同题。题图的红绿轮廓透过浮层可辨。该固定样本不具备可操作的选项媒体和超长选项，未在本轮实测。 [弹层参考](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-references/ts-universal-attributes-popup/) · [选择浮层整套实测](../artifacts/validation/aurora-glass-v2-20261125/native-glass-hosts-20261126/choice-popup-device.json)
- 启程在自身页签内用 `Navigation.title` 承载身份和品牌标记。原生标题宿主透明，`THICK` 材质作用在各胶囊表面。关闭材质阴影后，旧标题下沿的分界消失，15 个跨边界像素全部与页面原底色一致。收藏切回启程的 20 帧均保持正文可见，头像到护照及返回通过。用私有 `native-glass-hosts-20261126/lobby.py` 复现。 [启程真机报告](../artifacts/validation/aurora-glass-v2-20261125/native-glass-hosts-20261126/lobby-title-device.json)
- 答题在透明 `NavDestination.title` 中绘制返回与场次名胶囊，材质为 `THICK`，背景延续原有页面与状态栏过渡。浅色真机同题取胶囊外和状态栏 8 个点，与原页面最大通道差 1。上下滚动显隐时答题视口尺寸一致，真实 IME 期间标题常显，点返回到启程。选择浮层打开和 Back 返回在最终包通过。用私有 `native-glass-hosts-20261126/gameplay-title-probe.py` 复现。正确星芒期间标题按实际遮挡状态隐藏，该状态及深色标题本轮未单独实测。 [答题真机报告](../artifacts/validation/aurora-glass-v2-20261125/native-glass-hosts-20261126/gameplay-title.json)
- 调试包 `511a058014d194781bcece607fddf9f0fabc48d9d9224afc7060464df3b50a33` 完成 `scripts/hm.sh build`、HAP 和签名 profile 双验签，以及 `scripts/hm.sh run --skip-build` 安装启动。`scripts/hm.sh test` 通过 323 项。`scripts/hm.sh lint` 无错误或警告，保留一条既有建议。 [验签](../artifacts/validation/aurora-glass-v2-20261125/native-glass-hosts-20261126/source/signature.json) · [单测](../artifacts/validation/aurora-glass-v2-20261125/native-glass-hosts-20261126/source/local-test-summary.json) · [lint](../artifacts/validation/aurora-glass-v2-20261125/native-glass-hosts-20261126/source/lint.json)

## 2026-11-26 正式作答栏浮动页签

- 用户批准在已推送的 `a00fc45` 上接入。单内容页 HdsTabs 承载答题视口和原生浮动底板，现有题目 Swiper 管理切题。50vp 输入和主操作位于 58vp 原生栏内，启用原生背景折射时只使用一层底板。编辑时切到透明栏，保留原生输入实例及局部 18vp 高斯模糊。设备不支持沉浸材质时采用已有作答容器。 [HdsTabs 原生材质](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/ui-design-hdstabs/)
- 隔离真机运行私有 `native-answer-dock-20261126/probe.py --hap <签名包> --label final`。`0f6b5a9b…` 隔离预览通过只读填空、下一题主操作、原生选项及四个禁用 Radio、点击外侧与系统返回、真实 IME、草稿及双向横滑。三个状态的作答栏上下边缘均与推送版相差 1px，编辑态恢复原先宽度。 [完整真机行为](../artifacts/validation/aurora-glass-v2-20261125/native-answer-dock-20261126/device.json)
- 最终包 `223263aee30331b1baf1fed3844de80838dc1eda1c5a6195f6bc03a5b872cce6` 额外关掉编辑态的系统分隔线，完成构建、双验签和安装启动。`scripts/hm.sh test` 323 项通过，lint 零错误、零警告与一条既有建议。 [验签](../artifacts/validation/aurora-glass-v2-20261125/native-answer-dock-20261126/source/signature.json) · [单测](../artifacts/validation/aurora-glass-v2-20261125/native-answer-dock-20261126/source/local-test-summary.json) · [lint](../artifacts/validation/aurora-glass-v2-20261125/native-answer-dock-20261126/source/lint.json)
- 最终包用私有 `ime_quick.py` 和 `scroll_check.py` 在同一隔离预览复验。真实 IME 收起后，浮动栏和内容视口恢复原坐标。输入框外三个采样点与已批准编辑态的最大 RGB 通道差为 1。上下滚动时题面移动、标题隐显，作答栏与视口位置固定，随后通过进度星点切题。本轮使用浅色主题及触控，未单独测试深色、无材质设备、无作答内容状态、读屏和外接键盘。 [最终包真机报告](../artifacts/validation/aurora-glass-v2-20261125/native-answer-dock-20261126/final-package-device.json)

## 2026-11-27 作答栏独立胶囊和智感握姿

- 在直板机独立示例上验证 HdsTabs 的 MiniBar。收起时迷你栏固定 58vp，展开至 120vp 时主栏收缩为 58vp。正式作答栏保留透明的原生 TabBar。输入／选项与可执行的空闲主操作各用 `THICK`。主操作在材质上铺到边缘的半透明冰蓝渐变，使用白色前景。禁用使用原生背景模糊与低强调冰蓝色，取消操作阴影。 [MiniBar 探针](../artifacts/validation/aurora-glass-v2-20261125/split-dock-20261127/minibar-probe.json) · [系统材质生效范围](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/arkts-immersive-light-sense-component-adaptation/)
- `HoldingHand.ets` 使用 API 26 SDK 的 `motion.on('holdingHandChanged')`。仅在当前可见答题栏监听，离开时释放，识别结果只在本地驱动布局。清单中的 `ohos.permission.DETECT_GESTURE` 属系统授权。未握持、两手和未知状态按默认右侧显示。 [官方动作感知指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/motion-guidelines/) · [系统授权权限](https://developer.huawei.com/consumer/cn/doc/harmonyOS-guides/permissions-for-all/#ohospermissiondetect_gesture)
- 先前候选在固定隔离直板机验证了实际键盘避让、重聚焦草稿、原生横滑及「前往下一题」。选择浮层居中，四项只读，关闭按钮、外侧点击与系统返回可关闭。独立包注入左侧事件后验证镜像及同一浮层锚点。用户随后在真机确认真实左右手换握可切换按钮位置。 [真机交互](../artifacts/validation/aurora-glass-v2-20261125/split-dock-20261127/device.json) · [左侧布局检查](../artifacts/validation/aurora-glass-v2-20261125/split-dock-20261127/injected-left.json)
- 蓝底白字版本 `scripts/hm.sh build` 成功，SDK 完成 HAP 与 profile 验签。 `scripts/hm.sh test` 通过 340 项，`scripts/hm.sh lint` 为零错误、零警告及一条既有建议。 [验签](../artifacts/validation/aurora-glass-v2-20261125/split-dock-20261127/blue/signature.json) · [单测](../artifacts/validation/aurora-glass-v2-20261125/split-dock-20261127/blue/local-test-summary.json) · [lint](../artifacts/validation/aurora-glass-v2-20261125/split-dock-20261127/blue/lint.json)
- 蓝底白字候选装至固定隔离直板机，浅色和深色均核对可用蓝底白色前景、无白色描边、浮层展开后的原生禁用和浮层居中。外观已恢复「跟随系统」。 [深浅主题真机报告](../artifacts/validation/aurora-glass-v2-20261125/split-dock-20261127/color-device.json)
- 以归档的权威永久锁定选择题快照，在隔离 HTTPS 真机验证淡冰蓝禁用操作。测试包只更换隔离 CA。点击提交无效且下缘无残影，四个选项可看但不可改选，系统返回后锁定及错误次数保持原值。服务收到零次答题及入场请求。已恢复固定预览连接并安装最新签名包。深色锁定、无材质设备、读屏和外接键盘未单独实测。 [锁定真机报告](../artifacts/validation/aurora-glass-v2-20261125/split-dock-20261127/blue/locked-ice-device.json) · [截图](../artifacts/validation/aurora-glass-v2-20261125/split-dock-20261127/blue/locked-ice-dock.png) · [最新验签](../artifacts/validation/aurora-glass-v2-20261125/split-dock-20261127/inactive/signature.json)

## 2026-11-26 全屏判题反馈与圆角

- 最终包复用答对星芒的全屏蒙层和位置。答错暖玫瑰色双环、提示图标与进度条直叠玻璃。一次性真机 HTTPS 选择题验证关闭后的原题、有效答题回执以及 503 的胶囊重试恢复。两帧进度线实心段从 245px 缩到 69px，之后自动关闭。另用早期包验证草稿清空重进、各类关闭和正确 EXP 回执。保留两个签名包的独立行为记录。 [全屏反馈](../artifacts/validation/aurora-glass-v2-20261125/answer-judgment-20261126/countdown-device.json) · [草稿与回执](../artifacts/validation/aurora-glass-v2-20261125/answer-judgment-20261126/isolated-device.json)
- `AnswerHaptics` 使用 API 26 SensorServiceKit。按有效回执选择成功、失败预设，不支持指定预设时各用一次不同时长的触摸反馈。两版 HAP 含 `ohos.permission.VIBRATE`。实际马达振感、系统触感关闭后的行为、减少动画和深色外观均未单独实测。 [华为振动接口](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-vibrator/)
- 固定预览及一次性隔离包通过 SDK HAP 与 profile 验签，编译产物及模块清单逐字节一致。最终包已通过官方 `scripts/hm.sh run --skip-build` 装机并恢复到固定预览首页。 `scripts/hm.sh test` 通过 324 项，lint 零错误与警告，有一条既有建议。一次性测试环境已停止。 [验签](../artifacts/validation/aurora-glass-v2-20261125/answer-judgment-20261126/signature.json) · [单测](../artifacts/validation/aurora-glass-v2-20261125/answer-judgment-20261126/local-test-summary.json) · [lint](../artifacts/validation/aurora-glass-v2-20261125/answer-judgment-20261126/lint.json)

## 2026-11-26 答题触感与作答栏切题过渡

- `ohos.permission.VIBRATE` 为已声明的系统授权，权限校验拒绝使用 `201`。应用按 `physicalFeedback` 调用，受系统触感反馈开关控制。本机该开关原为关闭，预设及短振回退返回 `14600101`。临时启用后，两种预设都成功，随后恢复原系统状态。另核对应用开关默认开启、关闭值跨冷启动保留，以及应用内入口打开官方声音和振动页面。 [权限清单](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/permissions-for-all/) · [振动场景和权限错误](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-vibrator/) · [设备操作错误](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/errorcode-vibrator/) · [系统开关复原](../artifacts/validation/aurora-glass-v2-20261125/answer-haptics-transition-20261126/system-switch.json)
- 最终隔离包验证已答填空与待答选择双向横滑、恢复已选项、相同的浮动底板边界和选择浮层命中。包含多次自动化输入的第一轮收到 3 个有效回执，超出原计划的 2 个，保留原报告并拆分补验。最终同包单次选择题点击产生 1 个新回执和 1 次成功下发的失败振动，短滑取消无额外回执。只记录系统接受调用，未人工判断触感强弱或逐帧量测动画。 [双向滑动与预设回执](../artifacts/validation/aurora-glass-v2-20261125/answer-haptics-transition-20261126/device-final.json) · [单击与系统设置入口](../artifacts/validation/aurora-glass-v2-20261125/answer-haptics-transition-20261126/device-link-and-motion.json)
- 固定预览包和隔离包均完成 SDK 双验签，编译代码和模块清单一致。已安装固定预览包并停止一次性隔离环境。本地测试 324 项通过，lint 无错误和警告，保留一条既有建议。 [验签](../artifacts/validation/aurora-glass-v2-20261125/answer-haptics-transition-20261126/signature.json) · [单测](../artifacts/validation/aurora-glass-v2-20261125/answer-haptics-transition-20261126/local-test-summary.json)

## 2026-11-26 答题视频全屏方向

- 答题的原生 ArkUI Video 收到当前尝试的全屏事件后，使用现有旋转校正后的显示尺寸选择方向。主窗口通过 `getPreferredOrientation` 保存原策略并串行更新。离开全屏、失败、关闭和授权失效释放对应请求。 [华为窗口方向 API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-window-window/)
- 固定隔离预览已完成场次「清宫那点事」的通关线索，普通封面打开保持 1260×2720，点原生全屏后为 2720×1260，第一次系统返回回到竖屏视频预览，第二次返回第 1 题。试验只读取现有进度和视频。竖版、旋转元数据样本的实播以及独立的 BGM 交互未复验。 [真机报告](../artifacts/validation/aurora-glass-v2-20261125/video-fullscreen-20261126/landscape-device.json)
- 官方调试构建、安装与 SDK 双验签通过。本地 Hypium 326 项通过，两项新增覆盖比例选择、保存原策略和并发进入退出。lint 无错误和警告，有一条既有建议。 [签名](../artifacts/validation/aurora-glass-v2-20261125/video-fullscreen-20261126/signature.json) · [单测](../artifacts/validation/aurora-glass-v2-20261125/video-fullscreen-20261126/local-test-summary.json)

## 官方本机输入

- IDE：`/Applications/DevEco-Studio.app/Contents`。
- 工程模板：`plugins/openharmony/lib/templates/project/New Project/code template/`。
- 模块模板：`plugins/openharmony/lib/templates/module/New Module/code template/`。
- Empty Ability：`plugins/openharmony/lib/templates/ability/Empty Ability/code template/`。
- 工程配置 schema：`tools/hvigor/hvigor-ohos-plugin/res/schemas/ohos-project-build-profile-schema.json`。
- 模块配置 schema：同目录 `ohos-module-build-profile-schema.json`。

工程级 `hvigorfile.ts` 导入 `appTasks`；HAP 模块导入 `hapTasks`，来源都是 `@ohos/hvigor-ohos-plugin`。二者导出 `{ system: appTasks/hapTasks, plugins: [] }`。工程 `build-profile.json5` 负责 products、SDK、runtimeOS、签名与 modules；模块文件负责 `apiType: stageMode`、buildOption、targets。模板中的 `signingConfig: default` 不能证明签名材料存在。

SDK 安装元数据为 HarmonyOS 26.0.0 Release / API26 / 26.0.0.105。商业 HarmonyOS 工程使用 `runtimeOS: HarmonyOS`；SDK 字符串应与工程生成器结果和真实编译器核验。不要因为 SDK 内含 `openharmony` 目录改为 OpenHarmony 目标。

## 命令入口

以下命令应在本项目根目录执行，构建脚本统一使用 IDE 配套运行时。

```sh
export NODE_HOME=/Applications/DevEco-Studio.app/Contents/tools/node
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
export PATH="$NODE_HOME/bin:$PATH"
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw --version
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw --mode module -p product=default -p module=entry@default -p buildMode=debug assembleHap --no-daemon
```

`DEVECO_SDK_HOME` 由内置插件的 `src/sdk/lib/property-get.js` 支持。Hvigor 的 `--help` 已实际执行；上面的 `assembleHap` 仍需有工程后真实执行确认。无签名材料时保留 unsigned HAP 构建验证，不把它算成安装验证。

已安装 CLI 的 `--help` 确认以下入口（本次未使用它们写工程或签名）：

```sh
devecocli create --project-path <new-directory> --app-name Starward --bundle-name com.sitkin.starward --api-level 26
devecocli build --product default --modules entry --build-mode debug
devecocli signature generate --help
```

`create` 的现有目录覆盖行为须在新临时目录中核验，避免覆盖本项目已有 docs 和配置。签名生成属于独立步骤，可能要求华为开发者账号，不应复制其他应用的签名配置。

## Local Test / Hypium

实际读取了 CLI 自带官方文档：

```sh
devecocli docs read '开发指南/开发自测试/测试框架/代码测试/Local_Test/ide-local-test'
devecocli docs read 'FAQ/应用测试/使用命令行执行单元测试脚本常见问题和解决方案/faqs-app-test-26'
```

[官方 Local Test 指南](https://developer.huawei.com/consumer/cn/doc/doccenter-deveco-studio/ide-local-test)明确支持 Stage 模型 ArkTS，不能测试系统 API 或 C/C++。测试位于模块 `src/test/`，手写测试要在 `List.test.ets` 引用。

```sh
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw test -p module=entry -p coverage=false --no-daemon
```

可用 `-p scope=SuiteName#methodName` 或 `-p scope=SuiteName` 限定用例；多个值用英文逗号隔开。API26 文档还支持绝对路径 `.patch/.diff` 的 `-p patch=<path>`。此入口会使用 SDK `previewer/common/bin/Previewer`，不是 Node 替代执行 ArkTS。

必须读取以下真实结果，并核验用例数和失败数：

- `entry/.test/default/intermediates/test/coverage_data/test_result.txt`。
- 启用覆盖率时：`entry/.test/default/outputs/test/reports/index.html`、`coverageReport.json`。
- Previewer 原始日志：`entry/.test/default/intermediates/test/coverage_data/coverage.log`。

只有构建退出码为 0、没有上述结果或用例数为 0 时，不能标记单测通过。脚本必须使用正确 cwd 和上述环境；官方 FAQ 明确把脚本环境变量和 cwd 缺失列为 Local Test 不执行的原因。

## Instrument Test / UiTest 与设备

本次 `hdc list targets` 的只读查询识别到 1 台设备，未记录标识。设备 API、签名可用性仍由实际验证记录确认。未发现家目录 `.ohos/` 签名目录，这不能排除 IDE 或其他安全位置保存账号材料；不能据此宣称已具备调试签名。

官方 FAQ 要求先安装应用 HAP 与 `ohosTest` HAP，再执行测试 runner，例如：

```sh
hdc install <entry-default-signed.hap>
hdc install <entry-ohosTest-signed.hap>
hdc shell aa test -b com.sitkin.starward -m entry_test -s unittest OpenHarmonyTestRunner -s timeout 15000
```

`entry_test` 与 runner 名称必须与最终测试模块生成结果一致。只有安装、启动、测试报告、日志和截图齐全后，才算打通真机验收；Local Test 不能替代 ArkUI UI 验证。
