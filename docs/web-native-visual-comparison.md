# 首切片 Web 与 ArkUI 视觉对照

核验日期：2026-10-28；下列已有捕获的原始时间仍保留2026-10-27。当前准则为 **arkui-system-v1**，依据更新后的AGENTS.md与ADR-013：保留品牌、文案、业务语义和信息布局，通用容器、材质、反馈与动效采用官方ArkUI二次封装。Web是业务与布局参考；已批准的官方材质、原生反馈/动效及首页悬浮布局不按逐像素模拟Web判定。用户进一步要求系统状态栏与手势区使用全窗口材质背景、仅前景内容避让安全区，最终版本标记为 **edge-to-edge-v1**。全窗口调整前证据已归档；首次全窗口构建2b757938…的认证4张、主捕获18张及UI22也已归档为修复前证据，已知404默认0/0和大字号密码键盘下主按钮未完整露出，不计最终通过。最终1倍构建 **3bacb424…** 已全新完成认证4张及主捕获18张，来源核验、逐图目视记录与设备UI22分别保存；当前来源覆盖为主18/18、故障2/2、原生键盘2/2。目视核对仍有编号栏菱形位置与404重试短文案两项非官方细节待调整，不能称全部像素或中文文案一致。这些证据不覆盖减少动画、动效录制、读屏、折叠/悬停/分栏或强制材质降级。

## 当前准则与图片来源

| 来源模式 | 保存位置 | 用途与当前状态 |
| --- | --- | --- |
| 冻结Web原始字体与同字体控制组 | web-baseline、web-baseline-font-controlled | 原始390×844参考继续保留，不能代替原生测试 |
| 本轮Web20张 | web-isolated-content/forced/waiting/expired/locked/error | 主状态18张与显式404回放2张；同一隔离账号、同字体本地回放，六组来源均固定为同SHA不可变副本，原始捕获路径另记originalFile |
| 旧阶段Web12张 | web-legacy-pre-system-content/forced | 旧快照和PNG保留，不能用旧SHA冒充本轮实际输入 |
| 迁移前原生 | native-legacy-pre-system归档；legacy-index.html/legacy-pairs.json | 原认证4张有捕获证据，旧主报告未完成，不存在旧18张通过结论，不计入新版通过 |
| 官方ArkUI、全窗口调整前 | native-pre-edge-to-edge | 原始认证4张、主捕获incomplete/count5、当时runtime/HAP/UI17及文件SHA归档，不计最终版通过 |
| 官方ArkUI全窗口修复前 | native-pre-final-fixes | 2b757938…构建22张及UI22、runtime/HAP原字节和已知缺口归档，不能替代最终修复后证据 |
| 官方ArkUI全窗口最终版 | native-system-visual | 只接纳arkui-system-v1 + edge-to-edge-v1的完整报告，3bacb424…HAP及新实测窗口来源SHA均匹配；认证4张加主18张全新采集，主报告无resume |

新版公开来源清单为 `artifacts/visual-comparison/pairs.json`，已按最终3bacb424…完整认证与主报告重建为 **主配对18/18、显式故障2/2、原生键盘2/2**。共22张原生图，其中20张有Web参考、两张普通账号IME仅作原生证据；四卡穿过浮栏的额外图不计入主18。旧2b757938…的图仅归档，不混入最终数量。这一计数只表示最低业务状态截图的来源配对，不能推出官方材质、交互、动画或折叠适配已通过。新增官方组件证据图可以额外记录，不能用旧图补齐计数。

## 新版验证框架

| 对照项 | 核对重点 | 需要的实际证据 | 当前状态 |
| --- | --- | --- | --- |
| 品牌与业务内容 | 品牌/资源、中文文案、账号与场次事实、认证/改密守卫、错误意义 | 同账号/状态/主题的原生图与可追溯Web响应回放；原生请求/业务报告单列 | 新原生22与Web20已逐图核对；两项非官方细节待调整，见下表 |
| 顶栏与分类 | 保留品牌、标题和操作布局；官方Navigation/通用材质、Tabs分类允许平台形态差异 | 两主题、实际材质支持/启用/降级、选择/焦点及内容保持 | 新runtime及最终UI22已验证支持、两主题系统栏、标题与分类；焦点与强制降级待测 |
| 首页滚动与底栏 | 官方透明悬浮底栏；列表延伸其下；原同步句是滚动内容最后一项，移除固定同步占位块 | 长内容滚动、浮栏重叠、末尾句可达、安全区与小屏/键盘 | 最终UI22已复验重叠/末尾句与安全区，额外四卡图可见内容进入手势区；其他窗口待测 |
| Sheet与反馈 | 官方Sheet/Toast/Dialog；短反馈与持久可操作错误区分；未开放入口不造成功页面 | 展示/拖动/关闭/返回、错误可恢复、无私密内容复现 | 最终UI22已复验Sheet打开/Back/退出清理；拖动与其余反馈待测 |
| Refresh | UI动效状态独立，业务并发由ViewModel控制，不将listBusy双向绑定系统Refresh | 本次真实GET台账、成功/失败/忙碌恢复，动画不驱动写入 | 最终UI22已复验成功/503保留内容/真实GET恢复；并发中断待测 |
| 动画与适配 | 系统转场、减少动画、中断不改变业务；实际窗口断点与避让区 | 正常/减少动画、退出/返回/恢复；折叠/悬停/分栏须独立设备证据 | 待实际验证 |

