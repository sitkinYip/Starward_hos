# 首切片真实后端隔离环境

日期：2026-10-27。此环境仅包含随机生成的测试玩家和虚构场次；没有连接、复制或修改生产数据库。当前采用真实PocketBase、仅回环监听的TLS网关与官方USB反向转发。测试构建通过SDK caData显式信任临时CA，证书链和主机名验证保持开启；不能把主机TLS探测代替真机HTTPS结果。

## 运行边界

- 通过已安装的官方 Docker Desktop CLI 启动引擎。PocketBase 固定 **0.40.1 / linux arm64**，官方发布ZIP的SHA-256为 `8e15eb6080de5ae7fcf789ac963d5c3c9328a491d5f7a24eb13c93a2f4bae4f1`，准备脚本实际比对后才解压构建。
- 使用相邻后端仓库冻结源码中的 hooks、migrations、Dockerfile。复制到本项目 gitignore 的 `artifacts/private/https-isolation/source/`；原 Web 与后端源码不修改。运行辅助器复用后端 `tests/server.mjs` 创建全新临时数据目录，并把代码只读挂载进独立容器。
- 真实 PocketBase、玩家代理、特权测试控制器全部只绑定 `127.0.0.1` 随机端口。只有玩家代理可作为TLS网关origin；不要把PocketBase原端口或控制端口放入USB转发或外部隧道。
- 随机账号、初始/新密码和控制token只写入 mode600 的 `artifacts/private/https-isolation/state.json`，不进入源码、构建样例或公开报告。它们仅属于此一次性测试库，不是客户端持久凭据。

## 可复现命令

```sh
docker desktop start
node scripts/isolated-backend.mjs prepare
node scripts/isolated-backend.mjs start
```

`start` 输出玩家代理loopback地址和私密状态文件路径，不打印账号密码。它种入玩家“远航者”、两道已发布题目、正常/未来开放/已过期/等级不符四个场次；主场次标题“星辰探险”、描述“解开谜题，发现惊喜。”。场次尚未开始，题目内容仍由真实服务端权限控制。

```sh
node scripts/isolated-backend.mjs status
node scripts/probe-isolated-backend.mjs
# USB TLS网关就绪后，同一探测器自动选择state.tls.hostBase。
node scripts/isolated-tls.mjs start
node scripts/probe-isolated-backend.mjs
```

TLS启动后，探测脚本自动读取当前runner的HTTPS主机地址及临时CA；使用Node https.request显式ca和rejectUnauthorized=true，校验证书链与SAN。脚本只接受当前runner状态中的地址，拒绝任意远端与生产API。脚本会重置测试玩家、执行实际登录/改密/列表/详情/file-token，再恢复首次改密初态，因此不能与真机玩家写操作并行执行。

## 玩家代理白名单

- GET：health、me、assignments、单个assignment、受保护玩家头像，以及Web布局所需的只读notifications/rewards。
- POST：game_players auth-with-password、me/change-password、files/token。
- Web CORS只允许本机 `localhost`、`127.0.0.1`、`local.sitkin.top` 开发来源；原生无Origin请求正常透传。
- `/__/`、`/_/`、`_superusers`、业务admin、测试控制接口、注册、入场、答题均未开放。非白名单请求返回404；后台控制器的随机token不会从公开代理获得。
- 正常响应的状态、JSON与业务值保持真实后端结果；代理只处理路由边界和CORS，不将错误包装成成功。

控制器仅用于本次测试库，可通过runner子命令重置测试密码、停用/启用测试玩家、设定展示场景、注入单次延迟/503/断连/畸形响应。`scenario {emptyAssignments:true}` 通过将此测试玩家四个测试session实际置为archived产生真实空列表；false或reset恢复published，不改写成功响应。`scenario {singleAssignment:true}` 实际归档其余三个session，留下ready场次用于同数据视觉配对；false恢复四场。`scenario {status:"active"|"completed"|"cancelled"|"assigned"}` 改动专用主assignment的真实状态，供七态及历史分类检查，恢复时用assigned。

