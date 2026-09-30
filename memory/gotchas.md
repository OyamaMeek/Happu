# 注意事项

- `Payload` 是 IPA 容器目录，实际应用是 `Shu.app`。
- 当前 Xcode 27.0 可使用 iOS 26 原生 Liquid Glass API；保持 iOS 18 部署目标时需处理 API 可用性。
- 当前工作目录已有 Git 仓库与 `origin`；修改前以实时 `git status` 为准。
- 沙箱不允许 `swiftc` 写默认的 `~/.cache/clang/ModuleCache`；编译自检时使用 `-module-cache-path DerivedData/ModuleCache`。
- 受限终端中的 CoreSimulatorService 连接失败不能直接判定模拟器不可用；先用获准的终端权限复查 `simctl`，并区分服务权限与设备状态。
- 系统 `/usr/bin/unzip -Z1` 对本次 UTF-8 中文 ZIP 条目显示乱码，切换 LANG/LC_ALL 仍然如此；用 Python `zipfile` 校验实际条目名和内容，保留系统工具成功读取的兼容性验证，不能凭终端显示判定文件名损坏。
- SSZipArchive 高层解压接口会跳过 __MACOSX 及已存在的目标，返回成功不等于处理完全部条目。归档服务必须核对完整性，真实测试覆盖重复条目、文件目录冲突、__MACOSX 往返和真正到暂存外的越界路径。
- 共用 DerivedData 的 Xcode 构建必须顺序运行，避免 build.db 锁冲突；simctl install 成功结束后才执行 launch，等待无输出时核实进程和退出码，不推测成功。
