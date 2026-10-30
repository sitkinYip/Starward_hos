# 专用隔离预览环境

2026-10-30，固定隔离预览已可使用：账号 `starward_preview`，口令仅保存在忽略的本机 `artifacts/private/profile-preview/login.json`。真实普通登录13项与3张原图静态审阅通过，第二次登录后已留在首页，无需首次改密。服务仍运行，依赖电脑保持唤醒、Docker运行与手机USB连接；仅供本机隔离审查。

当前用户手验补充（2026-10-30）：用户在最终交付的 `c2fdc343…` 固定预览中，手动拖动浮栏启程↔护照并松手切换、打开头像侧栏，对“跟手光感、松手选中和侧栏进出方向是否符合预期”明确回复“符合预期”。来源见 `artifacts/validation/profile/native-ui-user-confirmation.json`。这三项从当前待验中移除；6a历史采集、静态及官方注入报告的原限制保留，不反向改写。此次没有新增自动化或Root动态目视，不扩展为触感、取消/中断、减少动画、双主题全覆盖、折叠、重启或主动改密通过。

## 本轮实际证据

固定预览已完成真实seed、正式首次改密及显式状态修复，后续直接登录实测已通过，账号已可供审查。

首次因Docker stdin缺少`-i`失败，经业务写入0核验后显式恢复prepared；第二次seed和改密成功后，PB0.40.1拒绝删除唯一superuser，保留initializing而未重放。

随后 `profile/preview-initialization-reconcile.json` 实际passed，SHA `75ba302cacd5bf9fa5fca9764b92542bd8afdb961efdf12d57db9228724df5c3`：官方CLI对同一bootstrap身份换成不保留的随机密码，password hash/tokenKey均已变化，27个game表逐值与SHA一致、玩家口令/CA不变、seedReplayed=false，核验后才标complete并补回原IDs。

最终runner `61059c59de2ec4fc964ee01566557dca7e31fc1535d19ae0559529f6897b0460` 的唯一记录退役及镜像immutableID/逻辑tag/arm64校验已静态复核。

`profile/preview-environment.json` 已取得host_ready_native_pending（SHA `87b37b96a5f15571577b21c6d4edcd33cd26acd9f3161a205233c6bf6d7b517c`）：正式玩家直接登录verified_direct_login，独立CA可信200、不可信及错误主机名均拒绝，不开放玩家故障/重置接口；该原报告保持Host范围。

新预览HAP `c2fdc34356a6176953fac806157b7c82ac513345575f8368f95524cea8b7408b` 已经官方run构建签名安装，`profile/runtime-preview-final.json` 六项实际passed（SHA `77f6f84e2894cc376594a62afc02dc43af54559bc739fd2584eb0c08612d9527`），包括真机API可信CA接受及不可信/错误主机名TLS_ERROR、系统区透明和深浅内容色。

独立 `profile/runtime-preview-freshness.json` passed（SHA `eff6a1351013ebb908bebabbb8062318a0acfa7b3c48fe702d3732143c6860a2`），以当前自有进程的7条原始记录核window/material/TLS/双主题与原报告相同，不保存设备/进程标识，不改原runtime。

新预览包的 `profile/preview-native-smoke.json` 已实际passed/13项（SHA `c63aed805a9c218a0589366a623fe91a8d0bfd5b9acb2da16315978307054751`）：固定普通账号从空登录直接进首页，真实四类场次、权威资料/只读账号、菜单Back、显式退出空输入及第二次直接登录均已核；四项收尾全true，第二次会话有意留在已认证首页供用户审查。独立 `profile/preview-native-root-review.json` 为reviewed_static（SHA `467dcc5b64f2a1b70b14900dfc96638e75742330adece9dcb7d29ef068d36cff`），Root逐SHA亲看3张原图，已停止手机自动化。此13项只认证/读取/导航/退出，不重跑资料、头像或密码写链，也没有服务端写台账计数结论。固定账号直接预览现已可交付，服务收口时仍运行且Host直接登录再次验证；需电脑保持唤醒、Docker运行、手机USB连接。

独立 `profile/preview-package-source-binding.json` 为offline_binding_verified（SHA `19cf9511b823b3e4d19e1327dadef825ed068eda74ab7443cd3da3cade8bede8`）：35份源、8个导航SVG和包内ABC与6a逐字节相同；48个ZIP成员集合相同，45个内容字节相同，实际仅独立CA、完整1226条symbolMap记录重排及integration JSON空白/fontScale `1.0`→`1` 序列化变化，JSON值/顺序相同且timeout均15000。新signed HAP独立600归档，旧包/报告未改；不解析或归因ZIP之外的签名块。它只作离线来源绑定，不继承6a主轮39项为新包通过。

停止/重启持久保留及用户改密后的行为也未因此完成实测。一次性验收的6a手机主轮39项及静态审阅已完成，但使用另一数据库/账号/CA，不替代本预览任何启动或登录结果。

## 与一次性验收环境的区别

