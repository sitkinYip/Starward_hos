# 原生迁移基线与功能验收对照表

核验日期：2026-10-27；2026-10-28追加系统区沉浸、空详情进度及键盘避让修复（Asia/Shanghai）。本表把功能存在、代码实现、实际运行和视觉对照分开记录；列出验收项不等于通过。修复后最新源码37/37业务测试及lint（0 issues、filesChecked=0）已实际复跑通过；迁移前真实HTTPS49项和沉浸调整前官方UI17项保留各自版本归属。独立1.3字号构建已42/42通过；正常字号HTTPS构建22/22系统UI与6项运行时检查通过，认证4图及主视觉18图captured且清理完成。最终默认mock另有13/13冒烟与4项运行时检查通过，已恢复设备；Web20与原生22图已逐图对照，保留两项非官方细节待调，不标逐字逐像素全过。旧正常字号22项UI与22图已归档为修复前证据，不借旧计数推定新HAP通过。完整结果见 [首切片验收记录](slice-01-validation.md)、[HTTPS及视觉复核](slice-01-https-and-visual-validation.md) 与 [官方ArkUI验证](arkui-system-validation.md)。

## 冻结基线与证据边界

| 对象 | 本次实测 | 含义 |
| --- | --- | --- |
| Web 工作树 | `/Users/sitkin/my_code/questions-web`，`main`，干净；HEAD `4b7d1a0a00051ac630e459b0fd6c074f821d7455`，提交时间 `2026-10-27T09:59:24+08:00`，标题 `feat:pwa适配` | 原生首切片冻结的本地正式入口源码候选；本地跟踪的 origin/main 包含该提交，不代表刚刚查询过远端 |
| 后端契约 | `/Users/sitkin/my_code/sitkin-pb-backend-management/backend/contracts/game.ts`；HEAD `c28f488d6b682ae213713ccdd2d992595a941ae3`；该文件 SHA-256 `7264d8e16a65a64c8de8f39088327647bdfb5c1c635cb9393ebf80ae085c43bf` | DTO 权威。Web `src/api/game.contracts.ts` 为生成物，运行校验在 `src/api/game.schema.ts` |
| 本地既有 dist | `dist/version.json` 为 `0.0.0-local`、`channel: local`，commit `671c062210a3564335ad7be8f3f5a28352f573a4`，builtAt `2026-10-27T01:54:57.939Z` | 早于当前 HEAD，不能作当前视觉或正式发布证据 |
| 生产版本探测 | 无凭据 GET `https://sitkin.top/questions/version.json` 返回 HTTP 403 | 本轮未能确认线上 release commit。不得把当前 checkout 声称为线上同版；未读取私人业务数据，未执行生产写操作 |
| 视觉与交互基线 | 冻结源码390×844深浅12图、同Noto字体12图已捕获；迁移前391×777登录配对及认证4图留存 | 历史登录主要控件纵向差小于0.6vp、星中心差约0.41/0.09vp；旧主页等18项捕获仅incomplete/count5，键盘图主题校验失败。以上不是新系统UI通过证据；Web材质与动效不再是逐像素目标。详见 [视觉对照](web-native-visual-comparison.md) |

正式路由权威是 Web `src/app/App.tsx`：`/login`、`/`、`/profile`、`/rewards`、`/notifications`、`/play/:id`、`/play/:id/content/:contentId`。旧 `?qa/?qas`、独立 Letter/Bless、clearCache 和编辑器预览不属于本次玩家正式入口；正式解锁剧情中的 letter/bless 仍须迁移。PWA 安装机制由原生安装机制承接，无需复制浏览器 Service Worker。

后续发布基线确认应保存 production `version.json` 与对应 git commit 的核验结果；若与本表候选不同，明确差异清单后调整。不得静默换基线。

## 原生体验验收准则（2026-10-27、2026-10-28更新）

