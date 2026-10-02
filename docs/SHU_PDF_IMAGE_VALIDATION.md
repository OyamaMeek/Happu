# PDF 与图片阶段验收记录

实现范围：`72fa090d42610d10bc9bdd14febacf081410651f` 至 `9f3275717e5e259bb84973fab0e614f03dc960a8`。依据为本阶段规格和实施计划；整个 Shu 完整复刻仍未完成，剩余功能见 `SHU_FEATURES.md`。

## 实际证据

| 要求 | 当前证据 |
|---|---|
| PDF 合并与分割 | `Tests/PDFSmoke.swift` 真实文件断言页数、输入顺序、文字、余页、无需分割拒绝、尺寸、旋转及整页栅格内容；服务审查及路径修复复查通过。 |
| PDF 页面导出与密码 | 同一自检验证 PNG/JPEG、36–300 dpi、白底、像素限制、逐输入密码、错误密码拒绝、去密码后重读及原文件保持；最新 UI 实际运行合并、分割、144 dpi 导出和解密。 |
| 图片六格式与方向 | `Tests/ImageSmoke.swift` 使用实际 TIFF/GIF/WebP/PNG/JPEG/BMP 编码器，重新解码检查尺寸、颜色、八种 EXIF 方向、WebP EXIF/半透明、JPEG/BMP 白底。 |
| 图片多帧、质量与合成 | 同一自检核对全部帧、重复帧、时长、循环、显式选帧、提取编号、纵向合成与像素限制；Pillow 独立解码 16 件 GIF 核对循环、帧和时长。服务原审查及补强复查通过。 |
| 文件边界与发布 | 自检覆盖越界、内部/外部符号链接及祖先、原始点路径、非法参数、目标重名、读写失败、真实进行中取消、暂存清理及原输入/哨兵保护；同 Documents 文件系统使用 FileStore.rename/move 发布。 |
| 文件与更多入口 | 单项、批量入口接入同一处理页；更多使用原生 fileImporter，成功复制到工作区后处理；真实 UI 方法执行原生选择、复制、处理和返回文件列表。 |
| 页面参数与生命周期 | 实际测试操作密码、顺序、页数、dpi、质量、显式帧、名称、目的目录，验证错误重试、真实进度取消、关闭等待、重开、QuickLook 与系统分享返回。 |
| 最新完整 UI 回归 | `DerivedData/DocumentUIFullFinal.xcresult`：iOS 27.0 / iPhone 18 Pro 模拟器，6 通过、0 失败、0 跳过，无 testFailures/runtimeWarnings；执行日志方法合计记录为 1041.298 秒。 |
| 所有实际输出 | `Tests/prepare_document_ui_fixtures.swift --verify` 对十项输出及四个结果目录精确集合重读，`document-ui-actual-outputs-final.exit` 为 0；PDF 文字/顺序/尺寸及图片质量/帧/合成内容通过。JPEG 每通道相对真实输入误差≤2，PNG 帧/合成精确匹配真实输入像素。 |
| 原文件保持 | 七个输入 PDF/PNG/GIF 与来源 fixture 逐一 `cmp`，均退出 0；独立 Pillow 数值检查选帧、提取帧及合成上下区域与来源一致。 |
| 平台构建 | generic iOS Simulator、generic iOS Device、UI build-for-testing 通过；最终 Device 日志退出 0，保留既有 Supported platforms 提示。部署目标为 iOS 18，构建通过不代表该系统或真机实际运行通过。 |
| 独立审查 | 三个任务分别规格符合、质量 Approved；Task3 七项跨任务核验已逐项处理。阶段整体审查发现 PDF 页面导出遗漏可见 annotation：序列化后重读的真实批注 PDF，当前 CG 绘制红像素为 0，PDFKit.draw 为 3600；修复及整体最终判定尚未完成。 |

## 尚未验证的条件

- iOS 18、iOS 26 实际运行及真实设备 codec 行为。
- Dynamic Type、VoiceOver 专项、完整布局与视觉相似度；没有截图或视觉检查证据。
- 云端/其他 App 文件提供器的特殊授权条件、已打开结果目录的专项刷新。
- 人为磁盘耗尽等未实际诱发的故障；现有检查不能支持这些条件已通过的结论。
- PDF 内嵌素材、图片逐帧查看、Office 包内容、Photos/LivePhoto、媒体及其它后续功能依完整功能表实施。

## 阶段中作出的判断与代价

按决定发生顺序保留八项判断，避免临时审查目录清理后丢失依据。

1. PDF 重建允许非零 mediaBox 原点归一化，要求尺寸、旋转、文字和实际栅格位置保持。若栅格断言不足，可能遗漏平移或裁切。
2. 合法零页 PDF 由成熟 pypdf 一次生成并保存，产品不增加该运行依赖。若夹具不合法，零页拒绝证据不足。
3. 同 Documents 工作区以 FileStore.rename/move 无覆盖发布，失败不回退为可见部分复制。以后若增加跨卷目录，须另行实现对应卷内暂存与发布。
4. SwiftPM 以共享 ShuServices target 注册实际服务，两个 Smoke executable 引用同一实现。若模块边界设置不当，可能改变自检构建或 API 消费方式。
5. 唯一选择菜单放入现有底部工具栏，保留搜索词和选择集合。若底栏空间或辅助功能布局不足，可能影响其它批量按钮可访问性。
6. 选择状态使用系统 toolbar 隐藏 tabBar，结束选择后恢复。若作用范围或恢复条件不当，标签可能不可用。
7. 搜索使用原生 navigationBarDrawer(.always)，保留同一搜索和选择状态。若系统呈现受状态影响或占用过多高度，可能降低列表可访问性。
8. 非选择状态使用系统 .automatic，嵌套选择页使用 .hidden。若系统恢复行为不符合预期，退出选择后标签可能仍隐藏；最新根页/嵌套页真实回归已通过。

既有 Supported platforms 提示和预期坏 PDF 的 CoreGraphics 诊断继续作为轻微诊断项记录；没有通过隐藏输出改变验证结论。
