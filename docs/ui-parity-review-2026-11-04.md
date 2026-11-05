# Web 视觉还原复核与协作流程（2026-11-04）

本轮先讨论UI约束、核对参考与取得完整题库，再按确认的流程逐屏修改。首组样板已实现并完成新包构建/安装，实际视觉结论继续单独记录，不以构建代替验收。上一轮入场/答题业务验收继续保留；其14张原图的review范围是可读性与状态语义，不等于Web版式还原通过。

## 已确认的体验约束

- 保留品牌、中文文案、信息层级、内容顺序、字体和版式，以Web正式版尽量还原。ArkUI用于原生容器、材质、反馈、交互和动画，并通过二次封装调整样式；不能由此另做一套内容设计。
- 首页顶底栏现有外部位置、悬浮底栏能力和侧栏玻璃材质保留。侧栏本体用户认可，优先只改重复头部、顶部留白及可用高度，不借机重做中段菜单。
- 侧栏可见头部按Web合并为小星标、冒险者护照和右侧关闭按钮；不再额外显示“冒险者菜单”大标题。无障碍名称可以继续保留，不作为重复可见标题。
- 侧栏默认整体拉高，使普通直板机、正常字号下退出动作尽量无需滚动即可看到；短窗口、长内容及放大字号仍允许内容区滚动，交互目标和安全距离不能被压没。
- 答题页保留官方顶栏，RANK/等级名与下方分界之间增加真实内容留白，并同步核对标题高度预算，不能再塞独立背景占位块。
- **顶栏显隐：题卡上缘滚到顶栏下缘时收起；隐藏后只在回到页面顶部时恢复。反向滚动一点不显示，触底不强制显示。** 系统状态栏始终保留。该规则来自用户本轮确认，不冒充Web原有行为。
- 本轮包含题图和页面还原。视频、BGM、线索演出及后续媒体链路仍独立拆片，不为了对照伪造播放或解锁成功。
- 不确定的版式含义、交互边界及官方能力替代先和用户确认；已明确的要求不重复问。每个UI小点都做设计自审和实际原图对照。

## 参考版本与比较口径

已通过用户登录的Chrome读取线上`/questions/version.json`：production `1.17.1`，commit `4b7d1a0a00051ac630e459b0fd6c074f821d7455`，builtAt `2026-10-27T02:21:01.561Z`。与冻结Web源码提交一致。该观察补充了首轮无凭据探测403的历史，不反向改写旧探测结果。

新直板机已记录的正常字号宽度为376vp、fontScale 1。实际还原验收须将Web内容宽度设为376 CSS px，并分别记录原生状态栏/手势区域；不能把440px的浏览器图直接与376vp原生内容比字号和换行。浏览器本轮仅做页面抽样和诊断，临时尺寸已恢复为440×956，未形成同数据的Web/原生配对通过证据。

现有账号展示两场已完成场次，题数分别为6和8。页面抽样已暴露无题名/有题名、图片、长正文及只读答案差异；完整题库改由接口或数据库采集，不再逐题抄页面。账户、作答、线索及媒体原始数据只留本机私有参考，不写公开验收表。

## 已定位的差异

