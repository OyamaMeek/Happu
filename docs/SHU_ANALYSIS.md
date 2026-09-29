# Shu 1.2.4 离线分析与 Swift 复刻

## 概述

本次针对用户提供的 `Shu.app` 完成离线资源与 Mach-O 依赖分析，并实现可构建的 SwiftUI 首版。证据明确支持三个栏目及工作区分类；原版二进制链接多种压缩和预览框架，但没有执行原版界面，因此不推断具体页面布局。复刻版覆盖用户选定的文件管理与下载功能，视觉相似度仍需在设备上对照原版确认。

## 授权与方法

用户在本任务中确认拥有或已获授权分析、复刻本地 `Payload/Shu.app`。逆向范围为离线静态分析，记录在 `work/shu-ios-replica/scope.md`，`case-guard.sh` 校验通过。未对目标进行网络请求、动态注入或二进制修改。

## 证据与结论

| 证据 | 可复现位置 | 结论 | 置信度 |
|---|---|---|---|
| E-001 | `Payload/Shu.app/Info.plist` | 显示名 Shu、版本 1.2.4、包名 `com.pixelcyber.shu`；支持 iPhone/iPad 和多种文档类型。 | 高 |
| E-002 | `Payload/Shu.app/zh-Hans.lproj/Localizable.strings` 中 `tab.*`、`file.*`、`download.*` 键 | 主要栏目为“文件、下载、更多”；文件项有导入、预览、复制、移动、删除等操作，下载可填链接与请求头。 | 高 |
| E-003 | `Payload/Shu.app/zh-Hans.lproj/ShuFile.strings` | 工作区包含“下载”“共享”，并有文稿、图片、视频、音频等分类。 | 高 |
| E-004 | `Payload/Shu.app/zh-Hans.lproj/guide.webarchive` | 内置指南描述文件归组、格式转换、解压和 Wi-Fi 共享；这些功能未进入本次用户选择的首版范围。 | 高 |
| E-005 | `Payload/Shu.app/Assets.car` 和可见资源 | 缺少可直接运行的原版界面及完整屏幕截图，精确布局、间距和色彩无法仅凭字符串确认。 | 中 |
| E-006 | `work/shu-ios-replica/evidence/inspect_macho.py` 对 `Payload/Shu.app/Shu` 的输出 | 17,045,104 字节的 arm64 Mach-O 可执行文件，`LC_ENCRYPTION_INFO_64` 在 `0xd38`，`cryptid=0`；链接 ZipArchive、UnrarKit、7zSDK、WebServer、CFNetwork、QuickLook 等库。依赖关系本身不证明具体功能已经执行。 | 高 |

可执行文件 SHA-256：`0a4d9329c354c8840d31738ab61b8a604af5a57bc9f69d817f54343c93c14f2a`。

读取 plist 的复现命令：

```bash
/usr/bin/python3 -c 'import plistlib; p=plistlib.load(open("Payload/Shu.app/Info.plist","rb")); print(p["CFBundleDisplayName"], p["CFBundleShortVersionString"], p["CFBundleIdentifier"])'
/usr/bin/python3 work/shu-ios-replica/evidence/inspect_macho.py Payload/Shu.app/Shu
```

## Evidence → Finding → Path

- **E-001 至 E-004**：来源与复现位置见上表；plist 和 webarchive 使用 Python `plistlib` 读取，内容哈希未单独记录。
- **E-006**：来源为主可执行文件；上述 `inspect_macho.py` 命令可重现导入库、偏移和 SHA-256。
- **F-001**：`severity=n/a_re`，`evidence_ids=[E-002,E-003]`，`confidence=high`，`location=本地化资源`，`status=confirmed`。Shu 的可见栏目和工作区分类可由资源确认。
- **F-002**：`severity=n/a_re`，`evidence_ids=[E-004,E-006]`，`confidence=high`，`location=内置指南与 Mach-O 加载命令`，`status=confirmed`。指南提及多格式处理与共享，主程序链接相关框架；本次首版不覆盖。
- **P-001**：`path_type=solve`。读取本地资源（E-001 至 E-004）→ 确认首版栏目与范围（F-001）→ 用 SwiftUI、FileManager、URLSession 实现 → 运行自检与构建。
- **时间线**：授权、路由、范围校验、资源分析和实现记录见 `work/shu-ios-replica/timeline.md`。

## 首版结构

```mermaid
flowchart TD
    A[Shu Replica] --> B[文件]
    A --> C[下载]
    A --> D[更多]
    B --> E[工作区与文件分类]
    E --> L[Documents 文件夹]
    L --> F[导入与文件夹]
    L --> G[预览、搜索与整理]
    C --> H[HTTP(S) 链接及请求头]
    H --> I[URLSession 下载任务]
    I --> J[Documents/Downloads]
    D --> K[文件排序与关于]
```

文件页面使用 SwiftUI `List`、`NavigationStack`、系统文件导入、QuickLook 与分享面板。下载页面使用 `URLSessionDownloadTask`，支持进度、暂停、继续和删除；HTTP 非 2xx 响应判为失败。文件写入遇到同名项时自动编号，避免覆盖。

## 验证与界限

- `FileStoreSmoke`：真实文件夹创建、导入、重命名、复制、移动、删除通过。
- `DownloadRequestSmoke`：HTTP(S) 链接和请求头校验通过。
- `DownloadManagerSmoke`：本地 HTTP 服务返回 200、404，及暂停后继续的真实请求通过。
- `xcodebuild`：generic iOS Simulator 与 generic iOS Device 的 Debug 编译均通过，退出码 0；生成的设备版 `.app` 已核对显示名与包名。
- 沙箱内 CoreSimulatorService 无法连接；只读检查本机模拟器服务后发现 `simctl list runtimes` 为空，因此没有可启动的 iOS 模拟器。未获得可证明视觉接近原版的截图。
- 下载任务保存在运行内存中，应用重启后任务列表与续传数据不会恢复；已下载文件仍保留在 `Documents/Downloads`。
- 本次未实现多格式转换、镜像解压、局域网服务器或原生 Liquid Glass。

在 Xcode 中打开 `ShuReplica.xcodeproj`，选择 iOS 18 或更高版本的设备运行；实体设备需在 Xcode 配置签名团队。项目当前使用 Xcode 16.4 和 iOS 18.5 SDK 构建。
