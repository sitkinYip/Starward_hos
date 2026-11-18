# 赴星之约 · HarmonyOS Push 联调

应用已经在 sitkin 主账号「赴星之约」项目登记。正式包名一直是 `com.sitkin.starward`。现有 0.1.0 邀请包和审核状态保持原样。当前切片只接新场次下发、旅途来信与公告；题库编辑、答题结算和领奖不会触发本轮推送。生产 PocketBase 已部署，运营后台上传成功；生产 Push 保持关闭，0.1.1 邀请真机验收待完成。

## 从业务写入到通知点击

1. 「头像侧栏 → 设置 → 旅途通知」打开 Notification Kit 的系统设置。首次进入已认证首页时尝试一次原生通知授权，拒绝后可继续使用，并由玩家自行进入设置改变选择。未同意隐私、未完成登录或处于强制改密时不申请、登记或处理通知路由。已授权时在冷启后登记，收到 Push Kit 的 token 更新事件或账号凭据轮换后重新登记。
2. App 将随机安装 ID、Push Token 和专用匿名 profile ID 登记到当前已登录的游戏账号。退出、切换或系统关闭通知时，解绑本机 profile，并撤销后端设备绑定。离线撤销凭据保存在系统 Asset 中，与当前 HTTPS 环境及账号绑定；新账号不会复用旧 profile。
3. PocketBase 在原有场次下发或通知发布事务中为授权安装创建发送任务。worker 发前重新核对玩家、绑定和业务状态，过期、已撤回和已读任务跳过。Huawei Push Cloud 与终端分别去重。锁屏文案只显示「旅途有新消息，打开应用查看。」
4. 点击后只识别固定 action 和两种目标。场次进入对应场次并请求现有授权接口；来信和公告打开「来信 → 旅途来信」并重新同步。旧 profile、无效字段和同一进程重复事件会被丢弃。不会因为点击通知自动入场、答题、领取或已读。

