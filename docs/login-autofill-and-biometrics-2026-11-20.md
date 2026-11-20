# 登录自动填充与生物认证

## 系统密码保险箱

登录框使用 `InputType.USER_NAME` 和 `InputType.Password`。正式服务登录通过后，应用在表单仍在屏幕树中时调用 `autoFillManager.requestAutoSave`，让系统询问用户是否保存。PocketBase 登录与 `/me` 身份核对先完成，强制改密的临时密码跳过保存。下次需要登录时，点账号框并选择系统保存的账号，填好后点「进入冒险」。手机需设置锁屏密码，并开启「设置 → 隐私和安全 → 密码保险箱 → 自动填充和保存」。系统按设备配置处理填充认证。[华为快速适配](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/passwordvault-quick-adaptation) · [填充流程](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/passwordvault-autofill-acc-password) · [保存接口](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-app-ability-autofillmanager)

固定预览和普通隔离样包共用正式包名，继续各自读取按 HTTPS 源与 CA 隔离的续登记录。正式登录表单启用密码保险箱。Web 冻结基线 `4b7d1a0` 已有账号与当前密码的自动完成语义。本轮沿用原生表单的位置、尺寸和遮蔽规则。

## 验证记录

```sh
STARWARD_VALIDATION_DIR=artifacts/validation/login-autofill-20261120 scripts/hm.sh test
STARWARD_VALIDATION_DIR=artifacts/validation/login-autofill-20261120 scripts/hm.sh lint
python3 scripts/build-production-smoke.py
```

DevEco 26.0.0.851、SDK 26.0.0.105 构建并签出了正式服务联调 HAP，包内配置检查和 SDK 签名校验均通过。Hypium 300 项通过，覆盖登录验证失败、首次改密、废弃请求及系统保存接口失败时仍进入首页。codelinter 报告 0 错误、0 警告和 1 项既有信纸模糊性能建议。[Hypium](../artifacts/validation/login-autofill-20261120/local-test-summary.json) · [codelinter](../artifacts/validation/login-autofill-20261120/lint.json)

API 26 直板机使用一次性 PocketBase 测试玩家和独立 CA。以临时工程副本将密码保险箱开关指向该隔离环境，构建号与设备已装的调试包相同。用 `node scripts/prepare-push-smoke.mjs serve` 启动隔离服务，按当次 CA 和端口配置 HTTPS 及 USB reverse，再执行 `scripts/hm.sh build`、`scripts/hm.sh run --skip-build`。该包已实际签名安装和启动。

- 错误口令停留在原表单。正确口令进入首页，系统显示「保存密码」，确认后关闭。
- 冷启续登回到原隔离首页。显式退出后，两个输入框为空。点账号框并选中测试记录，系统填好两项并留在登录页。收起键盘时输入保留，主动点「进入冒险」后经隔离 HTTPS 重新登录。相同凭据未重复提示保存。
- 复核了日间空表单原图和实际键盘交互。系统认证因子、取消填充、夜间原图及与生产 Push 首询同时出现的时序留待对应设备和发行包验证。生产后端和市场分发均未在本轮执行。

通过系统密码保险箱删除了本次生成的测试账号密码，关闭一次性后端和转发。恢复原固定预览包、USB 转发与已登录首页，实测原预览会话冷启续登。

## 指纹和人脸的可行性

密码保险箱已经可以用设备认证解锁已保存的账号密码，实际可用方式取决于机型、设置和录入情况。只为减少手动输入时，现有链路即可覆盖。[华为密码保险箱概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/passwordvault-overview)

如果需要 App 内独立的生物解锁入口，可以复用现有会话。应用已有自动冷启续登，生物解锁作为用户主动启用的安全锁，会在读取仍有效的会话前增加一次系统确认。启用后，把当前账号的续登令牌保存为需要设备认证的 Asset。前台用 `userAuth.getAvailableStatus` 分别检查已录入的指纹和人脸，按官方应用登录场景从 ATL2 验证，声明 `ohos.permission.ACCESS_BIOMETRIC`。用 `preQuery` 的挑战值唤起系统认证窗口，把成功返回的授权交给 Asset，读取后调用 `postQuery`。随后复用 `/me` 的身份、停用和强制改密检查。现有密码入口承担设备无能力、认证取消及会话失效时的恢复。迁移时需同步处理原来仅受设备锁屏保护的续登记录、账号切换和退出删除。这是客户端改造，关键在凭据迁移和真机认证生命周期。[认证能力查询](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/obtain-supported-authentication-capabilities) · [认证 Asset 查询](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/asset-js-query-auth)

如果目标是显式退出、会话过期后仍能在登录页点一次并取得新会话，可采用 Online Authentication Kit 的 FIDO2 通行密钥。用户先在已验证的玩家账号下注册公钥。再次登录时，服务端提供一次性挑战并校验签名，核对玩家状态后签发新令牌。现有 PocketBase 玩家认证使用账号密码，接入时需增加通行密钥注册、验签、撤销和恢复能力。API 26 SDK 已有 `fido2` 接口，仍需验证正式应用身份与 RP 域名绑定、机型支持和真实设备流程。[华为通行密钥概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/onlineauthentication-passkey-intro) · [ArkTS 客户端接口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/onlineauthentication-passkey-arkts)
