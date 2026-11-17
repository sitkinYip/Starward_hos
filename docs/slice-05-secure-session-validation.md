# 安全续登验收

范围见 [A10 冷启动安全续登](feature-acceptance-matrix.md#a10-冷启动安全续登)。冻结 Web `4b7d1a0` 保存已认证会话，启动时校验 `/me` 后再开放业务页面。原生通过官方 Asset Store Kit 保存令牌及玩家 ID，资产只在设备解锁时读取，不同步到其他设备。固定预览和一次性验收共用手机端回环 URL，但独立 CA 产生不同的资产别名。密码、临时头像令牌、业务缓存和待确认写入仅留在各自原有的会话边界。[Web 认证客户端](/Users/sitkin/my_code/questions-web/src/api/game.client.ts:23) · [系统存储接口](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-asset)

```sh
export STARWARD_VALIDATION_DIR=artifacts/validation/secure-session-20261117
scripts/hm.sh run
scripts/hm.sh test
scripts/hm.sh lint
python3 scripts/capture-window-evidence.py --font-scale 1 --require-tls \
  --output "$STARWARD_VALIDATION_DIR/runtime-isolated-final.json"
STARWARD_SESSION_HAP=$(shasum -a 256 entry/build/default/outputs/default/entry-default-signed.hap | cut -d' ' -f1)
python3 -B artifacts/private/secure-session-20261117/device-session.py \
  --runtime "$STARWARD_VALIDATION_DIR/runtime-isolated-final.json" \
  --hap-sha "$STARWARD_SESSION_HAP" --device-ref artifacts/private/tab-drag-20261117/device-ref.json
```

一次性 PocketBase 和 HTTPS 网关只用于独立测试玩家。官方设备指令结束应用进程，再启动后分别核 UI 门禁和真实请求台账。界面证据、故障注入、业务处理与固定预览分开记录，令牌及私人账号资料留在本机隔离范围。

API 26 调试构建、签名、直板 USB 安装和启动通过，运行时确认透明系统栏并通过三种 TLS 正反例。Hypium 218 项通过，含 `/me` 临时错误、玩家身份不符、旧令牌响应与改密并发，以及退出和凭据保存并发。codelinter 零错误、零警告，信纸性能建议沿用既有记录。[签名版运行时](../artifacts/validation/secure-session-20261117/runtime-isolated-final.json) · [Hypium](../artifacts/validation/secure-session-20261117/local-test-summary.json) · [codelinter](../artifacts/validation/secure-session-20261117/lint.json)

隔离真实 HTTPS 与直板真机 17 项通过。第一次登录仍进入强制改密。重启时延迟一份真实 `/me` 成功响应，等待期间只有恢复界面，回执到达后仍停在强制改密。成功改密只发一次 POST，新进程只用新令牌回源。单次 503 及只断开连接的故障分别验证重新尝试成功，期间没有密码请求。明确退出后重启不再校验旧凭据。后端停用账号产生真实 401，恢复启用并重启也不会重用被清掉的会话。测试还核对失败时选择重新登录、第二个真实玩家的资料，以及台账仅包含四次显式密码登录、一次强制改密和只读请求。[真机验收与台账](../artifacts/validation/secure-session-20261117/native-isolated-01.json)

目视检查与 388 CSS px 宽的冻结 Web 同状态原图。等待页保留星图、文案与读取状态，原生沿用沉浸认证顶栏。两端失败图重放同一 503 错误消息，原生提供重新尝试和重新登录两项可用操作。直板定版截图为日间原图，夜间原生、减少动画开启和连续录屏留待对应设备检查。锁屏拒读由系统资产策略配置，资产删除失败用单测模拟。两种系统状态留待真机专项验收。退出验收在用户界面已经回到登录后结束进程。[Web 重放](../artifacts/validation/secure-session-20261117/web-reference-01.json) · [原图复查](../artifacts/validation/secure-session-20261117/visual-review-01.json)

先在固定预览保存有效会话。随后安装同地址、不同 CA 的隔离验收包，新进程在空白登录页，未读取已有预览令牌。一次性环境清理后重装同 ArkTS 字节码的固定预览包，原固定账号仍直接续登，无需再次填写密码。固定预览数据库、CA、口令文件、进度和经验核对一致，手机留在已登录首页。[命名空间和包来源](../artifacts/validation/secure-session-20261117/environment-scope-01.json) · [固定预览交付](../artifacts/validation/secure-session-20261117/fixed-preview-final.json) · [环境清理](../artifacts/validation/secure-session-20261117/restore-config-01.json)
