# 入场与答题主链（2026-11-04）

按用户要求拆小点顺序推进：每点先完成直板机交互和独立一次性真实HTTPS后端验证，再进入下一点。固定人工预览的账号、DB及凭据保留，故障及答题实验使用另一套临时玩家；Web和后端仓库只读。未改动的资料、头像、改密及底栏效果不重复完整验收。折叠等设备专项后置。

| 顺序 | 功能及逐状态 | 当前状态 |
| --- | --- | --- |
| E0 | 重启DevEco/HDC，新API26手机调试签名、安装启动、隔离HTTPS可达 | 已通过：官方IDE重新自动签名，官方CLI在新手机安装启动；A阶段历史包27be…及其runtime-02五项通过，当前B包证据见后文 |
| E1 | 入场pending/单飞、真实成功、同requestId原体重试、准入失败、返回再进与账号迟到隔离 | 已通过本轮直板机与真实隔离HTTPS范围；主路径11、503重试7、丢响应重试7、退出迟到8，报告分别保留包及源码绑定 |
| E2 | 权威快照取题、入场前题目null、未来题不泄露、读取失败/重试、返回恢复 | 已通过本轮范围：主路径及返回恢复，GET503/真实GET恢复5项；没有独立取题endpoint |
| E3 | 文本/选择答题、空输入、pending、错答200、冷却/锁定、同ID/原答案重试、账号边界 | 本轮普通文本/选择范围通过：text-02 12项、manual-05 18项、cooldown 11项含未选零POST、lock 6项、503/drop各9项及退出迟到8项；均有直板机与真实隔离HTTPS证据 |
| E4 | 后端进度、题号导航、手动下一题及autoNext、回访恢复 | 本轮普通主链通过：手动上题只读/下一题、权威进度、完成同步与回访，以及独立autoNext 6项；题目可见性边界见E2 |
| E5 | 最后一题完成、权威玩家经验和历史回源、完成页/返回、不重复提交或重复反馈 | 本轮普通完成范围通过：组合完成与100XP、历史2/2及GET不重复提交/庆祝，单题正常内联完成7项；护照XP UI未额外重验，终章/出口不在本轮范围 |

权威契约：后端 `c28f488d6b682ae213713ccdd2d992595a941ae3`，Web `4b7d1a0a00051ac630e459b0fd6c074f821d7455`，本轮只读核验工作树干净。GET `/assignments/:id`返回完整场次；POST `/start`只传`requestId`；POST `/answers`传`sessionLevelId, answer, requestId`；最后一关成功由服务端直接完成，不增加finish接口。错误响应不当空成功，incorrect不因HTTP200当作正确。

本轮覆盖普通文本/选择、正常完成的业务主链。剧情、线索演出、媒体播放、奖励领取、finale/出口编排各自仍需后续切片；不把普通主链通过扩大为它们已迁移。所有写入、题目可见性、进度、等级与惩罚以后端为准。

## E0与E1/E2主路径的实际证据

- 工具恢复：HDC与DevEco已启动。首次安装因新手机不在旧profile中失败；通过官方Studio自动生成签名后，`scripts/hm.sh run`调试构建、签名、安装、启动成功。未修改CLI或签名材料，未登记线上应用。
- A阶段主路径当时安装的历史HAP SHA256：`27be3fe9964cb61de7a3884d21838dd6102a6637c97358b17d4911ac14a53773`。`artifacts/validation/gameplay-entry-20261104/runtime-02.json`五项真实窗口/沉浸/透明系统栏/字号/独立TLS检查通过；不继承旧手机的UI证据，也不将此包写为当前B包。
- ArkTS/Hvigor构建通过；新GameplayData 9/9、新GameplayViewModel 10/10（失败0、忽略0）；codelinter issues 0。报告分别在同目录`data-tests/local-test-summary.json`、`viewmodel-tests/local-test-summary.json`及`lint.json`。这些测试不代替设备验收。
- `host-entry.json`：严格校验证书的真实HTTPS 23项通过，包含未入场题目隐藏、成功入场、相同请求幂等重放、不同原体冲突、时间/等级限制及他人场次404。全程一次性玩家与独立DB，没有生产写入。
- `device-entry-main.json`：新直板机11项通过。原始UiTest pending树确认“正在进入…”及`enabled=false`；真实服务端2条progress、1条start receipt、0条answer、0条XP账目；返回重进和同步只有GET；退出清空登录表单及私密题页。
- 两张private原始截图已由Root查看：当前题与返回恢复画面一致；题干、权威0/2进度、字号换行、顶栏和底部系统区域可读，未出现独立实心系统栏占位。该A阶段视觉确认仅涵盖入场后的只读题页，答题表单/键盘/完成态证据见后续B阶段。
- 固定预览DB、CA及登录资料保留。临时环境首次发现创建用例会覆盖磁盘TLS回执，在实际答题或入场前停止并清理该临时实例；修复后重新启动独立环境并重新构建安装。`environment-rebuild-1-cleanup.json`、`environment-02/startup.json`记录实际清理和新环境启动，不算业务验收。

上述是入场包的验收范围；其余状态按小点继续追加实际结果，不能把只读题页或测试断言数解释为完整业务已迁移。

## E3/E4/E5逐状态清单

E1/E2已关闭后开始E3。以下按实际证据更新，仅计对应小点，不以已实现替代直板机验证。

