# Shu 本地网络共享实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. 沿用已选择的顺序实施、每任务独立审查和阶段整体审查；在当前 main 工作区执行，普通推送已配置的 origin/main。

**Goal:** 让同一 Wi-Fi 或个人热点上的设备通过浏览器或 WebDAV 操作选定应用目录，提供真实地址、二维码及可确认完成的停止清理。

**Architecture:** 固定 GCDWebServer 源码包提供 HTTP 核心及 DAV 解析，局部适配统一处理受限文件操作、完整上传发布与连接终止。单个 NetworkSharingService 管理会话及生命周期；原生页面和本地浏览器页面调用同一文件服务。

**Tech Stack:** Swift/SwiftUI、Objective-C、GCDWebServer 3.5.4（`1c36bf07c848476111d523057a3a63b05328ce2a`）、Darwin 文件描述符 API、libxml2、Network、CoreImage、XCTest/WKWebView。

**Spec:** [已确认设计](../specs/2026-10-03-shu-local-network-design.md)。用户“确认”批准该设计；本实施计划待用户审阅，尚未执行。

## Global Constraints

- 部署目标继续为 iOS 18，iOS 26 使用现有系统 Liquid Glass；不重构 PDF、图片、归档或媒体服务。
- 一次只运行一种模式，使用系统分配的可用端口，显示实际端口，不承诺固定 8080。
- 所有请求的源和目标都限制在本次共享根目录；拒绝原始或解码后的点路径、非法路径分隔、NUL、符号链接及链接祖先；不开放隐藏项目及内部暂存。
- 完整请求流式写到本会话的隐藏暂存，再执行无覆盖发布；同名上传、COPY/MOVE 不覆盖已有目标，零字节完整文件合法。
- 页面关闭、应用进入后台或锁屏后停止；回到前台保持停止状态，由用户重新启动；资源释放完成后才允许再次启动。
- 浏览器使用中文、本地资源及实际上传进度；文件名以文本节点呈现，不开放任意 CORS，NAT 自动映射关闭。
- 不新增账号、密码、后台常驻或公网映射；保留上游许可证，不增加 CocoaPods 或第二套依赖管理。
- 未经用户要求不截图或图像检查；二维码只验证编码内容。实际设备、热点及权限拒绝证据与模拟器结果分别记录。
- 每任务先取得行为 RED，再实现并取得 GREEN；只暂存本任务文件，更新 memory、CHANGELOG 与可见对话归档，Conventional Commits 后普通 push。历史用户改动保持原样。

## Review Focus

1. 定长或 chunked 请求截断、冲突 framing：失败不发布，已有文件不变，暂存最终清理。
2. 校验后目录替换、链接祖先、并发同名：操作时仍受共享根约束，仅一个发布成功，范围外 sentinel 不变。
3. 停止与 accept、读写回调、再次停止竞争：旧会话不发布，socket/句柄实际关闭后才可重新启动。
4. 中文、空格、XML/HTML 特殊名称及编码路径、恶意 PROPFIND/Destination：内容准确，不执行标记、不读取外部实体、不越界。
5. 无适用接口、IPv6、接口变化、权限弹窗及后台/锁屏：地址真实，监听/发现/权限状态分开，停止后不自动恢复。

## 文件职责

- `Vendor/GCDWebServer/`：本地 SwiftPM 包、Core/Requests/Responses/DAV、许可证及 `SOURCE.md`；不接入 WebUploader。记录固定来源、文件校验及每项局部修改。
- `NetworkSharingBridge/ShuNetworkFileAccess.h/.m`：共享根句柄、逐段路径检查、统一文件操作和会话暂存。
- `NetworkSharingBridge/ShuNetworkHTTPServer.h/.m`：HTTP 路由、流式请求/响应、连接跟踪与异步停止；`ShuNetworkDAVServer.h/.m`：DAV 路由复用同一文件操作。
- `NetworkSharingBridge/Resources/index.html`、`sharing.js`、`sharing.css`：中文浏览器页面及上传流程，通过包资源加载。
- `ShuReplica/NetworkSharingService.swift`：唯一产品会话；`NetworkSharingAddresses.swift`：实际接口地址；`NetworkSharingQRCode.swift`：CoreImage 编码；`NetworkSharingView.swift`：原生控制页面。
- `Tests/NetworkSmoke.swift`：Mac CLI 与 hosted iOS 共用真实请求断言；`NetworkRuntimeTests.swift`：iOS 服务测试；`NetworkBrowserRuntimeTests.swift`：真实 WKWebView 页面测试；`prepare_network_ui_fixtures.swift`：真实 UI 产物准备/核对。
- 修改 `Package.swift`、`ShuReplica.xcodeproj/project.pbxproj` 与现有 scheme 注册包和测试；Task 3 修改 `ShuReplicaApp.swift`、`MoreView.swift`、`FilesView.swift`、`Info.plist`、`Tests/ShuReplicaUITests.swift`。注册及 vendoring 属机械配置，功能代码按职责分段实施。

