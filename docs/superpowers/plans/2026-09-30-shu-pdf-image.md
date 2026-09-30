# Shu PDF 与图片处理 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** 补齐 PDF 与图片主要处理入口及真实文件行为，完整复刻目标继续保留。
**Architecture:** PDFService 和 ImageService 在后台处理，先暂存再发布。共用一个 SwiftUI 操作页接入单项/批量菜单与更多入口，复用 FolderPicker 和系统预览分享。
**Tech Stack:** SwiftUI、PDFKit、ImageIO、CoreGraphics、libwebp 1.6.0、Foundation。
**Spec:** `docs/superpowers/specs/2026-09-30-shu-pdf-image-design.md`

## Global Constraints

- iOS 18 部署目标，iOS 26 系统 Liquid Glass，main 开发已授权。
- 不覆盖输入或现有输出；失败/取消无发布且清理暂存；拒绝越界与符号链接。
- 真实文件测试先失败后实现；密码不写日志/持久化。
- 不主动截图，不重试已连续失败的相同 UI runner；只记录实际验证。
- 用户 AGENTS.md 改动与 Xcode workspace/xcuserdata 不暂存。每个逻辑单元记录 changelog、Conventional Commit、普通推送已配置 upstream。

## Review Focus

- 页面旋转、非零 mediaBox 原点：导出尺寸和绘制方向正确；Task 1 真实页测试。
- 加密输入与混合密码：错误密码无部分合并结果；Task 1 逐输入密码测试。
- 多帧透明/不同延迟：不丢帧、不偷偷转为静态；Task 2 真实动画测试。
- EXIF 方向与大图片：方向正确，分配前限制尺寸；Task 2 像素与超限测试。
- UI 连续操作/关闭重开：不重入，不发布取消产物；Task 3 生命周期及测试。

### Task 1: PDF 服务

**Files:** Create `ShuReplica/PDFService.swift`, `Tests/PDFSmoke.swift`; update project source registration and `docs/CHANGELOG.md`.
**Interfaces:** `PDFService(root: URL)`；`merge(_ inputs: [URL], passwords: [URL: String], in folder: URL, named name: String, progress: Progress) throws -> URL`；`exportPages(_ input: URL, password: String?, dpi: Double, jpeg: Bool, in folder: URL, named name: String, progress: Progress) throws -> URL`；`removePassword(_ input: URL, password: String, in folder: URL, named name: String, progress: Progress) throws -> URL`。操作使用 FileStore.importFile 发布；输入/目标完整边界校验由本服务执行。

- [ ] Step 1: 写真实 PDFSmoke，用 CoreGraphics 生成独立两页 PDF（文字 A/B、不同尺寸与旋转），合并断言文字/页数/顺序；生成加密 PDF，验证密码成功/失败与去密码；按页导出 PNG/JPEG 解码断言尺寸及有内容；同名保留、空输入/坏文件/非法参数/越界/符号链接/取消/清理。
- [ ] Step 2: `swiftc -module-cache-path DerivedData/ModuleCache ShuReplica/WorkspaceCategory.swift ShuReplica/FileStore.swift Tests/PDFSmoke.swift -o DerivedData/PDFSmoke` 记录因 PDFService 缺失的 RED；新增最小接口后用未实现行为断言验证 RED。
- [ ] Step 3: 实施接口，PDFKit 重建文档、CoreGraphics 绘制页并用 ImageIO 编码，页边界取消与真实进度，内存限制（单页最多 4000 万像素），重读核对后发布。
- [ ] Step 4: 加上 PDFService.swift 编译运行 `DerivedData/PDFSmoke DerivedData/TestRuns/PDF`；运行既有五项自检与 ArchiveSmoke（下载用真实 localhost HTTP）；generic Simulator 构建。
- [ ] Step 5: 检查 diff，changelog 记录命令/退出码，提交并普通推送，写 Task 1 报告。

### Task 2: 图片服务

**Files:** Create `ShuReplica/ImageService.swift`, `Tests/ImageSmoke.swift`; update `Package.swift`, Xcode project dependency/source registration, `docs/CHANGELOG.md`。
**Interfaces:** `ImageFormat: String, CaseIterable` 的 cases `tiff, gif, webp, png, jpeg, bmp`；`ImageService(root: URL)`；`convert(_ input: URL, to format: ImageFormat, quality: Double, frame: Int?, in folder: URL, named name: String, progress: Progress) throws -> URL`；`extractFrames(_ input: URL, in folder: URL, named name: String, progress: Progress) throws -> URL`；`compose(_ inputs: [URL], in folder: URL, named name: String, progress: Progress) throws -> URL`；`frameCount(_ input: URL) throws -> Int`。frame 为零开始，nil 表示保留所有帧；多帧到单帧编码格式必须给 frame。JPEG/BMP 白底，纵向合成 PNG，EXIF 方向正常化。

- [ ] Step 1: 写真实 ImageSmoke（同服务在 SwiftPM 可执行 target），CGImage 生成颜色/透明/方向样本，ImageIO 生成两帧 GIF（0.1/0.3 秒，循环 3）；断言六格式实际解码、方向尺寸/像素、动画 GIF/WebP/TIFF 往返帧数与可表达的时长/循环、显式选帧、提取、合成、同名保留、超限/坏输入/边界/取消/清理。
- [ ] Step 2: 接入 fixed libwebp 1.6.0 和 ImageSmoke SwiftPM target，执行 `swift run --scratch-path DerivedData/ImagePackage ImageSmoke DerivedData/TestRuns/ImageRed`，记录因服务缺失或未实现行为 RED。
- [ ] Step 3: 使用 ImageIO 与 libwebp 标准编码/解码/动画 API 实施，限制单帧 4000 万像素和所有帧合计 8000 万像素；质量验证 0.1–1.0，失败信息清楚。
- [ ] Step 4: 运行 ImageSmoke、PDFSmoke、ArchiveSmoke 与既有自检；generic Simulator/Device 顺序构建，重新读取输出核实。
- [ ] Step 5: diff/check、changelog、原子提交与普通推送，Task 2 报告。

### Task 3: 操作页与入口

**Files:** Create `ShuReplica/DocumentOperationView.swift`; modify `ShuReplica/FilesView.swift`, `ShuReplica/MoreView.swift`, `Tests/ShuReplicaUITests.swift`, Xcode source registration and changelog。
**Interfaces:** `DocumentOperationRequest` 使用 `[URL]` 和 PDF/image 模式，`DocumentOperationView(store: FileStore, request: DocumentOperationRequest, onFinish: () -> Void)`。消费 Task 1/2 接口及已有 FolderPicker。

- [ ] Step 1: 添加 UI 用例：导入/选中文件后进入 PDF 或图片表单、PDF 合并至少两项且可排序、图片转换选格式/质量/选帧、目标选择、错误和取消重试；记录 runner 尚无执行证据，不用源码匹配测试冒充 RED。
- [ ] Step 2: 实现共享表单：单项/多项操作选择、各输入密码、dpi/质量/显式帧输入、上下移动顺序、命名与目标目录。后台任务、真实 Progress 定时观察、取消且等待、错误重试、预览分享/完成刷新。更多入口 fileImporter 复制到工作区再调用同页。
- [ ] Step 3: 运行服务真实自检及完整旧自检；Simulator/Device、UI build-for-testing 顺序构建；模拟器 install 成功后 launch，收集退出码；不宣称未执行的触控及视觉。
- [ ] Step 4: diff/check、changelog、原子提交与普通推送，Task 3 报告及独立复查。
