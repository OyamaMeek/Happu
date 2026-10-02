# Shu 完整复刻设计状态

## 范围

原版 1.2.4 的本地资源确认“文件、下载、更多”三个栏目。当前用户要求完整复刻可见页面与主要操作，在 iOS 26 使用 Liquid Glass；少见格式允许明确提示不支持。继续扩展现有 SwiftUI 工程，保持 iOS 18 起的部署目标。

## 实施

1. 用户已批准第一阶段规格及实施计划 `docs/superpowers/plans/2026-09-29-shu-file-workspace-liquid-glass.md`，选择由子代理分步执行与复查。
2. 第一阶段文件工作区、批量整理、系统导入分享及系统玻璃导航已实施；iOS27完整六项回归通过，覆盖搜索、精确反选、取消归零、标签恢复、嵌套目录逐行选择及PDF/图片处理。其余文件操作和完整布局仍按功能核对表验收。
3. 格式阶段按ZIP、PDF/图片、媒体、文本与结构化文档推进，并补齐其它常见归档；少见格式在入口明确提示。
4. 后续补齐下载增强、传输与设置，并对各功能运行真实行为检查。

完整目标拆为文件工作区与 Liquid Glass、格式处理、下载增强、传输与设置四个可验证阶段；第一阶段已完成代码与构建复查，并取得相关六项真实交互通过记录。全功能、动态字体和布局验收尚未完成。

## 格式处理实施

- 建议分成 ZIP 归档、PDF 与图片、媒体、文本与结构化文档四个独立片段，逐个规格、计划、子代理实施和复查；完整主要操作范围仍保留。
- 用户本会话要求读取交接后直接开发，按现有 ZIP 建议执行；规格见 `docs/superpowers/specs/2026-09-30-shu-zip-design.md`，实施计划见 `docs/superpowers/plans/2026-09-30-shu-zip.md`。SSZipArchive 2.6.0 接入文件单项与批量菜单，提供普通 ZIP 打包和普通／密码解压、目标选择、进度取消及分享；先暂存后发布。
- PDF 使用 PDFKit；图片使用 ImageIO；媒体使用 AVFoundation/AudioToolbox。输入与输出能力分别判定，UTType 或文件格式常量不能证明编码器存在。
- WebP、MP3 是常见格式，输出能力需要实际核实或成熟编码器，不能依据“少见格式可提示”忽略。XML/YAML 与 JSON/plist 的结构映射也需明确规则。
- 官方依据：https://developer.apple.com/documentation/imageio/cgimagedestinationcopytypeidentifiers%28%29 、https://developer.apple.com/documentation/audiotoolbox/kaudioformatproperty_encodeformatids 、https://developer.apple.com/documentation/pdfkit/pdfdocument 。

## PDF 与图片阶段

- 持续目标“完整复刻”已要求继续工作；沿用已授权的 main 与子代理实施方式。规格 `docs/superpowers/specs/2026-09-30-shu-pdf-image-design.md`，计划 `docs/superpowers/plans/2026-09-30-shu-pdf-image.md`。
- 原版字符串确认 PDF 合并、按页导出、移除密码，以及图片转换、质量压缩、合成和按帧提取。PDFKit / ImageIO 优先，WebP 使用 fixed libwebp 1.6.0；动画不能静默丢帧，密码不持久化。
- PDF 内嵌素材与包内容提取、相册/LivePhoto、常见其它归档、媒体、文本、下载增强、传输、更多设置和 UI 验收继续保留在完整目标中。
- Task3实现9f32757已普通推送，完整六项与实际产物验证通过，document_ui_review规格符合、质量Approved；七项跨任务核验已逐项记录。整体审查的批注遗漏已修复并通过唯一针对性复查、真实PDFSmoke及两平台构建；用户补充持续授权后，cb7e7e5已提交并普通推送。阶段记录保存后继续媒体。

## 媒体阶段准备

- 原版需求、native 实测和 MP3 编码器依据记录于 `docs/SHU_MEDIA_CAPABILITIES.md`；后续规格 `docs/superpowers/specs/2026-10-01-shu-media-design.md` 包含四种视频、五种音频、质量/音轨/区间和 GIF/WebP 动图参数、边界与真实验证。
- 媒体实施计划 `docs/superpowers/plans/2026-10-01-shu-media.md` 已写：音频与真实iOS编码、视频转换/编辑、逐帧动图、共享媒体操作页面四个独立审查任务。当前唯一audio_service实施Task1，固定LAME 3.100.3已写入未提交的Package/Xcode注册；部分Mac编码和聚焦边界通过，最终完整回归、iOS运行及独立审查仍待完成。
- PDF/图片三个任务和整体修复复查已完成，cb7e7e5已普通推送；完成记录保存与八项判断披露后继续媒体。Photos/LivePhoto另阶段实施，完整范围不缩小。

## 最新优先级

- 用户要求“在这个部分做完了建议先做本地网络共享功能”。当前按音频Task1完成实施、真实验证及独立审查后优先网络共享理解；已提供纠正顺序的机会，暂不派发媒体Task2。音频UI仍属Task4，服务验收不能代表完整音频用户流程。
- 网络是新的服务模块，先按brainstorming读取原版指南/字符串/Info.plist及现有入口，记录于`docs/SHU_NETWORK_CAPABILITIES.md`。范围含同网段/热点浏览器传输、WebDAV、选定共享目录、真实地址/二维码、启动停止和文件操作；尚无产品网络代码或运行结论。
- 音频、视频、动图、Photos/LivePhoto及其它完整目标继续保留，优先级调整不删除需求。网络依赖与前台生命周期方案尚待具体设计。
