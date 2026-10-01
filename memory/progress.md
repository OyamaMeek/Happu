# 进度

- [x] 核实样本与范围，建立逆向授权记录。
- [x] 从 Info.plist、中文字符串和内置指南识别栏目与功能。
- [x] 完成文件操作逻辑和可运行自检。
- [x] 完成 SwiftUI 文件页面。
- [x] 完成下载逻辑和页面，验证本地 200、404 和暂停/继续。
- [x] 下载列表跨重启恢复，并用真实下载自检验证（见 `Tests/DownloadManagerSmoke.swift` 与当前实现）。
- [x] 创建并构建 iOS 工程。
- [x] 用户要求 main 直接开发；已切到 main、快进合入之前分支并 fetch 核对 origin。已有 origin/main upstream，自动普通推送获授权。
- [x] 本次逆向授权、路由及离线范围校验完成；证据 E-001 至 E-003 已记录。
- [x] 第一阶段书面规格已写出并完成自查。
- [x] 用户批准第一阶段书面规格。
- [x] 第一阶段实施计划已写出并完成需求、接口和验证步骤自查。
- [x] 用户审阅第一阶段实施计划并选择子代理分步执行。
- [x] 第一阶段文件工作区界面、批量操作、嵌套普通文件归组和系统导航已实现；五项 Swift 自检、两种 generic 构建及 UI 测试目标编译通过。
- [ ] 完成 XCUITest 标签切换、文件夹导航、搜索/选择及动态字体验收；独立 iOS 27 设备已进入导航方法，当前失败于搜索控件无匹配，修改后需回归。
- [ ] 实现常见格式处理、下载增强、传输与设置；少见格式提供明确不支持提示。
- [x] 由两个只读子代理核对 ZIP 库及 PDF、图片、媒体、文本处理的官方能力边界。
- [x] 用户本会话明确直接开发；已写 ZIP 规格与计划、自查边界及测试覆盖，沿用子代理分步执行。
- [x] ZIP Task 1：产品服务、精确依赖、真实归档 RED/GREEN 与独立审查。
- Task 1 当前：52c1a41 修复已普通推送，真实自检、Simulator 构建及主代理独立自检退出 0；复查确认重复／冲突、__MACOSX 和越界测试问题全部解决，无新增重要问题。
- [x] ZIP Task 2：文件入口、后台处理页、回归构建与模拟器运行、独立审查。
- Task 2 当前：4b30df6 已普通推送；完整归档自检、五项旧自检、三类构建及模拟器安装启动退出 0，规格合规且质量审查 Approved，无严重／重要问题。进度变化及交互取消重开未运行验证，scheme 提示仍存在。
- [x] ZIP 整体审查与最终测试强化复查：Ready Yes，无严重／重要问题；2b556f4 真实自检退出 0，已普通推送。
- [x] 本阶段可见对话已保存 `context/2026/09/30/22-22-33/对话.md`；最终文档和实际提交哈希已补记。
- [x] 最终文档、会话归档及提交哈希已获用户授权并普通推送，远端 `origin/main` 最近核对为 `ba8d9ef71e13b9cb1928fe4eff107a6be9f9962e`。
- [x] 推送后的完整消息快照保存在 `context/2026/09/30/22-42-45/对话.md`、`context/2026/09/30/22-46-03/对话.md`；提交哈希已补记 changelog。
- 后续顺序：PDF／图片、媒体、文本与结构化文档，再补齐下载增强、传输及更多设置；完整复刻尚未完成。
- [ ] 运行后续格式、下载、传输、设置阶段的功能验证；本阶段应用已在 iPhone 18 Pro 模拟器安装并启动，界面交互尚无运行证据。

## 持续完整复刻：PDF 与图片

- [x] 再读当前代码、进度与原版资源，确认 PDF/图片具体操作；scope gate 退出 0，main upstream 为 origin/main。
- [x] 写 PDF/图片规格与三项实施计划，检查原版操作、输入输出、动画、安全边界和验证覆盖。
- [x] Task 1 PDFService 与真实 PDFSmoke，独立审查及修复复查通过。
- Task 1 实施 3d1ee23、路径修复 e48284b、日志补记 67d6953 / 164ca77 已普通推送。内部链接回归 RED 退出 133，修复后 PDFSmoke 与最终 Simulator 构建退出 0；pdf_path_review 确认全部问题已处理，无新增重要问题。PDF UI 入口仍待 Task 3。
- [x] Task 2 ImageService、libwebp 与真实 ImageSmoke，独立审查及最终补强复查通过。
- Task 2 实施 27cc40e / 939f672、兼容补强 ccf23be / 12265da 已普通推送；ImageComplete、PDFSmoke、ArchiveSmoke、五项既有自检及 Simulator/Device 顺序构建退出0。最终 ImageLoopGreen、Pillow16件独立解码与 Simulator 构建退出0；image_review spec✅/Approved，image_loop_review 补强复查 Approved、无新增问题。UI 入口待 Task3，设备 codec 运行尚未验证。
- [ ] Task 3 操作页、文件/更多入口、构建运行及独立复查。
- Task2 保留总播放次数语义，真正缺全局属性时默认一次；没有把错误样本前置断言当服务RED。Task3已补充真实fixture生成器、文档交互测试及搜索失败回归，document_ui 正在顺序实施，BASE为34808842255a85f65c4c4bf22791cce47983c46e。
- [ ] 后续补齐常见其它归档、PDF 内嵌素材及包内容、相册/LivePhoto、媒体、文本/结构化文档、下载增强、传输、设置与完整 UI 验收。
- 完整功能核对表 `docs/SHU_FEATURES.md` 已从原版资源建立，包含 PDF 分割、简介/哈希、外部文件接收、通讯录/扫描/iCloud 等待完成项，不能只按原有四阶段的简略列表判定全部完成。
- 后续媒体能力证据见 `docs/SHU_MEDIA_CAPABILITIES.md`：Mac 原生 MP4/MOV/M4V/3GP 三帧 H.264 写读成功，FLAC 编码存在且 MP3 需库；尚未实现产品媒体功能，iOS Simulator 独立 CLI 探测终止、未验证运行能力。
- 主代理 UI 诊断：独立 ShuReplicaFunctional（4DA3B41E-303F-4B8E-A77C-340A5DC1A7BD）bootstatus、安装成功，同一次 test-without-building 真正进入导航方法。session56245已退出65；结构化xcresult为total=1/failed=1/passed=0，10:55在 Tests/ShuReplicaUITests.swift:79 找不到SearchField失败，前段标签切换、新建文件夹、全选已执行。诊断采集另超时600秒。搜索显示/激活条件需在Task3查明并用该方法回归；未查看图片或截图。
- 图片阶段完成记录及当前可见消息快照：`context/2026/10/01/14-31-40/对话.md`，47条消息，不含内部推理、工具输出或目标继续控制消息；阶段文档3480884已普通推送origin/main，退出0。
- 媒体实施计划已完成自查，四任务及精确服务接口、hosted iOS编码验证和真实页面路径已写；固定LAME3.100.3 tag/manifest核实，但没有下载二进制或实现媒体。待PDF/图片Task3及阶段整体审查完成后执行。当前控制器可见消息归档为 `context/2026/10/01/14-54-03/对话.md`（53条，编号/角色验证退出0）。
