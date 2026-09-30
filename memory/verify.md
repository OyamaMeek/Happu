# 验证标准

- `FileStoreSmoke` 在项目内被忽略的 `DerivedData/TestRuns/` 中真实创建、导入、移动、复制、重命名、删除文件，结果符合断言。
- `xcodebuild` 针对 generic iOS Simulator 编译成功，代码签名关闭。
- 下载输入仅接受 HTTP(S) URL；进度、暂停/继续与完成文件由真实 URLSession 回调驱动。
- 重建 DownloadManager 后，已完成文件与中断任务列表仍可见；删除任务后不再恢复。
- UI 使用系统文件导入、QuickLook 预览和 ShareLink；没有数据丢失式覆盖。
- 使用可连接的 iPhone 18 Pro（iOS 27.0）运行应用并检查导航与文件操作；XCTest runner 未执行到测试方法时，不声称交互已经验证。

## 本次结果

- 上一版的三个自检和两种构建已通过。本次用 `swiftc -module-cache-path DerivedData/ModuleCache ShuReplica/FileStore.swift Tests/FileStoreSmoke.swift -o DerivedData/FileStoreSmokeBaseline` 编译基线自检，随后运行 `DerivedData/FileStoreSmokeBaseline DerivedData/TestRuns/FileStoreBaseline`，两步退出码均为 0；未运行新的功能测试。
- 本次只读检查确认 Xcode 27.0；受限终端运行 `simctl list devices available` 因 CoreSimulatorService 连接失败而退出 1，提高终端权限后退出 0，确认 iPhone 18 Pro（iOS 27.0）已启动。
- 后续每个功能使用真实文件或请求验证；能运行模拟器时再验证界面。未获视觉验证要求，不主动截图。

## 第一阶段 Task 4（2026-09-30）

- `swiftc -module-cache-path DerivedData/ModuleCache ShuReplica/WorkspaceCategory.swift ShuReplica/FileStore.swift Tests/FileBatchSmoke.swift -o DerivedData/FileBatchSmoke && DerivedData/FileBatchSmoke DerivedData/TestRuns/FileBatchTask4Red`：更新嵌套归组断言后退出 133，断言命中原逻辑；修正后改用 `FileBatchTask4Green` 退出 0。
- `swiftc -module-cache-path DerivedData/ModuleCache ShuReplica/WorkspaceCategory.swift ShuReplica/FileStore.swift Tests/FileStoreSmoke.swift -o DerivedData/FileStoreSmoke && DerivedData/FileStoreSmoke DerivedData/TestRuns/FileStoreTask4`：退出 0。
- `swiftc -module-cache-path DerivedData/ModuleCache ShuReplica/WorkspaceCategory.swift ShuReplica/FileStore.swift Tests/WorkspaceCategorySmoke.swift -o DerivedData/WorkspaceCategorySmoke && DerivedData/WorkspaceCategorySmoke DerivedData/TestRuns/WorkspaceCategoryTask4`：退出 0。
- `swiftc -module-cache-path DerivedData/ModuleCache ShuReplica/DownloadRequest.swift Tests/DownloadRequestSmoke.swift -o DerivedData/DownloadRequestSmoke && DerivedData/DownloadRequestSmoke`：退出 0。
- `swiftc -module-cache-path DerivedData/ModuleCache ShuReplica/WorkspaceCategory.swift ShuReplica/FileStore.swift ShuReplica/DownloadRequest.swift ShuReplica/DownloadManager.swift Tests/DownloadManagerSmoke.swift -o DerivedData/DownloadManagerSmoke`：退出 0。用 `/usr/bin/python3 -m http.server 8765 --bind 127.0.0.1 --directory Tests/fixtures` 启动本地服务，`DerivedData/DownloadManagerSmoke DerivedData/TestRuns/DownloadManagerTask4` 退出 0，随后停止服务。
- `xcodebuild -quiet -project ShuReplica.xcodeproj -scheme ShuReplica -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData/ShuReplica CODE_SIGNING_ALLOWED=NO build`：提高终端权限后退出 0；`-sdk iphoneos -destination 'generic/platform=iOS'` 对应命令退出 0。应用与 UI 测试目标的 `build-for-testing` 退出 0。部署目标仍为 18.0。
- 两次 `xcodebuild ... -only-testing:ShuReplicaUITests test` 均停在 runner 启动阶段，无测试方法事件；首次终止退出 75，原始日志含 `NSMachErrorDomain Code=-308 (ipc/mig) server died`；第二次关闭并行测试后仍停在 `Launch session started`，人工终止。UI RED/GREEN 均无有效执行结果。
- `xcrun simctl bootstatus AF847C96-0AAE-4682-B1B4-45A9DFA161EC -b` 退出 0，但报告 `Data Migration Failed`。`xcrun simctl install ... ShuReplica.app` 最终退出 0；`xcrun simctl launch ... com.happu.shureplica` 退出 0，返回 PID 16264。未执行标签切换、文件夹导航、导入或动态字体的运行时交互检查；未截图或进行视觉检查。
