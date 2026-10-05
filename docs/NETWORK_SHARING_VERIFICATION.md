# 本地网络共享验证

## 使用

底部“网络共享”默认分享首页全部文件夹。选择浏览器或 WebDAV，启动后使用页面显示的实际局域网地址连接；可以更换共享目录。目录页面的“新增”菜单也提供“通过本地网络共享”，预选当前目录。现有下载管理页面位于“更多 → 下载”，使用原来的 DownloadManager。

浏览器首页显示文稿、图片、视频、音频、电子书、压缩文档、镜像文件、脚本配置、工具配置、下载、共享及用户实际创建的目录和文件。下载目录的显示名称为“下载”，实际路径仍为 Downloads。支持导航、逐项上传进度、文件下载、新建目录和确认删除；同名文件明确拒绝覆盖。

选择文件后立即上传；将文件或文件夹拖到页面也会自动上传到操作开始时的当前目录。文件夹保留顶层名称、嵌套层级和空目录；已有目录可以合并，同名文件拒绝覆盖并显示逐项错误。上传期间文件选择暂时禁用，完成后可继续添加；这一批文件的目标不会随页面导航改变。

共享只在前台运行。切离共享页、关闭目录共享页、进入后台或锁屏会停止监听和在途传输；清理完成后才能重新启动，回到前台不会自动启动。WebDAV 支持 OPTIONS、PROPFIND Depth 0/1、GET/HEAD、PUT、MKCOL、DELETE、COPY、MOVE；无限查询深度及锁定方法明确拒绝，不宣称完整 Finder/Class 2 兼容性。

## 已取得的证据

- Mac 真实 HTTP 98 项、DAV 37 项、资源 GET/HEAD 与包字节 13 项通过。资源测试从不含资源的独立工作目录启动也通过。
- 独立 curl 客户端 MKCOL/PUT 返回 201，PROPFIND 返回 207；下载与原始中文文件 `cmp` 完全一致。
- MOVE 暂存期间将源父目录移出共享范围：真实 RED 后修复，3 项 GREEN，范围外源保留、目标不发布。
- 512MiB COPY 中停止：真实 RED 后修复，5 项 GREEN；保留的暂存句柄最终长度小于源长度，证明读写提前终止，最终目标不存在、会话暂存清理完成。
- 浏览器活动 HTML 文件下载：真实 RED 后修复，3 项 GREEN；attachment、nosniff 和 sandbox CSP 生效，文件字节不变。
- 代码质量独立复查未发现剩余 Critical/Important；上游 UTType 弃用诊断保留。
- iOS 五项 NetworkRuntimeTests 均取得通过结果，覆盖 HTTP98、DAV37/资源13、真实地址/二维码、COPY提前取消和WKWebView。网页最终25项包含390/1100宽度无横向溢出、长中文名称、SVG、44px触控、选择/清空状态、新建后的键盘焦点、实际上传/冲突/删除和跳转焦点。
- `NetworkWebFinalConfirmation.xcresult` 命令退出0，结构化3通过/0失败/0跳过、运行警告为空：最终网页、原生两个共享方法通过，包含实际复制后粘贴、PUT/GET字节、标签切离与后台端口关闭、不自动恢复、共享目录选择和启停。已有下载导航/搜索/选择方法在 `NetworkWebPolishGreen1.xcresult` 通过。早期失败结果包保留，不作为全部成功的证据。
- 普通Simulator签名构建及build-for-testing退出0；已有缓存普通构建也退出0，Xcode自动清理旧资源目录。最新generic Device编译退出0，未以关闭签名的构建代替资源包签名验证。
- 最终应用 `codesign --verify --deep --strict` 独立命令退出0；网页Impeccable机械检测一次退出0、输出空问题列表。最后Mac资源GET/HEAD与准确包字节13项退出0。

## 验证命令

### 自动上传（2026-10-05）

- Chrome真实文件选择与CDP原生拖放：8组通过，核对服务端实际磁盘字节；覆盖105个同级文件、空目录、中文与特殊名称、混合拖放、目录合并、文件冲突、忙碌保护、导航目标固定和原生File回退。测试为 `BrowserTests/network-upload.cjs`，无 mock。
- 修改前选择文件用例exit1，20秒内未发生上传；实现后完整用例exit0，日志 `DerivedData/network-auto-final.log`。
- Mac网络回归HTTP98、DAV37、资源13、MOVE3、提前COPY取消5、下载安全3均exit0。
- iOS普通签名构建及完整NetworkRuntimeTests：隔离重跑exit0，`NetworkAutoUploadIsolated.xcresult` 为5通过/0失败/0跳过、无运行警告。初轮4通过/1失败，既有COPY响应时限测得411毫秒，隔离重跑通过；保留原始结果。
- 目录行显示“文件夹已创建”，子项结果独立显示；只读代码审查及针对性复查无未解决问题。
- 审查后最终Chrome8组再次exit0（`network-auto-reviewed.log`），最终普通签名Simulator及WebKit方法exit0；`NetworkAutoUploadReviewed.xcresult` 为1通过/0失败/0跳过、无运行警告。
- 网页机械检测一次exit0、空问题列表；JavaScript语法和本次改动空白检查通过。设备签名构建因未配置Development Team失败，关闭签名的设备平台编译exit0；该结果仅证明编译。没有真机或视觉验证。

安装了Node.js、Playwright及Chrome后，可使用新的项目内目录运行：

```sh
swift build --scratch-path DerivedData/NetworkPackage --product NetworkSmoke
node BrowserTests/network-upload.cjs DerivedData/NetworkPackage/out/Products/Debug/NetworkSmoke DerivedData/AutoUpload-<唯一名称>
```

Playwright通过现有运行环境提供，本项目没有增加前端依赖。测试使用本机 `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`；服务器复用NetworkSmoke的 `serve-browser` 模式。

### 网络服务

CLI 使用项目根目录的 SwiftPM 清单，产物位于 `DerivedData/NetworkPackage`：

```sh
swift build --scratch-path DerivedData/NetworkPackage --product NetworkSmoke
DerivedData/NetworkPackage/out/Products/Debug/NetworkSmoke DerivedData/TestRuns/<唯一目录> http
DerivedData/NetworkPackage/out/Products/Debug/NetworkSmoke DerivedData/TestRuns/<唯一目录> dav
DerivedData/NetworkPackage/out/Products/Debug/NetworkSmoke DerivedData/TestRuns/<唯一目录> assets
DerivedData/NetworkPackage/out/Products/Debug/NetworkSmoke DerivedData/TestRuns/<唯一目录> move-boundary
DerivedData/NetworkPackage/out/Products/Debug/NetworkSmoke DerivedData/TestRuns/<唯一目录> stop-copy
DerivedData/NetworkPackage/out/Products/Debug/NetworkSmoke DerivedData/TestRuns/<唯一目录> download-safety
```

iOS 验收目标是 ShuReplicaRuntimeTests/NetworkRuntimeTests；原生两方法位于 ShuReplicaUITests/ShuReplicaUITests。测试使用真实 URLSession、BSD socket、WKWebView、磁盘文件和接口地址，不使用 mock。构建、结果包及失败尝试保存在忽略的 DerivedData；以命令退出码和 xcresulttool 的结构化计数为准。

## 实测范围

当前 iOS 运行环境为 iPhone 18 Pro / iOS 27.0 模拟器。模拟器不能证明真实手机的同网设备访问、热点、局域网隐私拒绝和物理锁屏行为；这些场景仍需真实设备证据。未进行截图或视觉验收。