按 [ADR-013](architecture-decisions.md#adr-013官方-arkui-组件与沉浸光感优先)，保留品牌、文案、业务语义和既定信息布局，通用容器、材质、反馈及动效优先采用官方ArkUI并封装于 `ui/`。Web继续决定业务、布局和逐状态对照；官方沉浸光感、浮动容器及平台交互是已批准差异，分别记录实际支持、降级和设备表现。

顶栏布局保持，使用官方Navigation及真实通用沉浸材质；底栏采用官方浮动Tabs，分类采用Tabs/SubTabBarStyle，Sheet、Refresh、Toast和动画使用相应原生能力。首页移除固定同步块，列表延伸到浮栏下方，原句“场次与进度会自动同步，放心去探索。”作为自然滚动内容的最后一项，只保留浮栏和安全区所需间距。Refresh动画独立持有UI状态，不能与 `vm.listBusy` 双向绑定或由动画结束驱动业务写入。

2026-10-28按 [ADR-014](architecture-decisions.md#adr-014系统避让区只约束内容背景与材质延伸到屏幕边缘)追加系统区沉浸：状态栏和底部手势区透明，背景与材质延伸到屏幕边缘，仅交互内容按真实避让区留距，不放独立白/黑占位块、不隐藏系统栏。当前HAP来源为 `native-system-visual-hap.json`，准则与窗口版本必须同时匹配 `arkui-system-v1 / edge-to-edge-v1`；后续字号或mock构建另存产物摘要，不覆盖该来源。

按 [ADR-015](architecture-decisions.md#adr-015真实业务事实与页面级键盘避让)，详情ID为空时不绘制默认进度；认证页使用官方页面级 `KeyboardAvoidMode.RESIZE`，按实际App/Scroll/IME交集验证字段和完整主按钮可滚动到达。旧构建实测404仍显示“0/0”，1.3字号密码IME下主按钮仅露46px且继续滑动无变化；这两项缺口不能由旧报告的通过计数抹去。

沉浸调整前官方系统UI17项通过报告在 `artifacts/native-pre-edge-to-edge/`；修复前 `2b757938…` 构建的系统UI22项、认证4图和主视觉18图在 `artifacts/native-pre-final-fixes/`，其 `archive.json` 明确不计当前验收。更早的Web近似布局图在 `artifacts/native-legacy-pre-system`。正常字号最终HAP为 `3bacb424…`、viewRevision为 `authoritative-progress-and-keyboard-resize`；独立1.3字号HAP为 `fdda3840…`，不得互换。官方组件提供的窗口适配能力单独记录，折叠、悬停、分栏和窗口变化须有对应实测，不因选用了官方组件而标通过。

## 首切片范围

首切片是“登录 → 首次强制改密 → 主页场次列表 → 一个场次的开始前详情”。允许以可辨识的本地 mock 构建打通，HTTPS 实现使用同一 Repository 契约。答题、领取、通知、剧情及完整媒体不在本次实现范围，保留下一切片入口边界，不能显示为已经完成的业务能力。

如果为了完整演示包含“开始”写操作，必须另行满足 B09/B10 的幂等和返回结果验证；只有详情只读时不要用点击后本地改成 active 冒充服务端已开启。

下表未明确标注修复后版本的“真机已验”，仍指迁移前49项或已注明的历史设备报告；最终版本结果须附匹配HAP、viewRevision及窗口版本的报告。

| 编号 | 触发/逐状态 | 必须保留的行为与可观察断言 | Web/后端证据 | 原生验收证据 |
| --- | --- | --- | --- | --- |
| A01 | 未登录启动或直达受保护详情 | 转登录；不闪现私人内容；合法待前往路由可恢复；不能跳至外部 URL | `GameContext.tsx`、`GameLoginPage.tsx` | 真机已验：HDC Want冷启动 `starward://assignment/<id>` 进入登录/强制改密，门禁前无列表或详情请求，真实改密成功后恢复原目标；有限ID/拒绝外链另有Routes测试。未宣称生产App Links域名关联已验证 |
| A02 | 登录空账号/空密码、输入/显示密码 | 输入标签、密码显隐、键盘遮挡；空值不发请求；帮助说明账号由管理员提供，无注册 | `GameLoginPage.tsx`、`e2e/game-pages.spec.ts` | 历史真机空输入不发认证POST已验。修复后1.3字号42项验证账号/密码焦点、完整CTA在实际IME上方可滚动到达、无键盘区手势，并用非敏感探针核验密码显隐；探针不发认证请求。普通账号IME有截图，密码焦点只用脱敏UiTest几何，不计主题截图通过；实际读屏语音另验 |
| A03 | 正常登录及重复点击 | POST 账号 trim+lowercase，密码保持原值；请求中禁用；只有 auth 返回与 /me 均通过结构验证才完成登录；密码不持久化 | `game.client.ts`、`game.client.test.ts` | 真机已验：带首尾空格及大写账号登录，认证延迟下双击仅一条POST；auth及/me验证后进入门禁。请求台账确认原token且无Bearer；身份不符与迟到响应另有Repository/ViewModel测试 |
| A04 | 账号错误、网络错误、超时、503 | 原位错误，可再次提交；不进入主页；保持有用输入；不会把 HTML/空成功体当正常 DTO | `game.client.ts`、`e2e/api-errors.spec.ts` | 真实错误密码400与注入认证503均原位显示错误；18秒注入延迟已触发配置2秒的原生超时，并经后续新GET200恢复。代理错误体业务回归已过；改密丢响应另见A08，不将注入当生产故障 |
| A05 | /me 响应缺字段/错类型 | 明确契约错误；不得展示半截私人内容或接受未校验玩家 | `game.schema.ts`、`e2e/api-errors.spec.ts` | 真机已验：本次auth200后，带认证的/me实际消费注入200畸形DTO，显示精确契约错误且不读列表/详情；缺字段、错类型、身份不匹配另有Contract/Repository测试。该畸形体是故障注入 |
| A06 | mustChangePassword=true | 强制展示改密，主页/详情/深链受同一门控；可退出；系统返回不能绕过 | `GameContext.tsx`、`PasswordPage.tsx`、`e2e/quest-flow.spec.ts` | 真机已验：首次改密前无列表/详情请求；系统Back及实际边缘返回不能绕过门禁；改密后恢复原深链。强制页显式退出后账号/密码为空，仍回登录门禁 |
| A07 | 首次改密的无效输入 | 当前/新/确认密码有标签；两次不同、长度或 UTF-8 字节越界、与旧密相同均不进入成功状态；服务端仍权威 | `PasswordEditor.tsx`、后端 `api.js:changePassword` 与 `rules.js:password` | 真机四类输入已验且无改密POST：过短、新旧相同、确认不一致、UTF-8超限；完整长度边界由Domain测试覆盖。服务端真实旧密码校验另见A08 |
| A08 | 改密成功、旧密错误、响应丢失 | POST 只发一次且不自动重试；成功替换 token/player 并清空三个密码输入，解除门控；失败留在改密；响应不确定时允许重新登录确认 | `game.client.ts`、`usePasswordEditor.ts`、后端 `api.js` | 真机已验旧密错误单次POST、成功改密后恢复详情；明确注入“真实写已200完成后丢响应”，原生不自动重放，退出后新密码登录确认成功。5xx/4xx文案及token代次另有Local Test；故障注入不称生产网络故障 |
| A09 | 退出、401、账号切换期间旧请求返回 | 清 token、玩家数据、头像 file token、路由与旧账号缓存；旧请求成功/401 不污染新账号；退出后回退仍不可见私有页 | `GameContext.tsx`、`game.client.test.ts` | 迁移前强制页/菜单退出、Back及Ability恢复门禁、真实停用/me及详情401清理已验；最终正常字号22项再次验证Sheet退出清输入与私有内容，Back不能恢复主页，cleanup两项true。修复后1.3字号另验退出清空输入；跨账号/迟到响应及旧401隔离另有业务回归；头像file token未接入原生UI |
| H01 | 主页正常数据 | 原文案、玩家昵称/等级/经验；待赴之约只含 assigned/active；旅途回响只含 completed/cancelled，计数正确、顺序遵从后端 | `GameDashboard.tsx`、`PlayerPassport.tsx` | 真实隔离列表已验七态分类/文案及后端顺序；最终正常字号22项重新验证Navigation标题、分类历史空态、首次头像Sheet及Back关闭，报告绑定3bac构建。最终同账号Web/原生两主题图已目视核对；编号栏菱形位置/轻微重叠待调，见V01 |
| H02 | 首次加载、空列表、失败及重试 | 对应加载、两类不同空文案、错误可重试；不把错误显示为空列表 | `GameDashboard.tsx`、`GameState.tsx` | 真机已验两类独立空文案：历史空态与真实归档测试session后的当前空态；注入列表503保留旧列表，显式重试由本次新GET200恢复，不把错误显示为空列表。加载帧另随视觉记录 |
| H03 | 七类场次状态 | completed→故事已解开；cancelled→旅程已撤回；过期→已过开放时间；未开始→静候启程；等级不符→等级暂不符合；active→探索进行中；可开始→可以出发，按源码优先级 | `game-presentation.ts:assignmentState`、`AssignmentCard.tsx` | 七态均已在真实隔离记录上逐个定位状态Text并精确验文案；active/completed/cancelled通过专用assignment真实状态切换验证。优先级及时间/等级边界另有Domain和条件反转证据 |
| H04 | 时间变化、后台返回 | 时间窗变化后重新计算；前台恢复回源；已知详情 serverTime 时使用偏移，不把本地时间当准入权威 | `GameDashboard.tsx`、`GamePlayPage.tsx` | 真机已验后台再前台实际发出新的/me请求，详情同步可在暂时失败后恢复；serverTime偏移已实现、时间边界有业务测试。没有人工修改系统时钟或宣称已覆盖所有时钟偏差 |
| H05 | 首页滚动、手动同步和浮栏重叠 | 列表延伸到官方浮动Tabs下方；原同步句为滚动内容末项且可完整露出；官方Refresh独立管理UI动画，触发本次真实回源且不阻断并发门控 | 用户2026-10-27更新、ADR-013；Web保留文案与信息布局 | 最终正常字号22项重验：Scroll底2848px到物理底，末句2419–2473px完整在浮栏顶2531px上方，浮栏交互项2544–2707px在手势区上缘2754px之上；无固定同步块，Refresh一次新成功GET，503保留列表且由新真实GET恢复。独立1.3字号末句2401–2471px与浮栏安全几何另有42项证据 |
| B01 | 点击场次卡片打开一个 assigned 详情 | GET /assignments/:id；展示标题、描述、题数、等级范围、开放/结束时间、进度及开始前说明；返回保持主页分类和合理位置 | `AssignmentCard.tsx`、`AssignmentBrief.tsx` | 迁移前真实GET详情200、只读投影及返回已验；最终正常字号22项重新验证NavDestination标题、开始不可用及实际边缘返回。独立1.3字号另验只读开始控件完整可达及Back回主页；最终两主题真实详情已与同账号Web参考逐图核对 |
| B02 | 详情未到开放时间、过期、等级不符 | 正确原因；开始禁用；过期提供回首页；客户端仅展示，后端最终控制 | `AssignmentBrief.tsx`、`e2e/game-pages.spec.ts` | 时间/等级业务边界及四类列表状态已验；当前开始按钮保持只读并解释范围。最终主视觉含等待/过期/等级不符各深浅两图，来源为真实隔离玩家成功GET，均themeVerified，已与对应Web逐图核对；这不扩写为全部交互/动效通过 |
| B03 | 详情 401/403/404/410/SESSION_OFFLINE | 不继续展示被撤销的缓存私人题目或空模型默认进度；明确错误和返回/重登入口；409 SESSION_OFFLINE 也属致命资源错误 | `isFatalGameError`、`e2e/api-errors.spec.ts`、ADR-015 | 历史终态清旧DTO及真实401回登录保留。最终3bac主视觉中明确注入404的深浅两图authoritativeProgressHidden=true，空模型“0/0”已消失；两主题各自重试实际GET200且authoritativeProgressRestored=true。注入不是生产业务故障；旧2b缺口图保留归档 |
| B04 | 后台同步短暂失败 | 有旧有效数据时保留页面，显示同步中断；恢复后更新；不得把短暂失败等同注销 | `GameContext.tsx`、`GamePlayPage.tsx`、`e2e/api-errors.spec.ts` | 真机已验注入列表/详情503时保留旧有效数据，显式重试必须由本次新GET200恢复；后台返回触发回源，18秒延迟触发原生超时后亦能重试。没有把旧卡片可见等同于新请求成功 |
| B09 | 可选：开始请求及超时重连 | POST /assignments/:id/start {requestId}；一次用户命令固定原账号/内容/requestId，重试沿用；阻止连续点击；按返回 assignment 更新 | `game.client.ts`、`GamePlayPage.tsx`、`e2e/api-errors.spec.ts` | 超出只读详情，若实现则待验证 |
| B10 | 可选：进程中断后的开始结果不确定 | 回源 detail 确认；不能生成新 requestId 盲目补发；未持久化命令不得宣称恢复同一命令 | 后端幂等契约、预研风险 4 | 超出只读详情，若实现则待验证 |
| V01 | Web布局参考、小屏ArkUI、键盘打开 | 品牌、文案、信息布局及状态对应；主要CTA、字段、错误不被裁切；记录实际像素、vp、字体/字号和安全区，官方材质/反馈差异另列 | `e2e/game-pages.spec.ts`、`tokens.css`、`game.css`、ADR-013/015 | 最终Web20/原生22图已逐图核对，主配对18/18、故障2/2、原生普通账号IME2/2，绑定3bac HAP及新窗口；1.3字号另有42/42可达性证据。结论为已对照、两项非官方差异待调：编号栏菱形在原生顶部与01轻微重叠而Web在底部；404按钮“重试”对Web“重新尝试”。主要信息/入口与恢复语义保留，但不标逐字逐像素全过，也不归入官方材质批准差异 |
| V02 | 深/浅/系统主题 | 暗色金/黑、浅色绿/白语义色和同一信息层级；系统变更有响应；官方材质随系统能力与主题降级 | `GameThemePicker.tsx`、`tokens.css`、`e2e/theme.spec.ts`、ADR-013 | 原生冷启动日志实测supported=true、ENABLE(1)、IMMERSIVE(2)、EXQUISITE(0)。最终3bac认证4图与主视觉18图全状态深浅PNG的themeVerified已核，并完成Web逐态目视；系统主题动态跟随、禁用或不支持设备降级仍另验 |
| V03 | 系统返回、手势、读屏、大字体、减弱动画 | 合理路由栈，改密不可绕过；可访问名称及选中语义；焦点/输入、对比度、目标大小；使用系统动画并响应减少动画，动画中断不改业务结果 | `e2e/accessibility.spec.ts`、`global-motion-plan.md`、ADR-013/015 | 修复后独立1.3字号42/42已验登录/强改密字段和IME下完整CTA、密码显隐、帮助、浮栏/末句、详情Back及退出；runtime实测fontScale1.3，未改系统全局设置。最终正常字号22项重验Sheet Back、详情边缘返回及退出后Back门禁；49项强改密门禁保留原归属。实际语音读屏、连续录屏、减弱动画设置无通过证据 |
| V04 | 官方顶底栏、分类、Sheet和短反馈 | 顶栏保留品牌/标题/操作布局并采用Navigation及真实官方材质；底栏官方浮动Tabs；分类Tabs/SubTabBarStyle；弹层/Toast用官方反馈且不掩盖持久错误 | 用户2026-10-27更新、ADR-013、固定API26声明及官方指南 | 官方能力已实现；最终正常字号22项重新验证Navigation/分类/Sheet、未开放目的地拒绝跳转、浮栏和返回/退出，绑定3bac构建。材质支持有最终runtime日志；Toast/通用动效完整视觉、减少动画及降级继续单独验收 |
| V05 | 窗口、折叠、悬停和分栏 | 按实际窗口/容器断点及避让区布局；内容和操作可达；分别记录官方组件能力与硬件结果 | 项目规则、ADR-013、官方Navigation/Tabs能力 | 当前仅有上述手机窗口参数；折叠、悬停、分栏及窗口变化无对应通过证据，不能由采用官方组件推断 |
| V06 | 系统状态栏与底部手势区域 | 背景/材质延伸至物理边缘；系统栏透明且保留显示；图标随实际主题保持可读；标题、浮栏和末句按实际避让区保持可达 | 用户2026-10-28更新、ADR-014、固定API26窗口能力 | 最终正常字号HAP的6项runtime及22项UI均通过：fontScale1、immersiveLayout=enabled、两栏alpha=0、深浅系统内容色白/黑；标题动作避让131px顶部区，浮栏交互项在手势区上缘2754px之上，Scroll到物理底2848px，末句完整可达。全状态视觉继续另取证 |

表中 Contract、Domain、Repository、ViewModel 及 Routes、Environment 指 `entry/src/test/` 中同名 Hypium 套件。37/37是修复后最新源码实际复跑的Local Test总数，0失败、0忽略，不是37项UI验收；原始test_result已重新生成。lint的issues/errors/warnings/suggestions均0，filesChecked=0照实保留；两项执行前后捕获HAP仍为3bac且SHA未变。沉浸调整前17项设备检查单独计数。迁移前真实HTTPS49项含1项主机配对数据准备，并非49例Hypium/UI测试。报告保留core20→core28的SHA检查点链，仅继承28项已确认core断言，重新执行故障恢复及后段；不声称单次不中断全过。

H03 的展示优先级：completed、cancelled、endsAt≤now、startsAt>now、仅 assigned 的等级限制、active、ready。对于 active，等级变化不应单靠客户端重新锁场；请求仍须服从后端。

## 首切片真实 HTTPS 契约

基地址由本地打包的受控配置提供，Web 默认 `https://api.sitkin.top`；原生缺省为明确标识的mock，配置存在但无效时禁止登录。本轮真实联调使用一次性PocketBase测试玩家和严格USB HTTPS，不请求生产玩家；启动/隔离/清理见 [隔离环境](isolated-https-environment.md)。所有业务请求的认证为 `Authorization: <token>`，没有 Bearer 前缀。错误规范为 `{error:{code,message}}`；PocketBase 原生认证错误可能只有顶层 message，需要安全映射，不能依赖业务 error 嵌套一定存在。

| 操作 | 方法与路径 | 请求 | 响应及验证要点 | 重试约束 |
| --- | --- | --- | --- | --- |
| 登录 | POST `/api/collections/game_players/auth-with-password` | `{identity: account.trim().toLowerCase(), password}` | `{token:string, record:{id:string}}`，随后使用新 token GET /me；校验 player.id 与登录记录一致可额外防御 | 不跨账号重放；不得记录密码/token |
| 玩家 | GET `/api/questions/v1/me` | Authorization | `GamePlayer`：id/account/displayName/avatar 字符串；mustChangePassword 布尔；totalXp 非负整数；level 为 GameRank；nextLevel 为 GameRank/null | 读重试可限次；401 仅清同一身份 |
| 首次及后续改密 | POST `/api/questions/v1/me/change-password` | `{oldPassword,password,passwordConfirm}` | `{token:string,player:GamePlayer}`；新密码 10～71 字符且 UTF-8≤72 字节；两次相同且不同旧密；服务端旧密校验 | 禁止自动重试；丢响应视为结果未确认 |
| 主页列表 | GET `/api/questions/v1/assignments` | Authorization | `{items:GameAssignmentSummary[]}`；status 仅 assigned/active/completed/cancelled；maxLevel 数值或 null；日期为空串合法 | 可限次读重试 |
| 详情 | GET `/api/questions/v1/assignments/{encodeURIComponent(id)}` | Authorization | `GameAssignment` 扩展 summary：presentation、completionTarget/null、currentIndex、clues、levels、serverTime；question=null 在未解锁时合法 | 可限次读重试；致命错误清当前资源 |
| 受保护头像（有头像时） | POST `/api/files/token`，之后 GET `/api/files/game_players/{id}/{avatar}?token={fileToken}` | body `{}`，主 token 请求 file token | `{token:string}`，头像 URL 分段编码；刷新临时 token；token 不写日志、不跨账号复用 | 需单独覆盖过期/切换；没有头像不能伪称已验证 |

GameAssignmentSummary 的字段为 id、player、session、status、order、startsAt、endsAt、startedAt、completedAt、previousAssignment、title、description、minLevel、maxLevel、completedLevels、totalLevels。GameRank 为 id、order、name、minTotalXp、visualConfig，另有可选 defaultName/customTitle。DTO 边界允许未知兼容字段，但已消费字段必须逐项校验；不能用裸 JSON.parse 类型断言代替校验。

首切片若暂不渲染完整 GameAssignment 扩展字段，应说明投影范围，保留后续解码入口；不得把该投影宣称为全量契约迁移。

## 全功能后续验收范围

| 编号 | 业务能力与逐状态 | 原生验收目标 | 源码/现有用例 |
| --- | --- | --- | --- |
| P01 | 资料：昵称读取、草稿、JSON 保存、失败与重试 | 草稿不被同步覆盖，保存后回显；昵称服务端权威 | `GameProfilePage`、`ProfileEditor`、`e2e/game-pages.spec.ts` |
| P02 | 头像：选图、无效类型、超大、裁剪、取消、压缩、multipart 上传 | 原生系统选图/裁剪；压缩方图≤512、≤200KB 的 Web 目标对照；后端上限 2MB；失效 file token 续取 | `avatar-image.ts`、`AvatarCropDialog`、`e2e/game-pages.spec.ts` |
| P03 | 后续改密及退出 | 保留本表 A07/A08/A09；成功状态文案和输入清空 | `PasswordEditor`、`game.client.test.ts` |
| Q01 | 单题/多题、填空/选择、锁定未解锁题、前后导航与返回位置 | 后端返回 question 决定可看题；本地不得恢复旧判题/解锁逻辑 | `GamePlayPage`、`QuestCard`、`e2e/quest-flow.spec.ts` |
| Q02 | 空答、正确、错误、already_completed、并发及重复点击 | UI 输入校验只防空，正确性、XP、奖励、进度由响应决定；答题 requestId 原样重试 | `game.client.ts`、`e2e/api-errors.spec.ts` |
| Q03 | 冷却、永久锁、时间偏移、到期、后台恢复 | 计时依据 serverTime；进程恢复回源，不能把本地倒计时完成当权限恢复 | `GamePlayPage`、`session.test.ts` |
| Q04 | 自动下一题、手动下一题、答对演出、中断/离开/重启 | 演出状态与业务完成状态分开；不能重发已成功提交，允许安全中断与恢复 | `useGamePresentation`、`session-presentation.ts`、`question-ui-preservation.md` |
| C01 | 普通/多题组合线索：文本、图片、视频、链接、题目/场次来源 | 解锁与组合来源来自服务端；旧返回结构兼容只按已验证规则；自动播放顺序与手动重开一致 | `clue-presentation.ts`、`MultiQuestClueDialog`、`e2e/desktop-clue-video.spec.ts` |
| N01 | 解锁剧情：缺权限、读取失败、letter 开合/分页/全文/滑动/音频 | 统一路由门控；原生文字排版、翻页与中断；保护未解锁内容 | `GameNarrativePage`、`LetterExperience`、`letterPagination`、`e2e/bless-flow.spec.ts` |
| N02 | bless 粒子、配音、BGM、片尾、再次访问与退出 | 原生绘制/媒体；生命周期显式暂停/释放；不因回放重新结算 | `features/bless`、`features/completion`、`global-motion-plan.md` |
| R01 | 奖品：loading/empty/error/available/redeemed/voided | 私人领取信息只归本人；状态、数量、核销与快照来自服务端；客户端不提供伪核销 | `GameRewardsPage`、`makeRewards` |
| M01 | 来信：未读弹窗队列、关闭/收下、标已读、归档、关联场次 | 已读写成功后更新；去重及账号隔离；定时同步按前后台生命周期控制 | `GameNotificationCenter`、`GameNotificationsPage`、`e2e/mailbox.spec.ts` |
| M02 | 星海信笺：已解锁信件/祝福、旅途终章、重开 | 只聚合有权读取的服务端内容，保留返回场次关系 | `features/mailbox`、`star-letters.test.ts` |
| T01 | 主题、安全区、导航/抽屉/弹窗、toast、媒体缩放、大字体 | 逐个状态截图和真机可访问性验证；系统返回关闭顶层，焦点合理恢复 | `ui-system.md`、`e2e/mobile-layout.spec.ts`、`e2e/accessibility.spec.ts` |
| T02 | 浮动 BGM、语音/视频抢占、静音偏好、拖动、后台/焦点中断 | 平台媒体适配有状态机；前后台及音频焦点安全处理；账号隔离偏好 | `BgmControls`、`useQuestBgm`、`e2e/music-control.spec.ts` |
| F01 | 后续 Form Kit：未登录、摘要、离线、刷新、点击 | 进程隔离持久化摘要；私密字段裁减；退出清卡片；统一鉴权深链 | 预研“卡片预留”，需官方版本核验 |
| F02 | 后续 Push Kit：token 注册/轮换/解绑、消息/点击、去重 | 后端绑定和发信；收到消息回源；推送不成为事实源；统一鉴权路由 | 预研“Push 预留”，当前没有等价 Web 推送能力 |

以上后续项均为待实现/待验证。应在每次切片验收报告中明确本次覆盖编号，避免空表被误认为完成清单。

## 夹具、文案和视觉输入

- 首选 `questions-web/e2e/fixtures.ts:mockStarwardApi`：玩家 `playeralice`/`alice`，昵称“远航者”，等级“初见”，totalXp=0；场次 `assignment1`/`session1`，标题“星辰探险”，描述“解开谜题，发现惊喜。”；`mustChange` 开关可覆盖强制改密。未开启时 levels.question 为 null，是合法服务端权限状态；mock 仅验证 UI，不证明后端事务/权限。
- `questions-web/src/test/game-fixtures.ts` 提供护照、场次摘要、奖品和通知展示夹具；`e2e/session-preview-fixture.ts` 可参考复杂场次，但编辑器预览不属于首切片路由。
- 文案权威：`src/config/ui-copy.ts` 的 common、authLayout、gameLoginPage、passwordEditor、gameDashboard、gamePresentation、assignmentBrief、assignmentCard、gameLoadingScreen。登录标题“以你的名字，\n开启冒险。”，按钮“进入冒险”；强制标题“首次登录，请先修改密码”，按钮“保存新密码”；主页标题“下一段故事，等你落笔。”，分类“待赴之约”“旅途回响”。不要重新撰写近义文案。
- 品牌色与布局参考：`src/styles/foundation/tokens.css`；暗色 canvas `#10110f`、surface `#151612`、text `#e7e6e1`、accent `#d4bc7d`；浅色 canvas `#ffffff`、surface `#f7f9f8`、text `#293c38`、accent `#187b69`；Web控件高52、圆角10、面板圆角18、间距4/8/12/16/20/24/32/40/48/64记录为输入。通用容器、材质及反馈按官方ArkUI策略验收，批准的平台差异另列。CSS px不能无条件等同物理像素，ArkUI使用vp/fp并记录实际尺寸。
- 现有品牌位图位于 `public/branding/`，包含 starward-icon 和 starward-mark 多尺寸；优先复用原图，勿新造品牌。`CelestialAtlas` 可参考其参数用原生 Canvas/Shape 重写，无需引入 WebView。

## 实际验收记录要求

每次运行记录时间、构建产物摘要、IDE/SDK/API、模拟或真实数据源、设备系统 API（不公开设备 ID）、用例编号、命令和真实通过数。Hypium/UiTest 必须检查报告及非零用例数；CLI 包装器成功或编译成功不等于 UI 验收成功。

视觉证据至少覆盖登录、首次改密、主页两类、详情可开始/等待/过期/等级不符、错误、键盘打开；每组保存深/浅主题Web与ArkUI配对截图，核对布局、文案和状态，并独立记录官方材质、反馈与动效。迁移前证据归档保留，新官方容器须补浮栏/滚动末句、Refresh回源、Sheet/Toast、材质降级及返回门禁。动态/生命周期至少录制登录到主页到详情返回、系统返回无法绕过改密、网络中断恢复；完整动画验收在相应切片补录。没有对应截图、真机操作、网络或录屏报告的条目继续标待验证。

本轮只读 questions-web 和后端源码，没有修改二者；没有执行其 pnpm 发布门禁，也不把历史报告计入本次鸿蒙验证。

## 分阶段真机回填

2026-10-27的历史模拟13项、Local Test37项、真实HTTPS49项（含1项主机配对数据准备）、主机HTTPS25/25和原生TLS三项握手分别保留。沉浸调整前官方UI17/17验证了容器、Refresh/503恢复、浮栏/末句、Sheet和详情返回及退出清理，已归档；这不等于2026-10-28最终沉浸版通过。

最终正常字号HAP `3bacb424…` 的冷启动6项检查与22/22系统UI通过，认证4图及主视觉18图captured；各报告绑定同一HAP，来源JSON原字节SHA已核对。UI cleanup两项true；认证仅一次UI改密且响应200已确认，cleanup三项true。主视觉newCapturedCount=18、resumedFrom=null，为全新单次完整捕获，场景恢复/退出/故障中和三项true；404两主题隐藏默认进度且真实GET200恢复进度。最终Web20/原生22已目视核对，来源配对18+2+2；保留V01两项非官方差异待调，预览14项HTTP与22状态图片加载检查单独通过。修复后的独立1.3字号HAP `fdda3840…` 已42/42通过，runtime来源SHA匹配；cleanup确认新密码、恢复singleReady、退出均true，cleanup无额外改密。跨日后旧隔离控制场景请求失败，原因未确认；仅重建一次性数据库和随机玩家，保留同CA、HTTPS入口/玩家代理端口和冻结后端，已验证新控制场景及严格HTTPS健康200，见 `edge-isolation-recreated.json`。原生产与源仓库不受影响。

最终默认mock经 `scripts/hm.sh run` 构建/签名/安装/启动成功，HAP为 `82baeefc…`，不打包integration配置或临时CA；实际fontScale1、全屏与透明系统栏的4项runtime检查及13项UiTest冒烟均passed。报告为 `native-mock-installed-hap.json`、`native-mock-runtime.json`、`device-smoke.json`；28份App源码SHA仍匹配 `final-source-checks.json`，该mock流程不计真实HTTPS或最终22图的来源。

环境收尾已passed：先核自有runner的UID/argv/工作目录，再停止自有TLS和一次性后端；专用USB映射、临时CA/私钥目录、数据库、1个自有容器、实时状态与扫描后的3份私有检查点已移除，四个自有loopback监听及Web基线服务已关闭，未改无关容器/映射。冻结无凭据DTO与安全视觉viewer保留，viewer仍在本机响应200。`public-artifact-scan.json` 最终扫描814个公开候选文件，敏感命中0、读取错误0；覆盖旧/新隔离凭据、仅内存传入的设备标识、解码JWT形状、PEM私钥头和签名扩展名，两处PRIVATE KEY拒绝校验引用另列。原Web和后端工作树改动均0，清理证据为 `isolated-environment-cleanup.json`。

Web原始12图、同字体控制12图已冻结；迁移前登录配对及认证4图保留，旧主页18项捕获仅incomplete/count5且键盘图主题校验失败，归档为未完成证据。首次改密Web参考只消费真实改密前/me快照，未请求场次或执行浏览器真实改密；其余本地回放同样仅作视觉输入。原生实际网络由TLS及请求台账证明。生产release commit仍因403未确认，公网/生产联调未执行。