| 小点 | 直板机状态与真实隔离后端证据 | 状态 |
| --- | --- | --- |
| E3文本 | 空白本地提示且零POST；键盘下答案/主要动作可滚动到达；提交pending输入/再次提交禁用；错答HTTP200显示未通过且保留权威进度；正确答案由服务器结算 | text-02独立原生12项通过 |
| E3选择 | 未选提示零POST；单选提交原始key；错答后的wrongCount、cooldownUntil、locked按服务端显示；冷却/锁定不能本地绕过，服务端拒绝仍解释响应 | 本轮通过：manual-05正常选择；cooldown 11项含未选零POST、倒计时/禁用与期满恢复；lock 6项含GET重进保持锁定 |
| E3重试/隔离 | 503及已提交后断响应保留相同requestId、原答案、sessionLevelId与发起账号；不重复submission/XP；退出后旧响应不恢复页面或玩家事实 | 本轮通过：503/drop各9项，四项请求身份哈希一致；退出迟到8项确认同进程收包后丢弃 |
| E4进度/导航 | 服务端completedLevels/currentIndex用于事实；手动阅读题号与currentIndex分开；未解锁题不暴露题目；非autoNext停留已完成题并显示lastAnswer及下一题动作；autoNext依返回关卡配置推进 | 本轮通过：text-02/manual-05手动路径、独立autoNext 6项；未来题可见性见E2 |
| E4读取/返回 | 同步/返回重入只GET；读取失败不显示空模型默认事实；已完成题只读；恢复当前权威进度，不重放写操作 | manual-05验证完成同步/回访只GET与只读；读取失败证据限E2已验范围 |
| E5完成 | 最后一题答对同事务转completed；完整player直接替换，不能累加xpDelta；普通多题完成使用官方反馈，单题正常完成内联；回访不重复庆祝/提交 | 本轮普通完成范围通过：manual-05组合弹窗/100XP及GET回访，single-normal 7项内联完成；already_completed协议证据限Host检查 |
| E5首页 | 返回后历史/详情摘要按权威事实回源；护照玩家经验不累加xpDelta；仍不代表奖励领取、通知或全部历史业务已迁移 | manual-05验证历史2/2与权威完整玩家100XP；护照XP UI本轮未额外重验 |

### E1故障重试补验

新手机使用不同专用玩家完成以下真实HTTPS检查，没有重置前一个玩家的事实：

- `device-entry-503.json` 7项通过：转发前503时服务端零入场事实，错误页显式重试后2条progress、1条start receipt；两个POST的requestId、完整原体和账号身份哈希完全一致，raw Authorization未加Bearer。
- `device-entry-drop.json` 7项通过：真实后端已提交并返回200，代理销毁客户端响应；手机显示错误，重试同一原命令后startedAt不变、progress/receipt不增、answer及XP仍零。
- Root已查看503错误与恢复两张原始截图：真实错误与重试动作可见，错误时没有题目泄露，恢复后显示权威题干及0/2进度。
- `device-entry-read-retry.json` 5项通过：GET503时题干与正文进度消失，显式重试只有GET200，原入场receipt仍为1。Root已查看错误及恢复原图。
- `device-entry-late.json` 8项通过，绑定补探针包`11e7e4a3d49bbde2a4e7cb891c8da407dc9ef24297b93b5fea8b924fc737c062`与`runtime-03.json`五项。12秒响应延迟期间，实际约10.256秒内从头像侧栏退出，未先按返回；同一冷启动进程后续唯一接收日志确认完整200且`sessionCurrent=false`，紧邻账号检查在解码前丢弃。退出后无认证/路由/私密题页恢复、无新玩家请求。Root已查看空登录原图；自有日志进程与故障规则均已收尾。
- 探针改动的相关GameplayData 9/9与边界lint 0 issues分别在`boundary-data-tests`和`boundary-lint`，不重复旧业务UI验收。

本轮发现短内容题页的Scroll默认垂直居中，后续答题表单实施时改为显式顶对齐，并只补本页视觉验证；不重跑未变动的旧业务。

## E3协议层实际结果与原生分段验收

入场验证结束后，停止其确切自有backend并删除一次性DB，保留已核验的TLS gateway/CA与原代理端口，新启完全不同DB、玩家和control token，仅继承TLS receipt。`artifacts/validation/gameplay-answer-20261104/environment-01/startup.json`记录该启动事实，不算业务验收。固定人工预览DB未动。

新runner SHA `3d50d3769b146297435e6df559e2eb0fd169a18d344c8e761f325e18cd87cbdf`开放玩家答题代理；每个manual、auto-next、cooldown、lock、single场次使用自己新发布的session，未修改A旧场次。真实Host答题检查`artifacts/validation/gameplay-answer-20261104/host-answer.json` 60项通过，包括错答200、正确结算、原体重放与不同原体409、顺序/他人场次边界、真实冷却/永久锁定、最终完成及经验回源、取消后的历史收据回放。它只证明严格HTTPS协议与真实后端事实，不提供手机表单、键盘或官方完成弹层通过结论。

### 首次文本手机验收发现的问题（保留失败）

HAP `5cef8cecc94ad0fccdfdc5050f45dd6ef5cd94a9fd5ce86de1b3995250ae2d5e`已实际官方构建、签名、安装启动；`runtime-01.json`五项及最终lint零问题。GameplayAnswerData 10/10、GameplayAnswerViewModel 12/12、GameplayData 9/9、GameplayViewModel 10/10全部失败0/忽略0；随后仅给视觉autoNext timer补句柄身份检查，再跑相关AnswerVM 12/12并重新安装该包，未重新跑旧业务UI。

`device-answer-text.json`为 **incomplete**，只有已执行的6项检查：空/空白零POST、实际IME测得可用区内输入与提交可滚达、错答200且零进度/经验、正确提交pending原始输入及按钮禁用。随后等待正确完成UI超时。独立真实后端诊断确认当前玩家已active 1/2、2条submission/2条answer receipt、唯一50XP，入场仍一次；手机顶栏1/2及正确反馈已更新，但正文仍0/2且保留禁用的提交按钮，没有只读完成标记和下一题。Root已亲看IME与故障原图。这不能记为文本功能验收通过。

