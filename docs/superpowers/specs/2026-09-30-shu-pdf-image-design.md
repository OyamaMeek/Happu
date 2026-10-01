# Shu PDF 与图片处理规格

## 目标与依据

继续用户已授权的完整 Shu 1.2.4 复刻。沿用 SwiftUI、main 开发、子代理分步实施与复查、iOS 18 部署目标及 iOS 26 系统 Liquid Glass。原版中文 Localizable.strings 确认 `file.merge.pdf`、`public.convert.pdf.page`、`file.remove.pdf.pwd`、`file.convert.image`、`file.compress.image`、`file.composite.image`；内置指南确认多帧提取及 TIFF/GIF/WebP/PNG/JPEG/BMP 转换。

这一阶段实现 PDF 合并、按指定页数分割、按页导出、输入密码解锁后移除密码，以及图片转换、质量压缩、合成和按帧提取。分割依据原版 `file.split.title` 与 `file.split.fmt`。原版 PDF 内嵌素材提取、office/电子书包内容、相册/LivePhoto 和媒体等其余完整目标继续保留在进度记录，不把按页快照等同内嵌素材提取。

## 服务与文件安全

PDFService 使用 PDFKit / CoreGraphics，ImageService 使用 ImageIO / CoreGraphics 及 libwebp 1.6.0。服务接收工作区 root、输入 URL、目标目录、输出名称及 Progress。只处理工作区内普通文件；拒绝越界、符号链接、含 `.`/`..` 的原始文件路径、特殊文件、非法名称与非目录目标。先在工作区隐藏独立暂存目录完成输出，再使用 FileStore 的无覆盖重命名与移动发布文件或整个结果目录；失败或取消清理暂存，原始文件保持完整。当前处理目标位于同一个 Documents 工作区，发布不得回退为向最终可见名称复制部分结果。取消至少在页/帧/文件边界生效，单个编码阶段可能延迟。Progress 按真实页/帧/文件更新。

PDF 合并依用户可调整的输入顺序逐页复制，至少两个输入；输入逐个可提供密码。拒绝空文档、损坏文档和无法解锁的文档。分割接收每份页数（正整数），最后一份允许不足该页数；若页数不超过每份页数则明确提示无需分割，不发布重复文档，结果存为编号 PDF 的一个目录。按页导出 PNG 或 JPEG，默认 72 dpi，允许 36–300 dpi，每页 mediaBox 尺寸与旋转均影响像素尺寸；白色页底，结果存为一个目录。移除密码输出可重新打开且不再需要密码，保留页数、文字和页面尺寸；需要原密码，不能用此入口绕过未知密码。合并和移除密码输出应以重建新 PDFDocument 保证不会带回原文档加密设置。

图片静态输入支持 ImageIO 可解码的常见格式和 libwebp；输出 TIFF、GIF、WebP、PNG、JPEG、BMP，使用实际编码器并重新解码核对。JPEG 压缩支持 0.1–1.0 质量；透明输入转 JPEG/BMP 明确使用白色底。尊重 EXIF 方向。多帧输入转 GIF/WebP/TIFF 保留全部帧；GIF/WebP 保留每帧时长及循环数；静态格式转换多帧输入须明确选帧，不能静默丢失其余帧。按帧提取输出编号 PNG 到独立目录。图片合成按用户顺序纵向排列，白色背景，宽度取最大输入宽度，输出 PNG。必要的像素及帧数限制必须报出具体错误，防止巨幅图像导致进程内存耗尽。

## 页面与交互

文件单项 context menu：PDF 提供“PDF 处理”；图片提供“图片处理”。批量文件菜单：多个 PDF 可合并，多个图片可合成。操作页列出输入并允许上下调整顺序，展示相关操作、格式/质量/dpi/密码、目标目录和名称；目标目录选择复用现有 FolderPicker。多帧到静态格式的转换提供显式帧序号。后台处理、真实进度、取消、错误重试、结果预览/系统分享与关闭后刷新文件列表；进行中关闭需先取消并等待任务结束。密码仅保存在当前页面状态，不持久化或记录日志。

“更多”增加图片转换和 PDF 处理入口，可通过系统文件导入选择外部输入，复制到工作区后打开同一操作页。现有排序与关于保留。所有按钮有可理解辅助功能标签；不固定文字高度。

## 验证

真实 PDF/图片自检覆盖合并顺序及文字、页面导出尺寸/旋转、密码成功/失败、输出重新读取、全部六种图像编码、EXIF、透明白底、动画帧数/时长/循环、合成尺寸及像素、非法参数/损坏/越界/符号链接/同名/取消及清理。使用相同服务在 macOS 命令行执行真实文件自检，iOS Simulator/Device 构建检查平台接口。UI 测试补充入口和表单，不把目标编译视为交互通过；runner 已失败两次，修复其根因前不重复同样启动。未经用户明确要求，不截图或进行视觉检查。

## 官方依据

- [Apple PDFKit](https://developer.apple.com/documentation/pdfkit/pdfdocument)
- [ImageIO 输出类型查询](https://developer.apple.com/documentation/imageio/cgimagedestinationcopytypeidentifiers())
- [libwebp API](https://developers.google.com/speed/webp/docs/api)
- [libwebp Apple SwiftPM 包与版本](https://github.com/SDWebImage/libwebp-Xcode/releases/tag/1.6.0)
