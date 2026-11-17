# 首版生产写入候选

0.1.0 生产写入候选使用现有 `com.sitkin.starward` 开发身份和官方调试签名。真实写入验收使用一位明确指定的生产测试玩家和用户为该玩家指定的测试场次「清宫那点事 V2」。此前只读验收的线上登录、续登和详情结果仍独立有效。[只读联调](production-https-smoke-2026-11-17.md) · [逐状态验收](feature-acceptance-matrix.md#p02-首版生产候选与真实答题闭环)

```sh
export STARWARD_VALIDATION_DIR=artifacts/validation/production-candidate-20261117
scripts/hm.sh test
scripts/hm.sh lint
python3 -B scripts/build-production-smoke.py --write --install
```

候选 HAP 已检查 `production-write` 标记、无隔离配置和私有 CA，安装后真机显示「生产测试候选」和登录入口。生产 HTTPS 固定绑定正式域名，沿用系统证书校验。两项原有只读边界和新增的生产写入同源校验有实际测试，Hypium 226 项全部通过，codelinter 无错误和警告。[候选 HAP 回执](../artifacts/validation/production-candidate-20261117/candidate.json) · [真机登录入口](../artifacts/validation/production-candidate-20261117/device-ready.json) · [业务测试](../artifacts/validation/production-candidate-20261117/local-test-summary.json) · [代码检查](../artifacts/validation/production-candidate-20261117/lint.json)

专用玩家在手机上登录，原生以 Wi-Fi 重新读取生产玩家和场次列表。指定场次有 6 道填空题，每题配置 20 EXP。先打开原生入场说明，核对场次详情回源、初始 0/6，并记录答题前的总经验。[登录后读回](../artifacts/validation/production-candidate-20261117/production-ready-auth-01.json) · [入场前基线](../artifacts/validation/production-candidate-20261117/v2-baseline-01.json)

同一签名包在直板真机上收到 1 次入场和 6 次答题的生产 HTTP 200。生产后台记录 6/6、6 条答题记录，全部答对。V2 的配置无发奖规则。返回首页重新读取场次列表和玩家资料后，「旅途回响」为 6/6，总经验增加 120 EXP。再次点开同一场次，确认完成状态可回访，没有新增入场或答题请求。后台进度页可核对答题记录，实际经验增量以玩家资料回源为准。[真机写入及回访](../artifacts/validation/production-candidate-20261117/v2-production-write-01.json) · [生产后台只读对账](../artifacts/validation/production-candidate-20261117/v2-production-admin-observation-01.json)

结束进程后冷启动同一签名包，无需输入密码，生产玩家、列表和详情回源成功。再次回访仍为 6/6、经验增量 120 EXP，未发送写入。随后退出生产专用玩家，用官方 DevEco 装回原固定隔离预览包，冷启恢复预览会话，隔离 HTTPS 校验通过。[生产冷启回访](../artifacts/validation/production-candidate-20261117/v2-production-cold-01.json) · [生产退出](../artifacts/validation/production-candidate-20261117/v2-production-logout-01.json) · [固定预览恢复](../artifacts/validation/production-candidate-20261117/v2-preview-restored-01.json)

当前签名用于已登记设备调试。正式包需先核对包名与 AGC 归属，并使用匹配的发布证书和 Profile 构建 `.app`。受邀范围与实际分发进度另记。[华为发布签名说明](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-hmos-publish-app/) · [邀请测试渠道](https://developer.huawei.com/consumer/cn/doc/app/agc-help-invite-test-overview-0000002287701773/)
