# 本地网络共享需求核查

核查时间：2026-10-02。用户要求当前部分完成后优先本地网络共享；当前按音频Task1验收后切换理解，音频任务继续。此文档是原版需求与依赖预研记录，尚无网络实现或运行通过结论。

## 原版实际依据

- `Payload/Shu.app/zh-Hans.lproj/guide.webarchive`通过系统textutil完整读取：Wi-Fi共享用于同网段传输，热点共享需要手机建立个人热点并连接其它设备；共享目录中的文件可通过iTunes共享。完整输出有textutil缓存权限诊断，退出0且指南正文完整，未视为无警告。
- Localizable.strings通过plistlib读取：`file.export.wifi`为Wi-Fi传输，`file.export.wifi.qrcode`为二维码，`file.uploader.wifi`与`file.uploader.webdav`分别为浏览器和WebDAV入口，提示包含当前共享目录名称、其它设备输入地址、共享时不离开页面或锁屏、热点需至少一台连接设备。
- `vo.uploader.*`包含启动/停止、上传、下载、删除、创建目录和地址操作，证明共享范围包含实际双向文件操作。
- 原版Info.plist声明`NSLocalNetworkUsageDescription`和Bonjour `_http._tcp`。当前复刻Info.plist尚未声明这些；现有FilesView的“共享”只进入本地目录，MoreView没有实际网络服务入口。

## 需求与验收范围

- 从用户选定工作区目录启动或停止共享，显示当前目录、真实可访问地址及二维码；浏览器可浏览、上传、下载、创建目录、删除，WebDAV客户端可操作相同共享范围。
- 只访问选定目录，复用文件边界与无覆盖发布规则；断开、停止或上传失败不能留下可见部分文件，不能访问路径越界、符号链接、隐藏暂存或其它未选定目录。
- 在真实HTTP/WebDAV连接中核对文件字节、重名、失败/取消、文件列表刷新和服务停止。Mac本机测试、iOS hosted运行、同局域网其它设备、热点、权限拒绝分别记录，不能用loopback通过替代跨设备证据。
- 共享需显式启动，页面关闭/应用后台或锁屏时停止并清理在途资源；原版提示的前台使用条件保留。具体交互和服务方案仍需形成设计。

## 成熟服务能力预研

[GCDWebServer官方项目](https://github.com/swisspol/GCDWebServer)提供HTTP流式响应、文件范围请求、浏览器WebUploader和WebDAV扩展，可复用成熟协议处理；仓库于2023-01-11归档，尚未验证当前SDK构建或采用为产品依赖。

公开[GCDWebUploader接口](https://raw.githubusercontent.com/swisspol/GCDWebServer/master/GCDWebUploader/GCDWebUploader.h)要求附带网页资源bundle，提供上传、移动、删除、创建目录的自定义检查；[WebDAV接口](https://raw.githubusercontent.com/swisspol/GCDWebServer/master/GCDWebDAVServer/GCDWebDAVServer.h)另含复制检查。默认隐藏项目不开放，默认修改检查允许操作，仍需验证实际路径与发布保障，接口存在不能证明安全行为。

公开[yene SwiftPM manifest](https://raw.githubusercontent.com/yene/GCDWebServer/master/Package.swift)仅注册Core/Requests/Responses/private及隐私资源；没有注册WebUploader/WebDAV扩展。不能把这个包直接当作两个扩展都可用的依赖。当前未下载、安装或修改产品网络依赖。

## 采用前必须处理的实际行为

- 官方[WebDAV实现](https://raw.githubusercontent.com/swisspol/GCDWebServer/master/GCDWebDAVServer/GCDWebDAVServer.m)的PUT在上传检查后删除已有目的文件，再移动临时文件；原样接入不能满足无覆盖发布。GET根据拼接路径读取，隐藏检查只看末段名称，仍需验证每个路径祖先、符号链接及选定目录边界。
- 官方[浏览器上传实现](https://raw.githubusercontent.com/swisspol/GCDWebServer/master/GCDWebUploader/GCDWebUploader.m)为同名文件选择递增名称，再移动完整临时文件；与WebDAV的默认重名行为不同。复刻需要明确两种客户端的重名结果并用真实文件测试。
- 官方[服务接口](https://raw.githubusercontent.com/swisspol/GCDWebServer/master/GCDWebServer/Core/GCDWebServer.h)明确stop只停止接受新连接，已有请求继续完成；默认后台自动暂停后可自动恢复。前台显式启动/停止及在途上传清理不能仅依赖stop调用或后台默认值，需要具体生命周期设计和实际验证。
- SDK编译、两个扩展与网页bundle的完整注册，以及上述行为约束仍未验证；目前保留候选，不宣称依赖已经选定或可直接满足产品范围。