| 部分 | 当前问题 | 修复方向与边界 |
| --- | --- | --- |
| 侧栏头部 | 自建64vp大标题行后又放护照标题，造成双头与过大留白 | 合并自定义头部，保留现有官方Dialog材质、左右侧入和关闭语义 |
| 侧栏高度 | 当前取可用高度90%，还扣除重复头部，退出落到屏外 | 先移除重复头部，再按真实可用高度微调；优先保留现有中段样式，正常字号检查退出可见 |
| RANK留白 | 三行内容高度正好填满68.6vp固定区域，底部余量为0 | 补真实bottom padding并同步调标题总高度，保持沉浸背景连续 |
| 玩法内容顺序 | 顶栏已有计数，正文又多出场次标题/文案/条形总进度，题面被推低 | 恢复Web的顶栏→题号导航→题卡顺序，不保留为了验收便利增加的常驻块 |
| 手机字级与宽度 | 原生外20+内24、标题28、正文17/1.85，与Web手机样式不同 | 依据同宽Web量取；Web手机外12、题卡内18、正文16/1.72；有题名时标题clamp在376px为37.6px。这些是参考值，最终以同状态原图核对 |
| 无题名状态 | 题库内部名和实际可见标题不是一回事 | 现有hideTitle解码/优先级已保留；按场次及关卡override决定，不给无题名状态新增标题或空占位 |
| 题卡框架 | 只剩普通单圆角边框，遗漏内双线与四角装饰 | 用ArkUI基础布局/边框封装恢复品牌静态装饰；材质和反馈仍用官方能力 |
| 文本答案 | 复用了登录表单的可见标签、整框与字号 | 单独封装官方TextInput的玩法line变体，对齐Web底线、行高与只读状态，不改认证表单 |
| 题号/选择 | 尺寸、间距和额外单选圆点改变了Web节奏 | 题号按手机Web尺寸对照；选择优先核官方Radio完整内容定制，保留原生分组/禁用/选中语义，真实原型通过后采用 |
| 题图与内容块 | 尚无真实题图布局，纯文本测试题不足以证明真实题页还原 | 使用真实内容顺序（图片集合→正文→提示），核图片加载/失败/比例及长文，不以“媒体未迁移”占位代替已纳入本轮的图片 |
| 反馈及重连 | 反馈简化为一行，重连变成占据题卡的大内联块 | 按Web状态层级二次封装原生反馈/Dialog，保持原答案和requestId等已验业务边界；单独小点验证 |
| 常驻操作 | 玩法底部新增大“同步进度”与返回动作干扰版式 | 对照Web保留实际需要的动作，回源优先现有官方Refresh，返回遵循导航栈 |

源码依据：Web `GamePlayScene.tsx`、`QuestCard.tsx`、`QuestAnswerForm.tsx`、`QuestContent.tsx`及手机媒体查询；原生`GameplayPage.ets`、`Index.ets`的`sessionHeader/detailTitleHeight`、`StarwardSidePanel.ets`、`StarwardPassport.ets`及`StarwardMaterial.ets`。不把通用设计skill中的换字体、重配色或新增装饰建议当成迁移要求。

## 官方能力核对结果

固定API26 SDK支持`NavDestination.hideTitleBar(hidden, animated)`。现有`bindToScrollable`会反向滚动即展示且触底展示，不能直接用于本轮已确认语义；应组合官方滚动/可见事件与官方标题显隐动画，UI本地状态不驱动业务提交，减少动画设置继续生效。

当前侧栏的重复大标题是应用自行绘制，不是`CustomDialogOptions`强制提供。合并它不要求移除`systemMaterial`或官方move动画。Radio的`indicatorBuilder`只覆盖选中指示，完整选中/未选中内容应核`contentModifier`并做直板机小原型，不能仅据声明就写交互通过。

## 已确认的协作节奏与首组样板

用户选择“先确认一组样板，后续按规范推进”。第一组只处理侧栏头部/高度与Rank留白；展示同数据对照并由用户确认还原尺度后，再把规范固化为项目skill。之后自行设计自审、真机对照和逐点验证推进，仅新增原生差异或未定边界再询问，不增加每屏都必须人工审批的流程。

| 样板小点 | 需要实际看到的结果 | 本轮状态 |
| --- | --- | --- |
| 侧栏头部 | 只有Web式星标/护照/关闭一行；现有玻璃、头像和中段菜单保留 | 新包两主题原图已核；单行头部/关闭均44vp，距面板上沿12vp；用户已确认本组尺度 |
| 默认高度 | 正常直板机和字号下退出可见，短窗口仍可滚动且关闭可达 | 新直板机普通字号下，两主题首页/详情侧栏退出均初始完整可见；短窗口及放大字号本次未复测 |
| Rank底距 | 等级文字下有真实留白，导航总高度对应，无实心系统栏占位 | 两主题实际RANK底460px，TitleBar底494px，相距34px/3.5=9.714vp（10vp预算的一物理像素舍入）；Root原图已核，用户已确认 |
| 行为与对照 | 打开、关闭、Back及侧入语义保持；同数据Web/原生正常字号两主题原图 | 目标真机29项通过、原生6图/Web4图已逐图核对；对应4组同数据配对，另2张详情侧栏检查左右来源及Back；不扩展为完整玩法视觉通过 |

