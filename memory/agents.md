# 当前工具与环境

- 主实现与复查：Codex 子代理分步执行第一阶段，SwiftUI / Foundation / XCTest，Xcode 27.0。
- 逆向路由：本地 `reverse-skill` 仓库，R2 mobile-reverse；本次离线授权范围见 `work/payload-liquid-glass/scope.md`。
- 原版样本：`Payload/Shu.app`；无需在线连接目标。
- Git：当前工作区位于 `codex/shu-liquid-glass-replica`，已配置 `origin`；当前分支尚无上游分支。
- 模拟器：iPhone 18 Pro（iOS 27.0）可用；`simctl` 需要提高终端权限。XCTest runner 两次未进入测试方法。
