# 匿名经验记录

- 场景：用户授权的本地 iOS 文件工具复刻，离线样本为 `.app` 目录。
- 路由：R2 mobile-reverse；`case-init` 用可执行文件作为 `--sample`，再把整个 `.app` 目录列入范围。
- 有效证据：Info.plist、二进制 plist 格式的本地化字符串、内置 webarchive 指南。
- 工具选择：没有 Ghidra、radare2、Frida 时，先用索引中的 Python 标准库解析资源；不为 UI 复刻安装不必要的反编译器。
- 界限：资源可确认功能入口，不能证明像素级 UI 样式；构建成功也不能代替模拟器运行。
