# 奇遇收藏验收

2026-11-17。范围见 [R01a](feature-acceptance-matrix.md#r01a-奇遇收藏的奖品列表与详情)。冻结 Web `4b7d1a0` 与当前 Web `7f7c789` 的收藏实现一致。本轮冻结同一组真实隔离 PocketBase 数据，覆盖四份奖品、空收藏、可领取私密内容与两种领取终态。专属口令、登录材料、原图和采集器留在本机私有验收目录。[后端夹具](../artifacts/validation/ui-rewards-collection-20261117/host-fixtures-01.json)

Web 用 388 × 771 CSS px 重放同数据、同图片字节。核对日夜列表、三种状态的详情、图像查看、滚动位置、空态、失败重试、侧栏入口及减少动画。浏览器只重放隔离数据并拦截实时请求。[冻结 Web 对照](../artifacts/validation/ui-rewards-collection-20261117/web-collection-03.json)

```sh
export STARWARD_VALIDATION_DIR=artifacts/validation/ui-rewards-collection-20261117/final-tools
scripts/hm.sh run
scripts/hm.sh test
scripts/hm.sh lint
python3 scripts/capture-window-evidence.py --font-scale 1 --require-tls \
  --output artifacts/validation/ui-rewards-collection-20261117/runtime-isolated-04.json
```

官方 SDK 26 完成调试构建、签名、直板 USB 安装及启动。运行时核对一倍字号、387.69 × 771.08 vp 安全内容区、透明系统栏及三种 HTTPS 信任状态。Hypium 212 项通过，涵盖奖品 DTO 状态、来源账号、旧响应取消、临时错误、详情权限更新及权限终止。codelinter 零错误、零警告，已有的信纸模糊性能建议保留。[运行时](../artifacts/validation/ui-rewards-collection-20261117/runtime-isolated-04.json) · [业务测试](../artifacts/validation/ui-rewards-collection-20261117/final-tools/local-test-summary.json) · [codelinter](../artifacts/validation/ui-rewards-collection-20261117/final-tools/lint.json)

用户指出详情底部固定留白和关窗后残留蒙层。定版把安全间距移动到内层滚动内容，直板日间原图的详情边缘颜色跨过手势避让起点保持一致，初始封面像素延伸到该起点下方约 14.46 vp，滚到底完整显示最后一段。使用关闭按钮、系统返回、点遮罩和下滑后只采集截图，没有再触摸。四次闭合的顶部采样颜色与打开前相同，打开时的最大通道差为 126。图片查看器的系统返回只关闭查看器并回到同一详情。系统减少动画的 Web 对照通过，真机未单独触发开启分支。

定版直板从底栏打开四条收藏，先观察真实读取期间的加载态，再核对封面、状态与数量。可领取详情展示该奖品公开指引及本人专属内容，已领取只展示公开内容及服务器时间，已失效的奖品无专属内容。从已滚动的位置关闭两张终态详情后，按钮坐标偏移均小于或等于 2 物理像素。从未入场场次的头像侧栏进入收藏并返回同一场次。应用后台停止轮询，返回前台恢复。显式退出清理列表和详情，保留进程供另一账号接续。该过程有 32 次使用原始授权头的奖品 GET，业务写入为零。[定版直板收藏及蒙层](../artifacts/validation/ui-rewards-collection-20261117/native-populated-01.json)

第二个账号在同一进程登录，真实列表为空。首次单次 503 截到错误提示，五秒轮询在采集期间先恢复了列表。续测在同一包与账号上持续返回 503，采集原图后恢复网关并点击「重试」，随后取到真实空数据。下拉回源、空态返回启程均通过。独立 404 保留登录状态并在收藏页重试恢复。隔离 SQLite 的奖品、进度、经验和命令台账与准备时一致，应用没有发送领取、核销、入场或答题写入。[首个失败原图记录](../artifacts/validation/ui-rewards-collection-20261117/native-empty-initial-01.json) · [空态与重试](../artifacts/validation/ui-rewards-collection-20261117/native-empty-01.json) · [只读台账](../artifacts/validation/ui-rewards-collection-20261117/native-read-only-audit-01.json)

十二组同数据原图对照中，首张原生卡片宽 347.69 vp、高 224.92 vp，Web 为 348 × 225.28 CSS px，两端封面同为 72 × 72。夜间详情的表面色同样延续到系统手势区。官方弹层的蒙层与单高度拖动标记、原生富文本高亮和日期的时段标记有可见差异。系统减少动画开启仅有 Web 证据，奖品详情内嵌视频沿用播放器，当前夹具实际核对的是图片和富文本。[日夜与手势区原图测量](../artifacts/validation/ui-rewards-collection-20261117/visual-review-01.json)

临时后端及对应 USB 映射已释放。定版在固定预览重新安装，原数据库、账号和 CA 一致，直板通过严格 HTTPS 直登并保留原进度和经验，停在已登录首页。固定预览与隔离包的 ArkTS 字节码一致。[恢复回执](../artifacts/validation/ui-rewards-collection-20261117/restore-config-01.json) · [固定预览](../artifacts/validation/ui-rewards-collection-20261117/fixed-preview-home-01.json) · [包字节码](../artifacts/validation/ui-rewards-collection-20261117/preview-package-equivalence-01.json)
