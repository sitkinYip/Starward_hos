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
