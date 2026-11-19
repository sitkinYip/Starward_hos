# 0.1.2（4）邀请候选与提审

0.1.2（4）已完成云签、仅测试渠道上传和合法性检测，并在原「赴星之约」项目及 `com.sitkin.starward` 提交邀请测试，当前为「预审中」。这不代表预审、正式审核、实际分发或生产 Push 已通过。原测试版本未覆盖或撤销；根源码的开发版本号仍为 0.1.0（1），发布版本号只在独立候选副本内设置。

2026-11-19，主任务在原应用的华为控制台现场复核：0.1.1 已处于「测试中」，上架自检通过，不是「预审中」。此前的“草稿待提交”和“预审中”均为旧状态；本次仍需独立核验 0.1.2 新包、邀请状态和生产 Push，不能沿用旧包的合法性或自检结果。

## 当前状态

| 环节 | 本轮证据与状态 |
| --- | --- |
| 发布工具 | 新增参数化验包与源码冻结工具；14 项发布边界测试通过，包含云端构建号添加与其他内容篡改的区分 |
| 既有签名兼容 | 参数化验包工具已对原 0.1.1（3）真实签名包执行官方 SDK 验签，并与 0.1.0（2）的分发身份比对通过；没有生成或更改凭据 |
| 新版源码冻结 | 已在独立私有副本冻结；仅副本设为 0.1.2（4）及 `production-invite-push`，没有复制本机签名配置。13 个本轮运行/测试变更源与最终测试基线哈希一致，214 个 `entry/src` 文件与冻结时工作区一致 |
| 新版构建、测试和 lint | 官方依赖安装、Release 完整 App Pack 构建通过。原生业务测试 255/255 通过、失败及忽略均为 0；副本哈希一致，未重复全量测试。Release lint 为 0 错误、0 警告、1 项既有模糊效果建议；工具报告 `filesChecked=1`，不据此宣称全文件检查数 |
| 新版签名、上传和邀请 | DevEco 官方云签及仅测试渠道上传完成；官方 SDK 验包及与 0.1.1 原发布身份比对通过。平台合法性「已达标」，build 为 1；邀请已提交，控制台显示「0.1.2测试版本 - 预审中」 |
| 通知自分类权益 | 2026-11-19 11:43:36 已提交「订阅」，申请记录为「审核中」；不等于权益获批 |
| 生产部署与 Push | 后端发布已 `recorded`（revision 15），HTTPS 健康 200、同一容器健康检查与零重启通过。发送开关及订阅权益开关关闭，没有正式发送凭据挂载，不能宣称生产 Push 已启用 |
| 本轮真机与隐私 | 保留原 Debug 身份覆盖安装。官方侧载隐私调试配置后仍曾拉起失败；后续已出现真实系统声明，用户自行同意。清除私有诊断代码后再次覆盖安装，同源最终包通过订阅 UI/真实 HTTPS 主验证及冷启。失败根因尚未确定，不能据此宣称正式分发包首次隐私已验收；详见专项记录 |

当前发布证据见 [未签名包检查](../artifacts/validation/push-subscription-20261119/release-unsigned-0.1.2.json)、[原生业务测试](../artifacts/validation/push-subscription-20261119/local-test-summary.json)及 [Release lint](../artifacts/validation/push-subscription-20261119/release-lint-0.1.2.json)。较早的 `release-tools.json` 中 `newCandidateFrozen/newCandidateBuilt=false` 记录的是工具准备阶段，不覆盖上述后续结果。订阅能力和未验边界见 [本轮实现记录](push-subscription-2026-11-19.md)。

私有冻结目录为 `artifacts/private/invite-candidate-0.1.2-jdypcwc3/`，保留 `source-snapshot.json`、完整 `project/`、安装/构建/lint 日志及 `starward-0.1.2-4-unsigned.app`。未签名 App Pack SHA256 为 `bf92ad74b211e38a2d8b8c6f2dd79c641328e45c402b4551236fb66512bf209b`。后续文档更新不回写已冻结副本；发生运行源码变化时需重新冻结和核验。

## 冻结与构建

在业务改动结束、没有其他任务继续写源码时，从原生仓库执行：

```sh
python3 scripts/test-invite-package.py
python3 scripts/prepare-invite-candidate.py --version-name 0.1.2 --version-code 4
```

工具输出本机私有 `project` 目录。它只复制当前 Git 管理及未忽略的源码，包含尚未提交的新源文件，并记录输入哈希；不会复制被忽略的本机签名配置、隔离 HTTPS 配置或私钥。它在副本内设置版本与 `production-invite-push`，使用无凭据的签名样例，不改原工作区。若复制期间源码变化会拒绝本次准备。不要把该目录中的输出或签名配置强制加入 Git。

进入输出的 `project` 目录，安装依赖后使用固定工具链。Release 构建必须选择完整 App Pack，不能用 Debug HAP 替代：