根因定位为本页私有`@Builder`按值接收领域快照/关卡，加上稳定ForEach身份捕获旧对象；后续状态虽在V2 ViewModel更新，构建函数里的字段仍是旧值。官方API26指南`arkts-builder`明确默认按值传递不支持参数状态刷新，并建议私有Builder直接通过this访问状态。本页将改为直接读取play的Trace路径，不给领域模型添加ArkUI依赖，不用重建整张输入卡绕开状态问题。修复后以新玩家重新完整跑文本小点，旧玩家已结算事实不重置。

### 文本小点修复后通过

页面修复为零数据参数的私有Builder，所有变化的快照/关卡/进度/lastAnswer从play的Trace路径读取；当前题ForEach仅持有稳定的关卡身份，导航和选项也读取当前状态。新HAP `8cd8d5ceb97018db8fcfc9a7f0bce2cdc7f905e1504986d29cc175f89f8e3ea3`通过官方构建、签名、安装启动及lint零问题，`runtime-02.json`真实五项通过。纯UI依赖修正未改业务结算逻辑，未重复运行既有41个业务用例或旧UI回归。

`device-answer-text-02.json` **passed / 12项**，使用另一名新建普通玩家，旧失败报告与原事实保留。空白/真实IME/错答/pending重新实测后，正确结果实际更新正文与顶栏1/2；题号标记已完成，服务端normalized lastAnswer只读，旧提交按钮消失，并显示手动下一题，仍停在第一题。真实后端唯一正确结算50XP，2次答案请求对应一次错答及一次正确，入场仍一次。退出后的登录输入及私密页面均清空，故障和remote raw收尾全true。

Root已逐SHA查看该次IME和1/2完成的两张原图：实际键盘可用App视口通过官方RESIZE测得456vp（缩减314vp，并未声称这是IME窗口高度），答案与提交可滚达；正确态的正文进度、题号、只读答案和下一题均已刷新，顶对齐修正有效。此时选择题/最终完成仍继续独立验收。

组合后续首次`device-answer-manual-complete.json`仅2项后incomplete，尚未新增选择答案。Root独立原始UiTest树和截图确认上一题按钮完整可见且enabled，rect高度210px恰与横向Scroll一致；通用seek要求在该容器上下各留8px，故误判不可达。仅修复后续测试驱动：题号左右继续按真实横向Scroll裁剪，上下按所属真实纵向玩法Scroll/App裁剪，不放大到全屏；应用包、基础文本驱动及旧报告未修改，同一场次保持原2次答案、1/2及50XP，使用新报告继续。

### 手动组合后续：失败保留与完整通过

manual各次报告独立保留，不覆盖旧报告或累加部分检查数：

| 报告 | 实际结果 | 停止原因 |
| --- | --- | --- |
| `device-answer-manual-complete.json` | incomplete / 2项 | 题号控件的测试驱动几何误判 |
| `device-answer-manual-complete-02.json` | incomplete / 6项 | 官方完成弹窗已出现，但确认文案是Text子节点，旧驱动只查Button.text而未找到 |
| `device-answer-manual-complete-03.json` | incomplete / 5项 | CLI按id提交漏点，未产生最后的正确答案POST，等待完成弹窗超时 |
| `device-answer-manual-complete-04.json` | incomplete / 0项 | setup阶段官方CLI layout超时，未进入本次选择答题 |
| `device-answer-manual-complete-05.json` | passed / 18项 | 完整独立运行，cleanup五项全true |

`manual03-submit-injection-probe.json`只记Root的独立诊断：fresh raw确认B已选且提交可用后，一次HDC测量中心点击使submission从3增至4、完成2/2与100XP，官方完成弹窗出现且测量标签确认有效。状态为`observed_diagnostic_only`，不把这次补充诊断拼接成manual-03通过。之后仅修测试驱动：写动作先核原始可见/启用控件及实际App视口，再单次HDC中心点击，只有真实答案ledger恰增1才继续检查反馈；没有补点或自动重试。

manual-05使用新的专用manual case，其Host文本前置记录在`manual-04-fixture-preparation.json`：一次入场、两次文本答案、1/2、50XP；状态明确为`prepared_not_native_acceptance`，旧case未重置、固定预览未动。这里的Host前置不算新增原生文本验收，原生文本依据仍是独立`device-answer-text-02.json`的12项。

manual-05本stage实际原生提交只有两次选择答案：A错答后保留选项、权威wrongCount变1且仍可作答，B正确后服务端同事务完成并显示官方组合完成弹窗。最终4条submission、4条answer receipt、2条XP账目与100XP包含先前Host文本两次，不能写成本stage原生提交4次。报告显式区分`priorTextAnswerRequests=2`和`nativeChoiceAnswerRequestsInThisStage=2`。

18项还确认上一道文本题的权威lastAnswer只读、手动下一题、完成同步与详情/玩法回访只GET、历史展示2/2、完成选择只读、无额外入场/答题/XP和重复庆祝，最后注销清空登录输入与私密玩法。报告仍绑定8cd…HAP及runtime-02；followup driver SHA为`9a698a1a09a18bccdcd65bf0700a2a1dd1d63baec768f7d258087a627270257e`，未修改产品源码或重跑无关旧UI。

### autoNext独立交互结果

`device-answer-auto-next.json` **passed / 6项**，同一8cd…HAP、runtime-02及9a…驱动，使用另一新case真实入场。唯一一次原生正确文本提交产生1条submission、1条receipt、1条XP账目与50XP；场次仍active 1/2，依服务端`autoNext=true`自动显示下一道选择题，手动下一题点击为0、下一道选择题未答，没有提前出现组合完成弹窗。cleanup五项全true，原图复核记于后述独立sidecar。

### 单题、处罚与答题恢复实际结果

以下报告均绑定同一8cd…B验收HAP和runtime-02，各使用独立专用case。检查数只表示该stage已完成的断言，不换算为整体业务完成度。

