# 验证标准

- PDF/图片阶段遵循 `docs/superpowers/plans/2026-09-30-shu-pdf-image.md`：PDFSmoke / ImageSmoke 使用真实编码文件并重读断言内容、页/帧数、尺寸、顺序与时长；generic Simulator/Device、UI target 编译及模拟器安装启动。全目标仍需要其余功能与真实交互验收，阶段自检不证明全部复刻。

- ZIP 本阶段真实自检：`swift run --scratch-path DerivedData/ArchivePackage ArchiveSmoke DerivedData/TestRuns/ArchiveSmoke`；覆盖目录、中文、空目录、密码、错误、同名、越界、取消与清理。服务实现、审查修复和 UI 集成后均有退出 0 记录，见下方阶段结果。

- `FileStoreSmoke` 在项目内被忽略的 `DerivedData/TestRuns/` 中真实创建、导入、移动、复制、重命名、删除文件，结果符合断言。
- `xcodebuild` 针对 generic iOS Simulator 编译成功，代码签名关闭。
- 下载输入仅接受 HTTP(S) URL；进度、暂停/继续与完成文件由真实 URLSession 回调驱动。
- 重建 DownloadManager 后，已完成文件与中断任务列表仍可见；删除任务后不再恢复。
- UI 使用系统文件导入、QuickLook 预览和系统分享；没有数据丢失式覆盖。
- 使用可连接的 iPhone 18 Pro（iOS 27.0）运行应用并检查导航与文件操作；XCTest runner 未执行到测试方法时，不声称交互已经验证。

## 第一阶段运行条件

- 受限终端运行 `simctl list devices available` 因 CoreSimulatorService 连接失败；提高终端权限后退出 0，识别到 iPhone 18 Pro（iOS 27.0）。
- 后续各阶段继续使用真实文件或请求验证。未获视觉验证要求，不主动截图。

## 第一阶段 Task 4（2026-09-30）

- `swiftc -module-cache-path DerivedData/ModuleCache ShuReplica/WorkspaceCategory.swift ShuReplica/FileStore.swift Tests/FileBatchSmoke.swift -o DerivedData/FileBatchSmoke && DerivedData/FileBatchSmoke DerivedData/TestRuns/FileBatchTask4Red`：更新嵌套归组断言后退出 133，断言命中原逻辑；修正后改用 `FileBatchTask4Green` 退出 0。
- `swiftc -module-cache-path DerivedData/ModuleCache ShuReplica/WorkspaceCategory.swift ShuReplica/FileStore.swift Tests/FileStoreSmoke.swift -o DerivedData/FileStoreSmoke && DerivedData/FileStoreSmoke DerivedData/TestRuns/FileStoreTask4`：退出 0。
- `swiftc -module-cache-path DerivedData/ModuleCache ShuReplica/WorkspaceCategory.swift ShuReplica/FileStore.swift Tests/WorkspaceCategorySmoke.swift -o DerivedData/WorkspaceCategorySmoke && DerivedData/WorkspaceCategorySmoke DerivedData/TestRuns/WorkspaceCategoryTask4`：退出 0。
- `swiftc -module-cache-path DerivedData/ModuleCache ShuReplica/DownloadRequest.swift Tests/DownloadRequestSmoke.swift -o DerivedData/DownloadRequestSmoke && DerivedData/DownloadRequestSmoke`：退出 0。
- `swiftc -module-cache-path DerivedData/ModuleCache ShuReplica/WorkspaceCategory.swift ShuReplica/FileStore.swift ShuReplica/DownloadRequest.swift ShuReplica/DownloadManager.swift Tests/DownloadManagerSmoke.swift -o DerivedData/DownloadManagerSmoke`：退出 0。用 `/usr/bin/python3 -m http.server 8765 --bind 127.0.0.1 --directory Tests/fixtures` 启动本地服务，`DerivedData/DownloadManagerSmoke DerivedData/TestRuns/DownloadManagerTask4` 退出 0，随后停止服务。
- `xcodebuild -quiet -project ShuReplica.xcodeproj -scheme ShuReplica -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData/ShuReplica CODE_SIGNING_ALLOWED=NO build`：提高终端权限后退出 0；`-sdk iphoneos -destination 'generic/platform=iOS'` 对应命令退出 0。应用与 UI 测试目标的 `build-for-testing` 退出 0。部署目标仍为 18.0。
- 两次 `xcodebuild ... -only-testing:ShuReplicaUITests test` 均停在 runner 启动阶段，无测试方法事件；首次终止退出 75，原始日志含 `NSMachErrorDomain Code=-308 (ipc/mig) server died`；第二次关闭并行测试后仍停在 `Launch session started`，人工终止。UI RED/GREEN 均无有效执行结果。
- `xcrun simctl bootstatus AF847C96-0AAE-4682-B1B4-45A9DFA161EC -b` 退出 0，但报告 `Data Migration Failed`。`xcrun simctl install ... ShuReplica.app` 最终退出 0；`xcrun simctl launch ... com.happu.shureplica` 退出 0，返回 PID 16264。未执行标签切换、文件夹导航、导入或动态字体的运行时交互检查；未截图或进行视觉检查。