```sh
scripts/hm.sh install
scripts/hm.sh doctor
devecocli build --product default --build-mode release
STARWARD_VALIDATION_DIR=../validation scripts/hm.sh lint
```

业务测试由 `scripts/hm.sh test` 执行。本轮已有真实 255/255 报告，冻结副本按哈希复用该结果；仅变更后重跑相应检查。检查实际 App Pack 产物、版本、零隔离配置及测试报告。只通过这一步不能标记签名、安装、业务或网络验收通过。真机使用独立验收副本及原已批准的 Debug 签名，通过 `scripts/hm.sh run` 安装；不把 Release 副本改成新 Debug 身份，不默认卸载手机上的现有包。

## 云签及验包

延续上一版的官方 DevEco Studio「Build → Upload Product」，使用原应用的同一分发证书，选择仅测试渠道。云签前后分别保留 unsigned 与 re-signed `.app`。[官方上传流程](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/ide-publish-app/)和[软件包管理](https://developer.huawei.com/consumer/cn/doc/app/agc-help-release-app-upload-pkg-0000002277983368/)将上传、合法性检测及测试提交分为不同环节。

回到原生仓库，使用本机真实路径运行；下列路径参数指向实际文件，不是可直接照抄的占位文件：

```sh
python3 scripts/verify-invite-package.py \
  --unsigned-app /absolute/path/to/unsigned.app \
  --signed-app /absolute/path/to/re-signed.app \
  --baseline-app /absolute/path/to/previous-verified-signed.app \
  --version-name 0.1.2 --version-code 4 \
  --output /absolute/path/to/new-verification.json
```

验包使用官方 SDK 验证 App Pack 和 Profile 签名，比对原分发身份、证书、有效期与 Push 能力；同时比较签名前后每个 HAP 文件内容，防止只核对字节码而漏掉资源或配置变化。不会输出应用签名标识、证书内容或私钥。允许复用仍有效的发布 Profile，不以“必须新 UUID”强迫轮换签名。旧版私有验包脚本保持不变。

本轮真实云签给 `module.json` 的 `app.buildVersion` 和 HAP `pack.info` 的 `summary.app.version.build` 各新增字符串 `1`，并重新序列化清单。因此原始 ZIP 条目不是逐字节全同。核对实际添加值后，用 `--cloud-build-version 1` 显式允许这两处从无到相同构建号的添加；其他清单字段、条目集合、资源与编译代码必须一致，任何其他改变仍拒绝。14 项边界测试及真实签名验包通过，见 [签名验包报告](../artifacts/validation/push-subscription-20261119/release-signed-strict-verification.json)。正式签名 App Pack SHA256 为 `ad1c1e12f741c663d8b9b6ec968d9cd365f661a0a1c37748aef13d0d263264b3`。这只证明包和身份，不替代平台检测及邀请提交。

## 分类申请及邀请范围

订阅分类需以实际场次的订阅、取消、默认关闭的推送开关，以及订阅后的独立确认页面提供材料。推送示例应体现订阅关系。未订阅内容、平台公告和运营推广不能借用订阅分类；未获批的分类不会因为代码已支持而获得权益。[官方自分类要求及申请入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-apply-right/)

已在原应用「增长 → 推送服务 → 配置」提交三张同源直板真机截图，分别展示默认关闭、具体场次独立确认、已接收及取消入口。控制台申请记录为「订阅／审核中」，提交时间 2026-11-19 11:43:36；见 [平台事实与原图摘要](../artifacts/validation/push-subscription-20261119/huawei-invitation-platform.json)。只有实际获批后才允许服务端配置启用；保留默认营销分类与生产发送范围的独立控制。

新邀请已选择原「赴星之约首轮单人测试」群组（1 位用户），发送测试通知，不扩大到全网。窗口为 2026-11-19 11:32:32 至 2026-11-30 23:59:59，保留推荐加密和中国大陆手机范围。用户已直接在页面填入专用审核账号及口令，保存成功；未读取口令或将其写入仓库。关联本轮合法性已达标的 0.1.2（4）/ build 1 包及原托管隐私政策后，点击「提交审核」，控制台实际显示「预审中」，见 [平台事实与原图摘要](../artifacts/validation/push-subscription-20261119/huawei-invitation-platform.json)。平台提示预审通过后自动交正式审核；此时没有正式审核通过或可下载结论。

官方也提供基于 Service Account 的 Upload Management API 和 Testing API，但现有 Push 账号不因此自动获得发布权限；本轮不擅自扩大账号权限。[Connect API](https://developer.huawei.com/consumer/cn/doc/App/agc-help-connect-api-introduction-0000002270974725/) · [服务端授权](https://developer.huawei.com/consumer/cn/doc/App/agc-help-connect-api-obtain-server-auth-0000002271134661/)
