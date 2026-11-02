# 底栏主题色触摸流光（2026-11-02）

范围仅为沉浸光感底栏的小改，不扩大业务或跨设备回归。固定研发基线：API 26、SDK 26.0.0.105、DevEco Studio 26.0.0.851。

| 官方能力核对 | 本轮决定 |
| --- | --- |
| `uiMaterial.LightEffectOptions.color?: ResourceColor` 自 26.0.0，Stage、`ArkUI.Full`，用于替换默认白色触摸流光 | 底栏传入已有 `$r('app.color.accent')`：浅色绿 `#187B69`、深色金 `#D4BC7D` |
| 标准 SVG `BottomTabBarStyle.iconStyle` 的 `TabBarIconStyle` 仅有选中/未选中颜色，无单图标发光或阴影入口 | 保留现有 regular/fill 图标，本轮不做图标发光；不更换 symbol、自定义页签内容或自制光效 |

依据：[材质 LightEffectOptions](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-uimaterial#lighteffectoptions)、[沉浸式材质视效](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-immersive-light-sense-common-capability)、[TabBarIconStyle](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-container-tabcontent#tabbariconstyle12对象说明)。固定 SDK 声明分别为 `openharmony/ets/api/@ohos.arkui.uiMaterial.d.ts:440` 和 `openharmony/ets/component/tab_content.d.ts:449`。

实现仅改两文件：`StarwardMaterial.create` 增加可选流光颜色，交互开启时传 `{ color }`，未传颜色仍用 `{}`，关闭仍用 `null`；`StarwardTabs` 的底栏传品牌色资源。其他材质、路由、手势、布局及减少动画门控不变。保留 Resource 引用，未提前解析成固定颜色；官方[深浅色适配指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ui-dark-light-color-adaptation)支持 base/dark 同名资源。

局部验证结果：

- 官方 `scripts/hm.sh run`：Root 已观察实际退出码 0；新 HAP SHA-256 为 `ec325357a97501222147b6063056574d8384018376ee7eef12d4209e47a76cb1`。
- 本轮 lint：Root 已观察退出码 0、issues 0，报告为 `artifacts/validation/bottom-bar-theme-light-20261102/lint.json`。
- 同一进程内日夜切换、按压松手及一次启程/护照往返：`local-ui-2.json` 完成7项局部检查。Root查看夜间原始按压图确认金色光晕；日间截图不作颜色通过证据，用户在自动化停止后实际触碰/轻拖并回复“能看到绿色光晕”，单独记录为人工确认。

汇总及来源为 `artifacts/validation/bottom-bar-theme-light-20261102/summary.json`。首轮因预览USB映射丢失而未完成登录的记录保留；只恢复原预览映射，未重置账号或数据。日间不明确的取图和一次原生截图传输失败亦保留原状态，触摸均已抬起；没有用取图成功替代颜色确认。

本轮没有重跑业务大规模回归或修改密码、资料、游戏数据。手机留在已登录的日间首页，自动操作已停止；本结论限当前直板机日夜光晕，不扩写其他设备、中断或减少动画设置覆盖。
