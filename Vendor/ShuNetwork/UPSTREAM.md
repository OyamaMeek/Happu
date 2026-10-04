# 固定来源

- 上游：https://github.com/swisspol/GCDWebServer
- tag：3.5.4；提交：`1c36bf07c848476111d523057a3a63b05328ce2a`。
- 使用 `git archive` 获取该提交的 GCDWebServer、GCDWebDAVServer 与 LICENSE；原许可证保留在 Upstream/LICENSE，各源文件保留版权声明。
- `UPSTREAM_TREE.txt` 保存固定提交各原文件的 Git blob ID，可用 `git hash-object` 核对未修改文件。
- `Package.swift`、`Upstream/module.modulemap`：本地 SwiftPM 注册，保留 ARC 与 CFNetwork/zlib 链接；包包含固定上游 DAV 源码，当前服务仅启用 browser。
- `GCDWebDAVServer.m`：通过 SDK 的 `@import libxml2` 编译 XML，移除 SDK 绝对 include 路径需求。
- `GCDWebServerConnection.m/.h`：定长与 chunked 请求只有读取成功且关闭成功后才能处理；严格检查 Content-Length/Transfer-Encoding 冲突、长度及 chunk 溢出，chunk 分段流式写入；新增真正的 socket shutdown，早拒绝只由 dealloc 关闭 socket，释放请求/响应后才报告连接结束。
- `GCDWebServer.m/.h`：弱连接登记与 dispatch group 等待，停止 accept 后终止已有连接，重试停止不会触发重复 stop 断言；描述符 0 也被接受。
- `GCDWebServerRequest.m`：Range 数字和起止顺序严格校验，非法范围由 HTTP 适配返回 416。
- `GCDWebServerFileResponse.m/.h`：新增已验证文件描述符入口，沿用上游范围响应与读取机制，避免按可变绝对路径重开；描述符 0 合法，HEAD 与读取失败均关闭持有的句柄，异常 EOF 明确失败。
- `Sources/` 是项目适配：FileAccess 负责共享目录边界、会话暂存和排他发布；HTTPServer 负责 HTTP 路由、来源校验和停止结果。未使用上游默认 DAV 或上传器的覆盖行为。