批准差异只覆盖官方容器/材质/交互及明确的首页布局调整；丢失文案、字段被挡、越过守卫、假业务成功或错误的刷新门控仍是问题。“§”的澄清不是新增显示符号。完整策略与待验证项在 `artifacts/visual-comparison/criteria.json`，其中partial明确限定已验证范围，not_run不会因为使用官方API或编译成功自动变为通过。全窗口调整前归档 `native-pre-edge-to-edge/device-system-ui.json` 的17项实际检查覆盖原生标题/环境标识、Sheet打开与返回、分类切换、未开放入口、Refresh真实GET与503恢复、浮栏重叠和末尾同步句、详情守卫与返回、退出后私密内容清理。实际几何记录中滚动区延伸至2755px，覆盖浮栏顶部2531px以下区域，证明列表延伸至其下；末尾同步句底2378px在浮栏顶部上方153px。此记录来自当前手机，不能推导其他窗口或设备。

最终捕获报告至少包含：顶层visualCriteria=arkui-system-v1、immersionVersion=edge-to-edge-v1、status=captured、count=states.length；hap.source固定为native-system-visual-hap.json，hap.sourceSha256匹配该记录原字节，hap.sha256及hap.immersionVersion匹配最终HAP记录；认证包含login/forced-password×两主题，业务主报告包含home/detail/history/logout、等待/过期/等级锁定、404故障和原生键盘×两主题（允许额外官方组件图）。每项提供state/theme/screenshot/pixels/themeVerified，认证提供visibleInputsEmpty，键盘提供keyboard=true，故障提供injectedResilience=true。screenshotSha256若提供就必须匹配；缺失时仅记录配对生成时hash范围。报告本轮实测window的widthPx/heightPx/density/topInsetPx/bottomInsetPx；source固定指向native-system-runtime.json，sourceRecord和sourceSha256须与该文件原字节和对应records条目匹配。缺失window时仅显示完整原图预览，不沿用旧避让区称新版几何已通过；提供来源字段却不匹配时拒绝该图。官方能力运行检查与静态来源配对分别记录。

## 可复现基线

- Web 源码：`questions-web` HEAD `4b7d1a0a00051ac630e459b0fd6c074f821d7455`，本轮只读；未使用旧 `dist`。
- 服务：`scripts/start-web-baseline.mjs` 直接导入冻结源码的 Vite 配置和 React 插件，缓存放在本项目 `artifacts/private/web-baseline-vite-cache`。默认 API 地址为不运行真实服务的本地 `127.0.0.1:18790`，浏览器请求由截图脚本完整拦截。
- 数据：`entry/src/test/fixtures/WebFixture.ets`，由同一冻结 Web E2E factory 导出的完整玩家、场次及列表响应；未开启题目为 `question=null`。初始强制改密，随后仅在夹具内解除标记；没有真实账号或生产写操作。
- 浏览器：Google Chrome headless；精确版本、Playwright 版本、各次请求路径及页面错误数见 `artifacts/web-baseline/capture-summary.json`。390×844 CSS px，DPR 1，`zh-CN`，Asia/Shanghai，分别深/浅主题，减弱动画。截图没有浏览器或系统栏。
- 结果：6 个状态 × 2 个主题，共 **12 张截图**；**0 page errors**。非本地请求不放行；仅对原 E2E 的 `assets.example` 返回同一个占位 SVG，未访问其远端。
- 状态：登录、首次改密、主页、开始前详情、历史空状态、退出后的登录。退出截图通过清除隔离浏览器的本地认证状态后重新导航生成，**不是 Web 退出按钮的交互用例**。

```sh
node scripts/start-web-baseline.mjs
python3 scripts/capture-web-baseline.py
```

`capture-web-baseline.py` 使用 Python Playwright。当前安装在 gitignore 的 `artifacts/private/python-playwright`，可用 `python3 -m pip install --target artifacts/private/python-playwright playwright==1.64.1` 单独安装到该目录；截图浏览器使用本机官方 Chrome。源仓库没有安装或变更依赖。生成物位于 `artifacts/web-baseline/`，每张 PNG 均有同名 JSON，记录可见性、文字、矩形、字号、行高、颜色、内外边距和圆角。输入字段内容不进入测量 JSON。

## 同字体控制组

已另存 `artifacts/web-baseline-font-controlled/` 的12张截图和同名测量JSON。使用本轮原生 `rawfile/fonts/NotoSerifSC.ttf` 的同一字体字节，由Playwright拦截一个本地字体URL并注入 `@font-face`，仅将 `--font-display` 改为该字体；源仓库没有变更，原始system-font截图全部保留。字体SHA-256在该组capture-summary的fontControl字段，字体授权由原生资源记录管理。

```sh
python3 scripts/capture-web-baseline.py \
  --font-file entry/src/main/resources/rawfile/fonts/NotoSerifSC.ttf \
  --output artifacts/web-baseline-font-controlled
```

控制组实际0页面错误、0外部请求放行。相对于原始Web CSS字体栈，登录、首次改密、主页的已测矩形完全相同；详情昵称的normal行高增加1px，使session header高1px，卡片及卡内元素整体下移1px，其他宽高相同。控制组用于区分字体与原生布局的影响，不能冒充未修改字体的正式Web基线。

## 坐标与平台比较方法

Web 的 390×844 是 CSS 视口；迁移前原生截图是 **1320×2848 物理像素且包含状态栏/手势栏**。不能把整张原生图缩成 390 宽后直接将像素差称为业务布局误差。迁移前官方hdc hilog的窗口数据保存在 `artifacts/validation/native-tls-and-metrics.json`：density=3.375，topInset=131px、bottomInset=94px，内容宽391.111111vp、高777.185185vp。旧内容坐标按 `xVp=xPx/3.375`、`yVp=(yPx-131)/3.375` 换算；UiTest树有1物理像素的取整差。新版须重新记录窗口与避让区，旧量测不是新容器、折叠或窗口变化的验收证据。

