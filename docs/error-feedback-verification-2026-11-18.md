# 低干扰错误反馈验收

普通 Toast 不提供用户可点击的关闭键。本轮使用固定 API 26 SDK 中的 [华为 HdsSnackBar](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ui-design-hdssnackbar)，由原生组件处理关闭、退场和键盘避让。沿用项目绿／金主题和原有登录版式。日夜真机原图核对了文本、关闭键、登录主按钮与手势区位置。

| 场景 | 本轮结果 |
| --- | --- |
| 登录断网 | API 26 直板机通过。断开临时 HTTPS 反向映射后真实提交；账号、密码与「进入冒险」三个控件的原始坐标保持不变，无页内错误块或「回到首页」。可点关闭，第二次提交同一失败能再次显示，也能自动收起。恢复原映射后，不重新输入即可完成同一隔离玩家的真实 HTTPS 登录。 |
| 表单与键盘 | 真机通过。空输入与隔离后端实际拒绝的错误密码都留在表单内。网络提示弹出后，可以继续聚焦密码输入；系统键盘打开时浮层向上避让，关闭键仍能点击。 |
| 启程与收藏同步 | 真机通过。先分别收到真实的空列表，再停掉同一临时反向映射。轮询中断时保留原空态，只出现同步提示；手动关闭后，下一轮断网不重新弹。 |
| 星海信笺 | 真机通过已有空目录的刷新。断网后用官方下拉刷新，弹出可关闭提示，原空态保留、没有插入错误块。来源读取失败、权限撤销和切换账号由业务测试覆盖。 |
| 保留的恢复入口 | 首次加载、密码结果未确认和答题、剧情阻断错误这里没有再次走完整真机流程。服务端超时、限流和 TLS 文案、大字号及减少动画没有在本次真机逐项复测。 |

本机 DevEco 构建、SDK 签名验证和真机安装启动均分别核对。运行 `scripts/hm.sh build`、`STARWARD_VALIDATION_DIR=artifacts/validation/error-feedback-polish scripts/hm.sh test` 和同变量的 `scripts/hm.sh lint`。Hypium 实际报告 238 项通过；codelinter 无错误和警告，报告有一项既有信纸模糊建议。

真机复现用 `node scripts/prepare-push-smoke.mjs serve` 的独立 PocketBase 及真实本机 HTTPS 代理，不启用 Push。将当次公开 CA 放入同签名隔离工程：`scripts/configure-integration.py --endpoint https://127.0.0.1:18443 --ca <当次公开 CA> --timeout-ms 3000`，然后 `scripts/hm.sh build`、`scripts/hm.sh run --skip-build`。按发行工具链验证签名和包内配置。用 `hdc rport tcp:18443 tcp:<当次端口>`、`hdc fport rm tcp:18443 tcp:<当次端口>` 控制该隔离连接的恢复与断开；通过官方 UiTest 点按、读取布局、用 DevEco CLI 截图。原始图与设备输出保留在本机私有目录，验收记录不包含登录材料。

[真机与签名回执](../artifacts/validation/error-feedback-polish/device-feedback.json) · [Hypium](../artifacts/validation/error-feedback-polish/local-test-summary.json) · [codelinter](../artifacts/validation/error-feedback-polish/lint.json)
