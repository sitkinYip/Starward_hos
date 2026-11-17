# 首版候选的直板机验收

候选包使用真实 PocketBase 一次性环境和官方 USB HTTPS 映射。启程同步、子页签横滑、冷启和发奖闭环共用同一次签名构建。业务验证只使用各自的专用隔离账号，固定预览在验收后恢复。范围见[逐状态验收表](feature-acceptance-matrix.md)与[冷启星图验收](cold-launch-star-atlas-validation-2026-11-17.md)。

```sh
export STARWARD_VALIDATION_DIR=artifacts/validation/release-prep-20261117
scripts/hm.sh run
scripts/hm.sh test
scripts/hm.sh lint
python3 scripts/capture-window-evidence.py --font-scale 1 --require-tls \
  --output "$STARWARD_VALIDATION_DIR/runtime-isolated-candidate-01.json"
```

启程的停留同步对照冻结 Web `4b7d1a0` 的 `useAssignments` 和 `GameGate`，保持约五秒的请求间隔。来信与护照沿用现有原生版式，内层 Tabs 使用官方内容区横滑。冷启由系统增强启动窗显示日夜星图，已进入 ArkUI 后复用现有恢复界面。

## 构建与已验证范围

候选是通过 DevEco 构建、调试签名并安装到该直板机的 HAP。安装诊断验证了系统栏透明、预期字号，以及隔离 CA 受信、未知 CA 拒绝、主机名不匹配拒绝。[运行与 HTTPS 诊断](../artifacts/validation/release-prep-20261117/runtime-isolated-candidate-01.json)

固定运行时 Hypium 执行 223 例，全部通过。codelinter 无错误和警告，保留一条既有信纸背景模糊的性能建议。[业务测试报告](../artifacts/validation/release-prep-20261117/local-test-summary.json) · [codelinter 报告](../artifacts/validation/release-prep-20261117/lint.json)

启程的真机检查包含后台派发的新场次、远端进度与等级、滚动锚点、503 提示、页面切换暂停以及下拉和旧响应相遇。下拉完成约 5 秒后开始下一轮，旧响应完成后列表保持新数据，整个原生阶段无业务写入。系统后台和轮询直接收到 401 留待独立手机检查，门禁行为已跑 Hypium。[启程逐项证据](feature-acceptance-matrix.md#a11-启程停留时自动同步)

来信与护照的内层页签双向横滑及点按已在直板机通过。单封来信仍能侧滑「收下」且仅发一次已读；跨页保留昵称草稿，离开安全页清除密码草稿。[来信／护照真机记录](../artifacts/validation/release-prep-20261117/native-subtabs-01.json)

奖品闭环使用同一个已安装 HAP。真机答题的首个成功响应断开后，网关记录一次同请求重试；数据库只结算一次，进度、经验和奖品相符。收藏详情显示专属领取指引。管理端核销后，原生详情保持打开并自动回源显示领取时间，专属领取指引同时隐藏。[奖品逐项验收](feature-acceptance-matrix.md#r01b-直板隔离发奖与核销闭环)

同包从桌面实际点按冷启，日间原图采到系统静态星图接入 ArkUI 恢复页，真实 `/me` 返回后正常进入首页。夜间素材已核对打包，真机夜间与系统减少动画留待专项。[冷启验收](cold-launch-star-atlas-validation-2026-11-17.md)

隔离验收后关闭一次性环境，恢复固定预览。预览包采用独立 CA，ArkTS 字节码、启动窗和日夜素材与已验候选包逐字节相同。直板冷启无需输入凭据即恢复固定账号首页，场次进度与经验保持原样。手机已留在预览首页。[包内对照](../artifacts/validation/release-prep-20261117/candidate-versions-01.json) · [固定预览状态](../artifacts/validation/release-prep-20261117/fixed-preview-final.json)

本次签名、安装与运行结论属于 USB 隔离候选。当前客户端只接受预先打包的隔离 HTTPS 配置，缺少该配置时进入演示模式。公开发行还需要生产 HTTPS 配置及真实网络验收，并核定正式应用身份和发行签名。

## Push 接入条件

Push 的调查见 [ADR-010](architecture-decisions.md#adr-010桌面卡片与-push-的边界)。应用获取设备令牌后仍需要服务端做当前账号绑定和发送，请求触发点来自场次派发和来信写入。现有工程没有这两条后端链路，本轮 Push 记录依赖与授权边界。