纯像素相等还受字体栅格化、抗锯齿和平台系统图标影响。验收必须同时核对信息结构、文案、可见状态、尺寸/布局及配对截图，记录无法消除的平台差异。未有字体资源或授权证据时，不能把 macOS 的商业系统字体复制进 App。

首版原生原始截图未编辑地保存在 `artifacts/native-before-visual/`，SHA-256见该目录provenance。当前入口 `artifacts/visual-comparison/index.html` 使用官方ArkUI新准则，历史入口为legacy-index.html；旧原生归档 `artifacts/native-legacy-pre-system/` 已存在。最终预览默认展示完整原生屏幕，包含状态栏/手势区域以检查材质连续性；可选“仅业务内容区”只用于按vp/安全区与Web布局对齐，不用于评价全窗口沉浸效果。所有模式仅做CSS显示换算、原始PNG不变；新版未提供本轮window参数时只显示完整原图预览。待补状态不借用旧主题图。

本机预览可运行 `python3 scripts/serve-visual-report.py`，默认仅绑定127.0.0.1:5179，输出实际URL `http://127.0.0.1:5179/visual-comparison/index.html`；不占用Web源基线的5178。服务固定允许报告、指定公开PNG/测量JSON和明确的validation文件，拒绝private、原始响应快照、原生UiTest输入树、目录浏览、路径穿越和符号链接；使用目录描述符与O_NOFOLLOW打开白名单文件，不以路径字符串检查代替实际打开约束。临时端口安全烟测 **14/14通过、0失败**，见 `artifacts/validation/visual-report-server-summary.json`。2026-10-28已恢复自有detached预览，PID位置为gitignore内的artifacts/private/visual-report-viewer.pid；结束时只能停止该自有进程。新增`python3 scripts/check-visual-report.py`复验14/14：13次实际viewer请求及1次私有同handler目录符号链接探针。浏览器22状态按钮、历史入口正常，0 page errors、0 CSP errors、0非favicon HTTP错误。此处只验证预览框架，不代表原生验收；未接触后端或设备。

## 冻结Web移动端基准尺寸

以下为浅色主题实际DOM值，单位CSS px；深色布局相同。完整数值在同名JSON。它们是内容参考；官方顶/底栏、Tab材质及已批准的同步句滚动位置不再要求逐像素复刻这些容器。

| 状态/元素 | Web 实测 x/y/w/h | 字体及布局要求 |
| --- | --- | --- |
| 登录顶栏 | 20 / 0 / 350 / 84 | mark36；wordmark16、line24、tagline10；主题组三个图标按钮，123×48 |
| 登录故事小标题 | 20 / 116 / 186.56 / 12 | font10，line12 |
| 登录故事标题 | 20 / 144 / 186.56 / 95.19 | font34、line47.6，双行；display serif，weight500 |
| 登录故事说明 | 20 / 252.19 / 186.56 / 23.39 | font13、line23.4 |
| 登录表单标题 | 20 / 308.58 / 350 / 33.59 | font21、line33.6，移动端同一行 |
| 登录账号 | 20 / 385.17 / 350 / 52 | font16，左右padding12；radius10 |
| 登录密码 | 20 / 480.17 / 350 / 52 | 同上，右侧显隐按钮有可访问名称 |
| 登录主按钮 | 20 / 548.17 / 350 / 52 | font16、weight600；radius10；右箭头 |
| 登录帮助 | 20 / 612.17 / 350 / 45.59 | font12、line21.6，折叠摘要 |
| 登录页脚 | 20 / 669.77 / 350 / 57.59 | font12，带字距的短句 |
| 首次改密标题 | 56 / 308.58 / 264 / 36 | 复用完整故事区，标题前有钥匙图标，font24/line36 |
| 首次改密说明 | 20 / 356.58 / 350 / 23.39 | font13/line23.4 |
| 首次改密当前密码 | 20 / 430.97 / 350 / 52 | 后两输入按同一95px节奏排布 |
| 首次改密保存 | 20 / 688.97 / 350 / 52 | footer从814.97起；原始844视口下它可继续随页面滚动 |
| 主页顶栏 | 20 / 0 / 350 / 84 | 原品牌、右侧圆形账号菜单；底部分隔线 |
| 主页标题区 | 20 / 100 / 350 / 107.19 | eyebrow10；h1=28/40.6；说明14/26.6 |
| 主页分类 | 20 / 207.19 / 350 / 53 | 两个trigger宽76.95，x20/120.95，间隔24，font15，bottom-padding12，underline2 |
| 主页滚动区 | 20 / 284.19 / 350 / 439.81 | padding4/6/48；故卡片x26、y288.19 |
| 历史空卡 | 26 / 288.19 / 338 / 280 | icon64，x163/y352.09；h2 x79.5/y432.09，font21/31.5；说明x71.5/y479.59，font13/24.7 |
| 主页场次卡片 | 26 / 288.19 / 338 / 296.05 | 左58宽编号栏，右body padding20/16；radius18 |
| 场次标题 | 101 / 340.19 / 246 / 36 | serif24/line36 |
| 场次说明/元信息 | y388.19 / y428.23 | font13/24.05、font11；元信息有竖分隔 |
| 场次进度/入口 | y464.23 / y517.23 | 4px progress；入口246×46，文字“开启旅程”＋右箭头 |
| 主页底部导航 | 20 / 766 / 350 / 68 | 四入口：启程、收藏、来信、护照；主页不显示护照卡 |
| 主页同步短句 | 20 / 704 / 350 / 48 | 仅记录Web现状；新版原句进入滚动内容末尾，取消固定48vp占位 |
| 详情 session header | 12 / 24 / 366 / 68.58 | 圆形旅人菜单44；QUEST SESSION12；昵称22；rank11；右侧0/2为27 |
| 详情卡片 | 12 / 108.58 / 366 / 419.38 | surface背景、accent-border、radius18、padding24 |
| 详情标题 | 37 / 163.97 / 316 / 45 | font30/line45；上方eyebrow12 |
| 详情说明 | 37 / 224.97 / 316 / 26.59 | font14/line26.6 |
| 详情事实区 | 37 / 275.56 / 316 / 109.59 | 两列，各148宽，gap20；label11/value13；只有endsAt非空才显示截止 |
| 详情主按钮 | 37 / 409.16 / 316 / 52 | “开始本场冒险”＋右箭头 |
| 详情保存短句 | 37 / 472.16 / 316 / 19.8 | font11/line19.8；无底部四入口导航 |