## Task 4 审查修复第 1 轮

- 增加 `canGroup` 测试后，`FileBatchSmoke` 编译因缺少成员退出 1；实现后真实文件测试退出 0，覆盖未知类型、目录、符号链接及 Downloads/共享子目录排除。
- `FileStoreSmoke`、`WorkspaceCategorySmoke`、`FileBatchSmoke`、`DownloadRequestSmoke`、本地 HTTP 下的 `DownloadManagerSmoke` 均退出 0；具体命令及输出记录在 Task 4 报告。
- 最终 generic Simulator、generic Device、UI target `build-for-testing` 均退出 0；具体命令及日志见 Task 4 报告。XCTest runner 本轮未重试，UI 交互修复仍无运行证据。

## ZIP 开始前回归（2026-09-30 18:48）

- `swiftc -module-cache-path DerivedData/ModuleCache ShuReplica/WorkspaceCategory.swift ShuReplica/FileStore.swift Tests/FileStoreSmoke.swift -o DerivedData/FileStoreSmoke && DerivedData/FileStoreSmoke DerivedData/TestRuns/ZipBaselineFileStore`：退出 0，FileStore smoke passed。
- 同样编译 `Tests/FileBatchSmoke.swift` 并运行 `DerivedData/TestRuns/ZipBaselineFileBatch`：退出 0，FileBatch smoke passed。
- 同样编译 `Tests/WorkspaceCategorySmoke.swift` 并运行 `DerivedData/TestRuns/ZipBaselineCategory`：退出 0，WorkspaceCategory smoke passed。
- `swiftc -module-cache-path DerivedData/ModuleCache ShuReplica/DownloadRequest.swift Tests/DownloadRequestSmoke.swift -o DerivedData/DownloadRequestSmoke && DerivedData/DownloadRequestSmoke`：退出 0，DownloadRequest smoke passed。
- 四个命令均有宿主 `DVTFilePathFSEvents` 与 `DARWIN_USER_CACHE_DIR` 警告；这些警告未导致自检失败，未声称输出无警告。
- `swiftc -module-cache-path DerivedData/ModuleCache ShuReplica/WorkspaceCategory.swift ShuReplica/FileStore.swift ShuReplica/DownloadRequest.swift ShuReplica/DownloadManager.swift Tests/DownloadManagerSmoke.swift -o DerivedData/DownloadManagerSmoke`：退出 0。项目 fixtures 上运行仅监听 127.0.0.1:8765 的 Python HTTP 服务后，`DerivedData/DownloadManagerSmoke DerivedData/TestRuns/ZipBaselineDownload`：退出 0，DownloadManager smoke passed，真实 200／404／暂停继续／重启恢复均经过断言，服务已通过 Ctrl-C 退出 0。

## ZIP 服务主代理独立验证