`fault {dropResponse:true}` 会先把写请求真正发到PocketBase，取得已完成的响应后断开客户端连接；TLS网关收到上游中断时继续断开客户端，不伪造空200。故障注入必须另列为resilience证据，不能宣称它是原后端正常输出。请求台账只记录方法、路径、状态、是否带认证及是否误用Bearer；不记录密码、token、请求体或文件token URL查询。

## 原生测试与Web配对数据

安装包含当前临时CA及隔离配置的签名调试构建后，独占真机执行：

```sh
python3 scripts/device-https-acceptance.py --phase all
# 独立执行某一部分时：
python3 scripts/device-https-acceptance.py --phase core
python3 scripts/device-https-acceptance.py --phase resilience
python3 scripts/device-https-acceptance.py --phase rotation
python3 scripts/device-https-acceptance.py --phase visual
```

core、resilience、rotation各自使用本次测试玩家并可能重置密码，不得与其他原生、Web或协议探测并行。all按主链路、故障恢复、改密丢响应、配对数据导出、显式退出执行。visual只使用已改后的新密码，实际归档其他测试session并经严格HTTPS读取DTO，不操作设备；若core尚未成功改密则失败，不退回伪造夹具。

报告为`artifacts/validation/device-https-acceptance.json`，每项完成即保存。新执行先覆盖旧pass，适配或断言中断写incomplete并保留已通过项，不自动声称业务失败。独立phase的passed只覆盖所选部分。官方CLI只能导出屏内节点，辅助器会滚动查找目标；保存前去除所有TextInput内容。截图只在校验本测试App位于前台后生成。实际边缘swipe与keyEvent Back分开记录，未确认系统识别时不声称手势通过。

Web配对快照仅写private：`visual-responses.json`是改密后、单一ready场景的真实`GET me/assignment/assignments`；`visual-responses-forced.json`保留真实改密前`/me`的mustChangePassword=true，assignment/list来自解除门控后的实际GET，并在provenance明确分阶段时间和来源。后端在强制改密时真实拒绝后两项（403），不能把它们写成门控前可读取。快照不含token或密码；Web视觉渲染使用的网络夹具仍仅属于视觉对照输入，不能代替原生真实HTTPS证据。

`python3 scripts/capture-native-https-visual.py`用于后续独占设备的补充截图：前提是已完成改密、单一ready场景、App已退出且输入为空。脚本准备18张深浅主题截图，按实际PNG画布像素校验主题；补充阶段实际发布其余三个测试session并导出`visual-responses-waiting.json`、`visual-responses-expired.json`、`visual-responses-locked.json`到private，使用共用的`isolated_snapshot.py`。快照接口只允许当前state中固定生成的assignment ID，认证之外全部为GET。

其中两张`detail-404-fault-*`明确为单次404故障注入；配套`visual-responses-detail404.json`包含真实成功DTO及单独的error配置，供Web `--states error`重放。正常成功响应不改写，恢复必须观察点击后的新GET返回200且fault=false。脚本finally恢复assigned及单一ready、清理登录UI；若待注入故障尚未消费，将其替换成永远不匹配玩家白名单的路径，并明确记录faultNeutralised。截图采集完成只记captured，不能代替视觉差异评估；UI dump未提供clickable时会记录未知，不把缺字段当成禁用按钮证据。

## 已实际取得的设置证据

`node scripts/probe-isolated-backend.mjs` 的 **25项本机真实协议检查全部通过**，见 `artifacts/validation/real-pb-local-probe.json`：真实认证、强制改密、旧token失效、四个时间/等级场景、未开启题目null、serverTime、files token、Web CORS和公开代理禁用路径。该报告明确是本机HTTP设置探测，不是原生HTTPS验收。

`node scripts/isolated-tls.mjs start` 已实际生成两天有效的临时EC CA与SAN仅含 `IP:127.0.0.1` 的服务器证书。HTTPS服务器只绑定主机127.0.0.1随机端口，官方 `hdc rport tcp:18443 tcp:<hostPort>` 将设备本地18443映射到该主机端口。任务枚举/清理使用官方 `hdc fport ls` / `hdc fport rm <taskstring>`；不清除其他映射。