### Task 1：受限 HTTP 文件服务及完整停止

**Files:** 创建 Vendor 包、FileAccess/HTTPServer、NetworkSharingService、NetworkSmoke/NetworkRuntimeTests；修改包与 Xcode 注册。

**Interfaces:**
- `NetworkSharingMode: String, CaseIterable`，cases 为 `browser`、`webDAV`；`NetworkSharingStatus` 为 `stopped`、`starting`、`running`、`stopping`、`failed(String)`。
- `@MainActor final class NetworkSharingService: ObservableObject`：`init(root: URL)`、`start(folder: URL, mode: NetworkSharingMode) async throws`、`stop() async throws`；只读发布 `status: NetworkSharingStatus`、`sharedDirectory: URL?`、`mode: NetworkSharingMode?`、`listeningPort: UInt16?`、`canStart: Bool`。Task 1 实现 browser，Task 2 实现 webDAV。
- HTTPServer 的 Objective-C 入口为 `initWithWorkspaceURL:sharedDirectoryURL:error:`、`startWithMode:error:`、`stopWithCompletion:`（completion 携带可空 NSError）、只读 `port`；mode 使用明确的两值 NS_ENUM，Swift 层不暴露 Objective-C 细节。
- FileAccess 的公共接口：`initWithWorkspaceURL:sharedDirectoryURL:error:`；`listAtRelativePath:error:` 返回元数据字典数组；`openRegularFileAtRelativePath:error:` 返回调用方负责关闭的 int 描述符；`createDirectoryAtRelativePath:error:`、`removeItemAtRelativePath:error:`、`copyItemAtRelativePath:toRelativePath:move:error:` 返回 BOOL。源/目标均为相对路径，失败通过 NSError 报告；发布/暂存会话细节留在该对象内。
- `@MainActor NetworkChecks.http(root: URL) async throws -> Int`：返回实际通过检查数；CLI 仅在非 iOS 编译 `@main`，hosted 测试调用同一函数。
- 浏览器接口：`GET /api/list?path=<相对目录>` 返回 `{path, entries:[{name,isDirectory,size,modified}]}`；`GET/HEAD/PUT/DELETE /files/<逐段编码路径>`；`POST /api/directories` 接收 JSON `{path}`。创建/上传 201、删除 204、同名 409、非法输入 400、拒绝范围 403、真实 IO 失败 500，并给出原因；范围下载 206，非法范围 416。

- [ ] **Step 1：固定源码并注册可编译的失败入口。** 核对上游提交及许可证，保留 ARC、CFNetwork/zlib 链接，通过 SDK 的 `@import libxml2` 使用 XML 模块，不硬编码 SDK 目录；配置本地包与所有 smoke target excludes。服务入口暂明确抛出“网络共享服务尚未实现。”，不以编译失败代替行为 RED。
- [ ] **Step 2：添加真实 HTTP 测试。** 使用产品服务、真实临时工作区（`DerivedData/TestRuns`）、URLSession 与测试专用 BSD socket 客户端。断言中文/空格文件及多文件/空文件 PUT、列表、HEAD 无 body、GET 完整及范围字节、目录创建/删除；同名和并发同名分别 409、一个 201/一个 409，原文件不变。断言点路径/编码分隔/NUL、隐藏文件、各层链接、删除根被拒绝，真实祖先目录替换后外部 sentinel 不变。

  hosted 方法 `testHTTPFilesAndStop()` 调用 `NetworkChecks.http(root:)`；具体真实结果断言包含 `XCTAssertEqual(concurrentStatuses.sorted(), [201, 409])`、`XCTAssertEqual(downloadedBytes, sourceBytes)`、`XCTAssertEqual(sentinelAfter, sentinelBefore)`。
