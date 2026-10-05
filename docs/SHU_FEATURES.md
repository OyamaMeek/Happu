# Shu 完整复刻功能核对表

目标：复刻本地 Shu 1.2.4 可证实的页面与主要操作，在 iOS 26 使用系统 Liquid Glass，保持 iOS 18 部署目标。少见格式允许入口明确提示不支持；常见格式不适用此例外。状态“已实现”仅表示当前代码存在；运行与界面验收分别记录。没有原版运行画面，不能证明逐像素相似度。

依据：`Payload/Shu.app/zh-Hans.lproj/Localizable.strings`、`PreviewManagerRes.bundle/zh-Hans.lproj/Localizable.strings` 与 `guide.webarchive`，已用 plistlib 读取；更多背景见 `docs/SHU_ANALYSIS.md`。下表中的字符串键可复查原始操作。规格与测试应维护完整目标，不以现有实现反推范围。

| 页面或操作 | 原版依据 | 当前实现及验收 |
|---|---|---|
| 文件、下载、更多三栏与 Liquid Glass | `tab.*` | 已实现系统导航；iOS27导航单项通过标签切换及选择结束后标签恢复，动态字体和视觉未完成验收。 |
| 工作区分类、文件夹导航与一键归组 | ShuFile.strings、`file.autogroup.*` | 已实现，真实文件自检有通过记录。 |
| 创建文件夹、搜索、重命名、复制、移动、删除与选择 | `file.folder.*`、`file.copy/cut/rename.*` | 已实现，真实文件自检有通过记录；iOS27创建文件夹、搜索词/选择数量保持、筛选反选与取消归零真实交互通过，其余完整交互验收仍待完成。 |
| 系统文件导入、单项/批量分享、ZIP 导出 | 内置指南、`file.export.*` | 已实现；ZIP真实测试通过，更多PDF入口系统选取/工作区复制/处理输出/返回文件列表已真实通过；一般导入及分享验收待完成。 |
| 文件简介、媒体属性、MD5/SHA256、原始目录 | `file.detail.*`、`file.folder.parent` | 待实施。 |
| 外部 App 打开文件、URL scheme、拖放、挂载目录 | Info.plist、`file.folder.mount`、指南 | 待补齐文档接收和授权目录生命周期。 |
| ZIP 普通/密码解压、目标目录、进度取消 | `file.extract*`、`uncompress.passwd.input` | 已实现，真实归档自检有通过记录；交互未验收。 |
| 常见 RAR/7z/TAR/GZIP 解压；少见格式明确提示 | 内置指南格式列表 | 当前只有 ZIP；其它常见格式仍待实现，少见格式提示已有入口。 |
| Office/电子书等容器内容查看和导出 | 内置指南“显示包内容” | 待实施。 |
| PDF 合并、分割、按页图片导出、移除密码 | `file.merge.pdf`、`file.split.*`、`public.convert.pdf.page`、`file.remove.pdf.pwd` | 服务、自检及独立审查通过；iOS27完整PDF交互、六项回归与实际产物校验通过。可见批注遗漏已修复，真实PNG/JPEG回归、完整PDFSmoke、Simulator/Device构建及唯一针对性复查通过；修复cb7e7e5已提交并普通推送。 |
| PDF 内嵌素材提取 | 指南、`file.extract.pdf.fail` | 待实施；按页导出不能替代素材提取。 |
| 图片 TIFF/GIF/WebP/PNG/JPEG/BMP 转换、质量压缩、合成 | 指南、`file.convert/compress/composite.image` | 服务、真实文件自检、Simulator/Device 构建及独立审查/最终补强复查通过；iOS27完整图片交互、最新完整六项回归与全部实际产物校验通过，含JPEG质量0.6、显式选帧、全帧提取、批量选择及调整顺序合成。UI和阶段代码审查完成，代码及整体审查修复已普通推送。 |
| 多帧图片查看、按帧提取、动画完整性 | 指南、`public.btn.view.frames` | 服务已实现提取和 GIF/WebP 帧、时长、播放语义保留，真实自检和独立审查通过；显式选帧/全帧提取UI及实际输出内容重读通过，逐帧查看仍待补齐。 |
| 视频 MP4/MOV/M4V/3GP 转换、质量压缩、提取/去除音频、区间剪辑 | 指南、`file.convert.video`、`file.compress.video`、`file.extract/remove.audio`、`public.trim.video` | VideoService与真实自检已实现，Mac13项及时间线/选轨/取消边界、三构建通过；iOS27完整方法1通过/0失败/0跳过，包含相同13项与扩展/边界。页面待Task4，提取复用已验收AudioService。证据见`docs/SHU_VIDEO_VALIDATION.md`。 |
| 音频 M4A/WAV/MP3/CAF/FLAC 转换 | 指南、`file.convert.audio` | AudioService、固定LAME编码器、真实Mac/iOS33项及独立审查通过，759d1bd已普通推送；音频转换和提取页面待媒体Task4。 |
| 视频转动图、动图帧率/颜色/质量 | 指南、`more.anim.*`、`more.gif.*` | 待实施。 |
| Photos 多选导入/导出、LivePhoto 导入/导出及转换 | 指南、`public.export.livephoto.*` | 待实施。 |
| 相机扫描文档 | `file.scan.*` | 待实施；设备授权拒绝必须明确处理。 |
| 通讯录预览/保存、VCF 合并 | `file.save/delete.contact`、`file.merge.vcf` | 待实施；删除需显式确认。 |
| 文本编码 GBK/UTF-8/UTF-16 转换 | 指南、`public.export.convert.encoding` | 待实施，无法表达的字符不能静默丢失。 |
| JSON/XML/plist/YAML 转换 | 指南 | 待实施，明确类型映射并验证可读输出。 |
| Markdown/ipynb HTML 预览及网页导出 | 指南、`more.html_view.*`、`public.export.cur.html` | 待实施。 |
| 证书 DER/PEM/P12/Base64 预览与转换 | 指南、`cert.export.*` | 待实施；密码私钥保护不能省略。 |
| PS/EPS/DjVu/TGS 等少见格式 | 指南 | 核实可用处理能力；无支持时在具体入口明确提示。 |
| HTTP(S)、请求头、下载进度、暂停继续与重启恢复 | `download.*` | 已实现基础服务，真实 localhost 200/404/暂停/恢复有通过记录。 |
| 剪贴板及外部 App 批量链接导入、去重 | 指南、`download.new.urls`、`download.param.filtered` | 待实施，剪贴板探测设置可关闭。 |
| 下载详情、全部开始/暂停、清空、重试、原始链接/cURL | `download.detail/file.export/resume.all/suspend.all/clear.all` | 待实施。 |
| Wi-Fi/热点浏览器传输、WebDAV、共享目录与二维码 | 指南、`file.uploader.*`、`file.export.wifi.*` | 待实施，启动与停止真实服务须验收。 |
| iCloud 文件/外链 | `file.file2icloud.*`、`file.share.publicurl.title` | 待实施；运行依赖合法配置的容器和签名账户，不能伪造同步。 |
| 排序、HTML模式、静音、剪贴板、图片/动图设置 | `more.file_order/config/html_view/picture/gif.*` | 当前只有名称/修改时间排序；其余待实施。 |
| 文件缓存、帮助、关于、反馈/调试日志、隐私、推荐 | `more.cache/faq/about/feedback/privacy/tellFri.*` | 当前仅基础关于；其它页面待实施，不自动发送反馈。 |
| 重置文件及下载 | `more.reset.*` | 待实施；实际删除必须由用户在应用内确认。 |
| 全功能交互与布局验收 | 用户完整目标与已批准规格 | iOS27六项回归1041.298秒通过，6通过/0失败/0跳过；实际输出内容、准确目录集合、取消清理和七个原始输入字节保持均通过。操作页及阶段代码审查完成，批注修复另有真实文件回归与构建证据，已普通推送，未重跑未改动UI。动态字体和布局验收未完成，视觉尚无授权/证据；其它功能仍逐项实施验收。 |

所有“待实施”项和未完成验收均阻止宣布完整复刻完成。阶段构建成功及服务测试通过不能替代整表验收。
