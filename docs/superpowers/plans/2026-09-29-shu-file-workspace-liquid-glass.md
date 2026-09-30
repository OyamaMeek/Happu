# Shu File Workspace and Liquid Glass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完成 Shu Replica 第一阶段的真实文件归组、批量整理、系统导入导出和 iOS 26 原生 Liquid Glass 导航。

**执行状态（2026-09-30）：** Tasks 1–4 的代码、真实文件测试、构建与提交已完成，审查发现均已修正；Task 4 的模拟器交互验收仍待 XCTest runner 运行测试方法。下方复选框保留原计划步骤，实际执行记录见 `memory/progress.md`、`memory/verify.md` 与 `docs/CHANGELOG.md`。

**Architecture:** 沿用现有 SwiftUI 三栏和 `FileStore`，新增一个共享的文件分类定义，并让批量操作复用现有单文件方法。页面只持有选择状态，操作后重新读取真实目录；系统 `TabView`、工具栏和底部操作栏提供 iOS 26 的玻璃外观。

**Tech Stack:** Swift 5、SwiftUI、Foundation、UniformTypeIdentifiers、Xcode 27；无新增第三方依赖。

**Spec:** `docs/superpowers/specs/2026-09-29-shu-file-workspace-liquid-glass-design.md`

## Global Constraints

- 部署目标保持 iOS 18.0；iOS 26 上使用系统 Liquid Glass，旧系统使用对应系统外观。
- 内建分类为文稿、图片、视频、音频、电子书、压缩文档、镜像文件、脚本配置、工具配置；`Downloads` 和“共享”保持独立。
- 归组可处理工作区根目录及其它普通文件夹中明确选择的直接子文件，目标为工作区根目录的分类文件夹；不递归，不移动 `Downloads` 或“共享”中的内容；未知类型保留原位置。
- 文件写入不能覆盖已有内容；批量操作必须显示部分成功和具体失败项。
- 不新增第三方依赖；不主动截图或进行视觉检查。

## Review Focus

- 根目录已存在名为“文稿”的普通文件：初始化应失败并保留该文件（Task 1 测试）。
- 大写扩展名与无扩展名文件：前者按类型归组，后者跳过（Task 1、2 测试）。
- 指向工作区外的符号链接：批量操作报告失败，外部文件不改变（Task 2 测试）。
- 批次中途有文件已被移动或删除：保留先前成功项并报告失败项（Task 2 测试）。
- 多文件导入有一个源文件不可读：可读项导入，错误项报告，不覆盖现有文件（Task 3 测试）。

## File Map

- 新增 `ShuReplica/WorkspaceCategory.swift`：分类名称、图标和文件类型判定。
- 修改 `ShuReplica/FileStore.swift`：初始化分类目录、归组和批量操作结果；复用现有单文件操作。
- 修改 `ShuReplica/FilesView.swift`：分类首页、归组入口、选择状态、批量工具栏及结果提示。
- 修改 `ShuReplica.xcodeproj/project.pbxproj`：将分类文件加入应用 target。
- 新增 `Tests/WorkspaceCategorySmoke.swift`、`Tests/FileBatchSmoke.swift`，并调整 `Tests/FileStoreSmoke.swift` 的内建目录预期。
- 完成实现后更新 `memory/progress.md`、`memory/verify.md` 和 `docs/CHANGELOG.md`。

### Task 1: 分类定义与工作区初始化

**Files:** Create `ShuReplica/WorkspaceCategory.swift`, `Tests/WorkspaceCategorySmoke.swift`; modify `ShuReplica/FileStore.swift`, `Tests/FileStoreSmoke.swift`, `ShuReplica.xcodeproj/project.pbxproj`.

**Interfaces:** Produce `enum WorkspaceCategory: String, CaseIterable` with cases `document="文稿"`, `picture="图片"`, `video="视频"`, `audio="音频"`, `ebook="电子书"`, `archive="压缩文档"`, `diskImage="镜像文件"`, `script="脚本配置"`, `utility="工具配置"`, plus `var systemImage: String` and `static func forFile(_ url: URL) -> WorkspaceCategory?`. `FileStore.init(root:)` creates these nine directories, `Downloads` and“共享” once. Task 2 consumes this classification.

