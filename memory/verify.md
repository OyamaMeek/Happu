# 验证标准

- `FileStoreSmoke` 在项目 `work/` 内真实创建、导入、移动、复制、重命名、删除文件，结果符合断言。
- `xcodebuild` 针对 generic iOS Simulator 编译成功，代码签名关闭。
- 下载输入仅接受 HTTP(S) URL；进度、暂停/继续与完成文件由真实 URLSession 回调驱动。
- 重建 DownloadManager 后，已完成文件与中断任务列表仍可见；删除任务后不再恢复。
- UI 使用系统文件导入、QuickLook 预览和 ShareLink；没有数据丢失式覆盖。
- 本机模拟器服务若仍不可用，记录无法运行 UI 的事实。

## 本次结果

- 三个自检均通过；下载测试使用回环地址上的真实 Python HTTP 服务。
- generic iOS Simulator 与 Device Debug 构建退出码 0；设备版 `.app` 包信息已核对。
- 沙箱内 CoreSimulatorService 连接被拒绝；只读检查 `simctl list runtimes` 为空，未运行或截图验证 UI。