- [ ] **Step 3：运行 RED。** `swift run --scratch-path DerivedData/NetworkPackage NetworkSmoke DerivedData/TestRuns/NetworkHTTPRed http`；要求成功编译后实际请求流程因未实现入口失败，保存命令、退出码和失败断言。
- [ ] **Step 4：实现统一文件边界与 HTTP 操作。** FileAccess 在已打开的根目录句柄下逐段操作，用 `O_NOFOLLOW`/`fstatat` 识别链接和文件类型，操作前核实根身份；避免校验后按可变绝对路径重开。下载流消费已验证描述符。上传拥有隐藏会话目录中的描述符，完整关闭成功后以同卷排他 rename 发布；COPY/MOVE 的暂存和发布复用此边界。不能静默跳过目录中的隐藏项/链接而宣称完整复制成功。
- [ ] **Step 5：实现请求完成和停止语义。** 修正固定源码定长/chunked 回调忽略读取失败的问题及长度越界/framing 冲突；写入处理短写，描述符 0 合法，写入/关闭失败不发布。连接终止用实际 socket 能力，不调用 close 通知冒充关闭；弱连接登记避免循环持有。停止先失效会话、停止 accept，再终止连接、等待读写/句柄结束、清理；并发 stop 合并，失败保留诊断和资源状态并允许再次尝试清理，`canStart` 不能提前为真。拒绝建立连接路径只能关闭一次。
- [ ] **Step 6：添加真实故障及生命周期断言。** 原始 socket 分别截断定长/chunked、发送冲突 framing、取消上传；确认停止前真实暂存存在，停止后无可见部分文件/暂存、旧请求不能发布、新连接失败。中断下载、同时两次 stop、三个启动停止周期均验证。IO 错误使用真实只读目录或测试自己拥有的已关闭描述符诱发，分别记录组件 IO 与完整 HTTP 流程覆盖；不用 mock、产品测试开关或扫描未知描述符。
- [ ] **Step 7：运行 GREEN 与 iOS。** 同一 CLI 用新目录 `NetworkHTTPGreen http` 退出 0；按下方平台顺序构建并运行 `NetworkRuntimeTests/testHTTPFilesAndStop`，保存实际检查数、退出码、日志和 `NetworkHTTP.xcresult`。依赖下载/编译成功本身不证明服务正确。
- [ ] **Step 8：提交、普通推送、独立审查。** 提交 `feat: add local HTTP sharing and safe session shutdown`；审查覆盖本任务 BASE 至实际 HEAD 全部提交，规格及质量通过后才进入 Task 2。

### Task 2：WebDAV 与中文浏览器传输页面

**Files:** 创建 DAVServer 与三项本地网页资源、NetworkBrowserRuntimeTests；扩展 Service、NetworkSmoke/NetworkRuntimeTests，注册资源与 hosted 测试。

**Interfaces:** 消费 Task 1 的服务与文件边界；新增 `@MainActor NetworkChecks.dav(root: URL) async throws -> Int`。webDAV 使用同一端口的 `/` 作为共享根，browser 保持 Task 1 API；资源从模块 Bundle 读取，不依赖当前工作目录。

- [ ] **Step 1：写 DAV 行为测试。** 实际请求 OPTIONS、PROPFIND Depth 0/1、GET/HEAD、PUT、MKCOL、DELETE、COPY/MOVE，检查 207 XML href/propstat、真实文件字节和中文/空格/XML 特殊名称；未知属性返回对应 404。无限深度 403/finite-depth、无效 XML 400、未实现 LOCK/UNLOCK/PROPPATCH 501；不宣称完整 Class 1/2 或 Finder 兼容。Destination 外部 authority/端口/越界、源目标相同、目录移动至自身子目录均拒绝；已存在目标 `Overwrite: F` 为 412，T 或缺省为 409 并明确无覆盖策略。

  hosted 方法 `testDAVFiles()` 调用 `NetworkChecks.dav(root:)`；真实 COPY 冲突断言 `XCTAssertEqual(overwriteFalseStatus, 412)`、`XCTAssertEqual(overwriteTrueStatus, 409)`、`XCTAssertEqual(existingBytesAfter, existingBytesBefore)`。