[逐状态验收](feature-acceptance-matrix.md#f02-首个-push-切片2026-11-18) · [官方客户端接入](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-gettingstart) · [官方通知与多账号校验](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-send-alert/)

## 云端开通到发布

1. 原应用「增长运营 → 推送服务」已在 2026-11-18 开通，隔离真机联调使用新申请的 Debug Profile。0.1.1（3）使用 DevEco 云签生成带 Push Kit 的发布 Profile，沿用原包名与发布证书。0.1.0 邀请版本未改动。[官方开通步骤](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-config-setting)
2. 在该项目为发送端设置专用服务账号。项目 ID 用于请求路径，和 APP ID 并不通用。私钥 JSON 只以只读文件挂到隔离 PocketBase，使用测试消息标记及专用验收玩家白名单。客户端、配置示例、日志和聊天不保存这把密钥。[官方 JWT 授权](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-jwt-token)
3. 按[真机隔离联调步骤](push-isolated-smoke.md)启动独立 PocketBase 与 HTTPS，再使用 `scripts/configure-integration.py --push-test` 制作调试包；该模式仍要求官方托管隐私通过。`production-invite-push` 专用于后续同包名候选的打包标记。其余既有打包模式不启用 Push，后端不配置开关则不发送。
4. 先验证拒绝授权和改密门禁，再只给隔离玩家下发新场次、旅途来信和公告。记录 Push Cloud 的接收回执、前后台／进程终止后通知实际出现、点击准确打开与回源、后台退出或换账号后旧消息拦截。比较原场次进度与通知已读状态，验证点击没有额外写入。
5. 生产启用前复核当前托管隐私政策对可选系统通知及令牌处理的披露，确认正式消息分类。未取得自分类权益时使用官方默认普通通知额度，消息可能静默进入通知中心。系统权限、华为接受请求、终端收到和内容回源是四个独立证据。[通知分类与频控](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-apply-right)

## 本轮验证

- API 26 官方 DevEco 构建并生成调试签名 HAP，档案确认正式包名及两条 Push action。最终 Hypium 236 项通过。中途有一次原有祝福播放用例超时，完整重跑通过。codelinter 无错误和告警，保留既有信纸模糊建议，报告仅检查到 1 个文件。[构建](../artifacts/validation/push-20261118/signed-debug-build.json) · [最终测试](../artifacts/validation/push-20261118/local-test-summary.json) · [前次超时](../artifacts/validation/push-20261118/local-test-interrupted.json) · [代码检查](../artifacts/validation/push-20261118/lint.json)
- 后端在独立 Linux 容器的 PocketBase 0.40.1 与 OpenSSL 上全量 125 项通过，含 JSVM 用合成服务凭据实签 PS256、独立验签。发送链路使用替身接收端；正式 Alpine 镜像复建受软件包镜像网络阻塞。[后端配置与验收](/Users/sitkin/my_code/sitkin-pb-backend-management/docs/harmony-push.md)
- 无华为凭据的隔离联调启动器已验证专用 CA、拒绝未受信 CA／主机名不符、合成玩家登录、绑定与撤销、三类业务入队、禁止入场／答题／已读写入。
- 开通后已申请并验签同包名的独立 Debug HAP。调试证书保持一致，Profile 包含当前直板机。新 Profile 的应用标识与此前已签名的邀请包相同，和测试机上旧预览包不同。经用户确认后，仅在该测试机卸载旧预览并重装。首次侧载无法拉起隐私声明；按官方调试方式预置同一隐私声明链接后，真机拉起系统弹窗，由用户同意并成功进入隔离账号。拒绝系统通知时后端绑定数为零。系统通知设置的半模态窗口须点「确定」才保存；授权后真机获取非空 Token、绑定匿名 profile，后端确认一条登记。[申请与签名证据](../artifacts/validation/push-20261118/agc-debug-candidate.json) · [直板机登记证据](../artifacts/validation/push-20261118/straight-phone-registration.json) · [隐私托管调试](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/store-privacy/)
- 真实华为 V3 送测只绑定隔离玩家的一台手机，三次发送均一次收到 `80000000`。点击系统通知后，新场次从后台打开正确场次、旅途来信从前台切到信箱、公告在确认进程结束后冷启并续登到信箱。三次回源后场次仍待入场，答题和已读计数均为零。[新场次](../artifacts/validation/push-20261118/straight-phone-assignment.json) · [旅途来信](../artifacts/validation/push-20261118/straight-phone-letter.json) · [冷启公告](../artifacts/validation/push-20261118/straight-phone-cold-announcement.json)
- 退出隔离账号后真机返回登录页，服务端登记从一条归零。Token 轮换、离线补解绑和旧路由拦截有本地用例，本轮未做对应真机专项。[云端与设备联调汇总](../artifacts/validation/push-20261118/straight-phone-live-summary.json)

## 生产部署与剩余验收

2026-11-18，生产 PocketBase 发布 `harmony-push-20261118` 已完成记录（`recorded`，revision 15），无活动发布标记或阻塞。数据库迁移只新增三个空的 Push 集合，现有业务服务已恢复。切换和 finalize 后的生产 HTTPS 健康检查均返回 200；未认证调用管理端 `/me`、场次和管理端 `/push-settings` 均返回 401。发布期间观察到同一容器零重启，连续三个健康探针通过是发布程序的放行条件。

| 环节 | 状态 |
| --- | --- |
| 生产后端 | 已部署；健康与未认证门禁已核验 |
| 运营后台 | 已完成隔离 API 与浏览器验收；生产提交 `3c18d8a` 的 [Deploy to Server](https://github.com/sitkinYip/sitkin-pb-backend-management/actions/runs/44271575294) 已通过后台兼容检查、构建与 SCP 上传。线上登录后的配置读写仍待验 |
| 正式凭据与启用 | 已验证正式密钥与隔离验收属于同一华为项目、使用不同密钥；正式密钥已放入生产主机的 root 私有目录，文件权限为 `0600`。发送关闭的候选配置已通过本地检查，尚未挂载到生产容器；总开关仍关闭，未发送真实通知 |
| 0.1.1（3）邀请候选 | 华为 SDK 已验证 APP 签名与发布 Profile，沿用 0.1.0 的应用标识及发布证书，Profile 包含 `com.huawei.service.push.base_service`。「仅测试」包在 AppGallery Connect 的软件包合法性已达标；上架自检未核验。[签名与平台记录](../artifacts/validation/push-20261118/signed-invite-01.json) |
| 隐私声明 | 0.1.1 使用单独的 [11 月 18 日华为托管隐私声明](https://agreement-drcn.hispace.dbankcloud.cn/index.html?lang=zh&agreementId=2086442120947702528)。已在公开页面核对可选通知、令牌及标识用途、向华为提供的投递信息和关闭方式。只关联 0.1.1 草稿，保留旧版；控制台提示升级后会提示用户重新签署 |
| 邀请分发与生产验证 | 已保存独立的 0.1.1 邀请草稿，计划截止 11 月 30 日 23:59；只使用原有的单人测试群组。新表未继承旧版审核账号，待填写后提交。邀请装机和生产白名单真机登记、送达、点击与解绑待验；生产 Push 保持关闭 |

正式启用前仍需核对托管隐私披露、消息分类，并在限定玩家范围内验证正式登记、送达、点击回源和解绑。后端的发布记录及未认证探针只证明本次后端切换与门禁，未覆盖已登录运营操作或生产消息送达。
