# Starward_hos

赴星之约（HarmonyOS 原生版）

当前处于**基础只读切片完成、任务1资料功能收尾及原生导航调整待验**的阶段：登录/首次改密、首页列表及只读场次详情已接通；任务1的昵称、头像裁剪上传、普通改密及失败恢复已有隔离HTTPS真机证据。2026-10-30新增的键盘隐藏底栏、空心/实心图标、官方侧面板仍须完成新包独立验收，不能继承资料基线结果。原生端还不能开始和完成一次冒险；答题、线索/剧情/媒体、奖品与来信尚未迁移。底栏“启程”“护照”可用，“收藏”“来信”明确提示暂未开放。当前按小功能逐个搬运并验证直板机及真实隔离后端链路，主体功能完成后再集中验证折叠等场景。详见[业务完成度](docs/feature-acceptance-matrix.md)及[任务1验收](docs/slice-02-profile-validation.md)。

ArkTS + 原生ArkUI的Stage工程，研发基线为API26、DevEco Studio26.0.0.851、SDK26.0.0.105。2026-10-30当前 `6a5232af…` 已实际构建、签名安装，**72/72业务测试通过**，lint为**0 issues**（filesChecked=0照实保留），独立六项运行时检查通过。资料基线 `1a40c0ca…` 的core、S2、补充、头像、两类输入边界及24张Web/原生视觉原图已分别验证；迟到响应另用15秒超时变体记录。新包UI主轮仍为incomplete：最新尝试在Host只读前置后首个aa命令失败，HDC设备列表为空，尚未取得本轮UI启动成功及结束后写入增量核验证据。旧 `30de1956…`、`193b1e97…` 和各次未完成报告分别保留，下述首切片历史数量不累计为本次通过数。

首切片已有历史**49项隔离HTTPS流程检查**（含故障注入与1项主机准备）及沉浸调整前**17项原生UI检查**证据。2026-10-28修复空详情默认进度与键盘避让后，彼时源码**37/37业务测试通过、lint 0 issues**，独立**1.3倍字号42/42通过**；正常字号HTTPS构建**22/22系统UI与6项运行时检查通过，认证4图及主视觉18图captured**。上轮默认mock已签名安装，**13/13冒烟和4项运行时检查通过**，不含隔离配置及测试CA。20张Web与22张原生图已逐图对照，彼时仍有菱形装饰位置和重试短文案两项细节待调；旧22项UI及22图保留为修复前证据，不扩写为逐像素一致或生产验收通过。

从 [项目规则](AGENTS.md)、[工具接入](docs/toolchain-and-tools.md)、[架构决策](docs/architecture-decisions.md) 和 [逐状态验收表](docs/feature-acceptance-matrix.md) 开始。当前真实结果见 [首切片验收](docs/slice-01-validation.md)、[HTTPS及视觉复核](docs/slice-01-https-and-visual-validation.md)；Web和后端仓库均为只读基线。

## 本地开发

```sh
scripts/hm.sh doctor
scripts/hm.sh install
scripts/hm.sh build
scripts/hm.sh run
scripts/hm.sh lint
scripts/hm.sh test
```

脚本固定使用Studio配套Node、JBR、SDK和ohpm，需官方 `devecocli@1.3.0-stable`。`test`检查Hypium真实报告、非零数量及失败数；不接受缺失报告。构建产物位于 `entry/build/default/outputs/default/`。

本机通过官方Studio自动签名生成调试配置；CLI stable的USB设备筛选限制及官方IDE替代路径见 [工具记录](docs/toolchain-and-tools.md)。`build-profile.json5`及签名材料必须保持gitignore，版本管理只保留无凭据的 `build-profile.example.json5`；脚本仅在本机根配置缺失时复制样例，不覆盖有效签名。新环境仍须独立配置签名，安装/启动/实际UI分别验证。

## 当前切片与环境

首切片流程为登录 → 首次强制改密 → 待赴之约/旅途回响 → 只读场次详情 → 返回/退出。`starward://assignment/<id>`可保留目标直到登录和强制改密完成；退出清目标和内存凭据。开始按钮禁用，入场、答题、媒体、奖品、通知、卡片和Push尚未实现。任务1新增资料/安全页与头像处理代码，真实验收状态按独立报告记录，不能由编译成功推断。

没有本地打包 `integration.json` 时使用明确标识的mock；演示账号 `alice`、初始密码 `Starward1234`，改后密码仅在本次App进程有效。可用以下命令恢复默认演示配置并重新安装：

```sh
python3 scripts/configure-integration.py
scripts/hm.sh run
python3 scripts/device-smoke.py
```

首切片收尾时设备恢复默认mock，历史产物SHA `82baeefc…`；与真实HTTPS捕获HAP `3bacb424…`、独立字号HAP `fdda3840…` 分别记录，彼时28份App源码匹配其最终记录。任务1最后确认安装的是新UI隔离HTTPS构建 `6a5232af…`，本轮验收、旧环境清理及固定预览安装仍待完成；不能用历史mock结果证明当前代码。

