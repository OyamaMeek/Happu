# Shu 的 WebP 编码依赖

源自 [libwebp-Xcode 1.6.0](https://github.com/SDWebImage/libwebp-Xcode/tree/1.6.0)，固定提交 `2b5256c29ff4e20f2a0d5ee863b62b1a22144434`。保留 `libwebp/src`、`libwebp/sharpyuv`、公开头文件映射和原始许可文件；使用原有 SwiftPM 构建配置。

本地修改仅在 `muxedit.c` 和 `mux.h` 增加 `ShuWebPMuxAssembleAnimation`。新函数省略标准封装入口中的 `MuxCleanup`，保留覆盖画布的单帧动画的时长和循环数；之后仍执行原库的 `CreateVP8XChunk`、内存分配、块写出及 `MuxValidate`。标准 `WebPMuxAssemble` 保持原有清理行为，静态 WebP 和既有图片转换继续使用它。

验收使用真实 GIF/WebP 编码后再解码，覆盖一帧、重复帧、有限/无限循环、帧时长、颜色、透明度与原有图片转换。升级依赖时必须重新核对这两个源文件及全部真实用例。