## 历史首版差异调查

下表记录旧准则下的调查；当前官方容器策略以ADR-013为准，品牌、文案和业务事实仍保持对照。

| 项目 | 首版原生与Web差异 | 对齐目标/验收方式 |
| --- | --- | --- |
| 页边距/顶栏 | 原生24vp边距、72vp顶栏、20fp无tagline；Web20/84/16＋tagline | 按实际vp/安全区对齐内容边界，恢复品牌层级；系统栏单独排除 |
| 字体 | 原生`fontFamily('serif')`在首版截图上仍呈现无衬线；Web Mac截图为中文衬线效果 | 使用有授权且真实可用的中文衬线字体或记录平台例外；至少核对换行、字号和行高，不能只核对CSS字体声明 |
| 浅色输入 | 原生灰绿inset＋弱边框；Web白底＋`#BBCFC5`边框 | 恢复白色输入面和strong边框；52高/10圆角已相同 |
| 首次改密 | 原生省略故事标题、星图与footer，表单上移；Web仍套完整AuthLayout | 恢复同一结构，核验三个字段、保存与退出可达，不靠大块空白近似 |
| 主页 | 原生新增护照卡、退出和刷新按钮；缺底部四入口与右侧账号菜单 | 恢复移动端的信息结构；首片未实现的目的地不伪造功能，需显式保留范围边界 |
| 场次卡片 | 原生无编号栏/进度条、入口文字“查看详情”；Web有01栏、进度和“开启旅程” | 复原卡片结构和原文案；只读切片入口仍只读取详情，不发送start |
| 详情 | 原生系统标题栏＋一列facts、额外状态/进度/空截止、卡片缺失；Web为session header＋两列facts卡片 | 恢复版式和条件渲染；空endsAt不显示；系统返回能力仍须保留 |
| 详情动作范围 | Web可开始状态按钮可用；原生只读范围禁用start并说明演示限制 | **已知范围差异**，不能把disabled像素差隐瞒；本轮不据视觉任务实现未经完整验收的start写入 |
| 环境标识 | 原生有演示/隔离提示；Web正式UI无该提示 | 诊断标识需保留以防误用账号；配对报告明确其为测试构建附加区域，不误算为正式产品复刻 |

## 当前新版验收状态

原始Web参考、同字体控制组及本轮Web20张均保留。迁移前、全窗口调整前和修复前2b757938…证据各自归档；`native-pre-final-fixes/archive.json`明确旧构建的已知缺口且currentAcceptanceCredit=false。最终3bacb424…认证报告captured4、主报告captured18/newCaptured18/resumedFrom=null，均核对同一冻结HAP与runtime；主18为一次全新完成的捕获，没有复用旧图。来源覆盖为18主配对、2显式故障、2原生键盘，不是22项视觉或功能全通过。

`visual-review.json`保存逐图目视范围、每张原生/Web PNG哈希、六组快照兼容核对及两项待调整细节。`native-system-visual-content-check.json`的117项是离线产物与限定内容检查，`native-capture-final-audit.json`是捕获完整性审计，均不算117项设备UI用例；设备容器与交互另据同HAP的UI22/22。1.3字体42项使用独立HAP与runtime，不混入本1倍22图或来源计数。

| 逐图目视范围 | 本轮观察与限度 |
| --- | --- |
| 登录、首次改密×深浅（4张） | 品牌、故事、表单层级及主要中文文案保留；输入为空，首次改密三字段与保存按钮完整可见；不由静态图推断提交成功 |
| 主页×深浅（2张） | 场次标题、描述、题数、等级、0/2进度及入口可读，分类/浮栏采用官方样式；编号栏菱形位置差异另记 |
| 可开始详情×深浅（2张） | 实际0/2、题数、等级和开放文案保留；首切片只读，开始按钮禁用并显示范围说明，这是已声明的功能范围差异 |
| 历史空状态×深浅（2张） | 历史0与独立空文案完整；同步句属于滚动内容末项 |
| 退出后登录×深浅（2张） | 空登录表单，无玩家/场次私密内容残留；退出/Back门禁由设备报告另证 |
| 等待、过期、等级锁定×深浅（6张） | 等待起止为10月29日15:01/10月30日15:01；过期截止10月27日15:01且有回首页；等级锁定要求2级且原因可见，与冻结Web相同 |
| 显式404×深浅（2张） | 两图均无默认0/0，错误与重试/回首页入口可见；真实GET200恢复权威进度另见主捕获faultRecoveries；短文案差异另记 |
| 普通空账号IME×深浅（2张） | 账号框完整、只有标准键盘/工具图标，无可见私人候选、剪贴板内容或凭据；系统IME维持设备自身主题。密码安全IME和全部字段/CTA同时可见不由此推断 |
| 额外四卡图（1张，不计18） | `system-home-behind-bar.png`可见第二卡内容穿过官方玻璃浮栏，并继续绘制至手势区域；Scroll底2848px，进度文字2750–2811px跨越gestureTop2754px |