原验收环境运行的是独立 Docker PocketBase 数据库，复制冻结后端的 hooks/migrations，通过真实认证、改密、资料和受保护头像接口验证原生应用。它不是 Web mock，也没有在应用中绕过强改密。随机测试玩家、故障注入、数据重置和最终销毁用于复现边界，因此不适合作为长期人工审查账号。

新预览使用 `scripts/preview-environment.mjs`，数据位于忽略的 `artifacts/private/profile-preview/`；一次性验收继续使用 `artifacts/private/https-isolation/`。两者没有共用数据库、状态、玩家或故障控制。预览不会暴露故障注入、测试重置、通用管理员或 PocketBase 管理端接口。底层 PB 管理端仅绑定本机回环，玩家 HTTPS 代理有明确接口白名单。

固定玩家账号为`starward_preview`。密码首次生成后保存在本机  `artifacts/private/profile-preview/login.json`，文件权限为600，目录权限为700；密码、登录 token、签名和设备标识不进入受版本管理的代码或报告。该文件是用户要求的本机预览登录信息，应用自身仍然只在内存保存会话，不支持记住登录或重启自动恢复。

首次start初始化必须通过正式管理员接口创建专用玩家，再通过真实玩家改密接口完成一次初始改密并确认 `mustChangePassword=false`。用户之后直接登录，不再经过强制改密页。初始化用管理员会在操作完成后停用并轮换为不保留的随机密码，审计和场次的必需 actor 关联保留；临时 superuser 优先按确切记录删除；PB0.40.1禁止删除唯一记录时，仅在认证与sole记录ID/email完全一致、容器归属复核后，使用官方superuser update将同一记录换成不保留的随机密码。不会为规避唯一记录限制创建额外superuser，相关口令和token不持久化。固定预览玩家不得用于自动故障注入或改密验收。

一次性环境当前已有39项主轮、静态审阅，以及4次当机官方注入松手选中观察；这些结果不属于固定预览。真实PNG裁剪预览取消回归也已独立10项完成、8cleanup true，两原图由Rootreview；它不包含确认上传重验。旧一次性环境精准清理已独立完成，详见下段三份报告；持久预览与其分开。6a的4张终态图不替代动态人工观察；交付c2fd后上述用户手验另确认跟手光感、松手选中和侧栏进出方向，触感/取消/中断/减少动画等仍未验。39项主轮六cleanup true只说明该次App会话收尾，最终服务、映射、备份与媒体清理由各自独立报告证明。Host状态、预览HAP/runtime及native-smoke已分别记录；密码焦点黑图和动态光感的限制也不能通过换环境抹去。

本轮旧一次性环境清理已取得三份独立实际报告：`profile/owned-avatar-media-cleanup.json` passed（SHA `7ed276e89d9009f876cf02977b3866d4d08801e8fdc047f86f81389fe5ab9f7f`），仅5个自有测试媒体逐个新读回SHA核验后删除exact URI及各2个精确临时导出，查询均0；`profile/isolated-services-cleanup-final-complete.json` passed/9项（SHA `c4962d816368ed43fda23c8f8b462c2d318a27faf8c91b87447e0b73408ddd55`），旧TLS/gate/backend进程、监听、reverse、一次性容器/DB及运行凭据状态均已消失，其他映射保持不变；`profile/isolated-private-material-cleanup-final.json` passed（SHA `0f7ac7ad37a9ef4b073350f21f9fb0daebdf26542169c7d7b61f1f408a6f0d5a`），8份旧TLS备份材料逐SHA删除，只留非secret清单/恢复日志，持久预览目录之外的旧私钥文件为0。先前三份stop preflight均incomplete、checks为空且未请求官方stop，历史保留；最终服务报告自身不宣称备份已清，由后一份材料报告承接。没有宽泛Docker/目录删除或系统信任/签名修改，固定预览DB/CA/登录文件独立保留。

## 启动和安装

必须先完成旧验收环境的设备工作并关闭其 TLS / USB18443 映射。新工具遇到已有映射会拒绝启动，绝不替换。固定 Node 来自当前 Studio 配套运行时：

```sh
STARWARD_PREVIEW_NODE=/Applications/DevEco-Studio.app/Contents/tools/node/bin/node
"$STARWARD_PREVIEW_NODE" scripts/preview-environment.mjs prepare
"$STARWARD_PREVIEW_NODE" scripts/preview-environment.mjs start
"$STARWARD_PREVIEW_NODE" scripts/preview-environment.mjs status
```

`prepare` 要求原后端 checkout 未修改，且校验过的 `starward-hm-isolation:pb-0.40.1-arm64` 镜像已由既有官方运行时准备流程生成。它冻结只读 hooks/migrations 摘要与镜像ID，不下载另一套业务代码，不改变原后端文件。首次 `start` 创建独立数据库并种入四个真实场次状态；后续启动保留资料和头像，不重新生成账号、不重置玩家。

`start` 返回后仍须检查 `status` 中的 `loginValidation` 为 `verified_direct_login`。如果口令被用户改过，工具只报告保存的口令不可用，不静默改回。初次初始化中断会保留 `initializing` 状态并拒绝重放写请求，须由操作者核验本预览目录后恢复，不能反复重试种子命令假定成功。

