# 首切片 ArkUI 官方组件接入与验证

始于2026-10-27；2026-10-28追加 `edge-to-edge-v1` 系统区沉浸调整，沿用准则 `arkui-system-v1`。这是用户批准的原生体验调整：保留品牌、业务语义、中文文案和信息布局，顶底栏材质、Tabs、Sheet、Toast、刷新与通用动效交给官方 ArkUI。Web 继续用于业务及内容对照；平台材质和原生容器的差异不算像素复刻缺陷。

## 实现与边界

- `Index.ets` 使用原生 Navigation / NavDestination 自定义标题，保留首页及认证84vp品牌区。窗口全屏后，仅标题内容加真实 status/cutout.max 避让距离，标题材质继续覆盖系统区；详情保留原24vp间距，按真实字体环境换算高度，单行昵称和等级超长时省略。
- `ui/StarwardMaterial.ets` 统一 API26 `uiMaterial.ImmersiveMaterial`，先查询支持与配置状态；失败时使用普通主题表面。模块开启 `ohos.arkui.UIMaterial.state=enable`，没有自制 blur/shader 模拟材质。
- `ImmersiveWindow` 在首次页面布局前启用窗口全屏布局和透明系统栏；保留状态栏、手势条显示，按应用实际主题同步系统内容色。布局背景延伸屏边，整个 Navigation 不添加实心占位。
- `StarwardBottomTabs` 使用 `BottomTabBarStyle`、`barOverlap(true)`、`barFloatingStyle`。未实现的业务目的地禁止进入空页面，仅真实点击时用官方 Toast 提示。分类由 `SubTabBarStyle` 承担。
- 首页取消固定同步白块。列表 viewport 延伸到悬浮底栏下；“场次与进度会自动同步，放心去探索。”是自然滚动的最后一项，只为底栏预留末尾间距，没有额外符号。该句不再伪装刷新按钮。
- `StarwardRefresh` 使用官方 Refresh，UI 动效状态与 ViewModel 忙碌状态分离；异步完成、并发门控和账号代次继续由各自边界负责。失败仍展示可恢复的页面错误。
- `StarwardAccountSheet` 使用系统 bindSheet 标题、拖拽条和关闭控件，单个受控布尔值及关闭回传。退出仍清理账号、密码、导航和业务内存。
- `StarwardFeedback` 使用窗口级 PromptAction / AlertDialog，检测 UIContext 生命周期；没有新增业务确认步骤。`StarwardMotion` 读取并订阅系统减少动画设置，离开时解除订阅，业务完成不依赖动画回调。
- 布局采用 Navigation Auto 与实际窗口字体环境。代码具备响应式入口，不等于折叠、悬停、分栏或自由窗口已经验收。

## 已取得的真机证据

`artifacts/validation/native-system-runtime.json` 来自启动前开启的官方 hilog 采集，已冻结供本轮capture核SHA。此 API26 手机报告：支持 immersive material、应用状态 ENABLE(1)、类型 IMMERSIVE(2)、材质档位 EXQUISITE(0)。窗口1320×2848px、density3.375、status避让131px、cutout顶部84px、底部94px，默认字体比例1；实际窗口沉浸模式 enabled，系统栏背景alpha=0。两次实际主题变化分别返回白色与黑色系统内容色；没有通过隐藏系统栏来得到效果。

最终正常字号构建为 `3bacb424dee59591cc7cb9604bc53a3ab9e32e05fb89e2b9ab2cfee8d3eeaebe`。`native-system-runtime.json` 的6项检查通过；`device-system-ui.json` 22/22真机回归已通过，清理两项均true；全状态截图也已按此HAP重新采集完成。修复前 `2b757938…` 的22项UI、4张认证及18张主视觉已保存在 `artifacts/native-pre-final-fixes`，不作为最终修复验收。旧登录/改密布局测量也保留原构建归属。

正常字号实测Scroll底2848px，内容延伸到物理屏边；浮栏顶2531px，底部交互项2544–2707px，在手势安全区上缘2754px之前。末句2419–2473px完整位于浮栏之上。22项覆盖实际深浅系统内容色、标题安全区、Sheet首次打开/Back/退出、原生分类、未开放目的地拦截、Refresh单次新GET及503保留/新GET200恢复、只读详情和边缘返回。