### 首组样板实际验证

最终预览HAP `334ab6dd75ce07b4b4eeac78390811e506dc4549362a0a9bd47c066c5eff649b` 已由 `bash scripts/hm.sh run` 完成官方构建、签名产物、安装及启动；`bash scripts/hm.sh lint` 的实际JSON为0 issues/errors/warnings/suggestions，filesChecked=0照实保留。此轮只改UI，不重跑未改动的入场/答题业务套件；目标直板机操作单独完成。真实窗口宽376vp、density3.5、fontScale1；系统栏仍透明，原独立三项TLS结果通过。包内NotoSerifSC字体字节与Web注入参考一致。

可复现命令（每次报告与private目录须改为新路径，保留历史）：

```sh
python3 scripts/capture-window-evidence.py --output artifacts/validation/profile/ui-sample-20261104/runtime-02.json --font-scale 1 --require-tls
python3 scripts/device-ui-parity-sample.py run --expected-hap 334ab6dd75ce07b4b4eeac78390811e506dc4549362a0a9bd47c066c5eff649b --runtime-report artifacts/validation/profile/ui-sample-20261104/runtime-02.json --fixtures-json artifacts/private/ui-reference/ui-sample-real-preview-dto-20261104.json --output artifacts/validation/ui-parity-20261104/native-sample-02.json --private-dir artifacts/private/ui-reference/native-sample-02
python3 scripts/capture-web-ui-sample.py run --url http://127.0.0.1:5178 --fixtures-json artifacts/private/ui-reference/ui-sample-real-preview-dto-20261104.json --width 376 --height 742 --font-file entry/src/main/resources/rawfile/fonts/NotoSerifSC.ttf --output-dir artifacts/private/ui-reference/web-ui-sample-02-20261104 --manifest artifacts/validation/ui-parity-20261104/web-ui-sample-02.json
```

Web命令依赖本仓`start-web-baseline.mjs`的冻结只读Vite服务，不能指向真实Web账号浏览器。其认证/辅助响应为本地合成渲染驱动，业务DTO来自真实隔离HTTPS；6个正式Zod校验、22份served源码字节比较通过，4图完成，页面异常0、未预期API0。10条控制台错误来自资源阻断，原始明细仅private，不称控制台0错误或真实Web认证通过。原生新Host读取与同一fixture逐值一致，仅忽略serverTime。实际报告为[原生样板](../artifacts/validation/ui-parity-20261104/native-sample-02.json)和[Web渲染参照](../artifacts/validation/ui-parity-20261104/web-ui-sample-02.json)。原生29项是本组目标检查数，不是整体业务完成度。

首次构建遇到`accessibilityText(ResourceStr)`重载不接受联合类型，已按实际使用收窄为string后重新构建。首轮原生仅采日间2图后因9.714vp与过严9.8vp阈值停止；其间采集脚本又被修改，旧绑定也不再有效，因此保留`native-sample-01.json`为incomplete，不继承其计数。最终轮按真实密度允许一物理像素舍入，且修正关闭按钮贴圆角的问题：头部增加12vp内距，同时内容顶部24→12vp，头像、菜单及退出位置保持。最终29项来源是全新完整单轮，全部绑定最终源码及包。

首次Web采集在Playwright同步WebSocket close处理器等待，已中断并保留incomplete；按已安装官方库的默认路由语义，改成不调用`connect_to_server`的本地惰性mock，未开放WebSocket转发。重新独立采得4图，不继承首轮结果。

