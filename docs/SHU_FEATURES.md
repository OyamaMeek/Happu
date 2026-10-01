# Shu 完整复刻功能核对表

目标：复刻本地 Shu 1.2.4 可证实的页面与主要操作，在 iOS 26 使用系统 Liquid Glass，保持 iOS 18 部署目标。少见格式允许入口明确提示不支持；常见格式不适用此例外。状态“已实现”仅表示当前代码存在；运行与界面验收分别记录。没有原版运行画面，不能证明逐像素相似度。

依据：`Payload/Shu.app/zh-Hans.lproj/Localizable.strings`、`PreviewManagerRes.bundle/zh-Hans.lproj/Localizable.strings` 与 `guide.webarchive`，已用 plistlib 读取；更多背景见 `docs/SHU_ANALYSIS.md`。下表中的字符串键可复查原始操作。规格与测试应维护完整目标，不以现有实现反推范围。

| 页面或操作 | 原版依据 | 当前实现及验收 |
|---|---|---|
| 文件、下载、更多三栏与 Liquid Glass | `tab.*` | 已实现系统导航；交互和视觉未完成验收。 |
| 工作区分类、文件夹导航与一键归组 | ShuFile.strings、`file.autogroup.*` | 已实现，真实文件自检有通过记录。 |
| 创建文件夹、搜索、重命名、复制、移动、删除与选择 | `file.folder.*`、`file.copy/cut/rename.*` | 已实现；真实文件自检有通过记录，系统交互仍待验收。 |
| 系统文件导入、单项/批量分享、ZIP 导出 | 内置指南、`file.export.*` | 已实现；ZIP 真实测试有通过记录，系统导入/分享运行验收未完成。 |
| 文件简介、媒体属性、MD5/SHA256、原始目录 | `file.detail.*`、`file.folder.parent` | 待实施。 |
| 外部 App 打开文件、URL scheme、拖放、挂载目录 | Info.plist、`file.folder.mount`、指南 | 待补齐文档接收和授权目录生命周期。 |
| ZIP 普通/密码解压、目标目录、进度取消 | `file.extract*`、`uncompress.passwd.input` | 已实现，真实归档自检有通过记录；交互未验收。 |
| 常见 RAR/7z/TAR/GZIP 解压；少见格式明确提示 | 内置指南格式列表 | 当前只有 ZIP；其它常见格式仍待实现，少见格式提示已有入口。 |
| Office/电子书等容器内容查看和导出 | 内置指南“显示包内容” | 待实施。 |
| PDF 合并、分割、按页图片导出、移除密码 | `file.merge.pdf`、`file.split.*`、`public.convert.pdf.page`、`file.remove.pdf.pwd` | 服务与真实文件自检已实现，独立审查与路径修复复查通过。UI 入口待 Task 3。 |
| PDF 内嵌素材提取 | 指南、`file.extract.pdf.fail` | 待实施；按页导出不能替代素材提取。 |
| 图片 TIFF/GIF/WebP/PNG/JPEG/BMP 转换、质量压缩、合成 | 指南、`file.convert/compress/composite.image` | 服务、真实文件自检、Simulator/Device 构建及独立审查/最终补强复查通过；操作 UI 待 Task 3。 |
| 多帧图片查看、按帧提取、动画完整性 | 指南、`public.btn.view.frames` | 服务已实现提取和 GIF/WebP 帧、时长、播放语义保留，真实自检和独立审查通过；查看与操作 UI 尚待实施。 |
| 视频 MP4/MOV/M4V/3GP 转换、质量压缩、提取/去除音频、区间剪辑 | 指南、`file.convert.video`、`file.compress.video`、`file.extract/remove.audio`、`public.trim.video` | 待实施；原生编码能力核查见 `docs/SHU_MEDIA_CAPABILITIES.md`，Mac 探测不代表 iOS 运行通过。 |
| 音频 M4A/WAV/MP3/CAF/FLAC 转换 | 指南、`file.convert.audio` | 待实施；MP3 属常见格式，需要真实编码能力。 |
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
| 全功能交互与布局验收 | 用户完整目标与已批准规格 | 新独立设备已真正执行导航测试；1项失败于搜索控件无匹配，需修正回归。其余功能交互和布局未完成；视觉尚无授权/证据。 |

所有“待实施”项和未完成验收均阻止宣布完整复刻完成。阶段构建成功及服务测试通过不能替代整表验收。