| 仍待调整的非官方细节 | 影响与结论 |
| --- | --- |
| 首页卡片编号栏菱形位于原生顶部、与01轻微重叠；Web位于栏底部 | 属装饰位置差异，不属于官方材质批准差异；主要场次信息与入口仍可读，无业务阻塞，不称完全一致 |
| 404按钮原生“重试”，Web“重新尝试” | 属短文案差异，不属于官方材质批准差异；恢复语义和操作保留，仍待逐字对齐 |

22张完整原生图中系统状态区与顶栏表面连续，手势区域背景延伸至物理屏边；没有为避让增加独立实心占位。上述是当前手机与冻结图片的观察，不能扩大为其他窗口、动态主题跟随、强制材质降级、读屏或动效验收。

## 真实隔离响应与原生内容区的配对入口

截图脚本新增 `--fixtures-json`，格式为 `{player, assignment, assignments:{items:[...]}}`。它只读取主执行者从真实隔离PocketBase取得的快照，按实际assignment.id匹配详情，列表保留传入的全部items；没有assignments时才兼容回退为单个assignment。浏览器请求仍由本地快照响应，**不算浏览器真实HTTPS联调**，真实网络证据应来自另行保存的原生TLS检查及后端记录。输入快照文件的SHA-256与条目数写入capture-summary，不能和旧E2E夹具图混用。

```sh
python3 scripts/capture-web-baseline.py \
  --fixtures-json artifacts/private/https-isolation/visual-responses.json \
  --width 391 --height 777 \
  --font-file entry/src/main/resources/rawfile/fonts/NotoSerifSC.ttf \
  --output artifacts/web-isolated-content
```

实际设备参数由主执行者报告：density3.375，1320×2848px，状态栏topInset131px、底部bottomInset94px，widthVp391.1111、可用内容高度777.185185vp；后续配对采用约391×777CSS内容视口，原始390×844基线继续保留。截图脚本尚未在真实快照未提供时替换或制造同数据图。

若真实玩家快照的mustChangePassword为false，脚本会明确跳过首次改密状态而不擅自把它改true；需要该状态配对时，应另提供真实首次登录阶段的快照。若传入历史条目，历史截图显示真实列表，不强制制造空状态。实际登录/改密在浏览器截图里是渲染驱动的合成应答，不发送后端写入；本地改密应答仅在原始标记为true时解除它。

可以用 `--states detail` 只拍某个实际快照的详情；也可传多个值，例如 `--states login forced-password`。不传时仍保持原六状态。脚本只执行所选状态必要的登录/改密渲染前置，不为详情变体重复拍摄整套；所请求、实际生成和跳过状态均写入capture-summary。

错误态只在显式 `--states error` 时启用，快照需额外提供 `error:{requestPath,status,body,pagePath?,method?}`。例如指定某次真实故障的API pathname、HTTP 503及其原始错误对象；`pagePath`限制为首切片本地路由，默认使用该详情路由或主页，method默认读取GET、登录/改密POST。脚本不会自行制造错误对象；它在正常状态截图之外重置隔离浏览器的认证内存，再只对指定请求回放错误。登录错误在提交登录后拍摄，改密错误要求原始玩家仍处强制改密，读取错误在完成必要守卫后进入指定路由。capture-summary以`errorReplay.kind`明确标为**显式错误响应回放／合成故障UI**，并记录实际匹配请求数；不能把它当作浏览器真实失败网络验证。

### 最终全窗口版的新epoch Web与认证证据

跨日隔离控制端失败后，主执行者重建专用数据库及随机账号。本轮六组Web使用同一隔离账号及实际DTO，18张主状态图加2张显式404回放；viewport391×777、同Noto字体字节，20/20 PNG捕获时SHA与当前字节一致，0 page errors、无外部请求放行。每组capture-summary中的当前来源文件已固定为私有`https-isolation/web-final-*-frozen-<sha>.json`，并与`private/web-visual-inputs/<sha>.json`原字节一致；originalFile保留捕获时位置。认证脚本重新写入可变原始快照不会改变这20张的来源定位。

| Web组 | 图数 | 输入SHA-256 | 实际回复来源计数 |
| --- | --- | --- | --- |
| 主状态content | 10 | c83854996f09a7c6176dd08e76f3cef9fc08ef846b10042c8874af08be866996 | 合成auth2、真实player12、list8、detail3 |
| 首次改密forced | 2 | 49208fb29fc8232546350d639bcb0cc3e07afe07ce321c1a3d02d8efb281d934 | 合成auth2、真实改密前player4；不消费场次 |
| 等待waiting | 2 | 0f1b4195c64365c4a45fc6479d3dd345e74d35661c53ffd8eef4e556d0ca6899 | 合成auth2、真实player9、list4、detail4、固定空辅助2 |
| 过期expired | 2 | 465edaaaa59be282fac3370134490c2c0881ce58c7b63077f0b6582df91e50ee | 合成auth2、真实player9、list4、detail4、固定空辅助2 |
| 等级锁定locked | 2 | 13f5f86ecb26ccc9bfc4823ba0e50d00642429def324c0e525126fb0bdc7105d | 合成auth2、真实player9、list3、detail4、固定空辅助2 |
| 显式404 error | 2 | d0b65619d792e815d40e54391a3b6fd9174a5b0fe427408aa66de061b8c56e5b | 合成auth2、真实player8、list3、显式故障回复4 |

