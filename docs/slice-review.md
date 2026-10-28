# 首个原生切片独立审查

日期：2026-10-27。审查依据：本项目 AGENTS.md、ADR-001～010、feature-acceptance-matrix.md、冻结 Web 正式入口及后端 DTO。使用 code-review-and-quality 的正确性、可读性、架构、安全、性能五轴流程；不以格式偏好作为阻塞项。本文件记录静态审查和可取得的验证证据，不代表原生 UI 已验收。

## 审查范围

- UI：`entry/src/main/ets/pages/Index.ets`、`ui/LabeledInput.ets`、`ui/StarwardAtlas.ets`、`EntryAbility.ets`、`platform/AppLifecycle.ets`。
- 业务与数据：`business/models.ets`、`assignmentState.ets`、`GameRepository.ets`，`data/DtoDecoder.ets`、`HttpsGameRepository.ets`、`MockGameRepository.ets`、`features/SliceViewModel.ets`、`platform/HttpTransport.ets`。
- 先读测试：Domain、Contract、Repository、ViewModel 及 List 注册；关注逐状态断言、单次密码写入、跨账号延迟返回及错误路径。

## 发现与处理状态

| 编号/严重度 | 问题与影响 | 应有修复与回归 | 状态 |
| --- | --- | --- | --- |
| R01 Required/P1 | `SliceViewModel.refresh()` 初版只对 /me 的401清会话；403等终态仍保留 home、玩家和场次。账号停用后仍可继续显示旧私人内容，与 Web GameGate 终态逻辑不符 | 将 /me 认证/权限终态撤下私有UI并清会话；增加me403用例 | 已修复，31例业务回归通过 |
| R02 Required/P1 | `HttpsGameRepository.changePassword()` 初版只替换 token，不增加 generation。旧token在途请求于轮换后返回401会logout新认证，旧成功响应也可能覆盖新状态 | 成功验证后原子替换token并递增代次；mock同语义；增加改密后旧401不清新token用例 | 已修复，31例业务回归通过 |
| R03 Required/P2 | 原生传输异常文案初版统一提示“请重试原操作确认结果”，在改密丢响应时诱导再次使用旧密码提交 | 传输错误保持通用；改密结果不确定时指引退出后重新登录确认，禁止自动重试，保留退出入口 | 已修复，31例业务回归通过 |
| R05 Required/P1 | 真实认证400已返回，但初始为空的错误区域未更新。私有Builder值参数没有把动态字符串变化送入内部条件 | 错误展示改为V2 Param组件；同类busy文案和详情facts改为明确参数绑定；ForEach key覆盖实际DTO及排序变化 | 已修复，真实400及503/畸形me告警已重跑通过；七态及恢复另见最终设备报告 |
| R06 Required/P2 | 星图的溢出绘制参与点击命中，遮挡主题按钮 | 装饰层HitTestMode.None并排除全部无障碍子节点；布局测量与实际绘制分别核对 | 已修复，深浅真机截图确认；最终root offset星中心与Web差约0.41/0.09vp |

## 已确认的静态边界

- 登录先校验 PocketBase token/record，再使用新token校验 /me；身份不匹配不提交认证。业务请求 Authorization 使用原token，没有 Bearer。
- 账号代次与详情请求序号用于阻断登出/切换、换详情后的旧响应。当前代次401和旧代次401必须区别处理；R02 为轮换边界的补充。
- DTO 逐字段解析并拒绝错误类型，不以裸 JSON.parse 断言完成校验；未知额外字段可忽略。模型明确是首切片只读投影，未宣称迁移全部题目/线索/媒体字段。
- Navigation详情内容检查gate=home，非home状态监听清栈；显式退出清导航、密码和当前选中ID。静态代码未发现直接绕过强制改密的返回路径，但系统手势行为尚未实测。
- 模拟数据有环境说明；详情“开始本场冒险”禁用并解释当前只读范围，没有本地伪造active、进度或奖励。
- 凭据只驻内存；密码不落盘，不打印；应用仅声明INTERNET权限。没有新增业务第三方依赖或读取卡片/Push私密凭据。
- API26 SDK声明 `HttpRequestOptions.body` 自26.0.0可用（不是旧版extraData误用）；HTTP任务在finally销毁。详情使用serverTime更新偏移，时间窗只负责展示。
- 业务模型独立于ArkUI和平台Kit；网络和DTO在Repository/platform层；初期单entry边界与ADR一致。

## 验证证据与剩余边界

业务测试和变异验证由独立构建代理执行，本审查读取并复核了实际报告：