Root已查看最终Web4张及原生6张原图，确认本样板的内容语义、单头部、关闭内距、退出可见及Rank留白；侧栏中段仍按用户要求保留现有样式，正文题卡/玩法布局不在此结论中。并排页为仅提供该组原图的本机viewer `http://127.0.0.1:5181/`，截图仅等比例显示。用户已回复“符合，后续按此规范推进”，仅本组样板确认。项目skill已固化为`.agents/skills/starward-ui-parity/SKILL.md`并经独立只读前向审查调整；后续普通实现自主推进，仅改变既定可见布局/交互/材质的替代方案再询问。手机最终留在固定预览账号首页、面板关闭；本轮未临时修改息屏设置。

## 复用流程

1. 通过接口/一致只读数据库快照取得完整内容，按场次、关卡、题目关系建立参考；Web和原生使用同一份数据。完成态从只读参照核对，提交/错答/冷却在独立隔离玩家上验证。
2. 每小点先列Web参考状态、必须还原的内容和已批准的原生差异；遇到影响结果的未定边界先问。
3. 一次只处理一屏或一个明确状态。基于ArkUI二次封装，实现后用设计skill自审层级、字体、换行、留白、内容宽度、图标/表单与状态反馈。
4. 获取同宽度、同字号、同主题、同数据和同状态原图对照；业务、原生交互与视觉分别结论，缺图或只编译成功不记还原通过。
5. 首组样板给用户看具体对照结果并确认尺度；后续每小点交付对照与剩余差异，自行按已定规范推进。建议顺序为侧栏/Rank、玩法骨架与题图、选择/反馈及滚动边界。
6. 样板尺度确认后写项目内`.agents/skills/starward-ui-parity/SKILL.md`，只固化本项目决策和验收方法，引用现有ADR/矩阵，不安装全局风格包或复制大段通用规范。

## 完整题库读取范围

后端正式模型的题面为`content[]`（text/hint/imageUrl/imageUrls/videoUrl）和`options[]`；展示来自`session.presentation`及`session_level.presentationOverride`，不能只取题库title。所有状态、revision和原始JSON键都保留，不按series仅选最新。

已准备接口投影与只读数据库两种采集方式。API catalog覆盖全部题目/场次版本，但通用题目线索只给active，且为投影、非同一事务。要保留归档、原始列、字段缺失与false区别，使用数据库只读单事务采集。原始答案、媒体URL、关系ID和内容保存在ignored private、目录700/文件600；公开只记录数量、覆盖范围及哈希。

用户已通过既有`server.command`连接；本机专用socket已核验，远端已只读确认当前PocketBase容器与声明的数据挂载一致。同一冻结采集器先通过远端Python3.6.8编译预检，再通过stdin执行`capture_content`，未创建远端脚本或运行维护流程。SQLite以`mode=ro`、`query_only=ON`和单个读取事务取得12张内容表376行：28题、28答案键、25题设置、15题线索、41场次、121场次关卡、107场次线索、5叙事、5等级、1奖励；奖励规则及扩展定义均0。缺表/阻断表/显式检查issue均0，所有版本及归档行保留。见[采集回执](../artifacts/validation/ui-parity-20261104/content-capture.json)。这只是声明内容范围的完整读取，不是整库备份、全部业务一致性、媒体可用性或UI通过。

原始内容只保存在本机ignored private；生产库没有写入，玩家、认证及运行时表未读取。首组样板另从固定隔离预览取得真实玩家/list/未入场详情DTO；其ready场次目前已active，使用waiting场次作只读页头参照，不重置用户预览进度。Web重放使用独立合成认证驱动并拦截API，仅证明渲染参照；原生真实HTTPS与视觉分别验收。

内容读取结束后已关闭本任务专用SSH连接，未运行任何生产服务控制命令。离线[UI覆盖统计](../artifacts/validation/ui-parity-20261104/content-ui-coverage.json)已完成：28题全部有题图及正文，25文本/3选择；121个场次关卡组合有效隐藏标题24/显示97。长题干并非现有题库特征，但真实线索和叙事有长文、富高亮及内嵌图；后续必须按对应小切片验证，不能用本次侧栏/页头图替代。真实案例关联索引仅在private中保存。

