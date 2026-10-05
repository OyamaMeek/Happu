# Shu 完整复刻设计状态

## 2026-10-05 文件首页调整

- 移除首页“工作区”分组及“所有文件”“共享”入口；“下载”放在“文件分类”九项之后，仍打开 Downloads 目录。
- 更新真实 UI 测试的导航入口，保留文件处理、下载管理和网络共享功能；不进行截图或视觉检查。

## 2026-10-05 网络共享自动上传

- 按用户当前要求修改现有上传入口：选择文件后立即上传，拖入文件或文件夹后立即上传到拖入时的当前目录，删除二次上传按钮。
- 使用浏览器 File and Directory Entries API 递归读取目录（持续读取至空批次），先创建目录再上传内容，保留顶层名称、层级及空目录。已有目录可合并；同名文件继续拒绝覆盖。
- 保留真实 XHR 进度和逐项失败提示；读取和上传期间阻止重复提交，导航后仍使用操作开始时的目标目录。复用现有 POST/PUT 接口，不新增依赖。
- 使用真实 Chrome 文件选择和原生拖放、实际 HTTP 服务与磁盘字节验证新行为，并更新 WKWebView 回归。

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
- 媒体实施计划 `docs/superpowers/plans/2026-10-01-shu-media.md` 包含四任务。音频Task1已提交759d1bd并普通推送；Mac33项、两平台构建及hosted iOS33项通过，独立审查通过。视频Task2已实现，Mac完整13项/扩展/边界、三构建及完整iOS方法1/0/0通过，初审两项补强完成。动图Task3和页面Task4待执行。
- PDF/图片三个任务和整体修复复查已完成，cb7e7e5已普通推送；完成记录保存与八项判断披露后继续媒体。Photos/LivePhoto另阶段实施，完整范围不缩小。

## 最新优先级

- 2026-10-05 网络共享已完成，恢复媒体Task2视频、Task3动图、Task4页面，由root直接实施，沿用main与普通推送授权。

- 网络设计及实施计划均已获用户“确认”。`docs/superpowers/plans/2026-10-03-shu-local-network.md` 分为受限 HTTP/停止、DAV/浏览器、原生入口/地址/生命周期三任务；用户“你做啊”后由root直接实施，保留一次独立代码审查，沿用main和普通推送。
- 网络HTTP修复90ca408已推送；DAV/中文浏览器、原生网络共享入口与更多下载已实施。Mac HTTP98/DAV37/资源13和故障边界通过；普通签名Simulator、generic Device最新构建和严格应用签名校验退出0。五项Runtime和三项UI方法分别取得成功终态，最终Web25及两共享UI包3/0/0；独立代码质量通过。真机网络、权限拒绝和锁屏尚缺设备证据。
- 2026-10-04 用户要求优先完成本地网络共享，浏览器首页显示应用首页各个文件夹。底部标签为文件/网络共享/更多，共享默认工作区根目录；现有下载页面移到更多并复用原DownloadManager，不新增下载功能。浏览器列出全部分类目录、下载、共享及用户实际目录，Downloads仅在根目录显示为“下载”。沿用已确认三任务计划，继续实施、运行及审查。
- 用户追加apple-design/impeccable优化Web共享页。按Operate用途保留中文文件浏览和实际传输逻辑，调整浅色/深色系统字体、功能性半透明顶栏、当前位置标题、清晰列表、SVG图标、44px触控目标、键盘焦点、局部上传反馈及减弱动态设置；不增加依赖或截图。先以真实WKWebView暴露缺失状态与手机溢出，完成后一次机械检测及一轮手机/桌面布局行为验证。
