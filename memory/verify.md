# 验证标准

- `FileStoreSmoke` 在项目内被忽略的 `DerivedData/TestRuns/` 中真实创建、导入、移动、复制、重命名、删除文件，结果符合断言。
- `xcodebuild` 针对 generic iOS Simulator 编译成功，代码签名关闭。
- 下载输入仅接受 HTTP(S) URL；进度、暂停/继续与完成文件由真实 URLSession 回调驱动。
- 重建 DownloadManager 后，已完成文件与中断任务列表仍可见；删除任务后不再恢复。
- UI 使用系统文件导入、QuickLook 预览和 ShareLink；没有数据丢失式覆盖。
- 本机模拟器服务若仍不可用，记录无法运行 UI 的事实。

## 本次结果

- 上一版的三个自检和两种构建已通过。本次用 `swiftc -module-cache-path DerivedData/ModuleCache ShuReplica/FileStore.swift Tests/FileStoreSmoke.swift -o DerivedData/FileStoreSmokeBaseline` 编译基线自检，随后运行 `DerivedData/FileStoreSmokeBaseline DerivedData/TestRuns/FileStoreBaseline`，两步退出码均为 0；未运行新的功能测试。
- 本次只读检查确认 Xcode 27.0；`simctl list runtimes` 因 CoreSimulatorService 连接失败而退出 1。
- 后续每个功能使用真实文件或请求验证；能运行模拟器时再验证界面。未获视觉验证要求，不主动截图。