- [ ] **Step 1: Write failing category and collision checks.** `WorkspaceCategorySmoke` asserts `.forFile("A.EPUB") == .ebook`, `.forFile("B.JPG") == .picture`, `.forFile("unknown.blob") == nil`; a pre-existing root file named“文稿” makes `FileStore(root:)` throw without changing its bytes. In `FileStoreSmoke`, store the initial directory count and assert the current `beforeDelete`/`afterDelete` counts equal that baseline plus 3/2.
- [ ] **Step 2: Verify red.** Run `swiftc -module-cache-path DerivedData/ModuleCache ShuReplica/FileStore.swift Tests/WorkspaceCategorySmoke.swift -o DerivedData/WorkspaceCategorySmoke`; expect unresolved `WorkspaceCategory` and the missing initialization behavior.
- [ ] **Step 3: Implement classification and startup folders.** Put known eBook/archive/disk/script/utility extensions ahead of broad `UTType` document, image, video and audio matches; add the new Swift file to the app target.
- [ ] **Step 4: Verify green.** Run `swiftc -module-cache-path DerivedData/ModuleCache ShuReplica/WorkspaceCategory.swift ShuReplica/FileStore.swift Tests/WorkspaceCategorySmoke.swift -o DerivedData/WorkspaceCategorySmoke`, then `DerivedData/WorkspaceCategorySmoke DerivedData/TestRuns/WorkspaceCategorySmoke`. Repeat with `Tests/FileStoreSmoke.swift` and output `DerivedData/FileStoreSmoke`; expect both processes exit 0.
- [ ] **Step 5: Commit.** Stage only the five files above; commit `feat: initialize Shu workspace categories`.

### Task 2: 归组与批量文件操作

**Files:** Create `Tests/FileBatchSmoke.swift`; modify `ShuReplica/FileStore.swift`.

**Interfaces:** Produce `enum FileBatchAction { case copy(to: URL), move(to: URL), delete, group }`, `struct FileBatchResult { let succeeded: [URL]; let skipped: [URL]; let failures: [(url: URL, message: String)] }`, and `FileStore.perform(_ action: FileBatchAction, on items: [URL]) -> FileBatchResult`. Successful output URLs represent copied/moved/grouped files; delete returns original URLs.

- [ ] **Step 1: Write failing real-file checks.** `FileBatchSmoke` groups root `photo.PNG`, `book.EPUB`, `unknown` (no extension), an outside symlink and a file under“共享”: assert `succeeded.count == 2`, `skipped.count == 2`, `failures.count == 1`, and unchanged unknown/shared/external bytes. Pre-create `图片/photo.PNG`; assert the grouped file receives a unique name. Copy one existing and one missing item: assert one success and one failure. Move a folder into its child: assert failure and unchanged tree. Delete one of two files: assert only the selected file disappears.
- [ ] **Step 2: Verify red.** Run `swiftc -module-cache-path DerivedData/ModuleCache ShuReplica/WorkspaceCategory.swift ShuReplica/FileStore.swift Tests/FileBatchSmoke.swift -o DerivedData/FileBatchSmoke`; expect unresolved `FileBatchAction`/`perform`.
- [ ] **Step 3: Implement `perform`.** Iterate selected items, call existing `copy`/`move`/`delete`; for `group`, first check the source stays inside root, then classify ordinary files and move to the root category. Convert per-item thrown errors to `failures`, keep unknown or protected items in `skipped`, and never hide partial success.
- [ ] **Step 4: Verify green.** Compile with the Step 2 command, then run `DerivedData/FileBatchSmoke DerivedData/TestRuns/FileBatchSmoke`; expect exit 0. Re-run Task 1 smoke programs.
- [ ] **Step 5: Commit.** Stage only `ShuReplica/FileStore.swift` and `Tests/FileBatchSmoke.swift`; commit `feat: add Shu batch file operations`.

### Task 3: 多文件导入结果

**Files:** Modify `ShuReplica/FileStore.swift`, `Tests/FileBatchSmoke.swift`.

