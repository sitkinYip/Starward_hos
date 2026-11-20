# 答题 BGM 后台续播验证

日期：2026-11-20。范围为用户仍在答题场次时，将应用挂后台后保留正在播放的 BGM；不增加后台业务同步。

已实现并完成 API 26 直板机隔离验证。普通切后台保留同一播放器和播放位置；未播放完的加载不会在后台新起播。后台仍停止业务同步。

## 实现与官方能力

固定工具链为 DevEco Studio 26.0.0.851、HarmonyOS SDK 26.0.0.105 / API 26、Node 24.14.1、DevEco CLI 1.3.0-stable。已读取实际版本，当前连接一台设备。

采用官方 AVSession 与 AUDIO_PLAYBACK 长时任务。`EntryAbility.backgroundModes` 声明 `audioPlayback`，仅新增 `ohos.permission.KEEP_BACKGROUND_RUNNING`。元数据使用本地品牌封面、“赴星之约”和“答题背景音乐”，不向系统媒体卡片交付题面、玩家资料或媒体 URL。

官方文档经搜索后读取全文，并与固定 SDK 声明及实际编译核对：

- [后台音频场景](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/avsession-background-scene)：音乐后台播放需媒体会话和音频长时任务；暂停/停止及时撤任务，恢复播放重新申请。
- [媒体会话接入](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/avsession-access-scene)：元数据和播放/暂停回调先于激活，会话由成员持有，退出媒体业务销毁。
- [长时任务](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/continuous-task)与[接口](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-resourceschedule-backgroundtaskmanager)：采用 API 21 的 `ContinuousTaskRequest`，`MODE_AUDIO_PLAYBACK` 配 `SUBMODE_NORMAL_NOTIFICATION`，按返回的 taskId 精确取消。`continuousTaskCancel` 自 API 15 可用。

AVSession 基础接口自 API 10 可用，`setBackgroundPlayMode` 自 API 24、Stage 可用，SysCap 为 `Multimedia.AVSession.Core`。长时任务相关 SysCap 为 `ResourceSchedule.BackgroundTaskManager.ContinuousTask`。未使用 26.0.1 新增接口。

平台适配按账号/目的页和播放代次串行管理会话及任务。退出立即作废逻辑资格，迟到创建/申请仍回收。系统主动暂停会同步本地播放开关；系统撤任务只暂停后台资格，不覆盖用户选择。视频期间及用户暂停后，普通后台切换不自动恢复；用户明确操作系统播放键，可以恢复已有的准备完成曲目。

## 逐状态结果

| 检查 | 状态 |
| --- | --- |
| 固定工具链 ArkTS / Hvigor | `scripts/hm.sh run` 构建成功。保留既有 ArkTS 编译警告，不写为零警告。 |
| codelinter | 错误 0、告警 0、建议 1，为既有信纸模糊性能建议。工具 `filesChecked=1`，不扩大为全文件覆盖。 |
| 业务与竞态测试 | 完整 Hypium 299/299，失败 0、忽略 0；新增 9 项会话/任务迟到、暂停竞态、账号切换回收及系统取消测试。 |
| 调试签名、安装及启动 | signed HAP 生成并通过真实覆盖安装、启动。手机已有构建号 6，首个默认构建号 1 被系统以降级拒绝；验证临时使用相同 0.1.4（6），不改变仓库发行版本或提交商店。 |
| 隔离 HTTPS 与媒体 | 新建真实 PocketBase 0.40.1、独立 CA/网关及零经验无奖励场次。11 项主机证书与 MP3/MP4 字节/Range 检查通过；手机使用同一真实媒体读取。 |
| 后台续播与前台返回 | 初轮后台连续 35 秒；最终包另验约 20 秒。同一进程、同一 attempt 持续递增播放位置并循环，回前台无新的 begin/下载。系统 AudioPolicy 的应用渲染器处于运行态。 |
| 暂停与系统继续 | 系统媒体暂停后撤 task，后台保持暂停；显式媒体播放键在后台重新申请 task，并从同一 AVPlayer 续播。 |
| 加载与视频覆盖 | B 曲目延迟 10 秒，开始后立即 Home，旧 attempt 释放且没有 initialized/playing；视频打开先暂停，视频期间后台不恢复 BGM，回前台才按原意图继续。 |
| 离场回收 | 返回首页后播放器 released，taskStop、会话 released；账号及进程停止结果见原生证据。 |

暂停状态首轮使用 `speed=0` 时，系统拒绝媒体状态更新并返回 401；已修为速度保持 1、由 `PLAYBACK_STATE_PAUSE` 表达暂停。最终包真实暂停/恢复没有相同错误。保留早期日志，不计为最终通过依据。

静态审查发现并修正：系统 Stop 释放后的浮标状态、系统撤任务不应持久化为用户关闭音乐。最终独立复查未发现阻塞。将取消回调的 taskId 比较反向后，对应 Hypium 用例真实失败，恢复源码后完整 299 项重新通过。

## 命令与证据

```sh
scripts/hm.sh doctor
scripts/hm.sh run
STARWARD_VALIDATION_DIR=artifacts/validation/bgm-background-20261120/final scripts/hm.sh test
STARWARD_VALIDATION_DIR=artifacts/validation/bgm-background-20261120/final scripts/hm.sh lint
```

真机使用官方 UiTest / DevEco CLI 操作；Home 与媒体键通过官方 `uitest uiInput keyEvent` 发送。原始系统 dump、临时账号、媒体服务和驱动只在 gitignore 的 private 目录。报告仅保留安全摘要及哈希。

[原生结果](../artifacts/validation/bgm-background-20261120/native-background.json) · [Hypium](../artifacts/validation/bgm-background-20261120/final/local-test-summary.json) · [lint](../artifacts/validation/bgm-background-20261120/final/lint.json) · [主机媒体](../artifacts/validation/bgm-background-20261120/host-tls-media.json) · [后台请求](../artifacts/validation/bgm-background-20261120/host-background-polling.json) · [业务影响](../artifacts/validation/bgm-background-20261120/host-impact.json)

本次没有声学录音、真实来电/耳机拔出、长时间锁屏续播、系统主动撤长时任务或双账号真机切换；相关焦点原规则保留，迟到账号与系统取消分支由自动测试覆盖。BackgroundTaskManager 的 hidumper 在该机只返回服务头，不能用它独立证明任务数量；任务以官方成功回执、取消日志、媒体会话及真实音频状态交叉验证。生产写入、商店分发及跨设备专项不在本轮范围。

离场和登出均实测释放；后台播放时强制停止应用后，本应用的进程、AVSession 和音频渲染器消失。系统媒体 Stop 键在此设备实际触发暂停，未独立验收 `AVSession.stop` 回调；该回调保留源码审查覆盖。

已恢复手机的固定隔离预览并真实登录首页，预览服务继续运行。一次性验收后端、网关及临时 DB 已按归属清理，手机未执行新增入场或答题。仓库默认版本号已恢复；预览调试包沿用设备已有的构建号 6。测试 HAP 的哈希和清单在安装后实际采集，随后被官方预览重构建覆盖，原 signed 文件没有另行归档；不将恢复后的 HAP 冒充原测试包。[安装时包记录](../artifacts/validation/bgm-background-20261120/runtime-package-observed.json) · [隔离清理](../artifacts/validation/bgm-background-20261120/host-disposable-cleanup.json)