真实TLS正反检查 **3/3通过**，见 `artifacts/validation/isolated-tls.json`：curl指定CA返回HTTP200，不提供CA被拒绝（exit60），提供正确CA但使用错误主机名localhost也被拒绝（exit60）。随后同一25项真实协议经HTTPS再次全部通过，见 `artifacts/validation/real-pb-https-probe.json`。未关闭TLS验证、未安装系统根证书、未使用NODE_TLS_REJECT_UNAUTHORIZED=0。

临时CA公钥PEM被复制到gitignore的 `entry/src/main/resources/rawfile/integration-ca.pem`，仅供本轮测试构建通过API20起支持的HttpRequestOptions.caData使用；私钥始终位于private目录。state.json中的tls包含设备base、主机hostBase/hostPort、CA路径、公钥摘要、服务器证书指纹和TLSrunner PID。原生客户端实际HTTPS结果由主验收报告另行记录。

原计划的Cloudflare Quick Tunnel未被采用：官方下载程序被本机AMFI以CT签名问题终止，没有绕过系统校验。当前方案不创建公网入口，只验证USB隔离链路上的真实TLS与后端契约；它不能证明生产域名、远程网络、素材防盗链或互联网可达性。

## 保持证书的网关恢复

若gateway意外退出而backend、`state.tls`、原CA/证书/私钥及已打包CA仍在，使用`resume`，不要重跑会生成新CA的`start`。恢复会验证state中指纹、CA摘要、打包CA字节、证书有效期、唯一IP SAN、私钥与证书匹配、真实CA链；仅绑定原hostPort并复用原USB映射，不重建数据库、账号或HAP。现有不同映射、证书过期或任何身份不符均拒绝恢复。

```sh
node scripts/isolated-tls.mjs resume
```

该命令是长期服务，执行终端必须持续存在。自动化使用独立session和private日志运行，例如在项目根目录：

```sh
python3 - <<'PY'
import os, subprocess
from pathlib import Path
target = Path('artifacts/private/https-isolation/tls-resume-run.log')
descriptor = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
with os.fdopen(descriptor, 'ab', buffering=0) as log:
    child = subprocess.Popen(['node', 'scripts/isolated-tls.mjs', 'resume'],
        stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
        start_new_session=True)
print('Own gateway launched; check isolated-tls status and private log for readiness.')
PY
```

本轮确实观察到原gateway已退出、其原执行输出无法取得，退出原因未确认。修复措施为逐请求消费req/res/upstream/remote的error、abort、close，以及TLS socket错误，避免断连传播为未处理stream错误；不以全局忽略异常代替处理。恢复后严格TLS正反检查3/3通过，另经12次未完成health请求断连及一次明确health响应丢弃测试，gateway和原backend均存活，后续严格HTTPS health返回200；认证请求新增0、玩家写入0。证据为`artifacts/validation/isolated-tls-resume.json`，真机重新认证由后续设备验收单独记录。

## 清理

先停止本次TLS网关，再停止后端：

```sh
node scripts/isolated-tls.mjs stop
node scripts/isolated-backend.mjs stop
```

TLS停止会解除自己的USB映射、删除临时私钥及匹配的CA资源；后端停止只清理自己创建的容器及临时数据库、随机凭据状态文件。不会停止其他容器、清理Docker全局数据或修改生产。校验过的运行时下载与无业务数据的镜像缓存留在private目录/本机Docker，便于下次复用。


## 本轮收尾（2026-10-28）

最终已切回默认演示构建并通过13项真机冒烟。停止服务前逐一核对runner的UID、脚本参数及工作目录；先停止自己的TLS，再停止一次性PocketBase。`isolated-environment-cleanup.json` 记录自己的USB映射、临时CA/私钥目录、测试容器/数据目录及四个回环监听均已消失；原Web基线Vite也已停止，仅保留5179静态预览。没有停止其他容器、映射或修改系统信任。已冻结的真实DTO和图像继续用于离线对照；重跑真实测试须按上文重新建环境，不能使用已清理的测试账号或证书。
