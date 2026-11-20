# 订阅分类启用 · 2026-11-20

用户反馈原应用的 SUBSCRIPTION 分类已审核通过，但后台定向旅途消息没有收到。主任务核实平台确已通过，服务器仍为 `STARWARD_PUSH_SUBSCRIPTION_APPROVED=0`；账号已完成旅途订阅与独立通知确认，设备绑定有效，未读收件没有对应 Push 任务。平台审核不会自动改服务器配置，后台发送成功也只代表应用内收件已创建。

2026-11-20 16:09:24.657197（北京时间），服务端独立配置激活完成 `enabled-verified`：仅把 approval 从 0 改为 1，保留原镜像、数据库、两项挂载、正式发送模式、运营范围及账号同意。新容器同 ID、零重启、3 条不同的连续健康成功；HTTPS 健康 200，四项匿名保护接口 401。策略、schema、迁移账本和旧根审计保持，密钥仍只读挂载，没有读取或复制内容。

激活前 Compose SHA256 为 `7a78755f21f53f0cae98319c6d175fc052eebc5bf920af17bb02841a1de276c6`，激活后为 `f26ebeb828ff763341d036a37040e52e493fe269e533f73acf1792496b7a6088`；镜像仍为 `sha256:f3e1bc2ff3295772a50a497585bfcf51f4da1134ecdff3f9ec0ae06ac565e96a`。这次没有修改原生或后端运行代码、重新打包 App 或执行数据库迁移。

16:10:50.041（北京时间），主任务仅向当前授权玩家 1 人新发一条无场次的 `personal_journey`。新任务分类为 SUBSCRIPTION、范围 `personal_journey_v1`、同意 revision 17，正式模式 `testMessage=false`，首次尝试 `accepted / 80000000`。用户明确回复「已收到系统通知」；主任务未点开或标已读，没有历史补发，点击回源仍未验。单条成功不扩大为每日频次或所有设备送达保证。

16:11:50 最终只读核对同一已验证容器仍 healthy、零重启，三个开关为 `1 / 0 / 1`，无 active marker，旧审计不变；维护 socket 已关闭并确认路径不存在。见 [生产激活与单条收发证据](../artifacts/validation/push-subscription-activation-20261120/production.json)。现有发布 profile 仍仅支持 `APPROVED=0`，下次后端发布须另审保留当前值 1 的支持，不能为通过旧检查而关闭或改写本次状态。

后端完整步骤、审计与回退边界见 [独立激活记录](../../sitkin-pb-backend-management/docs/harmony-push-subscription-activation-20261120.md)，当前配置以 [生产状态入口](../../sitkin-pb-backend-management/docs/current-production.md) 为准。11 月 19 日公告验证及当时“订阅权益未启用”的日期记录保留原样。

公开脱敏证据见 [生产启用与单条收发](../artifacts/validation/push-subscription-activation-20261120/production.json)。