## 下一独立小点：题卡框架与手机字级（实施前计划）

2026-11-04：首组样板已由用户确认，按项目 `starward-ui-parity` skill 自行逐点推进。本点只恢复题卡静态框架、手机内容宽度、meta/标题/正文的字级与间距；先记录计划，不把实现、编译或既有玩法业务结果当成此点视觉通过。Web 源码基线仍为 `4b7d1a0a00051ac630e459b0fd6c074f821d7455`。

| 状态/范围 | Web 依据与本点实现目标 | 待执行验证与当前结论 |
| --- | --- | --- |
| 手机题卡框架 | `quest-card` 外框1、方角；Web的1px outline-offset为-7，角线CSS inset12、尺寸28×28。实际DOM的角线距外框13（含1px border），outline的绘制边缘为6。纯展示V2 `ui/StarwardQuestionFrame`使用ArkUI Stack与边框，装饰不命中、不进入无障碍树 | 最终108affda…包三组真实题面、两主题实测：四角12.857–13.143vp/28vp，内线5.714–6.286vp，符合一物理像素舍入；本点通过 |
| 手机宽度与内距 | `answer-feedback.css` 手机覆盖：页面左右12；题卡padding上22/左右18/下26。376视口时外框352、扣1边框后的正文314；按真实窗口记录 | 实测外框352、内容314.286vp，对应Web352/314px；本点通过 |
| meta与可见标题 | meta 12/14.4；有标题时meta后18；标题 `clamp(32px,10vw,48px)`、行高0.98、字距−0.055em及均衡换行；继续使用已登记展示字体。保留level `hideTitle` 覆盖session及false/缺失区别，隐藏标题不留空 | 长题名两行分配、短题名一行、无题名无节点/空白，两主题原图已核；本点通过 |
| 正文块与间距 | content上距20；block间20、内部13；正文16/27.52。继续直接读V2 ViewModel，保留当前关卡的稳定level.id | 三组正文1/2/3行与Web对应；提示开合后框架尺寸正确、返回GET不重复入场。真实图片引入后的块高及已完成事实刷新在所属点复验；本点不扩展该结论 |
| 明确后续范围 | 输入line、选择题样式、真实图片及其查看交互、反馈/重连、Refresh、重复总进度清理、题号导航样式和顶栏滚动显隐均不在本次修改中 | 逐点另列实现与实际验收；本点不声称玩法整体还原 |

本点由Root执行固定工具链构建/lint和直板机限定对照；业务未改，不重复旧入场/答题大回归。源码交接后冻结，运行中的采集器、产物及报告不得由本点实现者修改。

准备与首轮观察：已按完整私有内容快照选出3个完整单关原场次，覆盖有/无题名、多块、选择图和题图集。新增本仓受控导入器只在新一次性PocketBase内创建3组专用玩家/场次，通过官方管理员/玩家接口读回19条内容关联；原题面、线索及presentation保留，新身份/版本/发表状态明确为隔离夹具，不冒称历史数据库克隆。旧seed、全局rank及固定预览DB/账号没有重置。

题图CDN无Referer时实际返回403，错误指向来源校验；使用Web合法站点来源`https://sitkin.top/`后，8张题图原始字节全部读取成功，无Authorization。发现其中3张HTTP头为image/png但实际为JPEG，原始头/文件均保留，另记detectedMime；浏览器重放原始字节及响应类型，不能据错误的HTTP头拒绝有效图，也不能改图凑对照。此时Native图片仍未实现，不从参考字节读取推定原生加载通过。

首轮Frame包e29b73b8…已构建、安装、lint和真实窗口/TLS通过；case0仅到日间几何检查即incomplete，截图实测角线左/上11.143vp、右12.857vp、下13.143vp，内框上6/下8vp，证实绝对装饰层原点包含外框边界，已据实调整。该轮仅保留实际的0答题/0经验、退出清空等cleanup记录，不把结果或计数继承到后续报告。Web第一组参照虽完成渲染采集，但Root看原图发现浏览器BGM确认提示遮挡题卡；重采时只使用既有关闭动作收起提示，未开启播放，BGM仍在后续切片。新的实际DOM测量确认四角相对外框13px，后续原生按该坐标比较，未降低像素检查来掩盖偏移。

