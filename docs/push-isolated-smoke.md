# 直板机 Push 隔离联调

`scripts/prepare-push-smoke.mjs` 单独启动 PocketBase 0.40.1、临时数据库和带专用 CA 的本机 HTTPS。它与固定预览账号和生产完全分开。合成玩家、场次、来信和公告都是这次运行生成的。HTTPS 仅转发登录、只读业务和 Push 绑定／解绑；控制端只能通过当前用户可访问的 Unix socket 创建测试事件。脚本不会修改打包配置、安装应用或设置 HDC。

从原生项目目录运行，保证同级 `sitkin-pb-backend-management` 包含本轮 Push 改动，Docker 已在运行且本机有 `questions-pocketbase:starward-push-crypto-test`（ARM64、PocketBase 0.40.1 和 OpenSSL）：

```sh
# 先启动无华为凭据的本地联调：可以验证注册和入队，不能发送到华为。
node scripts/prepare-push-smoke.mjs serve

# 实际云送测才使用这一条。需要同项目的 ID 和仅供本轮测试的服务账号。
node scripts/prepare-push-smoke.mjs serve --live-test PROJECT_ID /absolute/path/to/service-account.json
```

后一条要求正式 AppGallery Connect 项目已启用 Push Kit、`com.sitkin.starward` 的分发状态及签名符合要求。填写项目 ID，不填应用 ID。服务账号文件应在源码目录之外，使用本人所有的实际绝对路径、权限 `0600` 或 `0400`，由 Docker 只读挂载。不要复制到原生应用、构建产物或报告。实际送测依旧仅允许本次随机生成的专用玩家，并发送 `testMessage:true`；没有绑定或显式测试事件时不会发送。

1. 保持启动进程运行。输出的 `hostHttpsPort`、`publicCaPath` 和 CA 哈希属于本次临时 HTTPS。先验证 `curl --cacert <publicCaPath> https://127.0.0.1:<hostHttpsPort>/api/health` 为 HTTP 200；去掉 `--cacert` 后应被拒绝。`loginFile` 只在本机打开，直接把合成凭据输入测试机。
2. 确认一台已授权直板手机，用 `hdc list targets` 和 `hdc fport ls` 检查连接及端口归属。只有手机端 18443 空闲或已走过固定预览的停用交接流程时，才用 `hdc rport tcp:18443 tcp:<hostHttpsPort>` 建立并复查映射。避免占用或删除其他运行的映射。
3. 在独立的原生构建副本中运行 `python3 scripts/configure-integration.py --push-test --endpoint https://127.0.0.1:18443 --ca <publicCaPath>`。从原仓库运行 `python3 scripts/configure-push-debug-privacy.py <隔离构建副本> <已批准的隐私声明HTTPS地址>`，按华为文档补齐侧载调试包的隐私声明元数据，正式 manifest 不变。按仓库中固定的 DevEco 工具及签名流程进行 Debug 构建并安装。包名须仍为 `com.sitkin.starward`，系统信任库保持原状。首次启动同意隐私，登录合成玩家，开启系统通知，并确认 `status` 里恰有一个绑定。[未上架应用的官方调试方法](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/store-privacy/)
4. 第一条优先用新场次检查后台通知和冷启动点击，核对点击后才回源看到目标场次，保持「待入场」。第二条用来信或公告检查已运行应用的通知点击，核对收件箱和未读状态。读取 `status` 中的 `providerCode` 区分请求接受与实际显示；只有手机实际收到并打开正确页面才算送达验证。第三种可在另一测试日验证，以免与 `MARKETING` 的设备频控相混。点击过程中不要入场、答题或点已读，之后核对三项计数。
5. 退出测试玩家并确认绑定清除；验证旧通知不能打开已退出账号的内容。先卸载实验包或恢复原候选包、移除本轮独有的反向映射（`hdc fport rm tcp:18443 tcp:<hostHttpsPort>`），再停止隔离服务。停止后脚本清理数据库、临时登录凭据及 TLS 私钥，保留公共证书。AGC 服务账号密钥仍由其所有者保管或停用。

对另一个终端使用本轮输出的 `privateRunDirectory`：

```sh
node scripts/prepare-push-smoke.mjs status RUN_DIR
node scripts/prepare-push-smoke.mjs trigger RUN_DIR assignment
node scripts/prepare-push-smoke.mjs trigger RUN_DIR letter
node scripts/prepare-push-smoke.mjs trigger RUN_DIR announcement
node scripts/prepare-push-smoke.mjs stop RUN_DIR
```

每类事件同一运行只能触发一次。若触发响应未确认，先读取状态确认是否入队。未提供 AGC 凭据的本机验证已覆盖 TLS 信任与错误主机名拒绝、合成玩家登录、绑定及凭据解绑、三类事件生成对应的本地发送记录，以及禁止入场、答题、标已读和管理访问。实际华为项目鉴权、系统通知和点击仍须按以上步骤在专用设备验收。
