# 生产 HTTPS 只读联调

生产联调包固定使用 `https://api.sitkin.top`，与正式 Web 的游戏 API 相同。通过官方 DevEco 构建并调试签名，用直板真机走生产网络。当前包名仍是开发身份，签名产物用于联调。正式发行身份和生产写入按各自验收范围推进。[架构决策](architecture-decisions.md#adr-028生产-https-的只读联调包)

```sh
export STARWARD_VALIDATION_DIR=artifacts/validation/production-smoke-20261117
scripts/hm.sh test
scripts/hm.sh lint
python3 -B scripts/build-production-smoke.py --install
```

构建助手在安装前校验并归档实际签名 HAP。安装使用该产物，隔离配置和隔离 CA 在安装前恢复为原字节。省略 `--install` 可单独构建和归档。装回原预览时使用保留的已签名预览产物，或以原预览配置重新运行 `scripts/hm.sh run`。两个环境的会话由各自的端点和 CA 隔离。[打包和安装记录](../artifacts/validation/production-smoke-20261117/candidate.json)

只读联调只放行游戏 API 的 GET、密码登录和头像文件临时令牌。业务写入和其他 origin 在请求到达网络之前拦截。Hypium 225 项全部通过，新增用例覆盖这两类边界。codelinter 无错误和警告，既有信纸模糊性能建议保留。[业务测试](../artifacts/validation/production-smoke-20261117/local-test-summary.json) · [代码检查](../artifacts/validation/production-smoke-20261117/lint.json)

真机已显示「生产联调 · 只读」。手机连接 Wi-Fi 时，原生进程用系统证书校验向生产 `/me` 发出无凭据请求，记录到 HTTP 401。这一项验证生产 HTTPS 和匿名鉴权入口。首次只读 UI 采集器的按 ID 过滤未拿到应用节点，独立重启并使用可见树后才取得完整记录。台式机公网请求遇到办公机域名策略，与手机证据分开。[真机生产连通性](../artifacts/validation/production-smoke-20261117/prelogin-02.json) · [首轮未通过采集](../artifacts/validation/production-smoke-20261117/prelogin-01.json)

专用玩家完成 Web 首次改密后，使用同一个签名包在手机 Wi-Fi 下手动登录。真机同时观察到登录、`/me`、场次列表的 200。点开用户指定的「清宫那点事」卡片，授权详情新请求返回 200，说明页仍在入场前、已完成题数为零。只操作卡片跳转和系统返回。两次初步驱动未观测到跳转，改用官方 HDC 点击后取得完整证据。[生产登录和列表](../artifacts/validation/production-smoke-20261117/production-session-wifi-01.json) · [场次详情](../artifacts/validation/production-smoke-20261117/production-detail-wifi-03.json)

返回首页后结束该进程并冷启动，新进程通过保存的生产会话重新读取 `/me` 和场次列表，直接恢复首页，全程未再提交密码登录。此专用玩家没有可用于验证的头像，临时文件令牌和受保护文件留待有数据时检查。测试机没有 SIM 卡，用户安排在个人手机上另验蜂窝网络。[Wi-Fi 冷启动续登](../artifacts/validation/production-smoke-20261117/production-cold-wifi-01.json) · [逐状态验收](feature-acceptance-matrix.md#p01-公网生产-https-登录与只读联调)

Wi-Fi 验收结束后退出生产专用玩家，重启同一生产包回到登录。装回固定隔离预览后，隔离 HTTPS 校验通过，原固定账号无需重新输入凭据即回到启程。生产联调 HAP 单独保留。[退出后冷启动](../artifacts/validation/production-smoke-20261117/production-after-logout-01.json) · [固定预览恢复](../artifacts/validation/production-smoke-20261117/fixed-preview-restored.json)
