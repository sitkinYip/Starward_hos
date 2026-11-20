# 0.1.5（7）邀请测试发布

2026 年 11 月 20 日在华为开发者中心提交「赴星之约」0.1.5（7）构建 1。控制台显示「0.1.5测试版本 - 预审中」。预审通过后由平台自动送应用市场审核，市场审核和实际下载待平台开放。[平台发布回执](../artifacts/validation/release-0.1.5-20261120/receipt.json)

| 项目 | 本次设置 |
| --- | --- |
| 群组 | 赴星之约首轮单人测试，1 组 1 人，已开启测试通知 |
| 时间 | 北京时间 2026-11-20 12:57:24 至 2026-12-20 12:57:24，开始时间取提交前在平台点击「此刻」的时间 |
| 设备与地区 | 手机、中国大陆 |
| 应用归属 | `com.sitkin.starward`，原应用发布签名和托管隐私声明 |
| 上传渠道 | AppGallery Connect「仅测试」，平台合法性已达标，上架自检显示未检测 |

## 本次更新

- `0aa690c` 支持答题配乐在系统后台继续播放。
- `62ca6a1` 优化开启、继续和重温旅程时的加载及失败重试提示。
- `da0444e` 接入鸿蒙密码保险箱，登录成功后可由系统保存并在下次回填账号密码。

## 构建与校验

候选从干净的 `da0444e6c06368cd65a50f2f1b91a15901a60248` 冻结。223 项 `entry/src` 源码及资源与提交逐文件一致，版本号和正式邀请模式在私有构建副本配置。使用 DevEco Studio 26.0.0.851、SDK 26.0.0.105（API 26）、捆绑 Node v24.14.1、ohpm 26.0.0.630 和 DevEco CLI 1.3.0-stable。

```sh
python3 scripts/test-invite-package.py
python3 scripts/prepare-invite-candidate.py --version-name 0.1.5 --version-code 7
# 在冻结副本运行
scripts/hm.sh install
DEVECO_CLI_STUDIO_PATH=/Applications/DevEco-Studio.app devecocli build --product default --build-mode release
STARWARD_VALIDATION_DIR=../release-validation scripts/hm.sh test
STARWARD_VALIDATION_DIR=../release-validation scripts/hm.sh lint
```

发布工具 14 项、候选 Hypium 300 项通过，codelinter 0 错误、0 警告、1 项既有信纸模糊性能建议。Release 编译有 39 条 ArkTS 警告，其中包括设备能力、异常处理、状态监听和 3 条重复组件 ID 提示。原始构建及测试报告位于 `artifacts/private/invite-candidate-0.1.5-g32w0gn9`。

DevEco Studio「构建 → 上传产品」选择「仅测试」。SDK 验证签名及有效发布 Profile，发布身份与 0.1.4 一致且含 Push 能力。签名前后仅两处清单增加平台构建号 `1`，其他资源和 ArkTS 载荷一致。平台在北京时间 12:53:58 收到软件包，随后显示合法性已达标。草稿使用已有审核账号配置，回执省略其内容。
