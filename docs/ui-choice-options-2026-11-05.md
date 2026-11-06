# 选择选项与选项题图小点

本点从已冻结Web `4b7d1a0a00051ac630e459b0fd6c074f821d7455` 还原 `ChoiceOptions.tsx`、`QuestAnswerForm.tsx`、`quest.css:413–519`、手机 `answer-feedback.css:461–469` 及 `quest-lighting.css:185–215`。实施前状态目标见[逐状态表](feature-acceptance-matrix.md#2026-11-05下一小点选择选项与选项题图实施前)。本页分开记录实现、实机、真实隔离HTTPS与视觉证据。

## 设计自审与官方封装

已依项目`starward-ui-parity`和`frontend-design`自审本点的信息层级、留白、字级、选中辨识、图片命中和资源归属。设计方向由冻结Web决定：沿用既有品牌资源和原生UI字体；保留方形字母与文本头、下方全宽缩略图，去额外Radio圆点。手机列间10、头部最小58、内距8/14、字母列40/字母框28、正文16；边框1与左选中3内线分别绘制，不加宽边框挤压正文。几何数值是实现目标，非设备测量值。

`ui/StarwardChoiceOption.ets`以V2参数接收原语及账号/关卡资源归属，不持有答案领域状态。官方Radio的`contentModifier`替换完整内容，Builder直接读取`RadioConfiguration.checked/enabled`；点击只在enabled时调用`triggerChange(true)`，由Radio的`onChange(true)`通知ViewModel。外层无点击处理，缩略图Button作为Radio兄弟，避免图片查看改变选择。Radio显式`.margin(0)`，去掉官方默认四边14px间距；不使用不存在的DOM式`stopPropagation`。

已先搜官方知识再读Radio及ContentModifier全文，并核固定API26 SDK：`contentModifier`、`RadioConfiguration`与`CommonConfiguration.enabled`自API12支持，Optional重载自API18支持，Stage/SysCap为`SystemCapability.ArkUI.ArkUI.Full`，不新增权限。[Radio](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-radio)、[ContentModifier](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-attributes-content-modifier)。实际自定义内容的checked、无障碍名称、焦点及输入仍需真机验证，API可用不代表交互通过。

选中沿现有accent/淡底/反色字母，绝对位置的官方径向渐变层以accent的24%透明度呈现8%/50%光晕，不截获输入。UIContext官方关键帧以620ms表达0→9vp/1.014→6vp/1.006的Web选择反馈；回调只改本地呈现，不驱动答案、网络或进度。递增代次和当前selected限制旧运动回调，减少动画时直接落到最终姿态。图片和文字头的最终几何、阴影与原图仍由同宽对照裁定；不能据动画参数宣称动态体验通过。

## 缩略图与查看归属

每个选项独立使用原有有界`QuestionImageLoader`，沿用既有来源校验、类型嗅探、尺寸/字节限制和系统TLS。源/owner变化及离开会取消并释放；每次异步结果校验挂载、代次、来源及owner，迟到结果只释放。选择或同题Refresh不主动重新加载同源图片；不改已验正文图片、查看器或平台资源源文件。

手机图框目标130高（含顶部1边框）、图片129高Cover；D无图时不渲染图框。就绪图片与其独立的原生Button分层绘制，加载与失败使用现有小型原生反馈，retry和图片Button均服从与Radio相同的editable门控。只读/已完成等Web字段集禁用状态同时阻止选答和开图，不由普通图片可见推定可点击。

`GameplayPage`按key直接读取当前V2 ViewModel的文字、图源、选中及editable，以稳定option key创建封装。选项图只把当前自己的单个URL交给既有查看器，附带账号代次/关卡/option/source与editable校验；A/B/C不会组合成跨选项图集。含视频的选项仍属后续播放小点，不把poster伪装成图片播放入口。

本轮真实case1参考包含A/B/C各一张已登记原图与无图D，视频均空。生产和原Web/后端仓库只读；验收使用专用隔离玩家、官方构建/lint和同数据日夜原图。正文404和历史选择业务验收不代替本点实测。


## 2026-11-05：首轮构建与采集器边界

[构建命令回执](../artifacts/validation/ui-choice-options-20261105/build-checks-01.json)实际official run、lint及两个相关业务测试命令均exit0，新signed HAP为`affea704d312f3505f983b1db37c52ed105de7bce5558dc3926ddd436b3ede2e`。已实际安装启动，[运行时](../artifacts/validation/ui-choice-options-20261105/runtime-01.json)五项passed；[质量回执](../artifacts/validation/ui-choice-options-20261105/quality-checks-01.json)核12项答题ViewModel与7项Refresh ViewModel均通过、失败0。lint归一化报告0issue，实际扫描覆盖数未证明。这些不代替自定义Radio交互和视觉验收。

[Native01](../artifacts/validation/ui-choice-options-20261105/native-normal-01.json)为incomplete、0检查/0状态，五项cleanup均true。专用case1经原生正式入场一次，正文及选项图已加载；第一份选项树实际仅含可见的A/B/C三个Radio，离屏D不存在，采集器错误地要求一棵树内四个节点而停止。现有raw仍保留，不能将此定性为产品丢失D或Radio失败。复核还发现A→B→A的采集文件名会重复，尚未执行到该分支；修复只限采集器，后续使用新报告/目录，不修改产品源码、不重写失败记录。

[Web01](../artifacts/validation/ui-choice-options-20261105/web-reference-01.json)已用本轮post-start DTO及同8张登记原图进行隔离重放：日夜14状态、2项目标检查、6项正式schema及50项served源码核验，后端/外部请求放行均0。9条被阻资源console错误保留private，认证与辅助响应为重放。该结果仅是Web参照，尚无Native视觉通过结论；后续原生新轮若DTO原字节变化，另取新Web报告保持同数据绑定。


[Native02](../artifacts/validation/ui-choice-options-20261105/native-normal-02.json)另为incomplete、1检查/4状态、五项cleanup全true：已实测四项宽度314/312、头部最小58与三图130，D无图框，原文案一致。首个选择动作后，采集器误从CLI归一化树读取其未提供的checked字段而停止；真实raw的Radio含checked/enabled字符串布尔，固定CLI转换函数不保留它们。该轮不据此判Radio选择失败或通过。新修正让CLI只等待控件存在，选择/禁用语义仍逐一读真实raw；旧cc5采集器与02报告保留，下一轮使用新目录，不重编或重跑未改产品的旧链路。


[Native03](../artifacts/validation/ui-choice-options-20261105/native-normal-03.json)保持incomplete、3检查/10状态，五项cleanup全true。日间初始几何、A→B→A的四个真实Radio互斥与实例保留、选中B时独立打开A及关闭无新增API/选择变化均有原始记录；未完成夜间和Refresh，不拼接为整轮通过。Refresh准备的旧`quantitative_top`把裁剪后的长题卡top误当真实位置：12份原始树中题卡top都等于顶栏bottom，不能证明距页顶只有16vp；工具因此在触发刷新前停止。后续仅修采集器：官方手势滚回顶部并下拉，以首个新真实GET/唯一请求/前后实例为目标，不再凭裁剪坐标声称页顶几何。产品和HAP未改。

## 2026-11-06：正常与完成态实际结果

[Native04](../artifacts/validation/ui-choice-options-20261105/native-normal-04.json)绑定首轮`affea704…`包，8项检查、21状态、19张原图、五项cleanup全true。376vp、字号1，日夜均实际选A→B→A且四个Radio实例不变。选B时点A的图只打开本图，关闭与系统Back都保留答案及节点，打开/关闭没有新增业务请求。滚回顶部再下拉产生一次新GET 200，四个Radio与三个图框/图片实例保持。返回后重进只读回源；退出清除私密页。真实台账为一次开始、一条进度、零答题、零答题凭证、零经验。此次不凭裁剪后的题卡位置推断真实滚动距离。

[Web04](../artifacts/validation/ui-choice-options-20261105/web-reference-04.json)按Native04的同一post-start DTO与登记原图重放14个深浅状态，正式schema 6项、served源码50项，未放行外部或后端请求。它是视觉参照，认证为重放，不能替代真实登录或接口结果。[原图复核](../artifacts/validation/ui-choice-options-20261105/root-delegated-normal-final-review.json)逐图看过17张独立Native原图与10张独立Web原图，其余为已看原图的字节重复，检查选项层级、文案、Cover裁切与日夜辨识。阴影/光晕强度略有差异；左选中线压到图的差异随下述颜色修正调整。原生截图证明真实显示，未记录设备下载字节的SHA。

[Native完成](../artifacts/validation/ui-choice-options-20261105/native-completed-01.json)同包真实提交一次，服务端记录一条答案、一个答题凭证、一条完成进度与一条经验记录，累计增加50 EXP。答题前后13个实测节点实例保持，四个Radio和三个缩略图按钮实际禁用，三次代表性触碰没有改变答案、打开大图或发出请求。报告保留`incomplete`：历史场次被采集器从错误分类查找；提交中的过渡太快，也未捕获。独立[历史重进](../artifacts/validation/ui-choice-options-20261105/native-completed-reentry-01.json)从「旅途回响」进同场次，只有两次真实详情GET 200，原答题凭证和50 EXP保持，控件仍只读。两份报告五项cleanup均true，未再次提交。[完成态Web](../artifacts/validation/ui-choice-options-20261105/web-completed-reference-01.json)用真实完成DTO重放日夜4状态；[完成原图复核](../artifacts/validation/ui-choice-options-20261105/root-delegated-completed-01-visual-review.json)发现禁用的原生Button连同其子Image变暗，Web仍保留原色。

## 完成态颜色修正与定向复验

保留官方Button和真实disabled属性。成功图作为不接收触摸的独立Image绘制，透明Button叠于其上；选中线先绘制，缩略图盖住它在图区域的部分。第一次构建[失败](../artifacts/validation/ui-choice-options-20261105/photo-color-fix-build-01.json)是占位Blank不能直接用于该层，改用空Column后[官方run及lint](../artifacts/validation/ui-choice-options-20261105/photo-color-fix-build-02.json)均exit0，lint归一化0项。最终隔离签名包`872a3a8e81463ded0948790edbcbe9aa325762827df855d8bc51edbbff2ed214`已实际安装启动，完成态和活跃态各有5项运行时检查通过；此次仅改绘制和命中分层，未重复既有19项业务测试。

- [完成态定向真机](../artifacts/validation/ui-choice-options-20261105/native-photo-color-completed-01.json)：保留原已结算的隔离玩家。三张缩略图各采深浅原图，覆盖图上的按钮确实禁用，代表性点击无查看器/无请求；两次详情GET 200，答题凭证与50 EXP不变，五项cleanup全true。[修正原图复核](../artifacts/validation/ui-choice-options-20261105/root-photo-color-completed-review.json)逐张查看六份原图，三图在日夜均保留原色与Cover，选中线止于图上方。
- [可编辑态定向真机](../artifacts/validation/ui-choice-options-20261105/native-photo-color-active-01.json)：另建一次性数据库及专用玩家，使用同源题库与图片；由隔离主机完成一次真实入场。两次详情GET 200，选B时实际点A图只打开单图，关闭仍为原已选B Radio实例。点击及关闭无新业务请求，未答题、未产生经验，五项cleanup全true。[打开原图复核](../artifacts/validation/ui-choice-options-20261105/root-photo-color-active-review.json)确认图完整、无图集控件、关闭及缩放说明可读。

官方命令由`scripts/hm.sh run`、`scripts/hm.sh lint`及[构建回执](../artifacts/validation/ui-choice-options-20261105/build-checks-01.json)中列出的两条定向测试组成。采集器为`scripts/device-choice-options.py`、`scripts/device-choice-completed-reentry.py`、`scripts/device-choice-photo-color.py`及`scripts/capture-web-choice-options.py`、`scripts/capture-web-choice-completed.py`，实际运行使用与报告绑定的私有配置与归档版本，不使用固定预览账号做写入试验。

选择控件的正常与完成态、图片打开和颜色修正已有上述实测。提交pending、冷却/锁定、缩略图失败/重试/取消未在本点实测；无全页视觉、减少动画实机或折叠屏结论。填空输入、提示/反馈、顶栏滚动显隐及媒体播放仍按独立小点推进。

[固定预览恢复](../artifacts/validation/ui-choice-options-20261105/fixed-preview-restored-01.json)另行通过：正式调试安装的预览包与隔离验收包的应用代码成员一致，环境配置与CA独立；原预览数据库、账号和CA保留。直板机直接登录、读取列表并停在首页。这不是新的答题验收。
