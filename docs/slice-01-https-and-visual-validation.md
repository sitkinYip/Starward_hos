# 首切片真实 HTTPS 与视觉复核

始于2026-10-27；2026-10-28追加原生沉浸系统区及键盘修复验证，Asia/Shanghai。本轮延续 [首切片](slice-01-validation.md)，目标是用一次性真实后端补齐原生网络及逐状态验证，并和冻结 Web 做视觉对照。执行结果以最终报告和各条验收记录为准。

## 环境与证据边界

使用 PocketBase 0.40.1、冻结后端 `c28f488d6b682ae213713ccdd2d992595a941ae3` 的真实迁移及 hooks、全新数据库、随机测试玩家。没有访问生产玩家。正常成功响应不改写；单次 503、畸形 DTO、超时与断连单列为故障注入。

链路为真机原生 Network Kit → `https://127.0.0.1:18443` → 官方 HDC USB 反向映射 → 本机 TLS 网关 → 白名单玩家代理 → 真实 PocketBase。临时 CA 只进入本次 App 测试构建，私钥和凭据只保存在 gitignore 的 private 目录；没有改系统信任或关闭证书校验。该结果覆盖隔离 USB 链路，不代表生产域名或公网移动网络已验收。启动、拓扑及清理命令见 [隔离环境](isolated-https-environment.md)。

Web 冻结源码为 `4b7d1a0a00051ac630e459b0fd6c074f821d7455`，原仓库只读；未拿旧 dist 或尚未确认的线上版本充当参考。视觉浏览器回放真实隔离响应快照，不执行浏览器真实改密或生产写入；原生 HTTPS 验收另有请求台账。首切片仍为只读详情，不包含开始、答题、奖品、通知、头像或媒体。

## 已验证的基础事实

| 项目 | 实际结果 | 证据 |
| --- | --- | --- |
| 主机真实协议 | HTTP 25/25、严格 HTTPS 25/25 | `artifacts/validation/real-pb-local-probe.json`、`real-pb-https-probe.json`；包括真实登录、强制改密、token 失效、列表/详情和 files token 的协议形状，后者不等于头像呈现完成 |
| 主机 TLS | 可信 CA 成功、无 CA 拒绝、错误主机名拒绝，3/3 | `artifacts/validation/isolated-tls.json` |
| 原生 TLS | 独立握手三项均通过；两个拒绝均为 TLS_ERROR | `artifacts/validation/native-tls-and-metrics.json`，由真机安全 hilog JSON 提取；负例不复用已经校验的连接 |
| 本地业务测试 | 37/37，0 failed、0 ignored | `artifacts/validation/local-test-summary.json`；增加路由、错误配置失败封闭及改密 5xx/4xx 不自动重试回归 |
| 真实窗口 | 1320×2848 px，density 3.375，top 131 px、bottom 94 px；内容约 391.111×777.185 vp | 同一份真实 metrics；Web 同内容对照使用 391×777 CSS px，原 390×844 基线保留 |

## 联调中发现的问题

- 装饰星图的溢出绘制参与点击命中，覆盖顶栏主题按钮。将装饰层设为 `HitTestMode.None`，并排除全部无障碍子节点；重装后真实截图确认深浅主题切换有效。
- 独立审查发现无效隔离配置会回退到 mock。现在配置存在但无效时使用拒绝认证的 Repository、禁用登录并显示配置错误；没有配置时才使用演示环境。两条实际 Local Test 回归通过。
- 第一轮真实错误账号请求返回 400，登录页面未显示错误。根因是动态字符串通过私有 `@Builder` 的值参数传递，初始空值条件未随请求结果刷新。错误区域改为 V2 `@Param` 组件；重装后相同真实错误账号已显示告警。业务按钮的 busy 文案和详情事实也改为显式参数组件；列表 key 包含实际投影及排序，使同 ID 的服务端状态更新能重建对应卡片，时钟 tick 不进入 key。首次中断报告保留在 `device-https-attempt-01.json`，不能计为通过。
- 官方 UiTest 的 text 操作会追加文本，CLI 对首尾空格的传参还返回参数数目错误。输入辅助器现在先以官方 Ctrl+A/Delete 清空，再安全引用输入，核对明文或掩码长度，且在内存中确认空格保留；错误输出不含输入值。早期不充分的 `/me` 断言已明确作废，正式断言要求本次认证200、注入的 `/me` 200及精确契约错误一一对应。
- 滚动定位曾把仅露出6px的按钮当成目标。现在以当前 App 与 Scroll 的交集、完整控件尺寸、边界指纹和状态文本ID定位；core28已逐状态通过。中断尝试不是完整通过，恢复报告保留检查点SHA链，并剔除重测项防止重复计数。
- 测试 TLS 网关进程曾意外退出，原退出原因没有足够日志确认。已补齐流的 error/abort/close 处理，以 detached 进程沿用原CA、叶证书、端口和USB映射恢复；未重置业务账号。恢复后的严格TLS三项检查见 `artifacts/validation/isolated-tls-resume.json`，不得把推测的退出原因写成事实。

## 视觉证据

原始 Web、同字体控制组、修复前原生图及最终配对的来源、矩形、平台差异见 [视觉对照](web-native-visual-comparison.md)。交互式并排入口为 `artifacts/visual-comparison/index.html`。原生使用有 OFL 授权的 Noto Serif SC；字体及 SVG 许可随仓库保存。

只读开始按钮、未开放的后续导航和隔离环境提示属于明确的切片范围差异。系统栏和字体抗锯齿分别处理，不把整图缩放或配色相似宣称为像素完全一致。

## 最终执行记录

2026-10-28最终真实HTTPS正常字号构建 `3bacb424…` 已完成22/22系统UI、4张认证及18张主视觉实采；18张为单次全新捕获，无历史继承，清理全true。两主题404不显示空模型默认进度，各自真实GET200重试后恢复。6项runtime记录实际系统栏透明、两主题图标颜色、真实避让区及严格TLS三项。独立1.3字号构建 `fdda3840…` 42/42通过，IME可达与截图范围分别记录。

最终同源码Local Test37/37、0失败/忽略；lint 0 errors/0 warnings（summary.filesChecked=0照实保留），见 `final-source-checks.json`。默认mock另行签名安装HAP `82baeefc…`，13/13冒烟与4项runtime通过，包内无隔离地址、临时CA或私钥/keystore，见 `native-final-mock-audit.json`。

视觉报告覆盖20张Web、22张原生，主配对18/18、显式404故障2/2、原生账号IME2/2；HTTP14/14、浏览器22状态逐图加载与尺寸检查通过，无page/CSP错误。`pairs.json` SHA为 `6f9ac03c3ce9a81af067149c1a817f17f118150572efdc13cb2909a22f815a3b`。这是来源覆盖与对照完成，不是逐像素全通过；编号栏菱形位置/轻微重叠、404按钮“重试”与Web“重新尝试”两处非官方细节继续列待调整。

临时HTTPS网关、特定USB映射、一次性后端容器及数据库、Web基线Vite服务已清理，仅保留回环静态[对照预览](http://127.0.0.1:5179/visual-comparison/index.html)。清理证据见 `isolated-environment-cleanup.json`；公开产物扫描另有 `public-artifact-scan.json`。未修改原Web/后端源码或生产数据。实际语音读屏、减少动画设置、连续录像、材质降级第二设备及折叠/悬停/窗口变化保持待验，不记为通过。