- `swift run --scratch-path DerivedData/ArchivePackage ArchiveSmoke DerivedData/TestRuns/ArchiveIndependent`：退出 0，输出 `ArchiveSmoke passed: roundtrip, interoperability, password, collision, boundaries, malicious paths, cancellation, cleanup`。
- `simctl list devices available -j`：退出 0，完整 JSON 筛选 iPhone 18 Pro，UDID `AF847C96-0AAE-4682-B1B4-45A9DFA161EC`，isAvailable=true、state=Booted。本检查未执行 UI 操作。

## ZIP 审查修复第 1 轮

- 新增重复／冲突、__MACOSX 文件、__MACOSX 空目录三个真实用例，修复前分别退出 133。实现者记录位于 `.superpowers/sdd/2026-09-30-shu-zip/task-1-report.md` 末尾。
- 最终 ArchiveSmoke 与 generic Simulator 构建均退出 0；实现提交 `52c1a4131414150142d9a0ce46fbfdac217e928f`，已普通推送 origin/main。构建仍有 supported-platforms 提示，未声称无警告。
- 主代理 `swift run --scratch-path DerivedData/ArchivePackage ArchiveSmoke DerivedData/TestRuns/ArchiveFixIndependent`：退出 0，输出 `ArchiveSmoke passed: roundtrip, interoperability, password, collisions, __MACOSX, CRC, boundaries, malicious paths, cancellation, cleanup`。
- 磁盘耗尽、清理权限失败未实际诱发；触控与视觉仍没有运行证据。

## ZIP UI 集成验证（2026-09-30）

- 实现 `4b30df6b139c78b3cb89f8b2f7583f4603c23c7b`；完整命令、退出码和生命周期核查见 `.superpowers/sdd/2026-09-30-shu-zip/task-2-report.md`。
- `swift run --scratch-path DerivedData/ArchivePackage ArchiveSmoke DerivedData/TestRuns/ZipTask2Archive`：退出 0；主代理核对 `DerivedData/zip-task2-archive.log` 的完整通过输出。
- FileStoreSmoke、FileBatchSmoke、WorkspaceCategorySmoke、DownloadRequestSmoke 均退出 0；DownloadManagerSmoke 在项目 fixtures 的真实 127.0.0.1:8765 HTTP 服务下退出 0，实际 200／404、暂停继续及恢复断言通过，服务已停止。
- generic Simulator、generic Device 和 UI target `build-for-testing` 最终均退出 0。日志为 `DerivedData/zip-task2-simulator.log`、`zip-task2-device.log`、`zip-task2-ui-build-final.log`；supported-platforms 提示仍存在。首次 UI 构建与 Device 共用目录产生 build.db 锁冲突退出 65，Device 完成后顺序复跑退出 0。
- iPhone 18 Pro（iOS 27.0）安装退出 0；安装完成后顺序 `simctl launch` 退出 0，返回 PID 17364。首次 launch 在 install 尚未结束时发起，虽最终退出 0，不采用该顺序作为推荐流程。
- UI 测试先于入口实现添加，未重试已有两次失败的 runner。源检查退出 1 不等同 XCTest RED，测试目标编译不等同 UI GREEN；触控、视觉和交互式取消／关闭／重开尚无运行证据。

## ZIP 独立审查

- 服务修复复查、Task 2 规格与代码质量审查通过；最终整体审查覆盖 `5d66f4a..4b30df6`，结论 Ready Yes，无严重／重要问题。
- UI 现有进度区标题断言不能证明动态进度或关闭重开；runner 恢复后仍需补充真实多条目交互测试。supported-platforms 提示保留为环境诊断项，未证明它与 runner 阻碍存在因果关系。
- 最终审查建议已由 `2b556f421ef4910bbe0ef767c39f33ea9d206b9d` 补齐：四种危险路径／链接统一断言拒绝发布、暂存清理，保留越界与 sentinel 保护。`swift run --scratch-path DerivedData/ArchivePackage ArchiveSmoke DerivedData/TestRuns/ArchiveFinalFix` 退出 0（`DerivedData/archive-final-fix-green.log`）；唯一针对修复复查确认 ADDRESSED，无新增严重／重要／次要问题，Ready Yes。仅测试改变，未重复产品构建或 UI runner。