所有组change-password回复均为0。固定空通知/奖励辅助响应属于切片外渲染，不是实际快照或已迁移能力；显式404是与原生配置相同的故障注入，不冒称真实后端业务失败。浏览器始终只做拦截渲染，不代表真实HTTPS认证或浏览器改密测试。`python3 scripts/write-web-provenance.py --groups web-isolated-content web-isolated-forced web-isolated-waiting web-isolated-expired web-isolated-locked web-isolated-error` 按实际summary计数与SHA更新最小公开provenance；不得沿用旧数字。

最终1倍HAP为 `3bacb424dee59591cc7cb9604bc53a3ab9e32e05fb89e2b9ab2cfee8d3eeaebe`。其runtime重新记录默认fontScale1、全屏布局、透明系统栏、两主题系统内容色和独立TLS检查，记录冻结后供所有捕获核SHA。新认证4张、UI22与主18张已分别完成并匹配该来源；认证唯一真实改密POST200，cleanup3项true，主捕获cleanup3项true。两张404均记录authoritativeProgressHidden=true，之后各自真实GET200的authoritativeProgressRestored=true。旧认证几何、ordinary-account IME图及UI22仅在 `native-pre-final-fixes` 保留。旧密码焦点截图全黑的确切OS原因未确认，仍为失败观察，不计主题或键盘通过；最终键盘截图只接受空账号普通IME，密码与字号的操作可达另据实测UI树记录。

本轮新canonical/forced及四份supplemental与Web冻结源逐字段核对：同player/assignment ID，player、assignment、assignments及error只发现assignment.serverTime随读取时间变化；实际渲染的文案、起止日期、等级、数量及错误配置均相同。因此沿用Web20原PNG与原输入SHA，没有修改DTO、图片或伪换来源哈希。具体兼容记录在 `visual-review.json`。

运行 `python3 scripts/measure-auth-layout.py` 从新3bac原PNG/UI树与当前冻结Web DOM重新生成 `edge-login-layout.json` / `edge-forced-layout.json`。两主题登录标题/账号/密码/按钮纵差为-0.134/-0.283/-0.172/+0.273vp；强改密当前/新/确认/保存为-0.154/-0.043/+0.365/+0.513vp，最大分别0.283vp与0.513vp。输入frame宽多1vp、主按钮宽多0.407vp。两主题星图中心(311.407407,186.370370)vp，相对同字体Web差(+0.407407,+0.089120)vp。此为新报告及新PNG字节的重新测量，不是替旧2b记录换HAP；UiTest哈希只声明测量时当前原文件，auth报告未提供capture-time UiTest哈希。frame/DOM差也不等于描边或字形逐像素相等。

可复现最终报告与框架检查：

```sh
python3 scripts/measure-auth-layout.py
python3 scripts/write-web-provenance.py --groups web-isolated-content web-isolated-forced web-isolated-waiting web-isolated-expired web-isolated-locked web-isolated-error
python3 scripts/build-visual-pairs.py
python3 scripts/check-visual-report.py
python3 scripts/check-visual-report-browser.py
```

本轮HTTP隔离检查14/14；浏览器22状态逐项验证原生/Web图片加载和尺寸、来源不可用项隐藏、默认完整系统区、可选内容区、历史入口与两项差异说明可见，0 page errors、0 CSP errors、0非favicon HTTP错误。两个框架报告绑定重建后的pairs原字节SHA。检查只证明预览框架与已声明来源可用，不替代逐图目视或设备产品验收。


### 全窗口调整前冻结的真实Web12张

本轮主组 `web-isolated-content` 的10张图使用实际单ready玩家/列表/详情，SHA-256为 `f33ce751f6a27c1635e4cf0318f6a881d8f2bf63254dea0cf85d2406e97d6317`；强改密组 `web-isolated-forced` 的2张图使用实际改密前玩家，SHA-256为 `69ff4f2d9888d94ca0a0379bb5d7314dfd04bb30d4a9e82069db5c164831b705`。两组均为391×777、同Noto字节、0 page errors，浏览器API全部本地拦截，不是浏览器真实HTTPS认证。

为保留这12张内容参考而允许后续原生auth重采更新可变输入，已将相同原字节固定到私有 `https-isolation/web-ready-frozen-<sha>.json` 与 `web-forced-frozen-<sha>.json`，只读权限400。capture-summary.snapshotInput.file现解析到该副本，originalFile保留捕获时原路径，sourceLocationUpdate说明仅来源定位归档；PNG、PNG捕获SHA和输入SHA均未变。不可变的第二份按SHA归档仍保留在private/web-visual-inputs。后续原生图来自最终HAP和真实服务端时，配对说明其业务内容与冻结参考的关系，不把两个时间点当同一网络请求。

