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