| 报告 | 实际结果 | 核实范围 |
| --- | --- | --- |
| `device-answer-single-normal.json` | passed / 7项 | 一次正确文本提交，单题completed、50XP、权威答案只读与内联完成；没有组合弹窗 |
| `device-answer-choice-cooldown.json` | passed / 11项 | 未选提示且零POST/事实不变；错选后服务端冷却、原始树确认倒计时及选项/提交禁用，触碰禁用提交零新增POST；真实期满后正确选择完成，合计两次答案与50XP，Host答案POST为0 |
| `device-answer-choice-lock.json` | passed / 6项 | 一次错选后权威wrongCount=1、永久locked，选项/提交禁用；返回再GET仍锁定，不增加入场/答案，XP为0 |
| `device-answer-503.json` | passed / 9项 | 转发前503无submission/receipt/XP；保留原始空格答案并显式重试，同一请求完成后仅一条submission/receipt及50XP |
| `device-answer-drop.json` | passed / 9项 | 后端已提交200后丢弃客户端响应；显式重试保持requestId、完整原体、账号及sessionLevelId四项哈希一致，完成时间不变且不重复submission/XP |
| `device-answer-late.json` | passed / 8项 | 实际12秒响应延迟，pending时直接从顶栏头像注销；同冷进程收到完整200且sessionCurrent=false，在解码前拒绝迟到账号代次 |

late报告进一步确认：从测量提交点击到注销为10278ms，早于12秒延迟结束；后续唯一同PID日志为`operation=answer received=200 sessionCurrent=false`。退出后没有私密内容、认证或导航恢复，新增player请求为0；该已注销case仍只有1条submission、1条receipt和50XP，没有重试。finally再次观测空登录，而非沿用收包前清理标记。

本轮九份passed报告的cleanup全部true，late另有`ownClientCaptureStopped=true`。这仅证明各用例注销、故障中和、临时raw及自有日志采集已收尾；一次性环境整体清理和固定preview恢复由Root另行记录，本节不将其标为通过。

### 原始视觉证据与驱动版本

Root已逐SHA查看14张本轮原图，`artifacts/validation/gameplay-answer-20261104/original-visual-review.json`状态为`reviewed`，逐项绑定原报告SHA、HAP与图片SHA，且`originalReportsUnmodified=true`。原报告保留采集时的`visualReview`字段，后续复核采用该独立sidecar，不回写旧报告。复核范围为正常字号直板机上的题目/输入与键盘、处罚、恢复、完成态可读性及状态语义；不是新增Web逐像素对照、全部主题或折叠适配验收。

manual-05、auto-next及single-normal报告保留当时followup driver `9a698a1a09a18bccdcd65bf0700a2a1dd1d63baec768f7d258087a627270257e`的绑定。增加选择未选零POST检查后的当前followup driver为`31d8aa7ab35450502c8a160ecfaea7b7c75292954a36dc6b9494afa43902ec13`，cooldown与lock报告绑定此版本；当前recovery driver及503/drop/late报告均绑定`cf4ac07e38960ca4a77acbc8a3be9a6f64422d1b7633743411dcd36b2d2826e5`。这些驱动变更没有改动产品源码。

## 可复现命令与构建证据

以下命令从项目根目录执行，使用固定Studio `26.0.0.851`、SDK `26.0.0.105 / API26`、Hvigor `6.26.8`及Studio内置Node `24.14.1`。`scripts/hm.sh`设置配套运行时；本轮第3次官方run已完成构建、签名、安装和启动，B验收HAP为`8cd8d5ceb97018db8fcfc9a7f0bce2cdc7f905e1504986d29cc175f89f8e3ea3`，玩法页源码SHA为`b79fddd9df14aa6480a353ba50ea0044da4fda46a02e673632c8a53bed0e5c75`。第3次官方lint成功，`ui-refresh-lint/lint.json`记录issues/errors/warnings均0，filesChecked为0；不把lint计数当作业务覆盖。

```sh
scripts/hm.sh run
STARWARD_VALIDATION_DIR=artifacts/validation/gameplay-answer-20261104/gameplayanswerdata scripts/hm.sh test GameplayAnswerData
STARWARD_VALIDATION_DIR=artifacts/validation/gameplay-answer-20261104/gameplayanswerviewmodel scripts/hm.sh test GameplayAnswerViewModel
STARWARD_VALIDATION_DIR=artifacts/validation/gameplay-answer-20261104/gameplaydata scripts/hm.sh test GameplayData
STARWARD_VALIDATION_DIR=artifacts/validation/gameplay-answer-20261104/gameplayviewmodel scripts/hm.sh test GameplayViewModel
STARWARD_VALIDATION_DIR=artifacts/validation/gameplay-answer-20261104/answervm-timer scripts/hm.sh test GameplayAnswerViewModel
STARWARD_VALIDATION_DIR=artifacts/validation/gameplay-answer-20261104/ui-refresh-lint scripts/hm.sh lint
```

上列业务测试的实际summary分别为10/10、12/12、9/9、10/10，timer句柄修正后相关AnswerVM再次12/12；全部失败0、忽略0。报告位于相应目录的`local-test-summary.json`。后续纯UI依赖修正未改业务逻辑，未据此声称重新执行了这些用例。

真实Host检查与新包runtime的命令如下；Host helper会创建专用一次性case并执行真实答题，须由Root在同一授权隔离环境运行。再次执行须选择新的输出路径，不覆盖本轮报告；runtime也须在安装新包后重新捕获并冻结，不继承旧包窗口/TLS证据。

```sh
python3 -B scripts/gameplay-host-answer-check.py run \
  --expected-runner 3d50d3769b146297435e6df559e2eb0fd169a18d344c8e761f325e18cd87cbdf \
  --output artifacts/validation/gameplay-answer-20261104/host-answer.json
python3 -B scripts/capture-window-evidence.py \
  --output artifacts/validation/gameplay-answer-20261104/runtime-02.json \
  --font-scale 1 --require-tls
```