Root原图复核又发现：70a21fa6…包长题名虽然同为两行，却按GREEDY将末字单独放一行；Web的`text-wrap: balance`分配不同。现按API26固定SDK和[官方Text全文](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-text)核验，使用自API12提供的`lineBreakStrategy(LineBreakStrategy.BALANCED)`，不插入换行或改字体/字距。最终108affda88c0c26634860095c467dee3d132135db530c8c14e9910d8580bf3b9包构建/签名产物/安装启动、lint零issue及窗口/TLS五项通过。三组case均用新目录完整执行（5/3/3项），退出清空及零越界写入均通过；不是继承70a21结果。

最终证据为`ui-question-frame-20261104/native-case{0,1,2}-03.json`、`web-case0-02.json`及`web-case{1,2}-01.json`。三组Native/Web DTO逐值对应，只忽略serverTime；Web独立浏览器重放原始题图与正式schema，均无页面异常/未预期API，非本点资源阻断错误保留private。Root实际核6张最终原生题卡顶部、1张提示展开及8张Web原图，确认框架/手机字级/换行这个窄范围。最终HAP字体与Web源文件字节一致；UiTest未暴露实际fontSize字段，不冒称独立读取了系统字体属性。报告见[Root复核](../artifacts/validation/ui-question-frame-20261104/root-frame-review.json)。题图、表单及整页差异仍明确待修，不能将此点写成整页视觉通过。已验包与当时Page/Frame源码仅private归档，便于后续小点不混用证据。

## 页面层级与手动回源（计划与实际结果）

仅在题卡框架/换行复核完成后实施。Web活跃态是原生顶栏对应信息→可选业务消息→多题导航→题卡，没有正文重复场次标题、条形总进度或常驻同步/首页大按钮。手机块间距16；保留现有官方顶栏布局、系统Back和头像侧栏首页入口，不直接打开一个会改变页头布局的系统返回按钮。

| 状态 | 本点目标与验证 |
| --- | --- |
| 正常单题、两主题；多题导航另点 | 移除重复摘要和常驻按钮；唯一顶栏计数来自有效玩法快照，正文首项及块间距按16核对；题卡内部不改。多题导航样式/横滑与相邻题切换在后续导航点独立验 |
| 下拉回源 | 复用官方StarwardRefresh，独立动效状态；新增有效页GET刷新，保留快照、同题输入实例及最新草稿，提交/切题与刷新互斥；不将动画结束当成业务完成 |
| 临时GET失败/重试 | 网络、超时、408/429/5xx保留已有可信快照和草稿，显示小型失败提示及GET重试；没有start/answer写入 |
| 认证/目标/契约失效 | 清私密快照与草稿，走既有错误/认证所有者边界；无有效玩法快照时隐藏顶栏旧计数，不补0/0 |
| 返回与账号边界 | IME优先关闭、侧栏优先关闭、系统Back只退一级；刷新中离开或退出，迟到成功/错误不恢复内容或修改新页状态 |
| 明确不改 | `reload/open`保留未知答题结果显式GET恢复语义；新增下拉refresh拒绝未确认写入。Web五秒自动回源、题图、表单、反馈、导航样式和顶栏显隐另验，不能从本点推定完成 |

先跑相关ViewModel测试、构建/lint，再限定直板机/隔离真实HTTPS检查。业务测试不能证明焦点或输入实例保持；它们必须看实际IME与页面交互。

### 本点实际结果

最终499bbf605fc1124fb567bf115f9f75bd20824d08bcf5e3eaff6fd94fe77bf5eb包已官方构建、生成signed产物、安装启动；lint实际零issue（filesChecked=0），真实窗口/透明系统栏/正常字号及三项TLS组成的五项运行时检查通过。独立refresh/canRefresh保留原reload的未知写入GET恢复语义；初次读取/致命错误仍清私密事实，只有有效页手动刷新保留快照与当前题。