- `scripts/hm.sh test`：Hypium本地业务测试 **31例通过，0失败，0忽略**，报告 `artifacts/validation/local-test-summary.json`，源报告 `entry/.test/default/intermediates/test/coverage_data/test_result.txt`。其中包含本轮R01/R02/R03回归及两例冻结Web完整响应夹具解码。
- 变异：把 `assignmentKind` 结束窗判断 `Date.parse(item.endsAt) <= now` 反转为 `> now`，执行 `scripts/hm.sh test Domain`。5例中4通过、1失败，`timeAndRankBoundariesRemainExclusiveAtEnd` 明确失败，验证脚本exit1。证据：`artifacts/validation/mutation-summary.json`、`mutation-test-result.txt`、`mutation-test.log`。
- 变异后原样恢复源文件，重新运行全套，结果31/31通过；本审查确认当前源码仍为 `<= now`。一次尝试将completed条件反转触发编译器静态窄化拒绝，不计为测试杀掉变异证据。
- 构建和codelinter的最终运行结果由主验收报告记录；本文件不把中间构建结果冒充最终结果。

本审查尚未运行原生UI、签名、安装、真机网络或截图对照。已有Web用例只作为行为输入，没有计入ArkUI通过数量。

必须保持待验证：键盘遮挡、390×844参考与真机vp/安全区配对、浅/深/系统主题动态变化、密码显隐的读屏名称、大字体、系统返回手势、后台恢复、动画/焦点。没有这些证据，不能称“一比一复刻通过”或“可在真机完整使用”。

当前结论：R01～R03已修复且对应业务回归通过，条件反转实验确认时间窗边界测试能捕获真实回归；未发现其他需阻塞此只读模拟切片的静态代码问题。该结论限于受审源码与业务测试，最终构建及UI运行、视觉验收保持独立记录，不构成生产联调、发布或合并授权。

## 真实 HTTPS 接入增量审查

本轮增量使用同一五轴审查流程，静态读取 `platform/AppEnvironment.ets`、`HttpTransport.ets`、`TlsProbe.ets`、`LaunchRoutes.ets`、`WindowMetrics.ets`、`EntryAbility.ets`、`features/createSliceViewModel.ets`、`SliceViewModel.ets` 及相关测试。该审查过程没有操作设备、修改后端或重置隔离服务。

| 编号/严重度 | 问题与影响 | 修复与回归 | 状态 |
| --- | --- | --- | --- |
| R04 Required/P2 | 打包配置存在但无效时，工厂曾因endpoint为空而回退Mock；错误提示又会在登录时清除，仍能用演示账号进入，可能把环境配置失败误认作真实登录成功 | 无效配置选用`UnavailableRepository`，所有数据/认证动作失败并保留CONFIG_ERROR；只有未提供集成配置才默认显式Mock。UI显示不可用环境并禁用主动作。增加无效配置登录、退出后重试均不能推进，以及无配置仍保留Mock的回归 | 已修复；本轮37/37业务测试通过 |

已确认：HTTPS仅可从包内显式隔离配置启用，允许源限定为专用测试域或loopback测试端口；自定义CA只在该loopback测试分支使用。`remoteValidation='system'`、`enablePartialChain=false`，每请求传入CA，关闭重定向；未发现跳过证书/主机名验证、修改系统信任或从外部Want注入地址的路径。TLS探针使用独立连接，只有明确TLS_ERROR才把负例判为拒绝，日志仅记录布尔结果与错误码。

深链仅解析有限业务路由，先执行登录/强制改密守卫；页面退出清pending路由。登录、账号切换与token轮换仍受账号代次约束，旧响应不能提交认证或恢复私有内容。未发现本轮新增凭据日志、密码落盘或默认生产地址。

修改密码503/其他5xx保持“不确定结果，退出后重新登录确认”的指引；400等明确失败显示服务端错误文案。两类新增回归均验证只发出一次改密请求、busy释放且仍在改密守卫内，没有自动重试。

最终业务报告 `artifacts/validation/local-test-summary.json` 为 **37例通过、0失败、0忽略**，源报告仍为 `entry/.test/default/intermediates/test/coverage_data/test_result.txt`。主执行者提供的原生独立TLS握手证据 `artifacts/validation/native-tls-and-metrics.json` 记录自定义CA接受、未信任CA拒绝和错误主机名拒绝三项；这是网络验证证据，未计入37例业务测试。本增量未发现其他Required静态问题；UI交互与逐状态视觉完成度按最终验收报告分别记录。