真实联调使用一次性PocketBase、冻结迁移/hooks、随机测试玩家及严格USB HTTPS；临时CA只由该App测试构建信任，没有改系统信任或关闭校验。随机凭据不打包、不打印、不入库；外部Want不能选择API地址，无效隔离配置禁止认证。启动、配置、验收和清理命令见 [隔离HTTPS环境](docs/isolated-https-environment.md)。该链路不等于公网/生产已验证。

按用户要求另准备[固定隔离预览环境](docs/isolated-preview-environment.md)，账号为 `starward_preview`，初始化后完成一次正式首次改密供直接登录；它与故障验收不共用数据库、账号或CA。目前仅prepare完成，尚未启动、初始化和真机登录，不作为已可用的预览账号交付。

首切片上轮临时HTTPS与后端已按资源归属核验后清理：当时专用USB映射、临时CA/私钥、一次性数据库/容器、实时私有状态与三个旧检查点均已移除，其他容器/映射未改。彼时公开扫描 **814个文件、敏感命中0、读取错误0**，原Web与后端工作树改动均0；证据见 [首切片验收](docs/slice-01-validation.md)。任务1重建了新的自有隔离环境，须另记本次清理及扫描，不能继承上轮收尾结论。

UI采用V2与Navigation，保留品牌、文案、业务语义和既定信息布局，通用控件及反馈优先封装官方ArkUI。按 [ADR-013](docs/architecture-decisions.md#adr-013官方-arkui-组件与沉浸光感优先)，顶栏保持布局并使用官方沉浸材质，底栏采用官方浮动Tabs，分类、Sheet、Refresh、Toast及动画使用官方能力；首页移除固定同步块，原句“场次与进度会自动同步，放心去探索。”作为自然滚动内容的最后一项，列表延伸到浮栏下方。2026-10-28再按 [ADR-014](docs/architecture-decisions.md#adr-014系统避让区只约束内容背景与材质延伸到屏幕边缘)让背景和材质延伸到状态栏与手势区，仅按钮等内容保留实际安全距离；系统栏透明且保留显示。当前手机材质受支持并启用，其他设备降级仍待验。详见 [官方ArkUI验证](docs/arkui-system-validation.md)。

按 [ADR-015](docs/architecture-decisions.md#adr-015真实业务事实与页面级键盘避让)，详情不存在时不显示空模型进度，认证页使用官方页面级RESIZE键盘避让。修复后1.3字号验证了密码显隐、普通账号及密码焦点下完整CTA可滚动到达、浮栏/末句、详情返回和退出；普通账号IME有截图，密码焦点只保留脱敏UiTest几何，未将历史黑图计为主题通过。修复前正常字号22项及22图归档到 `artifacts/native-pre-final-fixes/`；新正常字号22项已重新验证透明系统区、真实避让、Scroll到物理底、末句完整露出、Refresh/503恢复及返回/退出。主视觉18图全新单次捕获，404两主题均隐藏默认进度，经各自真实GET200后恢复服务端进度。

Web继续提供业务、布局和逐状态对照；官方材质、反馈及动效属于已批准的平台差异。最终来源配对为主18/18、显式404故障2/2、原生普通账号IME2/2，包含系统区的完整原图已逐图查看；菱形在原生编号栏顶部与01轻微重叠，以及404按钮“重试”对Web“重新尝试”，均是待调整的非官方差异。预览HTTP14/14及22状态图片加载通过，0页面/CSP/非favicon HTTP错误；这些框架检查不计原生UI用例。浏览器回放实际DTO快照只用于视觉，实际网络另查TLS和请求台账。详见 [视觉对照](docs/web-native-visual-comparison.md) 和 [并排报告](artifacts/visual-comparison/index.html)；安全本机预览为 `python3 scripts/serve-visual-report.py`。

## 代码入口

- `entry/src/main/ets/pages/Index.ets`：页面、门禁与返回栈。
- `entry/src/main/ets/features/`：ViewModel、环境选择与恢复。
- `entry/src/main/ets/business/`：领域模型、Repository接口、密码和展示规则。
- `entry/src/main/ets/data/`：mock/HTTPS Repository及DTO逐字段解码。
- `entry/src/main/ets/platform/`：原生HTTP、生命周期、透明系统栏策略、TLS检查和有限深链。
- `entry/src/main/ets/ui/`：官方ArkUI组件、材质与反馈的封装边界。
- `entry/src/test/`：当前72项Hypium Local Test；首切片历史37项单独归档。

实际语音读屏、连续录屏、减弱动画平台设置及其他API/尺寸覆盖仍需独立证据；官方组件的适配能力不等于折叠、悬停或分栏硬件已实测。生产release commit因公开版本探测403尚未确认，没有执行生产写入或发布。