本轮主组实际本地回复为：合成auth2、真实player快照16、真实assignments快照9、真实assignment快照4、固定空辅助1（Web后台GET notifications）。强改密组为合成auth2、真实player快照7、change-password0，未消费场次/列表。固定空通知属于切片外辅助渲染，不是通知能力已经迁移，也不称所有DTO均真实。完整逐请求responseSource在各capture-summary。`scripts/write-web-provenance.py`从经过SHA复验的summary重建最小公开来源摘要，并记录captureSummarySha256；每次Web重拍后必须同步执行，避免旧provenance.json残留。旧档中原先陈旧的provenance字节保留且在archive.json标为excludedMetadata，不作为有效来源。

上述12张另存`web-pre-edge-to-edge-content/forced`，对应全窗口调整前的旧隔离数据库与账号。跨日隔离控制端失败后将重建一次性数据库；最终auth完成后，主12张和等待/过期/等级不符及显式404会用新epoch真实快照重新捕获。旧12张及其不可变来源继续保留，不能将新ID冒称为旧输入，也不能改写这12张的快照SHA来填数。

### 保留的真实首次改密Web参考（迁移前阶段）

`artifacts/web-legacy-pre-system-forced/` 保留旧阶段最后认证快照的391×777同字体首次改密深/浅两张图；当前web-isolated-forced已用于本轮新快照，旧档为0 page errors、0外部请求放行。输入文件为主执行者提供的 `visual-responses-forced.json`，SHA-256为 `0c547436d8466e3c01e2458143fb965195f133f3a570784f294d01954c5e70d5`。其中player来自原生真实改密前的GET /me，mustChangePassword=true；assignment/list来自改密成功后的GET，仅作为脚本要求的后续支持字段。输入的不可变原字节副本按SHA保存在私有 `artifacts/private/web-visual-inputs/`，不由预览服务公开。

当时只选择 `--states forced-password`：捕获流程只回放auth与改密前/me，**没有请求或展示assignment/list，没有调用change-password**。浏览器auth响应为合成渲染驱动，全部API本地拦截；此参考不等于浏览器真实HTTPS联调。旧构建三个输入与保存按钮相对Web y差为-0.450/-0.339/+0.068/+0.216vp，最大0.451vp；输入frame宽多1vp，保存按钮宽多0.407vp。标题frame宽不等于字形宽。该历史量测已标记legacy-pre-system，见 `artifacts/validation/forced-visual-comparison.json`，不计新版通过。

```sh
python3 scripts/capture-web-baseline.py \
  --fixtures-json artifacts/private/https-isolation/visual-responses-forced.json \
  --states forced-password --width 391 --height 777 \
  --font-file entry/src/main/resources/rawfile/fonts/NotoSerifSC.ttf \
  --output artifacts/web-isolated-forced
```

### 保留的真实主状态Web参考与逐请求来源

`artifacts/web-legacy-pre-system-content/` 保留旧阶段canonical快照的登录、主页、可开始详情、历史空状态、退出后登录×深浅，共10张；当前web-isolated-content已用于本轮新快照，旧档为0 page errors。快照SHA-256为 `3e4ea98088cefea848dd365613b3425d9b45b6e8015db4d6a43637cee771f71e`，真实player/list/detail来自原生改密成功后的单ready场次隔离后端读响应。auth仅为本地合成渲染驱动，退出图仍按清理隔离浏览器认证状态生成，不冒充Web退出按钮交互测试。

| 来源 | 主状态10图实际回复数 | 首次改密2图实际回复数 | 含义 |
| --- | --- | --- | --- |
| 真实player快照 | 13 | 6 | 未修改mustChangePassword；分别为改密后/改密前玩家 |
| 真实assignments快照 | 8 | 0 | 保留输入items全部条目；主组为1个ready |
| 真实assignment快照 | 3 | 0 | 按实际assignment.id匹配详情 |
| 合成auth渲染驱动 | 2 | 2 | 不访问真实后端，不表示浏览器HTTPS认证通过 |
| 合成change-password驱动 | 0 | 0 | 本轮选定流程没有改密回复 |
| notifications/rewards固定空辅助响应 | 0 | 0 | 当前无请求；若后续页面请求，脚本仅回固定空items，不是实际快照或已迁移能力 |

每个实际请求均有 `responseSource`，摘要有 `responseSourceCounts`；不能把整个Web捕获统称为“所有DTO均真实”。主组与改密组provenance分别列出实际供应/实际消费DTO。截图PNG的SHA-256在各图JSON和capture-summary中，配对构建器同时核对当前输入及私有归档哈希、冻结Web版本、391×777视口和字体字节。`python3 scripts/build-visual-pairs.py` 生成公开的最小 `artifacts/visual-comparison/pairs.json` 与HTML内嵌来源映射，只有完成的原生捕获报告与对应Web图才计为配对；待补项继续显式展示。

公开预览与来源映射已由独立代理只读复核：未发现private、原始UiTest树、路径穿越或符号链接可读取的通路，未发现凭据字段被复制到公开manifest。证据边界须区分：Web PNG hash由捕获时记录并回验；原生报告若未记录捕获时PNG hash，则manifest只记录配对生成时的当前原文件字节hash，`shaScope`明确注明，不把它扩大为捕获时的密码学完整性证明。若原生报告提供screenshotSha256，构建器会校验并拒绝不匹配文件。来源配对、视觉判断与功能验收仍为三个独立结论。

## 迁移前登录量化记录（不计新版通过）

迁移前认证图已归档 `artifacts/native-legacy-pre-system/login-light.png`、`login-dark.png`，对应旧auth报告captured4。旧构建在根offset定位上补齐六个轨道节点，量测保存在已标legacy-pre-system的 `artifacts/validation/login-visual-comparison.json`；只供历史页查看，不纳入当前pairs计数。早期12:54定位修复副本保留在native-login-offset-verified。下面数值均为旧构建，不代表官方Navigation/材质版布局。