- [ ] **Step 2：运行 DAV RED。** `swift run --scratch-path DerivedData/NetworkPackage NetworkSmoke DerivedData/TestRuns/NetworkDAVRed dav`；编译完成且测试因未实现 DAV 行为失败，记录实际断言，不用 Task 1 通过替代。
- [ ] **Step 3：实现 DAV 适配。** 保留上游 libxml2 解析/序列化，所有路径和变更交由 FileAccess，删除默认覆盖及未经验证的 Class 宣告；DTD/外部实体拒绝，用真实范围外文件和本地监测请求证明没有读入/发出请求。目录 COPY 先完整暂存，再排他发布；失败不出现部分目标。
- [ ] **Step 4：实现浏览器页面与来源校验。** 中文目录导航、多文件选择、逐项 XHR 上传真实进度、下载、新建目录、确认删除及失败原因/成功刷新；名称使用 textContent、路径逐段编码。浏览器修改请求的 Host/Origin 必须属于当前真实服务地址及端口，不能仅比较攻击者控制的 Host 与 Origin；不开放任意 CORS。DAV 无 Origin 请求按正常协议和相同 Host 边界处理。
- [ ] **Step 5：添加真实页面验证。** `NetworkBrowserRuntimeTests/testBrowserTransfer` 在 WKWebView 加载真实服务资源，执行 DOM 文件选择/上传、导航、新建、确认删除，检查进度事件、结果刷新及真实磁盘字节；测试文件来自实际夹具字节。HTML 特殊文件名无标记执行，跨来源修改被拒绝。该证据是 WebKit 页面流程，不能代替其它设备浏览器实测，不截图。
- [ ] **Step 6：运行 GREEN 与 hosted 测试。** CLI `NetworkDAVGreen dav` 退出 0，再以 curl 对同一服务执行真实 DAV 请求交叉核对；按平台顺序运行 `NetworkRuntimeTests/testDAVFiles` 和 `NetworkBrowserRuntimeTests/testBrowserTransfer`，结果 `NetworkDAVBrowser.xcresult`。Task 1 实现被修改时重跑其相关回归。
- [ ] **Step 7：提交、普通推送、独立审查。** 提交 `feat: add WebDAV and local browser file transfer`；本任务完整 BASE..HEAD 审查通过后进入 Task 3。

### Task 3：原生入口、真实地址/二维码及生命周期

**Files:** 创建 Addresses、QRCode、View 和 UI 夹具脚本；修改 Service、App、MoreView、FilesView、Info.plist、ShuReplicaUITests 及机械注册。

**Interfaces:**
- `NetworkSharingAddresses.urls(port: UInt16) throws -> [URL]`；`NetworkSharingQRCode.image(for url: URL) throws -> CGImage`；Service 增加只读发布 `accessURLs: [URL]`、`discoveryError: String?`。
- `NetworkSharingRequest: Identifiable` 包含 `initialFolder: URL`；`NetworkSharingView(store: FileStore, request: NetworkSharingRequest, onFinish: () -> Void)` 从环境消费唯一 Service。App 的 Runtime 增加 `sharing: NetworkSharingService` 并在 TabView 注入，两个入口及多窗口不能各自创建独立服务。
- 原生文案为“本地网络共享”“通过本地网络共享”；默认目录为工作区“共享”；`NSLocalNetworkUsageDescription` 为“允许同一 Wi-Fi 或热点上的设备访问你选择共享的文件夹。”；`NSBonjourServices` 为 `_http._tcp`。

- [ ] **Step 1：写地址、二维码及 UI RED。** 添加实际接口分类/URL 合法性与 CoreImage 内容解码检查；UI 方法 `testNetworkSharingEntrypoints`、`testNetworkSharingLifecycleAndTransfer` 从现有两入口启动，检查默认/预选目录、模式、更换目录、地址复制/二维码内容、真实上传后的文件列表、停止/关闭重开/后台手动重启。夹具脚本用真实 app container 准备文件并提供 `--verify` 字节及无暂存检查；运行未实现入口断言失败，构建失败不计 RED。

  在 `NetworkRuntimeTests/testAddressesAndQRCode` 中以当前服务实际 URL 编码并解码，断言 `XCTAssertEqual(decodedURL, accessURL.absoluteString)`；真实页面重开后断言 `XCTAssertTrue(app.buttons["启动"].isEnabled)`，同时用先前地址确认连接失败。
