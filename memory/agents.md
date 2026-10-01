# 当前工具与环境

- 主实现与复查：Codex 子代理分步执行第一阶段，SwiftUI / Foundation / XCTest，Xcode 27.0。
- 逆向路由：本地 `reverse-skill` 仓库，R2 mobile-reverse；本次离线授权范围见 `work/payload-liquid-glass/scope.md`。
- 原版样本：`Payload/Shu.app`；无需在线连接目标。
- Git：用户明确要求直接在 main 开发；已切换 main 并快进合入此前功能分支，已有 upstream `origin/main`；普通自动推送已获授权。
- 模拟器：iPhone 18 Pro（iOS 27.0）可用；`simctl` 需要提高终端权限。独立 ShuReplicaFunctional 已真正进入方法，搜索显示/输入已核实，选择菜单已移入底栏，最终交互回归尚未通过。
- 格式处理：已安装 SSZipArchive 2.6.0 精确 SwiftPM 依赖（模块 ZipArchive），minizip 64-bit 公开 API 通过 ArchiveBridge 静态声明接入；ZIP 服务由 zip_service 实施、zip_service_review 独立审查并复查通过，真实文件自检直接编译同一服务。文件入口与处理页由 zip_ui 实施、zip_ui_review 独立审查通过；zip_final_review 完成整体及最终测试强化复查，Ready Yes。所有子代理已完成，保留明确的 UI 运行验证限制。
- 持续完整复刻：PDF/图片阶段计划与账本 `.superpowers/sdd/2026-09-30-shu-pdf-image/`；pdf_service 实施 Task 1，pdf_review 独立审查、pdf_path_review 修复复查通过。使用 PDFKit/CoreGraphics/ImageIO，同一服务由 macOS 真实自检验证。完整需求矩阵见 `docs/SHU_FEATURES.md`。子代理按计划顺序实施，每项独立复查。
- 图片 Task2：ImageIO/CoreGraphics/libwebp1.6.0，共享SwiftPM ShuServices target；image_service 实施、image_review独立审查、image_loop_review最终补强复查均完成。27cc40e/939f672/ccf23be/12265da 已普通推送；真实服务自检通过，设备 codec 运行与 UI 接入尚待后续验证。
- 独立功能测试设备：ShuReplicaFunctional，iPhone 18 Pro / iOS 27.0，UDID `4DA3B41E-303F-4B8E-A77C-340A5DC1A7BD`。runner 已真正执行导航方法；session71050终止退出65，搜索显示/输入/选择数量保持已执行，该次失败为激活搜索时顶部选择菜单隐藏。document_ui 正在真实文档交互及导航回归，未完成视觉验收。
- PDF/图片 Task3：document_ui（gpt-6.1-sol high）消费真实服务，实现操作页与文件/更多入口，补真实文档交互与搜索回归；控制器负责后续独立审查，不并行派第二个实现者。
- Task3取消重试98419与More成功导入65315两个单项均真实通过，各total1/passed1/failed0/skipped0；控制器独立核验真实PDF、工作区副本字节与结构化结果。完整六项回归19281已退出65，结构化Failed/total6/passed2/failed4/skipped0；Archive和More通过，三个文档方法在工作区入口失败，Navigation在选择菜单失败。同一document_ui依据现有文本诊断继续处理；全套输出验证、产品提交和独立审查未完成。