已补 `artifacts/web-content-login-reference/` 的391×777同字体登录深/浅截图，共2张、0 page errors、API请求列表为空。它仅捕获未提交的登录表单：脚本虽载入默认完整E2E夹具，但没有消费player/assignment DTO、没有填入账号或提交认证。此组用于登录版式配对，不冒充同一真实账号的业务页面。精确差值与图像provenance见 `artifacts/validation/login-visual-comparison.json`。

| 元素 | 原生物理bounds `[left,top,right,bottom]` | 原生内容x/y/w/h（vp） | 同字体391宽Web x/y/w/h（CSS px） | 原生y减Web y |
| --- | --- | --- | --- | --- |
| 表单标题 | 67 / 1171 / 1253 / 1284 | 19.852 / 308.148 / 351.407 / 33.481 | 20 / 308.578 / 351 / 33.594 | -0.430 |
| 账号输入 | 67 / 1429 / 1255 / 1605 | 19.852 / 384.593 / 352 / 52.148 | 20 / 385.172 / 351 / 52 | -0.579 |
| 密码输入 | 67 / 1750 / 1255 / 1926 | 19.852 / 479.704 / 352 / 52.148 | 20 / 480.172 / 351 / 52 | -0.468 |
| 登录按钮 | 67 / 1981 / 1253 / 2157 | 19.852 / 548.148 / 351.407 / 52.148 | 20 / 548.172 / 351 / 52 | -0.024 |

四个主要控件的纵向位置差均小于0.6vp，左边界差-0.148vp。相对新391宽参考，标题/按钮宽多0.407vp，输入框宽多1vp；扣除原生391.111与391视口差后的余差分别0.296vp和0.889vp。相对原390宽参考，输入宽差为2vp、视口差为1.111vp。这是UiTest组件frame与Web DOM矩形比较，未测得实际描边边缘，不能把余差直接当作描边误差或将全部矩形概括为“小于0.6vp”。

新原始PNG中两主题的完整星形填充路径栅格边界均为 `[908,617,1194,903]`px，换算内容中心为 **(311.407407,186.370370)vp**、栅格尺寸84.740741vp；相对391宽Web星中心(311,186.28125)，差值为 **(+0.407407,+0.089120)vp**。原图可见完整星形，轨道穿出story继续进入表单区，已解除故事宿主矩形裁切。测量脚本为 `scripts/measure-native-login.py`：只读PNG，按已冻结色值在无文字的星形区域提取0.22透明度路径填充，排除较淡轨道/轴线；没有编辑图片或把UiTest frame冒充绘制坐标。阈值和抗锯齿边缘约有1物理像素误差，84.740741vp栅格边界不等于Web SVG几何边界85.0564px，不宣称逐像素完全相等。

历史量测可运行 `python3 scripts/measure-native-login.py --native artifacts/native-legacy-pre-system --web artifacts/web-legacy-pre-system-content --output artifacts/validation/legacy-login-visual-comparison.json`。轨道节点的Web六个`i`坐标与1px边框包含块公式保存在web-atlas-layout的orbitMarkers，仍可作品牌装饰参考，但不证明新版容器已运行。

Web DOM和SVG矩形见 `artifacts/validation/web-atlas-layout.json`：390×844下story为(20,84,350,204.578125)，atlas为(100,-23.71875,420,420)，星中心(310,186.28125)；391×777下仅x加1，中心为(311,186.28125)。原CSS字体和同原生Noto组的上述矩形完全一致，实际SVG path约85.0564px见方，中心相同。

该证据确认登录主要控件布局与星图定位已接近冻结Web，仍不等于所有状态和所有像素一致。历史12:43的background方案曾右移约69vp、下移108vp并裁切，其原图和短弧拟合值保留在 `artifacts/native-atlas-background-observed/`，状态为失败且已被本轮根offset证据替代。Web装饰复测可运行 `python3 scripts/measure-web-atlas.py`；它读取登录、主页、详情DOM的getBoundingClientRect、SVG getBBox/getScreenCTM，所有API由冻结E2E夹具本地响应、外部请求阻断，不生成截图、不访问后端。

| 391×777同字体控制组装饰 | 宿主DOM x/y/w/h | atlas x/y/w/h | 星中心 |
| --- | --- | --- | --- |
| 登录故事 | 20 / 84 / 351 / 204.578125 | 101 / -23.71875 / 420 / 420 | 311 / 186.28125 |
| 主页intro | 20 / 100 / 351 / 107.1875 | 171 / 60 / 210 / 210 | 276 / 165 |
| 详情卡片 | 12 / 109.578125 / 367 / 419.375 | 238 / 50.578125 / 200 / 200 | 338 / 150.578125 |

主页atlas CSS为top=-40/right=-10、opacity0.17；详情art为top=-60/right=-60、opacity0.16，且位于有1px边框的卡片内包含块。详情atlas相对卡片外框的实际偏移为(226,-59)，直接用外框锚定时需计入这1px边框。原字体与Noto对照只有详情宿主和装饰y存在已说明的1px整体差。

环境徽标和页尾“隔离测试环境”为原生测试构建的附加可见标识，正式Web没有对应元素；字形栅格化与系统栏亦保留为平台差异。“同字体控制”仅固定display中文衬线为同一NotoSerifSC字节，正文仍使用各平台系统字体，不能解释为所有正文和图标逐像素相同。这些差异需在最终结论中明示，不能为追求像素相同隐藏隔离环境标识。
