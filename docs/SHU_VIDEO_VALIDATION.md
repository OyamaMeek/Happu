# Shu 视频服务验收

媒体Task2延续完整复刻目标；视频和音频的真实操作页面属于Task4，动图属于Task3，本记录不代表完整复刻完成。

## 当前实现

- VideoService提供MP4/MOV/M4V/3GP转换、高/中/低质量、原质量、移除全部音轨和秒数剪辑。保持显示方向、可表达的音轨和统一时间线，3GP多音轨要求明确选择。
- 高/中/低最长边为1920/1280/640，视频目标码率8/4/1Mbps、音频AAC192kbps，不放大输入。原质量通过实际保留轨道的原生兼容性判断决定直通；不兼容时H.264/AAC转码，兼容输入由压缩帧字节比较验证。
- 唯一暂存目录、真实媒体进度、取消检查与清理，复用MediaWorkspace/FileStore发布。同名自动编号，原文件保持完整。
- 发布前重读尺寸、时长、轨道数/参数、各音轨样本时间范围及前导静音，并检查视频内容范围首尾帧的实际解码时间。

兼容性采用Apple的[AVAssetExportSession资源兼容性接口](https://developer.apple.com/documentation/avfoundation/avassetexportsession/determinecompatibility%28ofexportpreset%3Awith%3Aoutputfiletype%3Acompletionhandler%3A%29)，容器支持列表不能代替具体资源的兼容性判断。

## 已取得的证据

| 检查 | 真实结果与记录 |
|---|---|
| 初始行为RED | video-red4.log / session93405，成功编译后正常转换因服务尚未实现退出1 |
| 不兼容原质量RED/GREEN | video-complete3.log /23571退出1，ProRes转换被拒绝；video-complete4.log /37910退出0 |
| 发布边界取消RED/GREEN | video-publish-red.log /63724退出1，100%进度取消仍发布；video-review-green1.log /24701退出0 |
| 最终Mac视频 | video-final-mjpeg-mac.log /87522退出0；13项主要操作，另含大尺寸、延迟短音轨、多轨、非零视频时间线、ProRes→MP4/MotionJPEG→3GP及路径/权限/同名/取消清理检查 |
| 既有服务回归 | video-audio-regression.log /59157：完整33项与全部边界退出0；video-image-regression.log /36862、video-archive-regression.log /70786退出0 |
| Device构建 | video-pcm-device.log /28603退出0，仅证明编译 |
| 普通签名Simulator测试构建 | video-mjpeg-testing-build.log /69813退出0，TEST BUILD SUCCEEDED；资源字节比较一致 |
| 最终iOS运行 | video-runtime-mjpeg.log /76484退出0；VideoRuntimeMJPEG.xcresult为1通过/0失败/0跳过，arm64 iOS27.0，方法215.559秒，内部13/13及全部extended/boundaries通过 |
| iOS首次运行 | /64708以TERM结束退出143，VideoRuntimeAttempt1.xcresult保留；音频方法33项通过，视频方法停在AVAssetReader音频初始化锁，无通过结论 |
| 源PCM参数实验 | video-pcm-testing-build.log /2387、video-pcm-mac.log /18991、video-pcm-device.log /28603退出0；iOS /97875自然退出65，13项主要操作已通过，方法随后因ProRes夹具编码器不存在失败 |

所有日志与xcresult位于忽略的DerivedData目录。没有读取XCTest视觉附件或截图。编译日志保留AVFoundation弃用提示和AppIntents系统提示，不能宣称无警告。

首次iOS等待证据：video-runtime-sample.txt显示AVAssetReader.startReading进入FigAudioQueueRenderPipeline与系统音频队列锁，应用CPU低且output.mp4为零字节。只结束本任务xcodebuild PID26029，关闭并重新启动专用模拟器一次，不重启系统服务、不清除数据或弱化测试。

重启后/2034先在测试夹具的Metal设备初始化等待，夹具完成后再次进入AVAssetReader音频锁；精确TERM自有PID26891退出143。两次中断包缺Info.plist，xcresulttool无法汇总，不构成有效结构化通过结果。随后仅补齐PCM源采样率、声道数和字节序，Mac全套再次通过；iOS自然等待系统HAL超时后完成13项主要操作，在ProRes测试夹具生成时失败。其结构化结果为1方法、0通过、1失败、0跳过，并包含原生调用的QoS运行警告。Mac与iOS都曾等待HAL设备调用，宿主默认设备为Apple Virtual Sound Device；不能将PCM配置变更宣称为已确认的环境修复。

## 不兼容原质量测试样本

`Tests/fixtures/video-mjpeg.mov`由VideoChecks.fixture在macOS原生AVAssetWriter生成，128×128、10fps、30帧、3秒、MotionJPEG，无音频，含同一空间与时间颜色标记；28839字节，SHA256为`7644645683f815b801665f2d7575efcc392490dc6a65e2ecf1e44cd11f432c98`。它仅打包进XCTest资源；iOS复制到独立工作目录后检查真实源codec、原生3GP直通不兼容、实际输出H.264及帧内容。Mac保留ProRes→MP4用例，并检查同一MotionJPEG→3GP用例。

ProRes夹具编码/97875失败后，真实ProRes输入/40769仍因Simulator缺少解码器-12906自然退出65，summary1/0/1/0；产品正确抛出原生不支持错误。原生JPEG兼容性probe/44006确认MP4可直通、3GP不可直通。MotionJPEG夹具生成/66940与签名build/69813退出0，完整Mac/87522及iOS/76484均退出0。此平台输入调整保留不兼容原质量断言；增加28839字节固定测试资源，Mac仍实际生成并验证ProRes。

## 独立审查与边界

- video_review逐行初审：无已确认Critical，R1短剪辑音频检查与R2发布前轨道时间校验需要补强。已补充动态采样窗口、跨信号边界剪辑和完整重读范围校验，最终Mac通过；没有把补充防御校验冒充新发现的编码错误。
- M1：方向测试的绝对亮度差未验证有向关系，保留到媒体整体验收。现有方向/尺寸、源帧内容及直通字节检查仍保留。
- 原质量兼容性依据实际保留轨道，系统判定可直通后保持全部选中编码。同名规则沿用现有自动编号；使用返回的实际URL定位产物。
- 真机codec、iOS18/26运行、页面交互与视觉未验证。原生单次解码或finishWriting期间取消可能延迟，操作结束后仍检查取消且不发布。
- iOS结果包保留两条原生音频初始化的QoS等待警告及HAL设备代理诊断，不能声称无运行警告或已修复宿主虚拟音频设备。系统初始化完成后全部功能断言通过。

## 复现入口

Mac执行`swift run --scratch-path DerivedData/MediaPackage VideoSmoke <全新项目内目录>`。iOS执行共享Happu scheme的build-for-testing，再在专用模拟器运行HappuRuntimeTests/MediaRuntimeTests；运行完读取xcresulttool test-results summary，不以编译代替方法通过。