`host-answer.json`实际60项通过；`runtime-02.json`实际五项passed并绑定上述8cd…HAP，包括真实窗口、沉浸布局、透明系统栏、字号1及三项独立TLS情形。这些结论与UI验收分别记录。

下列保留独立原生text-02与早期manual-02的历史参数；后者是incomplete / 6项，不能作为当前manual通过命令。这里只列ref路径，不包含账号、密码或会话；这些case已有结算，不能照抄重跑文本。复验须使用新的专用ref及新报告名，手动后续须匹配其前置事实，不能重置已结算事实或覆盖旧报告。

```sh
STARWARD_TEXT_CASE_REF=artifacts/private/gameplay-20261104/phone-answer-manual-02-case-ref.json
python3 -B scripts/device-gameplay-answer.py run --stage text \
  --runtime artifacts/validation/gameplay-answer-20261104/runtime-02.json \
  --case-ref "$STARWARD_TEXT_CASE_REF" \
  --output artifacts/validation/gameplay-answer-20261104/device-answer-text-02.json \
  --expected-hap 8cd8d5ceb97018db8fcfc9a7f0bce2cdc7f905e1504986d29cc175f89f8e3ea3
# 历史manual-02尝试：incomplete / 6项，保留原报告。
python3 -B scripts/device-gameplay-answer-followups.py run --stage manual-complete \
  --runtime artifacts/validation/gameplay-answer-20261104/runtime-02.json \
  --case-ref "$STARWARD_TEXT_CASE_REF" \
  --output artifacts/validation/gameplay-answer-20261104/device-answer-manual-complete-02.json \
  --expected-hap 8cd8d5ceb97018db8fcfc9a7f0bce2cdc7f905e1504986d29cc175f89f8e3ea3
```

以下为manual-05实际通过的参数，使用Host已准备文本前置的另一新case；不复用text-02的case，不将Host准备冒充新原生文本验收。该报告及ref现也已有结算，后续完整复验仍须另建case并换新报告路径。

```sh
python3 -B scripts/device-gameplay-answer-followups.py run --stage manual-complete \
  --runtime artifacts/validation/gameplay-answer-20261104/runtime-02.json \
  --case-ref artifacts/private/gameplay-20261104/phone-answer-manual-04-case-ref.json \
  --output artifacts/validation/gameplay-answer-20261104/device-answer-manual-complete-05.json \
  --expected-hap 8cd8d5ceb97018db8fcfc9a7f0bce2cdc7f905e1504986d29cc175f89f8e3ea3
```

已核实的原生证据分别为text-02 12项、manual-05 18项、auto-next 6项、single-normal 7项、choice-cooldown 11项、choice-lock 6项、503/drop各9项及late 8项。manual-01至04的incomplete和Root诊断继续独立保留；不将这些计数合并成整体业务完成度。

其余stage的本轮已结算ref如下，仅记录路径来源，目录均为`artifacts/private/gameplay-20261104/`：

| stage | 本轮历史ref文件 |
| --- | --- |
| auto-next | `phone-answer-auto-case-ref.json` |
| single-normal | `phone-answer-single-case-ref.json` |
| choice-cooldown | `phone-answer-cooldown-case-ref.json` |
| choice-lock | `phone-answer-lock-case-ref.json` |

以下为fresh复验命令。followups的`--case-ref`为必填，fixture名称由脚本校验；Root须分别提供全新的对应fixture ref文件路径。变量仅存路径，不能放账号或口令。下列使用新的报告后缀；已结算的本轮ref不能再跑，重新验证应另建case，不重置旧事实，也不覆盖旧报告。新安装包须重新捕获匹配runtime并替换HAP参数。

```sh
STARWARD_B_REPORTS=artifacts/validation/gameplay-answer-20261104
STARWARD_B_RUNTIME="$STARWARD_B_REPORTS/runtime-02.json"
STARWARD_B_HAP=8cd8d5ceb97018db8fcfc9a7f0bce2cdc7f905e1504986d29cc175f89f8e3ea3
python3 -B scripts/device-gameplay-answer-followups.py run --stage auto-next \
  --case-ref "${STARWARD_AUTO_NEXT_CASE_REF:?Root须提供全新auto-next ref路径}" \
  --runtime "$STARWARD_B_RUNTIME" --output "$STARWARD_B_REPORTS/device-answer-auto-next-recheck.json" --expected-hap "$STARWARD_B_HAP"
python3 -B scripts/device-gameplay-answer-followups.py run --stage single-normal \
  --case-ref "${STARWARD_SINGLE_NORMAL_CASE_REF:?Root须提供全新single-normal ref路径}" \
  --runtime "$STARWARD_B_RUNTIME" --output "$STARWARD_B_REPORTS/device-answer-single-normal-recheck.json" --expected-hap "$STARWARD_B_HAP"
python3 -B scripts/device-gameplay-answer-followups.py run --stage choice-cooldown \
  --case-ref "${STARWARD_COOLDOWN_CASE_REF:?Root须提供全新choice-cooldown ref路径}" \
  --runtime "$STARWARD_B_RUNTIME" --output "$STARWARD_B_REPORTS/device-answer-choice-cooldown-recheck.json" --expected-hap "$STARWARD_B_HAP"
python3 -B scripts/device-gameplay-answer-followups.py run --stage choice-lock \
  --case-ref "${STARWARD_LOCK_CASE_REF:?Root须提供全新choice-lock ref路径}" \
  --runtime "$STARWARD_B_RUNTIME" --output "$STARWARD_B_REPORTS/device-answer-choice-lock-recheck.json" --expected-hap "$STARWARD_B_HAP"
python3 -B scripts/device-gameplay-answer-recovery.py run --stage 503 \
  --case-ref "${STARWARD_FAULT_CASE_REF:?Root须提供全新manual ref路径}" \
  --runtime "$STARWARD_B_RUNTIME" --output "$STARWARD_B_REPORTS/device-answer-503-recheck.json" --expected-hap "$STARWARD_B_HAP"
python3 -B scripts/device-gameplay-answer-recovery.py run --stage drop \
  --case-ref "${STARWARD_DROP_CASE_REF:?Root须提供另一全新manual ref路径}" \
  --runtime "$STARWARD_B_RUNTIME" --output "$STARWARD_B_REPORTS/device-answer-drop-recheck.json" --expected-hap "$STARWARD_B_HAP"
python3 -B scripts/device-gameplay-answer-recovery.py run --stage late \
  --case-ref "${STARWARD_LATE_CASE_REF:?Root须提供另一全新manual ref路径}" \
  --runtime "$STARWARD_B_RUNTIME" --output "$STARWARD_B_REPORTS/device-answer-late-recheck.json" --expected-hap "$STARWARD_B_HAP"
```

