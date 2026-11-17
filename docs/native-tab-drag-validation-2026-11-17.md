# 原生悬浮底栏拖动验收

对应 [V04a](feature-acceptance-matrix.md#v04a-四页签浮动底栏的拖动选择)。旧包从「收藏」拖到「护照」时落在「来信」。拆掉应用的触摸事务及定时回放后仍复现。直板真机的只读探针确认原生收到了正确的终点，同一终点给出的索引取决于起始项。该现象与 OpenHarmony 公开实现中使用子项局部坐标命中父 TabBar 的代码一致，商业系统运行时内部未检查。[真机坐标和索引](../artifacts/validation/ui-tab-drag-20261117/native-coordinate-diagnostic.json) · [开源实现](https://github.com/openharmony/arkui_ace_engine/blob/master/frameworks/core/components_ng/pattern/tabs/tab_bar_pattern.cpp#L3722-L3757)

主导航接入 UIDesignKit `HdsTabs` 的官方浮动样式。`onContentWillChange` 校验目的地，`onChange` 同步已选中的索引。应用保留索引作为侧栏和返回的导航来源。官方沉浸材质、日间绿和夜间金的光色沿用现有品牌令牌。[官方悬浮样式](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ui-design-hds-tabs-bar-floating)

```sh
export STARWARD_VALIDATION_DIR=artifacts/validation/ui-tab-drag-20261117/final-tools
scripts/hm.sh run
scripts/hm.sh test
scripts/hm.sh lint
python3 scripts/capture-window-evidence.py --font-scale 1 --require-tls \
  --output artifacts/validation/ui-tab-drag-20261117/runtime-final.json
python3 -B artifacts/private/tab-drag-20261117/device-tab-matrix.py --inactive \
  --report artifacts/private/tab-drag-20261117/final-matrix.json
```

使用固定预览隔离 HTTPS 和直板真机。API 26 调试构建、签名、安装和启动通过。Hypium 212 项通过，codelinter 零错误、零警告，仍有一条原有的信纸模糊性能建议。[窗口与 TLS](../artifacts/validation/ui-tab-drag-20261117/runtime-final.json) · [固定预览](../artifacts/validation/ui-tab-drag-20261117/preview-login-final.json) · [测试](../artifacts/validation/ui-tab-drag-20261117/final-tools/local-test-summary.json) · [codelinter](../artifacts/validation/ui-tab-drag-20261117/final-tools/lint.json)

官方 DevEco 输入以实际节点中心为起终点。四个当前页各向另外三个页签拖动，共 12 项通过。从未选中的「收藏」起手拖到「来信」及「护照」、四个页签的点按、在「收藏」项内拖动和在收藏内容区横滑也通过。改选用例核对唯一一次原生 `onChange`、目标索引和目标页控件，同项与内容区手势均没有产生切换回调。387.69 vp 宽直板上，新旧底栏的触点中心相同，原始容器下缘差 1 物理像素。[20 项真机明细](../artifacts/validation/ui-tab-drag-20261117/native-tab-matrix-01.json)

同一真机通过侧栏进入「收藏」并读到隔离后端的真实空列表。在同一数据和内容宽度下目视检查了日夜原图，选中项保持主题色填充，首页滚动内容从浮栏下延伸至手势区。护照的真实输入法出现时底栏收起，关闭输入法后恢复在护照，系统返回回到启程。首次联测在切换主题期间出现一次意外跳回「启程」，拆分复测和完整重跑都保留了「收藏」，原因未定位。系统取消手势、密码结果未确认的准入限制、开启减少动画及折叠屏没有独立真机复测。手机保留在固定预览首页。[日夜、侧栏、键盘和返回](../artifacts/validation/ui-tab-drag-20261117/native-tab-followup-01.json)

## 松手后同步图标与主页面

用户反馈快速松手时页面已切换，填充图标有时仍留在旧项。旧包以 2800 px/s 反向快滑复现同类问题。从收藏切到来信，来信文字已变成选中色，收藏图标仍然填充。该次只有通过的 `onContentWillChange`，无 `onChange`。上一轮的 20 项主要检查目标页和回调，未逐手势核对实际 SVG 样式。[V04c](feature-acceptance-matrix.md#v04c-底栏松手后页面与图标同步)

主导航由 HdsTabs 的四个 `TabContent` 承载，场次、阅读等二级路由才进入 `NavPathStack`。`Index.mainIndex` 是应用的唯一主导航索引，同时驱动页面激活、菜单、返回与品牌 SVG。旧代码只在动画完成的 `onChange` 回写；本轮改用官方 `onSelected` 确认选中时更新该索引。`onContentWillChange` 负责准入，`onChange` 只记录诊断。真实图标资源直接从同一个索引计算，底栏材质和手势继续由 HdsTabs 承载。[HdsTabs 回调说明](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ui-design-hdstabs#onselected)

新签名包在直板固定隔离预览上通过 700 至 4600 px/s 的六种官方手势。每次对照同包点按原图，实际目标页与唯一填充图标一致。另用同一设备命令连续执行收藏 → 来信 → 收藏，两次确认回调均按顺序到达，最后显示收藏页与填充图标。侧栏切入收藏、日夜切换和系统返回也通过，恢复原主题与启程首页。只读核对场次、答题、经验、奖励和来信回执数据，记录保持一致。快速手势后的截图取自稳定画面，系统取消和连续逐帧视觉仍在专项范围。[旧包复现与定版原图摘要](../artifacts/validation/ui-tab-selection-20261117/selection-visual-01.json) · [真机签名与 HTTPS](../artifacts/validation/ui-tab-selection-20261117/runtime.json) · [Hypium 223 项](../artifacts/validation/ui-tab-selection-20261117/local-test-summary.json) · [codelinter](../artifacts/validation/ui-tab-selection-20261117/lint.json)
