# 注意事项

- 用户明确持续授权提交后的普通推送；在已授权开发范围内直接执行已配置远端的普通push，不重复索取同一授权。自动审批拒绝时如实记录；当前已补充的用户授权是新证据，不能把先前拒绝当作永久阻碍。

- `Payload` 是 IPA 容器目录，实际应用是 `Shu.app`。
- 当前 Xcode 27.0 可使用 iOS 26 原生 Liquid Glass API；保持 iOS 18 部署目标时需处理 API 可用性。
- 当前工作目录已有 Git 仓库与 `origin`；修改前以实时 `git status` 为准。
- 沙箱不允许 `swiftc` 写默认的 `~/.cache/clang/ModuleCache`；编译自检时使用 `-module-cache-path DerivedData/ModuleCache`。
- 受限终端中的 CoreSimulatorService 连接失败不能直接判定模拟器不可用；先用获准的终端权限复查 `simctl`，并区分服务权限与设备状态。
- 系统 `/usr/bin/unzip -Z1` 对本次 UTF-8 中文 ZIP 条目显示乱码，切换 LANG/LC_ALL 仍然如此；用 Python `zipfile` 校验实际条目名和内容，保留系统工具成功读取的兼容性验证，不能凭终端显示判定文件名损坏。
- SSZipArchive 高层解压接口会跳过 __MACOSX 及已存在的目标，返回成功不等于处理完全部条目。归档服务必须核对完整性，真实测试覆盖重复条目、文件目录冲突、__MACOSX 往返和真正到暂存外的越界路径。
- 共用 DerivedData 的 Xcode 构建必须顺序运行，避免 build.db 锁冲突；simctl install 成功结束后才执行 launch，等待无输出时核实进程和退出码，不推测成功。
- AudioToolbox 编码器查询在受限环境可能返回 noErr 但漏报 AAC/FLAC；能力判断需在实际权限下复核，并实际写出和重读，不将格式常量或查询成功视为编码通过。
- 图像容器原始 metadata 与 ImageIO 全局属性可能不同；GIF 原始重复次数可被归一化为总播放次数，缺扩展可合成为1。先用成熟编码器/解析器与实际平台回读核对，再修改映射；失败的样本前置断言不能充当产品行为RED。
