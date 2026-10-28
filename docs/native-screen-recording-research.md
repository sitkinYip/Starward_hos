# 官方真机录屏能力调研

核验日期：2026-10-27。范围：当前 API26 工具链、官方应用调试文档及 DevEco Testing 文档；仅主机只读查询，未执行设备命令、启动录制、修改应用或系统配置。

## 结论与限制

官方明确提供 HDC 调用系统录屏服务的开始、停止和导出流程，不需要自造 `screenrecord` 命令，也不需要经过 DevEco Studio 设备投屏。官方同时提供 Studio Log 面板和 DevEco Testing 投屏工具的录制入口。

**无音采集仍未证实。** 以下命令对应的官方调试文档没有说明默认是否采集系统音频、是否采集麦克风、是否沿用用户录屏偏好，也没有列出禁用两类音频的参数。因此不能把它标为满足“不得采集环境麦克风、不得改用户全局录音偏好”的已验证方案。本次没有尝试启动来猜测默认行为，也不补造 `--pb` 或其他音频参数。事后删除音轨不能证明采集阶段未使用麦克风。

官方调试文档也未承诺命令启动在所有设备上均无授权弹窗，未说明可将录制限制在指定 App，未说明系统通知横幅的过滤策略；因此“不弹授权窗”和“不会录到私人通知”亦不能由该文档推定。录屏调查及 CLI 语法核准不等于实际录制通过。

## 官方全文来源

以下均先使用 `devecocli docs search` 检索，再使用 `docs read` 读取全文。

| 来源 | 精确 documentId | 核准内容 |
| --- | --- | --- |
| 录屏 | `开发指南/应用调试/录屏/ide-screen-recording` | Studio Log 录屏；HDC 系统服务开始/停止；按指定文件名查询、复制与导出；真机保持解锁；模拟器不支持 |
| DevEco Testing 导出截图/录屏 | `FAQ/实用工具/设备投屏/如何通过DevEco_Testing将故障截图_录屏导出到电脑上/faqs-utilities-cast-5` | 实用工具→设备投屏→开始投屏→屏幕录制→结束录屏；保存位置见执行日志 |
| AVScreenCaptureRecorder 录屏写文件 | `开发指南/Media_Kit_媒体服务/媒体开发指导_ArkTS/录制/使用AVScreenCaptureRecorder录屏写文件_ArkTS/using-avscreencapture-arkts` | 应用录屏 API 可涉及系统音与麦克风；麦克风需要对应权限；PC/2in1 免隐私告警权限是受限能力，不能套用为本手机命令的免弹窗依据 |

重读主流程全文：

```sh
devecocli docs read '开发指南/应用调试/录屏/ide-screen-recording'
```

官方网页入口为 [录屏](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-screen-recording) 和 [AVScreenCaptureRecorder](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/using-avscreencapture-arkts)。本次网页请求超时，结论依据官方 CLI 已成功返回的全文，不声称网页另有独立核验。

## 已核准的命令流程

以下记录官方语法，**不是已执行命令或无音录屏批准**。示例使用独立文件名，避免扫描或导出其他媒体。多设备时使用官方 `hdc -t <目标>` 选择目标；真实设备标识不写入文档。

1. 真机运行测试 App，屏幕已经解锁；录制期间必须保持解锁。开始录制：

   ```sh
   hdc shell aa start -b com.huawei.hmos.screenrecorder -a com.huawei.hmos.screenrecorder.ServiceExtAbility --ps "CustomizedFileName" "starward-ui-motion-20261027-001.mp4"
   ```

2. 完成短流程后，官方给出的停止命令是同服务、不附文件名参数：

   ```sh
   hdc shell aa start -b com.huawei.hmos.screenrecorder -a com.huawei.hmos.screenrecorder.ServiceExtAbility
   ```

   文档没有给出此命令在“未成功开始录制”状态下的幂等保证；不要将它写成开始失败后仍无条件执行的清理步骤，也不要将 `aa start` 返回成功直接当成视频存在。

3. 仅按本次唯一文件名查询录制结果：

   ```sh
   hdc shell mediatool query starward-ui-motion-20261027-001.mp4 -u
   ```

4. 若结果包含 `uri` 字段，官方说明直接返回的媒体路径不能直接下载。将**实际返回的精确 URI**交给 `mediatool recv`，复制至可下载位置；不能照抄文档样例媒体编号：

   ```sh
   hdc shell mediatool recv '<实际返回的媒体URI>' /data/local/tmp
   ```

   此命令返回值第二行为后续使用的录屏路径。若查询结果不含 `uri`，官方说明查询返回值第二行即该路径。两种情况都应解析实际输出，不能硬编码媒体库路径。

5. 使用上一步取得的精确路径导出：

   ```sh
   hdc file recv '<实际返回的录屏路径>' artifacts/native-system-visual/starward-ui-motion-20261027-001.mp4
   ```

后续若取得满足无音前提的明确依据并实际执行，报告仍应分别记录开始/停止响应、指定文件命中、导出成功、文件可解码、尺寸/时长/帧率、音轨情况、原始文件 SHA-256 和实际观察到的 Sheet/Tab/Refresh 动效。当前均未执行，不能填为通过。

## 本机工具与其他入口

- `devecocli --version`：`1.3.0-stable`。`devecocli ui --help` 仅列截图、布局、窗口、点击与手势等能力，没有录屏子命令。
- 固定 SDK HDC：`/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc`，本机 `version` 返回 `3.2.0f`。主机 `help` 核准了 `-t`、`shell` 和 `file recv`，没有独立 `screenrecord` 主机命令。
- 本机已安装 DevEco Studio 和 `/Applications/DevEco_Testing_for_App.app`；本次未启动或控制它们。
- Studio 官方入口：连接真机并运行 App→底部 **Log**→左侧录屏工具→选择保存位置→**Start Recording**→**Stop Recording**。自定义默认保存目录位于 **HiLog > Settings > Record Screen**。它是独立于设备投屏面板的入口，之前投屏未成功不能证明该入口不可用。
- Testing 官方入口：**实用工具→设备投屏→开始投屏→屏幕录制/结束录屏**；输出路径见执行日志。文档没有给出该录制入口的无音保证。

没有执行 `param set`、更改系统录音偏好、重启 HDC、杀死 UiTest、读取通知或遍历个人媒体。测试工具关于切换投屏模式的排障命令不属于本方案。
