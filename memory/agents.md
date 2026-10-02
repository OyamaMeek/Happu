# 当前工具与环境

- 主实现与复查：Codex 子代理分步执行完整复刻，SwiftUI / Foundation / XCTest，Xcode 27.0。
- 逆向路由：本地 `reverse-skill` 仓库，R2 mobile-reverse；本次离线授权范围见 `work/payload-liquid-glass/scope.md`。
- 原版样本：`Payload/Shu.app`；无需在线连接目标。
- Git：用户明确要求直接在 main 开发；已切换 main 并快进合入此前功能分支，已有 upstream `origin/main`；普通自动推送已获授权。
- 模拟器：iPhone 18 Pro（iOS 27.0）可用；`simctl` 需要提高终端权限。独立ShuReplicaFunctional最新完整六项71766通过6/0/0，覆盖导航、归档入口、PDF/图片及导入/取消；没有iOS26或真机运行证据。
- 格式处理：已安装 SSZipArchive 2.6.0 精确 SwiftPM 依赖（模块 ZipArchive），minizip 64-bit 公开 API 通过 ArchiveBridge 静态声明接入；ZIP 服务由 zip_service 实施、zip_service_review 独立审查并复查通过，真实文件自检直接编译同一服务。文件入口与处理页由 zip_ui 实施、zip_ui_review 独立审查通过；zip_final_review 完成整体及最终测试强化复查，Ready Yes。所有子代理已完成，保留明确的 UI 运行验证限制。
- 持续完整复刻：PDF/图片阶段计划与账本 `.superpowers/sdd/2026-09-30-shu-pdf-image/`；pdf_service 实施 Task 1，pdf_review 独立审查、pdf_path_review 修复复查通过。使用 PDFKit/CoreGraphics/ImageIO，同一服务由 macOS 真实自检验证。完整需求矩阵见 `docs/SHU_FEATURES.md`。子代理按计划顺序实施，每项独立复查。
- 图片 Task2：ImageIO/CoreGraphics/libwebp1.6.0，共享SwiftPM ShuServices target；image_service 实施、image_review独立审查、image_loop_review最终补强复查均完成。27cc40e/939f672/ccf23be/12265da 已普通推送；真实服务自检通过，UI接入与实际产物已验证，真机codec运行尚未验证。
- 独立功能测试设备：ShuReplicaFunctional，iPhone 18 Pro / iOS 27.0，UDID `4DA3B41E-303F-4B8E-A77C-340A5DC1A7BD`；应用数据容器随安装变化，每次验证重新获取。未经授权不截图或读取视觉附件，数字像素断言用于文件内容验证。
- PDF/图片 Task3：原document_ui（gpt-6.1-sol high）完成操作页与文件/更多入口，9f32757已普通推送；完整六项1041.298秒通过、十项产物及四目录精确集合验证通过、七原输入字节比较通过。document_ui_review（gpt-6.1-sol high）规格符合、质量Approved；跨任务七项核验已处理，未运行条件继续保留。唯一整体审查者pdf_image_final_review（gpt-6-astra high）检查72fa090..9f32757；控制器不修改产品或派并行实现者，整体审查仍待完成。
