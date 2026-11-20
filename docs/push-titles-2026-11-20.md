# 系统推送业务标题 · 2026-11-20

用户确认将现有来信或场次标题展示在系统推送中。此前发送器写死品牌标题及通用正文；本次从后端有效业务对象提取标题，正文继续体现订阅关系，不发送通知正文、题面、答案或奖励。

本轮只改变后端通知显示载荷，沿用 `personal_journey_v1` 及现有订阅／营销用途。标题将显示在锁屏并发送给华为，这是本次已确认的展示变化。后台已有标题字段，原生点击仅解析既有 action／业务路由参数；不新增表单、DTO、数据库字段或 App 包。

| 环节 | 当前状态 |
| --- | --- |
| 业务标题、空值／长度／控制字符边界 | 已实现并通过纯边界与真实Goja验证 |
| 后端真实隔离测试及载荷／权限检查 | 已通过：目标21/21、完整154/154，失败/跳过0 |
| 保留 APPROVED=1 的发布程序兼容 | 已通过：新v2固定保留1，旧v1仍固定0；发布工具58/58及两项变异检出 |
| 发布包、备份恢复、无迁移切换、健康与认证边界 | 已完成：无迁移，16:49:22进入recorded revision14，健康200和四项匿名401通过 |
| 单人生产消息的华为接受、手机标题与点击 | 单人SUBSCRIPTION首次accepted / 80000000，用户明确“已收到，标题正确”；点击未重验 |

本次不重新申请消息分类；业务范围和订阅流程保持。华为允许发送端设置 `notification.title`／`body`，已获批分类在相同场景范围内无需重复申请，订阅消息仍须在标题或正文体现订阅关系。[通知发送](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-send-alert/) · [分类申请规则](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-apply-right/)

后端实施与发布计划见相邻后台仓库的 `docs/harmony-push-titles-20261120.md`；本轮不修改 Web 或原生运行代码。

最终生产镜像为 `questions-pocketbase:0.40.1-push-titles-20261120-amd64`，代码、环境和只读挂载已复核；APPROVED=1、正式模式及接收策略保持。数据库仍41集合、46表、18账本，无迁移。新场次标题已通过隔离真实PB验证，本轮未增加生产下发。

最终发布和单人消息证据见[生产摘要](../artifacts/validation/push-titles-20261120/production.json)，测试和变异见[验证摘要](../artifacts/validation/push-titles-20261120/validation.json)。首次Docker默认索引格式在打包闸门被拒，改以同config单平台重出，最终镜像再次验证通过；没有放宽校验器。

默认跨仓契约检查发现Web生成副本缺少既有11月19日订阅类型；本轮契约源无变化，admin-only检查通过。没有改Web运行代码、原生运行代码、签名或客户端安装包，因此本轮未运行原生编译和UI测试。