recovery脚本的本轮默认ref名分别为`phone-answer-fault-case-ref.json`、`phone-answer-drop-case-ref.json`及`phone-answer-late-case-ref.json`，均位于`artifacts/private/gameplay-20261104/`；它们已经结算，仅保留作本轮来源，不能用于上述fresh复验。整个本轮通过范围限普通文本/选择、惩罚、重试及正常完成主链；护照XP UI未额外重验，终章、媒体、出口、奖励及跨设备专项仍按原计划另行推进。

## 环境收尾与固定预览交付

本轮一次性B环境已关闭，持久预览另行恢复，未重置固定账号、口令或原数据库。各UI报告中的用例cleanup与下面的服务整体清理分别记录。

- `disposable-environment-cleanup.json`保留incomplete / 2项：已核精确UID、argv、cwd、birth、独占监听、证书、全部Docker挂载/镜像/端口，调用标准TLS stop后，HDC返回`[Empty]`；驱动把该空映射标识当成一条残留而暂停，尚未停止backend。
- 独立`disposable-environment-cleanup-complete.json` passed / 6项重新核验无自有TLS进程、证书、打包CA和USB映射；重新核当前backend进程及全部容器归属后调用标准stop，确认进程、proxy/control监听、确切容器、一次性DB和运行凭据state均移除。Docker成功枚举后确认exact ID缺席，未把daemon错误当成删除成功。原preview DB树、manifest、CA和login字节在此前后保持一致，没有宽泛kill或目录删除。
- 旧公开preview Host报告已逐字节归档到`preview-restore/previous-host-readiness.json`，SHA `87b37b96a5f15571577b21c6d4edcd33cd26acd9f3161a205233c6bf6d7b517c`。`profile/preview-environment.json`现为本次启动的新Host回执；历史验证按原SHA及归档识别，不借新文件反证旧版本。
- 持久preview仅增加精确玩家POST `/assignments/[a-z0-9]{15}/start|answers`代理白名单；44项纯离线路径断言和独立静态审查通过。未开放finish/admin/fault/reset，未改prepare、种子、数据或口令。既有四个预览场次中“星辰探险”为一道普通文本题，隔离示例答案为“星辰大海”；没有选择或组合预览场次，不能声称这些预览数据已具备。
- 已验B包8cd…在换环境前保存在ignored private目录，`preview-restore/accepted-b-package.json`记录原HAP及ABC来源。当前实际交付的preview HAP为`b4d5f7081bb5e26e5a44bcc15feec1319078a09d7819be13d6e6b65d8033a730`，通过官方`hm.sh run`构建、签名、安装启动；`preview-restore/package.json`确认其`modules.abc`与已验B包完全一致（SHA `51da5773fdfe26e36bb64d524d0db3933a30ea2a755addf59d15bc5aacb407fe`），只切换了环境配置和CA。
- `artifacts/validation/profile/gameplay-restore-20261104/runtime.json`真实五项passed，绑定新b4d5…包。`preview-login-list-smoke.json`独立6项passed：冷启动空登录、同一固定玩家严格HTTPS身份/列表、无强改密直接进入、四个真实预览场次可达，最终留在已登录首页。只认证/读取/滚动，不提交预览答案、不复跑旧资料链、不宣称观测了业务写台账；同源码的玩法交互验收仍归属于前述B包和一次性玩家。
- Root已查看这张固定preview首页原图，独立绑定见`preview-restore/original-visual-review.json`；原生自动操作已停止。`temporary-screen-timeout-restored.json`记录官方`hdc shell power-shell timeout -r`实际成功，移除本轮300000ms临时覆盖，原准备报告的restoreRequired由该后续回执关闭。

恢复步骤实际使用以下命令，前提是本轮一次性环境已经精确清理且18443无外来映射。`start`复用原DB及私有登录文件，不执行`prepare`或`reset-login`；凭据仍只在App内存，未新增重启恢复登录能力。

```sh
node scripts/preview-environment.mjs start
node scripts/preview-environment.mjs status
node scripts/preview-environment.mjs configure
scripts/hm.sh run
python3 scripts/capture-window-evidence.py \
  --output artifacts/validation/profile/gameplay-restore-20261104/runtime.json --font-scale 1 --require-tls
python3 scripts/device-gameplay-preview-smoke.py run \
  --runtime-report artifacts/validation/profile/gameplay-restore-20261104/runtime.json \
  --output artifacts/validation/gameplay-answer-20261104/preview-login-list-smoke.json \
  --expected-hap b4d5f7081bb5e26e5a44bcc15feec1319078a09d7819be13d6e6b65d8033a730
hdc shell power-shell timeout -r
```

上述runtime和smoke路径现已冻结；以后重新安装须选择新路径和匹配的新HAP。公开文件检查分别见`public-scan-before-cleanup.json`及`public-scan-final.json`，不输出设备标识、口令或token。Web/后端工作树始终作为只读输入，未执行生产写操作。

