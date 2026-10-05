# 媒体功能与编码能力核查

核查时间：2026-10-01至2026-10-03。音频Task1服务已实现，Mac及iOS Simulator运行验证和独立规格/质量审查通过，提交759d1bd已推送。音频UI、视频、动图及LivePhoto任务尚未完成；完整复刻仍未完成。

## 原版可证实需求

- 原版 `guide.webarchive` 确认视频格式“mp4, mov, m4v, 3pg”互相转换。最后一项暂按标准 3GP 容器理解，后续需与原版操作证据核对。
- 原版指南确认音频 M4A、WAV、MP3、CAF、FLAC 转换；视频转动图/实况照片、音频提取、视频质量压缩及 LivePhoto 批量导入导出。
- 中文字符串包含 `file.convert.video`、`file.compress.video` 的高/中/低质量、`file.extract.audio`、`file.remove.audio`、`public.trim.video`（区间剪辑）。
- 动图设置包含帧率、全彩/彩色/灰度/黑白及原画/最佳/极高/高/中/低质量。不能仅提供一个固定参数的 GIF 操作便宣称这些设置已完成。

## 原生能力的实际证据

- `AudioFormatGetProperty(kAudioFormatProperty_EncodeFormatIDs, ...)` 是编码器查询接口；音频格式常量本身不证明编码器存在。[Apple 格式属性](https://developer.apple.com/documentation/audiotoolbox/kaudioformatproperty_encodeformatids)
- 本机 macOS 受限环境仅返回 alaw/lpcm/ulaw；以获准权限复核后返回 AAC、ALAC、FLAC、PCM 等编码器，仍不包含 MP3。两次查询均返回 noErr，因此不能只依据查询退出状态忽略权限造成的能力缺失。
- 项目内临时探测程序 `DerivedData/MediaCapabilityProbe.swift` 使用 AVAssetWriter 实际写出三帧 64×64 H.264 视频，并通过 AVURLAsset 重读视频轨道与时长。macOS 上 MP4/MOV/M4V/3GP 四种容器均读回一条视频轨道、0.3 秒，文件分别为 998/1130/1002/994 字节。命令 `DerivedData/MediaCapabilityProbe` 获准权限执行退出 0；这验证短视频写读，不能替代视频转换、声音、方向、剪辑或取消验收。
- 初次无扩展名探测文件写出成功，但 AVURLAsset 读回报 -11828/-12847；`file` 能识别实际容器。采用对应格式扩展名后读回通过。后续产物必须使用正确扩展名并重读核对，不能以 writer completed 单独判定成功。
- SDK 27 的 macOS 编译显示旧 AVAssetWriter 输入 API 弃用提示，运行显示 AppleM2ScalerParavirtDriver 诊断；没有将输出记为无警告。后续 iOS 18 兼容实现需要明确 API 可用性范围。
- 同一探测程序已针对 arm64 iOS Simulator、iOS 18 目标编译通过；直接 simctl spawn 未返回有效输出，已终止自建探测进程，退出 143。未证明 iOS 的运行时编码能力，不重复同样探测；后续在应用或实际测试执行路径验证。

## MP3 依赖核查

MP3 输出需要实际编码器。已读取 LAME 的 Apple SwiftPM 固定版本 manifest：`BB9z/LAME-xcframework` 3.100.3 提供 LAME binary target，声明 macOS 10.13+、iOS 12+。[固定版本 Package.swift](https://github.com/BB9z/LAME-xcframework/blob/3.100.3/Package.swift)、[项目说明](https://github.com/BB9z/LAME-xcframework)

只读 `git ls-remote` 退出0，tag对应 `3f906714cf8a8cf2a82a8cf5bc760e639febf7b2`；manifest下载校验和为 `bcc33a8311c80993a06d363a29f631d74420cf954be8e8ee9e13450a525944ab`。

- 隔离SwiftPM解析下载session43904退出0，完整日志`DerivedData/media-dependency-resolve.log`保留上游watchOS最低版本弃用提示；未修改产品Package或Xcode注册。
- 实际artifact的Info.plist用plistlib读取：iOS arm64、模拟器arm64/x86_64、macOS arm64/x86_64存在。公开lame.h含初始化、输入/输出采样率设置、分块浮点编码、flush、标签获取和关闭API，modulemap导出LAME；LICENSE及LICENSE-LAME已读取并保留。
- 隔离初始化/关闭探测session72251编译成功，实际启动退出134，`DerivedData/media-dependency-link.log`记录dyld无法加载`@rpath/LAME.framework/Versions/A/LAME`。otool确认可执行文件仅有Swift系统rpath，而实际框架已复制到同一products目录。该结果证明运行路径缺失，未触达编码，不计行为RED；音频Task1需验证持久Package运行路径和iOS框架嵌入。

包下载、头文件、构建成功均不能证明产品编码运行通过。

最终Mac自检54523实际退出0，33项包括20项五格式/两采样率/单双声道内容、10项码率、1项真实I24逐样本与2项AAC/MP3输入转FLAC。完整套还覆盖选轨、六speaker、系统下混、有效音轨范围、路径、权限、十五项取消和清理。ImageSmoke与ArchiveSmoke共享模块回归退出0。

最终generic Simulator20826、Device92359和build-for-testing73620实际退出0。专用设备顺序安装后hosted61280实际退出0，`DerivedData/AudioRuntime.xcresult`为1方法通过、0失败/跳过，实际arm64 iOS27.0；方法5.485秒，内部33/33/0/0。控制器独立读取xcresult确认结果，保留API、PointerUI及carc原始系统诊断。Device构建不证明真实设备运行；iOS18/26运行、音频UI与视觉尚未验证。

实际I24输入输出88200样本完全一致，包括8个低于16-bit LSB的非零样本。当前平台编码器不能无损表达原始浮点PCM或超过24-bit的整数PCM，服务在写入前明确拒绝；AAC/MP3等压缩轨解码输入转FLAC正常支持。[FLAC官方FAQ](https://www.xiph.org/flac/faq.html)说明格式支持整数PCM而不支持浮点；格式能力与当前平台编码器实测分别记录。

TDD证据保留于Task1报告及原始日志：可编译服务stub实际退出133是首转换行为RED；原始Int32精度边界实际退出1，修复后完整验证通过。初次缓存或动态加载失败没有记作行为RED。

## 下一阶段仍需明确及验证

独立Task1审查覆盖2540efe..759d1bd完整三提交，规格通过、质量Approved，Critical/Important均0。两项Minor保留到媒体整体审查：部分失败断言尚未限定具体错误；Mac/iOS原始系统诊断继续保留，不能称为无诊断。控制器补核现存SwiftPM缓存zip真实SHA256与固定checksum一致，实际头文件SHA与源码一致，modulemap、iOS/Simulator/macOS slices及许可均存在；没有重新下载或重复测试。

审查证明边界逐项处理：历史真实命令终态按此前工具结果保留；同卷检查代码已核实，但没有第二卷夹具，跨卷运行仍未验证；页面关闭等待取消属于媒体Task4，真实iOS18/26设备与iOS26交互仍待后续验收。这些限制不扩展Task1服务通过的范围。网络共享已完成并普通推送，当前恢复媒体Task2–4。

- VideoService已实现四容器转换、质量压缩、去除音频与剪辑；Mac完整13项/扩展/边界、三构建及iOS27完整方法1/0/0通过，详情见`docs/SHU_VIDEO_VALIDATION.md`。原质量按所保留轨道的实际native兼容性选择直通或H.264/AAC。
- 将已验证的M4A/WAV/MP3/CAF/FLAC服务接入真实音频UI，完成新用户转换与取消流程。
- 将已实现的提取音频、去除音频和区间剪辑接入真实页面，验收无对应轨道/空区间错误与修正重试。
- 视频转动图的帧序、时长、循环、尺寸、颜色和质量参数；LivePhoto 生成及相册权限另行验证。
- 复用同工作区独立暂存、无覆盖发布、真实进度、取消、边界拒绝与清理，不将纯构建结果记为运行通过。
