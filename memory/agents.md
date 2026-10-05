# 当前工具与环境

- 媒体Task3由root直接实施，当前Happu源码/模块/工程沿用其它会话已推送更名和发布设置；AVAssetImageGenerator/ImageIO/逐帧libwebp1.6.0固定源码包Vendor/ShuWebP，仅两上游文件补保留单帧动画入口。Mac48、完整图片/视频/音频回归、三构建及当前hosted48已取得成功终态，待单次独立审查；不截图。

- 2026-10-05 IPA 自动发布由 root 直接实施；GitHub Actions/macOS、xcodebuild、git、Python 标准库、ditto 和 runner 内置 gh。本机没有 gh，远端状态通过 GitHub connector 读取；当前 Apple 团队未配置，产物供侧载重新签名。不截图。

- 2026-10-05 当前工程为 `Happu.xcodeproj`，scheme/app/module 为 Happu，源码位于 Happu/；测试目标 HappuUITests、HappuRuntimeTests。root 直接实施本次更名，保留原安装标识和现有媒体改动；构建时间由 PlistBuddy 在签名前写入，SwiftUI/Foundation 在关于中显示。不截图。

- 2026-10-05 自动上传由root直接实施，upload_review按requesting-code-review技能只读审查与复查，问题已关闭；浏览器使用已安装Chrome、bundled Node.js/Playwright与真实NetworkSmoke服务，目录读取采用File and Directory Entries API。保持main和已有用户修改；不截图。

- 主实现：root直接执行已批准计划；视频Task2由video_review独立只读初审。SwiftUI / Foundation / AVFoundation / XCTest，Xcode 27.0。
- 逆向路由：本地 `reverse-skill` 仓库，R2 mobile-reverse；本次离线授权范围见 `work/payload-liquid-glass/scope.md`。
- 原版样本：`Payload/Shu.app`；无需在线连接目标。
- Git：用户明确要求直接在 main 开发；已切换 main 并快进合入此前功能分支，已有 upstream `origin/main`；普通自动推送已获授权。
- 模拟器：iPhone 18 Pro（iOS 27.0）可用；`simctl` 需要提高终端权限。独立ShuReplicaFunctional最新完整六项71766通过6/0/0，覆盖导航、归档入口、PDF/图片及导入/取消；没有iOS26或真机运行证据。
- 格式处理：已安装 SSZipArchive 2.6.0 精确 SwiftPM 依赖（模块 ZipArchive），minizip 64-bit 公开 API 通过 ArchiveBridge 静态声明接入；ZIP 服务由 zip_service 实施、zip_service_review 独立审查并复查通过，真实文件自检直接编译同一服务。文件入口与处理页由 zip_ui 实施、zip_ui_review 独立审查通过；zip_final_review 完成整体及最终测试强化复查，Ready Yes。所有子代理已完成，保留明确的 UI 运行验证限制。
- 持续完整复刻：PDF/图片阶段已完成代码审查与修复发布，八项判断披露后清理了其ignored工作目录；持久验收见`docs/SHU_PDF_IMAGE_VALIDATION.md`，真实日志/结果在DerivedData。当前媒体账本`.superpowers/sdd/2026-10-01-shu-media/progress.md`，子代理按计划顺序实施与独立复查，完整范围见`docs/SHU_FEATURES.md`。
- 图片 Task2：ImageIO/CoreGraphics/libwebp1.6.0，共享SwiftPM ShuServices target；image_service 实施、image_review独立审查、image_loop_review最终补强复查均完成。27cc40e/939f672/ccf23be/12265da 已普通推送；真实服务自检通过，UI接入与实际产物已验证，真机codec运行尚未验证。
- 独立功能测试设备：ShuReplicaFunctional，iPhone 18 Pro / iOS 27.0，UDID `4DA3B41E-303F-4B8E-A77C-340A5DC1A7BD`；应用数据容器随安装变化，每次验证重新获取。未经授权不截图或读取视觉附件，数字像素断言用于文件内容验证。
- PDF/图片 Task3：原document_ui完成操作页与入口，9f32757已普通推送；完整六项6/0/0、实际产物与七输入字节比较通过，document_ui_review规格符合、质量Approved。整体审查I1批注遗漏已由原pdf_service修复，PDFSmoke及Simulator/Device构建退出0，唯一针对性复查确认ADDRESSED、无新增问题。用户补充持续推送授权后，cb7e7e5已提交并普通推送，HEAD=origin/main；原审批阻碍已解除，控制器未修改产品。
- 媒体Task1服务已由audio_service实施、audio_task1_review独立审查通过，759d1bd已推送；Mac及hosted iOS各33项通过，UI及媒体Tasks2–4尚未完成。用户优先本地网络共享，其设计和实施计划现均已确认。
- 网络阶段账本 `.superpowers/sdd/2026-10-03-shu-local-network/progress.md`；固定GCDWebServer3.5.4源码包、ObjC受限文件/HTTP/DAV适配、Swift唯一会话及原生页面，按计划顺序实施和独立复查。Task1实施者持有index/CHANGELOG时，控制器仅更新自有文档，不并发暂存或提交。
- 2026-10-04 network_http_finish（gpt-6-astra high）已完成网络 Task1接续及最终平台注册，BASE6f9f777；报告`.superpowers/sdd/2026-10-03-shu-local-network/task-1-report.md`。旧network_http不在本会话，已有代码及真实验证保留；index/CHANGELOG已归还控制器。
- 当前Xcode支持`-collect-test-diagnostics never`（本机help退出0核实），后续测试采用此参数避免每次失败触发最长600秒sysdiagnose；保留实际断言、原始日志及xcresult，不影响方法验收。
- network_http_finish已完成24541eb/e581739并普通推送，index/CHANGELOG已归还；network_http_review（gpt-6-astra high）只读审查完整6f9f777..e581739，报告本计划task-1-review.md。
- 用户“你做啊”后root直接执行余下网络任务；network_http_finish的R1/R2修复与15+15/HTTP98证据保留，root接续hosted与提交。后续TDD/真实验证并一次最终独立审查，实施代理不再派发。
- 网络最终由root实施，network_final_review独立只读审查与复查；使用本地固定GCDWebServer3.5.4、Foundation/Network/CoreImage/libxml2及标准process资源。用户追加apple-design/impeccable后已读取两技能、正常运行context和一次detect；网页保留原生系统字体/列表，未新增前端依赖或截图。最终真实WKWebView、URLSession、XCUITest和普通签名结果已写入验证记录。