相关业务测试唯一29项（刷新7、入场VM10、答题VM12）实际通过，失败/忽略0，Root已核原始report尾部及summary。补充503后答题成功清旧刷新提示的断言已在原12项内复验，不叠加计数。一次受控mutation实际失败1项，已逐字节恢复VM并7项复验，不计入通过数；见`ui-gameplay-layout-20261104/refresh-unit-validation.json`及`refresh-error-clear-validation.json`。

`scripts/device-gameplay-layout.py`只复用既有严格owner/case/CA/runtime守卫，未放宽旧Frame或入场/答题采集器。`native-layout-01.json`实际7项通过：两主题卡片距TitleBar底57px/3.5=16.286vp（16vp的一物理像素舍入）；正常页无重复摘要及常驻大动作。成功GET、503及显式重试前后，真实UiTest的非空accessibilityId/hashcode与草稿一致，原值只留private；404移除题目、输入和旧计数，reload后权威计数恢复、草稿为空。实际IME避让区中输入与未触碰的提交按钮可见，Back收键盘/关闭侧栏保持同一输入与草稿。

精确该场次GET延迟12000ms；原生直接菜单退出耗时6949ms，空登录已出现时完整成功响应仍在等待发送，之后完成而没有恢复私页或凭据输入。请求账本无start/answer/profile等写入，前后均0答题/0经验且原入场receipt仍1；退出清空、远端临时raw删除及未消费故障清除均通过。清除故障使用JSON null，不能用留下待消费对象的delay0冒充清空。固定预览服务、DB和账号未修改。

可复现设备命令（必须换fresh输出路径）：

```sh
python3 scripts/device-gameplay-layout.py run --expected-hap 499bbf605fc1124fb567bf115f9f75bd20824d08bcf5e3eaff6fd94fe77bf5eb --runtime artifacts/validation/ui-gameplay-layout-20261104/runtime-01.json --expected-fixture-sha 1ad7a59cc1f13e6dd7ec5550c8f5ab4a5906b90f9a9b56ac948143a4995e8745 --case-ref artifacts/private/ui-reference/question-frame-case-0.json --output artifacts/validation/ui-gameplay-layout-20261104/native-layout-01.json --private-dir artifacts/private/ui-reference/gameplay-layout-native-01
```

Root已实际核本轮5张原图，并与同数据Web参照核结构，DTO只忽略serverTime后逐值相同。独立源码审查无高置信阻塞；本点结论见[Root窄复核](../artifacts/validation/ui-gameplay-layout-20261104/root-layout-review.json)。本轮只验活跃单题页及其刷新/返回/账号边界，不将图数、29测试或本轮7检查换算为整体玩法完成度；多题导航、题图、表单和顶栏显隐等仍另点。

## 下一点：结构化题图显示（实施前）

先做正文`imageUrl/imageUrls`显示、加载/失败重试、比例/图集及取消；显示点验证后再做点击查看，选择图与完整Radio样式同点衔接。用户于2026-11-05明确选择小尺寸原生“图片加载失败，重新加载”动作，保留答案，不加固定大占位，这是本点已批准的Web差异。题图/选择图/正文内嵌图的本轮总范围不变，不把显示子点当作图片查看或全部图片通过。

| 状态 | 待验证 |
| --- | --- |
| 单图/多图 | 使用三组真实题面和实际CDN；图片先于同块正文、提示。316以下按实际内容宽算，376基准内容314；图框含2边框后等比缩小、不放大小图，手机最高340。图集列宽152/间距10，第三图不撑满末行 |
| 加载/失败/重试 | 官方加载反馈和小型重试；独立失败夹具明确合成来源，不篡改真实题目参照或固定预览；重试只有媒体GET，答案与判题requestId不变 |
| 取消/所有权 | 同题Refresh保留图片实例，换题/离页/退出清理请求和PixelMap；迟到成功/错误不能恢复旧图；原始URL不进入日志/公开报告 |
| 双主题/真实基准 | 真机实际网络与ImageKit解码，两主题同数据原图核自然尺寸、边框、块顺序/间距；加载成功与Web字节重放分开 |
| 明确后续 | 图片查看/索引/Pinch/Pan/关闭、选择图+Radio、富文本内嵌图合成正例、视频/BGM/线索演出、页面背景和顶栏显隐分别记状态 |