最近复核修复了两个真实问题（ADR-015）：404清空详情后不再展示空模型的默认“0/0”进度；认证表单改用官方页面级 `KeyboardAvoidMode.RESIZE`，按实际IME视口验证字段和主按钮可滚动到达。此前1.3字号仅露出46px按钮的中断记录保留，不能作为通过。

修复后的独立1.3字号HAP `fdda384054fbdb51e1276bc30dfb9fbeb9a7ec850f8fc84f5235e1e95857fad1` 已42/42通过。`device-large-font.json` 绑定 `native-system-font-runtime.json` 来源SHA，实测fontScale约1.3。覆盖登录及三个强改密字段、密码显隐、真实IME下完整CTA、帮助、浮栏与末句、只读详情/返回及退出；新密码确认、singleReady恢复、退出清理均true，cleanup没有额外改密写入。空账号IME有实际PNG；密码焦点只计脱敏UiTest几何，不将先前全黑截图当成主题通过或已确认的系统安全机制。浮栏底2721px在手势区上缘2754px之上，末句2401–2471px完整位于浮栏顶2531px之前。

最终认证4图已经重新采集，输入均为空，唯一实际UI改密响应200已确认，原生Refresh新GET200与新密码登录确认后完成三项清理。同一3bac截图/UI树重新量测：登录控件最大纵差0.283vp、强改密0.513vp，见 `edge-login-layout.json` / `edge-forced-layout.json`。测量绑定本次PNG、UiTest当前字节、auth报告、HAP及runtime来源SHA；不把几何接近推广为字体渲染或平台材质逐像素相同。

最终源码还已复跑 `scripts/hm.sh test`，实际37 passed、0 failed、0 ignored；`scripts/hm.sh lint` 的issues/errors/warnings均0，reported filesChecked=0照实保留。两项均未操作设备，HAP3bac字节前后不变，来源摘要在 `final-source-checks.json`。独立只读源码复核未发现阻塞问题，不能代替实际UI验收。

真实 HTTPS 的完整49项结果保留于 `device-https-acceptance.json`，属于容器迁移前的业务及网络证据；不能由它推定新版全部UI通过。旧主视觉捕获为 incomplete/count5，保存在 `artifacts/native-legacy-pre-system`，不计入新版视觉完成数。

最终认证4图及主视觉18图均为3bac实采，主视觉newCaptured18、无resume继承，cleanup三项均true。404两主题均隐藏未知进度，各自重试产生新的真实GET200后恢复进度。额外四卡图中第二卡文字2750–2811px跨越手势区上缘2754px，证明内容确实延伸至浮栏与手势区后方；附图不计入18。`native-system-visual-content-check.json` 的117项为离线来源及限定内容检查，不是117个新增真机用例。

Web20图与原生22图已建立主配对18/18、显式404故障2/2、原生账号IME2/2；报告HTTP14/14及浏览器22状态逐图加载检查通过，无页面或CSP错误。来源覆盖不等于视觉逐像素验收。复核还保留两处非官方细节差异：卡片编号栏菱形位置及轻微重叠，404按钮“重试”与Web“重新尝试”；它们单列待调整，不归为官方材质批准差异。

默认mock已重新签名安装，HAP `82baeefc…`，`device-smoke.json` 13/13通过，`native-mock-runtime.json` 4项通过，实际fontScale1及系统栏透明；`native-final-mock-audit.json` 确认App源码匹配本次冻结源码，包内没有隔离配置、临时CA或私钥/keystore。三种构建归属分别记录，不以mock冒烟替代3bac真实HTTPS。临时HTTPS服务、测试容器/数据库及自身USB映射已清理，静态对照预览保留。结果同步于[切片记录](slice-01-validation.md)及[逐项验收表](feature-acceptance-matrix.md)。构建成功不能代替后续验收。

## 限制

本轮不修改生产业务数据、原Web或后端源码。跨日后旧测试控制端不能更新场景，原因未确认；仅重建一次性数据库与随机测试玩家，保留原CA、证书、HTTPS入口及冻结后端源码，见 `edge-isolation-recreated.json`。旧环境报告与快照作为历史档案保留，不将旧账号结果冒作新账号测试。真实网络为专用账号、临时 PocketBase 数据库及严格校验证书的 USB HTTPS 转发；不等同公网生产联调。系统不支持材质时的代码降级已实现，未在不支持该能力的第二台设备上实测。尚无连续动效录像、实际读屏播报或折叠/悬停设备证据；这些项目保持待验。