旧环境关闭且清理完成后，操作者先显式移除旧打包配置，再配置预览并使用官方 CLI 安装：

```sh
python3 scripts/configure-integration.py
"$STARWARD_PREVIEW_NODE" scripts/preview-environment.mjs configure
scripts/hm.sh run
```

`configure` 不会覆盖另一环境的配置。它只写入忽略的 `integration.json` 和独立预览的公共 CA，不嵌入账号、密码或 token；`scripts/hm.sh run` 才执行构建、签名、安装和启动。原生页面继续明显标识隔离环境。操作者还须单独完成真机登录、资料读取和返回检查；主机状态 `host_ready_native_pending` 不能当作手机已通过。

原生安装并取得该预览HAP独立六项runtime报告后，可由唯一设备操作者运行以下只读冒烟。脚本只复用原生UI助手，不接入一次性验收的控制端或密码重置；核对独立CA、打包配置、固定玩家和真实HTTPS，验证空登录、直接首页、资料、菜单返回、显式退出及再次直接登录。`--leave-logged-in` 将第二次已验证的首页留给用户审查。该脚本已由唯一设备操作者实际执行并13项通过，第二次直接登录留在首页，随后已停止手机自动化；其结果写入 `artifacts/validation/profile/preview-native-smoke.json`。

```sh
python3 scripts/device-preview-smoke.py run --runtime-report <该预览HAP的runtime报告路径> --leave-logged-in
```

## 证书、重启与 USB

预览固定使用手机侧 `https://127.0.0.1:18443`，经官方 `hdc rport` 到本机回环 HTTPS。独立预览 CA 有效期365天，只在这份应用隔离配置中受信，不修改手机或电脑系统信任，也不关闭证书或主机名校验。服务器叶证书有效14天，**在启动时**临近到期会用同一 CA 续签；运行中的 gateway 不自动更换证书，需要停止再启动。CA 临近到期时工具拒绝自动替换，换 CA 后须重新打包和安装。

断开并重新连接手机时可重新附加原有预览服务：

```sh
"$STARWARD_PREVIEW_NODE" scripts/preview-environment.mjs attach
```

该操作要求恰好一台手机，只创建或复用完全匹配的本预览端口映射，不修改其他映射。电脑正常重启前可停止；下一次用同一个 `start` 恢复数据库、CA 和账号：

```sh
"$STARWARD_PREVIEW_NODE" scripts/preview-environment.mjs stop
"$STARWARD_PREVIEW_NODE" scripts/preview-environment.mjs start
```

`stop` 保留预览数据库、CA 和固定登录信息。它核对 UID、Node 完整命令、工作目录、进程出生时间、实际本机监听、私有控制鉴权及容器 image/label/精确挂载；容器停止还必须匹配本次 `docker create` 返回的完整ID。启动使用排他 `runner.lock`。电脑崩溃留下锁时不会盲删或抢占：须核对锁的 owner、PID 已不存在、同名容器及监听状态后，仅清除确切的遗留锁；不能删除数据库或套用一次性验收的清理命令。

## 用户主动改密后的处理

如果用户在应用里更改了预览密码，继续使用自己设置的新密码即可。工具不会跟踪明文新密码，原 `login.json` 会过期，`status` 会明确报告 `saved_login_rejected_or_unavailable_use_own_changed_password_or_explicit_reset_login`。

需要重新生成一份固定登录信息时，由操作者显式执行：

```sh
"$STARWARD_PREVIEW_NODE" scripts/preview-environment.mjs reset-login
```

它仅作用于该独立预览玩家，正式管理员重置后再执行一次真实改密，并确认新口令可以直接登录，才更新本机600登录文件；不自动重试改密，不输出口令。原生已有会话会失效，需重新登录。这不是自动化验收步骤，也不作用于生产玩家或一次性测试玩家。

补充 `profile/preview-public-secret-literal-scan.json` 实际passed（SHA `27f446cbc316df9babf3a1895ef376e0abd34fb57bf5c638d401043184615dbe`）：998个Git-visible文件、2个仅内存读取的预览口令/控制token字面量，发现0、读取错误0，来源文件均ignored/mode600；不把值写入报告。最终公开范围扫描以 `profile/public-artifact-scan.json` 的最新执行为准，不在文档嵌其滚动摘要；前述973文件扫描仍是pre-UI历史检查点。

## 证据分开记录

脚本准备校验：

```sh
/Applications/DevEco-Studio.app/Contents/tools/node/bin/node --check scripts/preview-environment.mjs
/Applications/DevEco-Studio.app/Contents/tools/node/bin/node scripts/preview-environment.mjs --help
```

运行后的主机报告是 `artifacts/validation/profile/preview-environment.json`，只记录模式、来源摘要、实际 TLS 正反校验和直接登录状态。它不包含口令、token、受保护文件地址或设备标识。原生构建、签名、安装、登录和视觉检查另记当前 HAP/runtime 证据；固定预览的准备和启动不得替换此前一次性验收报告的归属。
