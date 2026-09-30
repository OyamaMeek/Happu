# 注意事项

- `Payload` 是 IPA 容器目录，实际应用是 `Shu.app`。
- 当前 Xcode 27.0 可使用 iOS 26 原生 Liquid Glass API；保持 iOS 18 部署目标时需处理 API 可用性。
- 当前工作目录已有 Git 仓库与 `origin`；修改前以实时 `git status` 为准。
- 沙箱不允许 `swiftc` 写默认的 `~/.cache/clang/ModuleCache`；编译自检时使用 `-module-cache-path DerivedData/ModuleCache`。
- 受限终端中的 CoreSimulatorService 连接失败不能直接判定模拟器不可用；先用获准的终端权限复查 `simctl`，并区分服务权限与设备状态。