离线使用正式Web解析器核完整28题、35个content块、12个option条目，正文/提示/选项中四类富文本标记均0；三个已选真实case亦0。不能虚构“真实富文本正例通过”，后续正例用独立合成夹具。选择项Web本来是plain text；完成/禁用时其fieldset也禁图片按钮，原生默认保留该既定语义，不擅自增加“完成后仍能点选择图”的差异。

### 显示子点实现与当前阻塞

已实现独立`QuestionImageLoader`及V2 `StarwardQuestionImages`：官方HTTP/系统TLS/禁自动Cookie/固定Referer，真实格式与自然/解码尺寸分离、显式取消/释放；单图和图集保留品牌边框与顺序，小图居中且不放大、最小44高度；官方加载反馈遵守减少动画设置。Page图片先于正文/提示，移除已失真的“当前仅显示文字”实现提示，内容到答案区恢复24间距。VM只增加图片owner key，账号/离页代次失效，同题GET保持key；不改变判题或写请求。独立源码审查无高置信阻塞，但不能替代实际Image绘制和资源生命周期验收。

旧Frame/Layout一次性环境已精确退役，11项归属/DB/容器/监听/映射及其它容器保持检查通过，旧runner字节已按原hash恢复归档；固定预览服务/DB/CA/账号保留。新runner独立新增合成图片失败入口，不放宽原3case/19条守卫。真实原包重建3组专用普通账号并读回19条；单独派生case只覆盖原case0的首imageUrl，原包/8张参考图片字节不变，另7条目标记录完整读回。派生候选尚未实际确认404，不能从“随机缺失文件名”推断请求结果；见`ui-question-images-20261104/fixture-creation.json`。

初次编译发现`scale()`与ArkUI CustomComponent通用属性同名，已更名`imageScale()`后通过真实编译。最终ddc149ba768ba9781a0f3e46911c210f967300849c503085e9ac6c73e96c943f包已构建/生成signed产物并安装；`hm.sh run`整体exit0，但启动阶段日志明确返回官方10106102（屏幕锁定且自动解锁失败），因此**启动、当前包原生运行时、图片网络/绘制与视觉均仍待验**。用户解锁请求已发出；不反复尝试绕过锁屏。

相关刷新VM7项复验通过，失败/忽略0；lint实际零issue、filesChecked=0；新Host严格TLS三项通过。源、包、夹具及两个独立设备采集器已绑定到[待设备回执](../artifacts/validation/ui-question-images-20261104/build-and-device-pending.json)。公开候选1186文件扫描0敏感发现/0读取错误，Web和后端源仓均0改动。该回执不是Native图片验收报告。

解锁后的执行顺序：先`capture-window-evidence.py --output artifacts/validation/ui-question-images-20261104/runtime-01.json --font-scale 1 --require-tls`，确认已安装包与五项真实运行时；再对`question-images-case-{0,1,2}.json`分别运行`device-question-images.py`，输入原包SHA、manifest-sniffed SHA及既有三份Web参照，报告和private目录每次fresh。独立`device-question-image-failure.py`使用`question-images-failure-case.json`与derivation SHA707f2c0a…；它不借旧3case守卫冒充合成案例，必须从当前App PID官方hilog看到首次/重试/GET回访各一组loading→404，核同输入实例与草稿、零答题/XP及退出清图。尚未执行任何一份Native图片报告。图片查看和选择图仍在显示子点之后推进。

当前一次性图片服务仍运行等待手机，USB18443用于该测试；固定预览的原映射恢复回执继续保留，任务收尾须精确清该一次性环境并恢复固定预览。不得把旧预览账号拿来登录当前新测试DB或重置其口令。