**Interfaces:** Produce `FileStore.importFiles(_ sources: [URL], into folder: URL) -> FileBatchResult`; it calls existing security-scoped `importFile` and returns imported URLs in `succeeded`.

- [ ] **Step 1: Add failing import check.** In `FileBatchSmoke`, import one readable file and one missing path into a folder containing the same name; assert one uniquely named success, one failure, and unchanged original bytes.
- [ ] **Step 2: Verify red.** Re-run Task 2 compile command; expect compile failure for missing `importFiles`.
- [ ] **Step 3: Implement `importFiles`.** Call `importFile` once per source and collect results; preserve the security-scope access and unique destination logic already inside `importFile`.
- [ ] **Step 4: Verify green.** Re-run the Task 2 compile and run commands, plus the Task 1 `FileStoreSmoke` commands; expect exit 0.
- [ ] **Step 5: Commit.** Stage only the two files above; commit `feat: report multi-file import results`.

### Task 4: 文件界面与系统玻璃导航

**Files:** Modify `ShuReplica/FilesView.swift`, `memory/progress.md`, `memory/verify.md`, `docs/CHANGELOG.md`.

**Interfaces:** `FilesHomeView` reads `WorkspaceCategory.allCases` and invokes `FileStore.perform(.group, on:)` for root files; `FolderView` maintains a `Set<URL>` selection, invokes `perform`/`importFiles`, uses system share for selected URLs, and displays `FileBatchResult`. Existing `ShuReplicaApp` `TabView` and `NavigationStack` remain the system navigation layer.

- [ ] **Step 1: Wire the approved interactions.** Remove directory creation from `onAppear`; add root grouping, edit mode, all/invert selection, batch copy/move/share/delete/group, and per-item result feedback. Use system toolbar items including a bottom action group, with accessible labels. Keep existing single-file actions and QuickLook.
- [ ] **Step 2: Verify the full behavior suite.** Re-run Tasks 1–3 smoke commands. Compile `DownloadRequestSmoke` from `ShuReplica/DownloadRequest.swift Tests/DownloadRequestSmoke.swift`, and `DownloadManagerSmoke` from `ShuReplica/WorkspaceCategory.swift ShuReplica/FileStore.swift ShuReplica/DownloadRequest.swift ShuReplica/DownloadManager.swift Tests/DownloadManagerSmoke.swift`, each to `DerivedData/<test-name>` and with `-module-cache-path DerivedData/ModuleCache`. Run the request smoke directly; serve `Tests/fixtures` with `/usr/bin/python3 -m http.server 8765 --bind 127.0.0.1 --directory Tests/fixtures`, run the manager smoke with `DerivedData/TestRuns/DownloadManagerSmoke`, then stop the server. Expect all processes exit 0; record commands and exits in `memory/verify.md`.
- [ ] **Step 3: Verify both iOS builds.** Run `xcodebuild -project ShuReplica.xcodeproj -scheme ShuReplica -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData/ShuReplica CODE_SIGNING_ALLOWED=NO build`, then `xcodebuild -project ShuReplica.xcodeproj -scheme ShuReplica -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath DerivedData/ShuReplica CODE_SIGNING_ALLOWED=NO build`; expect both exit 0 and iOS 18.0 deployment target.
- [ ] **Step 4: Complete interaction verification.** The app installed and launched on iPhone 18 Pro, while XCTest stopped before entering a test method. Once the runner works, exercise tabs, navigation, selection, import, and dynamic type on a simulator. Record results separately from build and launch checks. No screenshots without explicit user request.
- [ ] **Step 5: Record and commit.** Update `docs/CHANGELOG.md` with actual results and“待提交”, then stage only this task’s files and documentation. Commit `feat: add Shu workspace controls with native glass navigation`.
- [ ] **Step 6: Save the actual commit hash.** Replace“待提交” in the changelog with the Step 5 hash and commit that documentation update as `docs: record Shu workspace commit`.

Task 4 added an XCUITest target after the simulator became accessible. The test target compiles; on this machine, the runner stopped before entering any test method, so UI interaction remains unverified. File-changing behavior was verified with failing real-file tests before implementation.
