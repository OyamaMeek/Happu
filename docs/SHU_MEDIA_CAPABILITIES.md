# 媒体功能与编码能力核查

核查时间：2026-10-01。此记录提供后续媒体规格的依据，当前产品尚未实现这些操作。

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

MP3 输出需要实际编码器。已读取 LAME 的 Apple SwiftPM 包注册：`BB9z/LAME-xcframework` 的 3.100.3 提供 LAME binary target，声明 macOS 10.13+、iOS 12+，包含下载校验和；项目尚未安装或验证该依赖。[项目说明](https://github.com/BB9z/LAME-xcframework)、[Package.swift](https://github.com/BB9z/LAME-xcframework/blob/main/Package.swift)

后续选择需固定版本、核对公开头文件和实际 Mac/iOS 构建，并用真实音频编码与重读测试证明输出。MP3 不能按“少见格式可明确不支持”的例外跳过。

## 下一阶段仍需明确及验证

- 保持真实轨道、时间范围、方向和同步的四种视频转换及高/中/低压缩。
- M4A/WAV/MP3/CAF/FLAC 的 PCM 解码、编码和可表达的采样率/声道规则。
- 提取音频、去除音频、区间剪辑以及无对应轨道/空区间错误。
- 视频转动图的帧序、时长、循环、尺寸、颜色和质量参数；LivePhoto 生成及相册权限另行验证。
- 复用同工作区独立暂存、无覆盖发布、真实进度、取消、边界拒绝与清理，不将纯构建结果记为运行通过。