## 非末题答对后的自动视频（2026-11-12）

逐状态结果见 [C01i](feature-acceptance-matrix.md#c01i-答对后自动播放视频线索)。复验用专用隔离账号、真实 PocketBase、带时间戳的合成 MP4 及专用 CA。为新一轮运行指定新报告目录及一次性账号，复用已结算账号会跳过首答演出。

```sh
starward_private=artifacts/private/gameplay-auto-video-20261112
starward_reports=artifacts/validation/ui-gameplay-auto-video-20261112
scripts/hm.sh build
STARWARD_VALIDATION_DIR="$starward_reports/GameplayClues" scripts/hm.sh test GameplayClues
STARWARD_VALIDATION_DIR="$starward_reports/GameplayAnswerViewModel" scripts/hm.sh test GameplayAnswerViewModel
STARWARD_VALIDATION_DIR="$starward_reports/lint-01" scripts/hm.sh lint
scripts/hm.sh run
python3 scripts/capture-window-evidence.py --font-scale 1 --require-tls --output "$starward_reports/runtime-01.json"
starward_hap_sha=$(shasum -a 256 entry/build/default/outputs/default/entry-default-signed.hap | awk '{print $1}')
python3 "$starward_private/device-auto-video.py" --runtime "$starward_reports/runtime-01.json" \
  --device-ref "$starward_private/device-ref.json" --expected-hap "$starward_hap_sha" \
  --usage natural --theme light --output "$starward_reports/native-natural-01.json"
```

`early` 使用日间模式，`failure` 使用夜间模式，分别指定独立报告。三组依次使用同一部手机，每组使用独立账号并核对答题台账、只读 SQLite 与媒体 GET。主机及冻结 Web 报告、应用签名、实际视口和真机报告分别记录。

## 非末题自动文字与图集演出（2026-11-12）

验收表见 [C01j](feature-acceptance-matrix.md#c01j-答对后的文字与图片线索演出)。私有目录 `artifacts/private/gameplay-auto-clues-20261112/` 提供真实隔离 PocketBase、固定 PNG/MP4、专用 CA 及三个真机账号。使用新的一次性账号和报告名复验。

```sh
starward_private=artifacts/private/gameplay-auto-clues-20261112
starward_reports=artifacts/validation/ui-gameplay-auto-clues-20261112
scripts/hm.sh build
STARWARD_VALIDATION_DIR="$starward_reports/GameplayClues" scripts/hm.sh test GameplayClues
STARWARD_VALIDATION_DIR="$starward_reports/GameplayAnswerViewModel" scripts/hm.sh test GameplayAnswerViewModel
STARWARD_VALIDATION_DIR="$starward_reports/QuestionImageLoaderTests" scripts/hm.sh test QuestionImageLoaderTests
STARWARD_VALIDATION_DIR="$starward_reports/lint-01" scripts/hm.sh lint
scripts/hm.sh run
python3 scripts/capture-window-evidence.py --font-scale 1 --require-tls --output "$starward_reports/runtime-01.json"
starward_hap_sha=$(shasum -a 256 entry/build/default/outputs/default/entry-default-signed.hap | awk '{print $1}')
python3 "$starward_private/device-auto-clues-02.py" --runtime "$starward_reports/runtime-01.json" \
  --device-ref "$starward_private/device-ref.json" --expected-hap "$starward_hap_sha" \
  --usage natural --theme light --output "$starward_reports/native-natural-02.json"
```

`early` 及 `interrupt` 分别指定独立真机报告。媒体请求台账与 SQLite 结算各自复核。冻结 Web 回放取独立账号的同场次响应与同一组媒体原文件，保持业务接口由测试拦截。

## 普通多题末题演出

逐状态结果见 [C01k](feature-acceptance-matrix.md#c01k-末题普通线索完成提示与组合线索)。本轮真机账号在真实隔离 HTTPS 后端各完成首题，再从当前第二题提交唯一的末题答题请求。复验使用新的预结算账号及报告名。

```sh
starward_private=artifacts/private/gameplay-final-clues-20261112
starward_reports=artifacts/validation/ui-gameplay-final-clues-20261112
scripts/hm.sh build
STARWARD_VALIDATION_DIR="$starward_reports/GameplayClues" scripts/hm.sh test GameplayClues
STARWARD_VALIDATION_DIR="$starward_reports/GameplayAnswerViewModel" scripts/hm.sh test GameplayAnswerViewModel
STARWARD_VALIDATION_DIR="$starward_reports/lint-01" scripts/hm.sh lint
scripts/hm.sh run
python3 scripts/capture-window-evidence.py --font-scale 1 --require-tls --output "$starward_reports/runtime-01.json"
starward_hap_sha=$(shasum -a 256 entry/build/default/outputs/default/entry-default-signed.hap | awk '{print $1}')
python3 "$starward_private/device-final-clues.py" --runtime "$starward_reports/runtime-01.json" \
  --device-ref "$starward_private/device-ref.json" --expected-hap "$starward_hap_sha" \
  --usage normal --theme light --output "$starward_reports/native-normal-01.json"
```

提前关闭分支使用 `--usage early --theme dark` 与独立报告。驱动逐步核对浮层关闭、请求台账、SQLite 和已完成场次回访。冻结 Web 使用同场次结算响应和相同媒体原文件，浏览器请求由回放接管。

## 题卡、浮标和完成提示的动态验收

见 [C01l](feature-acceptance-matrix.md#c01l-题卡组合线索浮标与完成弹窗动效)。连续采样使用系统截屏、实测控件边界和原始 PNG。界面保持相同状态，采样期间没有触摸或布局轮询。

```sh
starward_private=artifacts/private/gameplay-motion-20261112
starward_reports=artifacts/validation/ui-gameplay-motion-20261112
scripts/hm.sh run
python3 scripts/capture-window-evidence.py --font-scale 1 --require-tls --output "$starward_reports/runtime-02.json"
starward_hap_sha=$(shasum -a 256 entry/build/default/outputs/default/entry-default-signed.hap | awk '{print $1}')
python3 "$starward_private/device-motion.py" --runtime "$starward_reports/runtime-02.json" \
  --device-ref "$starward_private/device-ref.json" --expected-hap "$starward_hap_sha" \
  --usage normal --theme light --output "$starward_reports/native-motion-01.json"
```

扫光补拍从已完成场次读取同题，核对入场、答题、经验和授权台账。以下命令使用修正后的签名包与原隔离环境，保留首轮报告。

```sh
scripts/hm.sh run
python3 scripts/capture-window-evidence.py --font-scale 1 --require-tls --output "$starward_reports/runtime-03.json"
starward_hap_sha=$(shasum -a 256 entry/build/default/outputs/default/entry-default-signed.hap | awk '{print $1}')
python3 "$starward_private/device-motion-card-readonly.py" --runtime "$starward_reports/runtime-03.json" \
  --device-ref "$starward_private/device-ref.json" --expected-hap "$starward_hap_sha" \
  --prior-report "$starward_reports/native-motion-01.json" --output "$starward_reports/native-card-motion-02.json"
```

## 答题与线索动效逐项复核（2026-11-13）

见 [C01m](feature-acceptance-matrix.md#c01m-已迁移答题与线索动效复查2026-11-13)。两类隔离场次分开准备。普通多题场次验证答题、重连和选题，末题线索场次通过严格 HTTPS 验证文字、视频、图集、完成提示和组合线索的实际顺序。归档间距修正用该已结算场次只读补拍。原图及输入快照保存在私有目录，公开报告只记录哈希、控件坐标、状态和非私密对账结果。

```sh
starward_private=artifacts/private/gameplay-motion-audit-20261113
starward_reports=artifacts/validation/ui-gameplay-motion-audit-20261113
scripts/hm.sh run
python3 scripts/capture-window-evidence.py --font-scale 1 --require-tls --output "$starward_reports/runtime-06.json"
starward_hap_sha=$(shasum -a 256 entry/build/default/outputs/default/entry-default-signed.hap | awk '{print $1}')
python3 "$starward_private/device-archive-motion-readonly.py" --runtime "$starward_reports/runtime-06.json" \
  --device-ref "$starward_private/device-ref.json" --expected-hap "$starward_hap_sha" \
  --prior-report "$starward_reports/native-clue-motion-01.json" --output "$starward_reports/native-archive-motion-02.json"
python3 "$starward_private/device-answer-navigation-readonly.py" --runtime "$starward_reports/runtime-06.json" \
  --device-ref "$starward_private/device-ref.json" --case-ref "$starward_private/answer-actor-created.json" \
  --expected-hap "$starward_hap_sha" --output "$starward_reports/native-navigation-motion-01.json"
python3 "$starward_private/device-recovery-motion.py" --runtime "$starward_reports/runtime-06.json" \
  --device-ref "$starward_private/device-ref.json" --case-ref "$starward_private/recovery-actor-created.json" \
  --expected-hap "$starward_hap_sha" --output "$starward_reports/native-recovery-motion-01.json"
STARWARD_VALIDATION_DIR="$starward_reports/GameplayClues-final" scripts/hm.sh test GameplayClues
STARWARD_VALIDATION_DIR="$starward_reports/GameplayAnswerViewModel-final" scripts/hm.sh test GameplayAnswerViewModel
STARWARD_VALIDATION_DIR="$starward_reports/lint-final" scripts/hm.sh lint
```

## 首次多题答题引导（2026-11-13）

见 [Q01a](feature-acceptance-matrix.md#q01a-首次多题答题引导)。验收使用独立玩家、长填空及选择题场次、可回放的真实隔离 HTTPS 快照。Web 使用冻结提交 `4b7d1a0`、相同题面和约 388 的内容视口宽度。原图、带鉴权的快照与设备工具日志存于私有目录。公开报告只记录脱敏控件位置、原图哈希和台账差值。

```sh
starward_private=artifacts/private/gameplay-answer-guide-20261113
starward_reports=artifacts/validation/ui-gameplay-answer-guide-20261113
scripts/hm.sh run
python3 scripts/capture-window-evidence.py --font-scale 1 --require-tls --output "$starward_reports/runtime-02.json"
starward_hap_sha=$(shasum -a 256 entry/build/default/outputs/default/entry-default-signed.hap | awk '{print $1}')
python3 "$starward_private/device-answer-guide-final.py" --stage final --dark-choice \
  --runtime "$starward_reports/runtime-02.json" --device-ref "$starward_private/device-ref.json" \
  --expected-hap "$starward_hap_sha" --output "$starward_reports/native-answer-guide-final-01.json"
STARWARD_VALIDATION_DIR="$starward_reports/GameplayAnswerViewModel" scripts/hm.sh test GameplayAnswerViewModel
STARWARD_VALIDATION_DIR="$starward_reports/GameplayRefreshViewModel" scripts/hm.sh test GameplayRefreshViewModel
STARWARD_VALIDATION_DIR="$starward_reports/GameplayBgm" scripts/hm.sh test GameplayBgm
STARWARD_VALIDATION_DIR="$starward_reports/lint-final" scripts/hm.sh lint
```

复现需要重新准备未消费引导的隔离玩家和对应的严格 HTTPS、设备及 HAP 绑定，并使用新的报告路径。

定位使用 ArkUI `Scroller.scrollTo` 和窗口坐标。表单高亮使用不占布局的原生外描边。已对照固定 API 26 声明。[ArkUI Scroll](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-container-scroll/) · [ArkUI 外描边设置](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-attributes-outline/)
