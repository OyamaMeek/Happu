# 当前工具与环境

- 主实现与复查：Codex 子代理分步执行第一阶段，SwiftUI / Foundation / XCTest，Xcode 27.0。
- 逆向路由：本地 `reverse-skill` 仓库，R2 mobile-reverse；本次离线授权范围见 `work/payload-liquid-glass/scope.md`。
- 原版样本：`Payload/Shu.app`；无需在线连接目标。
- Git：用户明确要求直接在 main 开发；已切换 main 并快进合入此前功能分支，已有 upstream `origin/main`；普通自动推送已获授权。
- 模拟器：iPhone 18 Pro（iOS 27.0）可用；`simctl` 需要提高终端权限。XCTest runner 两次未进入测试方法。
- 格式处理：已安装 SSZipArchive 2.6.0 精确 SwiftPM 依赖（模块 ZipArchive），minizip 64-bit 公开 API 通过 ArchiveBridge 静态声明接入；ZIP 服务由 zip_service 实施、zip_service_review 独立审查并复查通过，真实文件自检直接编译同一服务。文件入口与处理页由 zip_ui 实施、zip_ui_review 独立审查通过；zip_final_review 完成整体及最终测试强化复查，Ready Yes。所有子代理已完成，保留明确的 UI 运行验证限制。
- 持续完整复刻：PDF/图片阶段计划与账本 `.superpowers/sdd/2026-09-30-shu-pdf-image/`；pdf_service 实施 Task 1，pdf_review 独立审查、pdf_path_review 修复复查通过。使用 PDFKit/CoreGraphics/ImageIO，同一服务由 macOS 真实自检验证。完整需求矩阵见 `docs/SHU_FEATURES.md`。子代理按计划顺序实施，每项独立复查。
