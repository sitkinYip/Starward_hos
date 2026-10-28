# 本机原生构建与测试入口核验

核验日期：2026-10-27。本文是工程创建前的工具与模板核验，不代表应用已经构建、签名或通过测试。实际执行结果以 `docs/toolchain-and-tools.md` 或首切片验收记录为准。

## 官方本机输入

- IDE：`/Applications/DevEco-Studio.app/Contents`。
- 工程模板：`plugins/openharmony/lib/templates/project/New Project/code template/`。
- 模块模板：`plugins/openharmony/lib/templates/module/New Module/code template/`。
- Empty Ability：`plugins/openharmony/lib/templates/ability/Empty Ability/code template/`。
- 工程配置 schema：`tools/hvigor/hvigor-ohos-plugin/res/schemas/ohos-project-build-profile-schema.json`。
- 模块配置 schema：同目录 `ohos-module-build-profile-schema.json`。

工程级 `hvigorfile.ts` 导入 `appTasks`；HAP 模块导入 `hapTasks`，来源都是 `@ohos/hvigor-ohos-plugin`。二者导出 `{ system: appTasks/hapTasks, plugins: [] }`。工程 `build-profile.json5` 负责 products、SDK、runtimeOS、签名与 modules；模块文件负责 `apiType: stageMode`、buildOption、targets。模板中的 `signingConfig: default` 不能证明签名材料存在。

SDK 安装元数据为 HarmonyOS 26.0.0 Release / API26 / 26.0.0.105。商业 HarmonyOS 工程使用 `runtimeOS: HarmonyOS`；SDK 字符串应与工程生成器结果和真实编译器核验。不要因为 SDK 内含 `openharmony` 目录改为 OpenHarmony 目标。

## 命令入口

以下命令应在本项目根目录执行，构建脚本统一使用 IDE 配套运行时。

```sh
export NODE_HOME=/Applications/DevEco-Studio.app/Contents/tools/node
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
export PATH="$NODE_HOME/bin:$PATH"
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw --version
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw --mode module -p product=default -p module=entry@default -p buildMode=debug assembleHap --no-daemon
```

`DEVECO_SDK_HOME` 由内置插件的 `src/sdk/lib/property-get.js` 支持。Hvigor 的 `--help` 已实际执行；上面的 `assembleHap` 仍需有工程后真实执行确认。无签名材料时保留 unsigned HAP 构建验证，不把它算成安装验证。

已安装 CLI 的 `--help` 确认以下入口（本次未使用它们写工程或签名）：

```sh
devecocli create --project-path <new-directory> --app-name Starward --bundle-name com.sitkin.starward --api-level 26
devecocli build --product default --modules entry --build-mode debug
devecocli signature generate --help
```

`create` 的现有目录覆盖行为须在新临时目录中核验，避免覆盖本项目已有 docs 和配置。签名生成属于独立步骤，可能要求华为开发者账号，不应复制其他应用的签名配置。

## Local Test / Hypium

实际读取了 CLI 自带官方文档：

```sh
devecocli docs read '开发指南/开发自测试/测试框架/代码测试/Local_Test/ide-local-test'
devecocli docs read 'FAQ/应用测试/使用命令行执行单元测试脚本常见问题和解决方案/faqs-app-test-26'
```

[官方 Local Test 指南](https://developer.huawei.com/consumer/cn/doc/doccenter-deveco-studio/ide-local-test)明确支持 Stage 模型 ArkTS，不能测试系统 API 或 C/C++。测试位于模块 `src/test/`，手写测试要在 `List.test.ets` 引用。

```sh
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw test -p module=entry -p coverage=false --no-daemon
```

可用 `-p scope=SuiteName#methodName` 或 `-p scope=SuiteName` 限定用例；多个值用英文逗号隔开。API26 文档还支持绝对路径 `.patch/.diff` 的 `-p patch=<path>`。此入口会使用 SDK `previewer/common/bin/Previewer`，不是 Node 替代执行 ArkTS。

必须读取以下真实结果，并核验用例数和失败数：

- `entry/.test/default/intermediates/test/coverage_data/test_result.txt`。
- 启用覆盖率时：`entry/.test/default/outputs/test/reports/index.html`、`coverageReport.json`。
- Previewer 原始日志：`entry/.test/default/intermediates/test/coverage_data/coverage.log`。

只有构建退出码为 0、没有上述结果或用例数为 0 时，不能标记单测通过。脚本必须使用正确 cwd 和上述环境；官方 FAQ 明确把脚本环境变量和 cwd 缺失列为 Local Test 不执行的原因。

## Instrument Test / UiTest 与设备

本次 `hdc list targets` 的只读查询识别到 1 台设备，未记录标识。设备 API、签名可用性仍由实际验证记录确认。未发现家目录 `.ohos/` 签名目录，这不能排除 IDE 或其他安全位置保存账号材料；不能据此宣称已具备调试签名。

官方 FAQ 要求先安装应用 HAP 与 `ohosTest` HAP，再执行测试 runner，例如：

```sh
hdc install <entry-default-signed.hap>
hdc install <entry-ohosTest-signed.hap>
hdc shell aa test -b com.sitkin.starward -m entry_test -s unittest OpenHarmonyTestRunner -s timeout 15000
```

`entry_test` 与 runner 名称必须与最终测试模块生成结果一致。只有安装、启动、测试报告、日志和截图齐全后，才算打通真机验收；Local Test 不能替代 ArkUI UI 验证。
