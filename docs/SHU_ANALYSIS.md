# Shu 1.2.4 离线分析与 Swift 复刻

## 概述

本次针对用户提供的 `Shu.app` 完成离线资源分析，并扩展现有 SwiftUI 工程。用户要求完整复刻可见页面与主要操作，使用 Liquid Glass；少见格式允许明确提示不支持。资源支持三个栏目及工作区分类；未运行原版界面，精确布局与视觉相似度尚未验证。

## 授权与方法

用户在本任务中确认拥有或已获授权分析、复刻本地 `Payload/Shu.app`。逆向范围为离线静态分析，记录在 `work/payload-liquid-glass/scope.md`，`case-guard.sh` 校验通过。未对目标进行网络请求、动态注入或二进制修改。

## 证据与结论

| 证据 | 可复现位置 | 结论 | 置信度 |
|---|---|---|---|
| E-001 | `Payload/Shu.app/Info.plist` | 显示名 Shu、版本 1.2.4、包名 `com.pixelcyber.shu`；支持 iPhone/iPad 和多种文档类型。 | 高 |
| E-002 | `Payload/Shu.app/zh-Hans.lproj/Localizable.strings` 中 `tab.*`、`file.*`、`download.*` 键 | 主要栏目为“文件、下载、更多”；文件项有导入、预览、复制、移动、删除等操作，下载可填链接与请求头。 | 高 |
| E-003 | `Payload/Shu.app/zh-Hans.lproj/ShuFile.strings` | 工作区包含“下载”“共享”，并有文稿、图片、视频、音频等分类。 | 高 |
| E-004 | `Payload/Shu.app/zh-Hans.lproj/guide.webarchive` | 内置指南描述文件归组、格式转换、解压和 Wi-Fi 共享；这些操作属于完整复刻范围。 | 高 |
| E-005 | `Payload/Shu.app/Assets.car` 和可见资源 | 缺少可直接运行的原版界面及完整屏幕截图，精确布局、间距和色彩无法仅凭字符串确认。 | 中 |
| E-006 | `otool -L`、`otool -l` 对 `Payload/Shu.app/Shu` 的输出 | Mach-O 的 `cryptid=0`；链接 ZipArchive、UnrarKit、7zSDK、WebServer、CFNetwork、QuickLook 等库。依赖关系本身不证明具体功能已经执行。 | 高 |

可执行文件 SHA-256：`0a4d9329c354c8840d31738ab61b8a604af5a57bc9f69d817f54343c93c14f2a`。

读取 plist 的复现命令：

```bash
/usr/bin/python3 -c 'import plistlib; p=plistlib.load(open("Payload/Shu.app/Info.plist","rb")); print(p["CFBundleDisplayName"], p["CFBundleShortVersionString"], p["CFBundleIdentifier"])'
otool -L Payload/Shu.app/Shu
otool -l Payload/Shu.app/Shu
shasum -a 256 Payload/Shu.app/Shu
```

## Evidence → Finding → Path

- **E-001 至 E-004**：来源与复现位置见上表；plist 和 webarchive 使用 Python `plistlib` 读取，内容哈希未单独记录。
- **E-006**：来源为主可执行文件；上述命令可重现导入库、加密标志和 SHA-256。
- **F-001**：`severity=n/a_re`，`evidence_ids=[E-002,E-003]`，`confidence=high`，`location=本地化资源`，`status=confirmed`。Shu 的可见栏目和工作区分类可由资源确认。
- **F-002**：`severity=n/a_re`，`evidence_ids=[E-004,E-006]`，`confidence=high`，`location=内置指南与 Mach-O 加载命令`，`status=confirmed`。指南提及多格式处理与共享，主程序链接相关框架；当前已实现 ZIP，其他格式处理和传输尚待实施。
- **P-001**：`path_type=solve`。读取本地资源（E-001 至 E-004）→ 确认首版栏目与范围（F-001）→ 用 SwiftUI、FileManager、URLSession 实现 → 运行自检与构建。
- **当前证据**：本次授权、路由、范围校验和资源证据见 `work/payload-liquid-glass/`；实施进度和验证结果见 `memory/progress.md` 与 `memory/verify.md`。

## 当前结构

```mermaid
flowchart TD
    A[Happu] --> B[文件]
    A --> C[下载]
    A --> D[更多]
    B --> E[工作区与文件分类]
    E --> L[Documents 文件夹]
    L --> F[导入与文件夹]
    L --> G[预览、搜索与整理]
    L --> M[ZIP 打包与普通／密码解压]
    C --> H[HTTP(S) 链接及请求头]
    H --> I[URLSession 下载任务]
    I --> J[Documents/Downloads]
    D --> K[文件排序与关于]
```

文件页面使用 SwiftUI `List`、`NavigationStack`、系统文件导入、QuickLook 与分享面板，提供分类目录、归组、批量复制、移动、删除和选择操作。系统 `TabView`、导航栏及工具栏在 iOS 26 及更高版本采用系统玻璃外观。下载页面使用 `URLSessionDownloadTask`，支持进度、暂停、继续、删除及任务持久化；HTTP 非 2xx 响应判为失败。文件写入遇到同名项时自动编号，避免覆盖。

ZIP 使用固定版本 SSZipArchive 2.6.0，提供单项及批量打包、普通／密码解压、目的目录选择、进度、取消、错误重试与系统分享。处理在后台执行，结果在独立暂存目录完成并核对后发布，同名自动编号。取消在条目边界生效；关闭处理中页面等待任务终止。其他归档格式在入口明确提示不支持解压。

## 验证与界限

- `WorkspaceCategorySmoke`、`FileStoreSmoke`、`FileBatchSmoke`：真实分类目录初始化、导入、重命名、复制、移动、删除和批量归组通过。
- `DownloadRequestSmoke`：HTTP(S) 链接和请求头校验通过。
- `DownloadManagerSmoke`：本地 HTTP 服务返回 200、404，暂停后继续及任务恢复的真实请求通过。
- `ArchiveSmoke`：真实中文／隐藏文件／空目录往返、独立工具兼容、密码、CRC、重复与冲突条目、合法 __MACOSX、恶意路径与链接、同名保护及取消清理通过；未实际诱发磁盘耗尽和系统清理权限故障。
- `xcodebuild`：generic iOS Simulator 与 generic iOS Device 的 Debug 编译均通过，退出码 0；生成的设备版 `.app` 已核对显示名与包名。
- 获准提高终端权限后，`simctl` 识别到 iOS 27 的 iPhone 18 Pro。应用安装与启动退出 0；XCTest runner 两次未进入测试方法，UI 交互验收仍未完成。未进行视觉检查。
- 下载任务跨重启恢复已实现并通过自检；已下载文件保留在 `Documents/Downloads`。
- ZIP UI 测试目标编译通过；已有 XCTest runner 启动阻碍，新增菜单、密码和处理页测试未执行到测试方法，未声明触控或视觉验收通过。
- PDF／图片、媒体、文本与结构化文档转换、下载增强、局域网传输和设置增强尚待实施，整体复刻未完成。

在 Xcode 中打开 `Happu.xcodeproj`，选择 Happu scheme 和 iOS 18 或更高版本的设备运行；实体设备需在 Xcode 配置签名团队。当前使用 Xcode 27，部署目标为 iOS 18。首页标题和应用名称为 Happu；“更多 → 关于”显示本地时区的编译时间，每次构建自动更新。