- [ ] **Step 2：实现实际地址与发现。** 使用 getifaddrs 加原生接口功能类型（如 `SIOCGIFFUNCTIONALTYPE`），不硬编码 en0；列出实际活跃 Wi-Fi/热点等适用接口，排除回环、蜂窝、未指定地址，正确表达 IPv6 scope。运行时监测接口变化、撤下旧地址并更新 QR；无适用接口明确提示。仅显式启动后用 NetService 注册实际端口，停止释放，不额外创建监听器。监听成功、Bonjour 注册、权限与可连接分别表达；没有通用权限查询 API，不把入站 TCP/模拟器成功标记为权限允许。
- [ ] **Step 3：实现两个原生入口和控制页。** 更多入口默认“共享”，目录菜单预选该目录，复用 FolderPicker；显示工作区相对路径、模式、开始/停止状态、真实地址复制与 QR、实际错误及清理重试。目录/模式变化先完成 stop；清理结束前不能 start。
- [ ] **Step 4：绑定实际生命周期。** Done 等待 stop 后再 onFinish、刷新文件列表与关闭；资源存活时禁用交互式 dismiss。App 的 background 与 protectedDataWillBecomeUnavailable 触发同一 stop，前台不自动恢复；不要把权限弹窗造成的每次 inactive 当作锁屏。关闭清理失败保留页面和可重试错误，不能假报成功。
- [ ] **Step 5：验证完整用户路径。** 运行新增两项 UI 方法和夹具 `--verify`， hosted/CLI 执行全部网络检查；保留已有六项 UI 方法。共享模块仅按实际影响范围运行一次回归；最终按平台顺序构建/安装/运行，结果 `NetworkUI.xcresult`。记录实际 methods/checks/失败/跳过和原始诊断，未取得视觉证据不宣称布局验证完成。
- [ ] **Step 6：取得设备证据或明确限制。** 条件允许时，用真实 iPhone 与同网段另一设备分别验证普通 Wi-Fi、个人热点、浏览器/DAV 传输、权限拒绝、锁屏停止及网络变化。模拟器不支持局域网隐私验证；缺少设备、签名或连接对端时逐项记录未验证，不把 loopback、Info.plist 或 Bonjour 注册充当证据。
- [ ] **Step 7：提交、普通推送与审查。** 提交 `feat: add local network sharing controls`；任务独立审查后，对整个网络阶段完整提交范围进行整体审查，处理发现并验证。更新完整目标剩余项：媒体 Tasks 2–4、音频 UI、Photos/LivePhoto、文本、下载/设置及完整 UI 验收继续保留。

## 平台检查及证据

- 所有中间目录使用 `DerivedData/NetworkPackage`、`DerivedData/NetworkXcode`、`DerivedData/TestRuns`；这些是已忽略的项目目录，不使用 `/tmp`。
- 顺序运行 `xcodebuild -project ShuReplica.xcodeproj -scheme ShuReplica -derivedDataPath DerivedData/NetworkXcode CODE_SIGNING_ALLOWED=NO -destination 'generic/platform=iOS Simulator' build`，再将 destination 改为 `'generic/platform=iOS'` 执行 build；两次退出 0 后执行指定设备 build-for-testing。
- 指定设备为 `platform=iOS Simulator,id=4DA3B41E-303F-4B8E-A77C-340A5DC1A7BD`（现有 ShuReplicaFunctional/iOS 27.0）；核实 Booted/available 后顺序安装完整 app，再执行同一设备 `test-without-building -parallel-testing-enabled NO -only-testing:ShuReplicaRuntimeTests/<上述类/方法> -resultBundlePath <本任务唯一结果路径>`。UI 两方法使用 `-only-testing:ShuReplicaUITests/ShuReplicaUITests/<方法>`；两个 target 名已由现有 project/scheme 核实。
- 用 `xcrun xcresulttool get test-results summary --path <实际结果路径> --format json` 核对实际方法、平台和计数；编译日志、退出码、原始诊断与失败尝试保留。运行中句柄先收取终态，不重复启动同一测试。
- 每任务派发前记录 BASE；报告包括 RED/GREEN 命令和真实终态、改动、未验证项及提交哈希。审查覆盖完整 BASE..HEAD，不只审 HEAD~1。

## 计划自查

设计目标/协议/文件边界由 Tasks 1–2 覆盖，入口/地址/生命周期/设备边界由 Task 3 覆盖；五项 Review Focus 均有对应真实行为断言。跨任务只消费上述稳定 Service 和 Checks 接口，停止及无覆盖规则一致；未写实现函数体或新增未来配置。源码可编译性、平台运行和真实设备结论必须等实施证据，当前无网络产品验证结果。

## 一手参考

- [固定 GCDWebServer 源码](https://github.com/swisspol/GCDWebServer/tree/1c36bf07c848476111d523057a3a63b05328ce2a)：Core 的 close 为通知，stop 不等于终止既有连接；定长/chunked 回调与默认上传暂存须局部适配。
- [RFC 4918](https://www.rfc-editor.org/rfc/rfc4918)：DAV 状态、Depth 和 Destination；本产品无覆盖策略及未实现方法如实表达。
- [Apple TN3179](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy)：入站 TCP、Bonjour 和权限证据不同，模拟器不能验证局域网隐私。
