# 验证标准

## PDF／图片操作页面当前证据（2026-10-01）

- `DocumentUITargetRed.xcresult` 的真实 `testDocumentCancellationAndRetry` 已从工作区进入 PDFs 并长按 locked.pdf，因缺“PDF 处理”入口失败；方法132.466秒，session11501退出65，结构化total1/failed1/passed0/skipped0。前一轮三项文件标签/启动前提失败不记为目标RED。
- `DocumentNavigationActivation.xcresult` 的真实导航方法382.118秒，session71050退出65，total1/failed1/passed0/skipped0。下拉显示SearchField、输入筛选、选择数量保持已执行；失败为顶部选择菜单在激活搜索时隐藏。原始log 384–423行及完整summary已核实，不声称导航通过。
- 菜单移动后的generic Simulator session30068、generic Device session1761、UI build-for-testing session5349最终退出0；控制器已读完整短日志 `DerivedData/document-ui-final-simulator.log`、`DerivedData/document-ui-final-device.log` 与 `DerivedData/document-ui-final-testing-build.log`，仅既有supported-platforms提示。ImageSmoke session34841及ArchiveSmoke session43411退出0，控制器已读完整通过输出，无unhandled-source警告。安装session19864退出0；真实UI GREEN尚未完成，构建和安装不能证明最终交互通过。
- 系统文件导入成功路径、操作输出独立重读、取消/等待/关闭重开与新旧方法均由同一document_ui实施者顺序验证；没有截图或图像查看授权。
- `DocumentUIComplete.xcresult`：session38495退出65，方法总耗时439.367秒，结构化total6/failed6/passed0/skipped0；控制器已读完整summary和失败日志、确认PID80563终止。归档行查询、目录误选底层BackButton、后续批量入口及原生导入/导航前提失败；没有判为UI GREEN。
- 独立检查实际归档输出 `归档测试-4BBA70.zip`：202bytes，Python zipfile条目为该空目录，testzip=None；只能证明该输出成功，不能证明原归档方法通过。前台查询修正后的单Image session62947退出65、200.068秒，失败于质量字段没有键盘焦点；目录修正尚未触达，后续条件修正需实际运行。
- 单Image条件修正session47018退出65、101.799秒，实际键盘条件通过并输入质量0.6；随后目标DocumentUITests未查询到，目录选择和最终输出仍未通过。原始日志为 `DerivedData/document-ui-input-condition.log`，未视为单方法GREEN。
- `DocumentUISheetList.xcresult`：单Image32884退出65、314.791秒；第一项生成真实JPEG795bytes，独立sips读取jpeg24×32。第二项进入Output后保存按钮即时isHittable失败，整项未通过；仅改为前台候选条件等待，保留实际点击与失败文字树，build47185退出0。
- `DocumentUICancellationAction.xcresult`：取消重试session98419退出0，方法422.970秒；控制器独立xcresulttool session81353退出0，result=Passed、totalTestCount=1、passedTests=1、failedTests=0、skippedTests=0。覆盖错误密码、正确密码重试、真实进度变化、取消处理、运行中关闭并重开、更多PDF/图片系统导入取消返回。其余方法及成功系统导入尚未通过。
- 控制器独立PDFKit session92896退出0：真实Output/ui-retry.pdf为2页、未加密且未锁定、第一页LOCKED1文字保留。随后实际根目录没有.pdf-/.image-暂存；PDFs只保留四个原始输入，Output仅ui-quality.jpeg/ui-retry.pdf，无两项取消输出。全套实际输出仍须完成生成器`--verify`。
- 运行环境完整JSON核对仅iOS27.0（24A434）可用；当前真实UI结果仅覆盖该Simulator，不证明iOS26运行通过；部署目标仍为iOS18。
- `DocumentUIMoreNativeCell.xcresult`：成功导入65315退出0、262.278秒，控制器独立xcresulttool1269退出0，Passed/total1/passed1/failed0/skipped0；真实系统选取/Open、工作区复制、共享PDF页处理输出及返回文件列表检查通过。受控reset前控制器cmp退出0，root b.pdf为6236bytes且与原始PDFs/b.pdf逐字节一致。真实两PNG由实施者检查大小1744/1907bytes，全部内容仍需最终`--verify`。
- 同代码受控reset85639退出0后运行完整六项19281，最终退出65；控制器独立`xcresulttool get test-results summary`退出0确认`DocumentUIFinalGreen.xcresult`为Failed、totalTestCount6、passedTests2、failedTests4、skippedTests0。Archive253.022秒与More277.018秒通过；三个文档方法在UITests:302工作区入口失败，Navigation在UITests:77全选菜单失败。未only/skip，不能因结果包命名判整套通过；全部方法与实际输出验证完成后再进入Task3独立审查。
- 点前选择菜单诊断`DocumentUISelectionBounds.xcresult`：实施者session26594退出65、52.069秒；控制器读取完整相关文字层级，Menu与TabBar按钮矩形实际重叠且点击前isHittable失败。已据此修正选择态系统工具栏显示，后续必须真实验证全选、搜索词保留、筛选反选精确数量、取消归零和完成后标签恢复；尚未判修复通过，未执行视觉验证。
- `DocumentUISearchSubmit.xcresult`：Nav32125最终退出0，.exit实际为0，方法63.327秒；控制器独立xcresulttool退出0确认Passed/totalTestCount1/passedTests1/failedTests0/skippedTests0。实际覆盖全选、搜索输入与选择数量保持、Search键提交及键盘收起后保持同查询、筛选反选仅减少目标一项、取消归零、完成后下载标签恢复/切换及回文件夹。没有删除断言或跳过方法；动态字体与布局视觉尚未验收，完整六项及全部实际文档产物仍待最终验证。

- `DocumentUIStableLists.xcresult`：9728退出65/.exit65，Image142.283秒、PDF34.276秒，两项失败/零通过/零跳过；稳定标识已通过真实目录前提。失败文字树证明逐行点击后count0、批量Menu Disabled、嵌套TabBar仍显示，尚无两项完整GREEN。
- `DocumentUIRowSelectionRed.xcresult`：仅加强逐行断言后build41589退出0，单PDF97628退出65、25.959秒；summary为Failed/total1/passed0/failed1/skipped0，首个a.pdf中心真实tap后仍未选择。行点击区域修复必须保留每行value=已选择、精确count2和批量菜单可点击断言，并完成原完整PDF/Image输出流程；工具栏改动还需覆盖根页及嵌套目录选择完成后标签恢复。
- `DocumentUIRowHitArea.xcresult`单PDF93434退出65、78.947秒，逐行value与count2通过，batch.isHittable失败；第二步原生automatic修正后`DocumentUIInheritedTabBar.xcresult`45810退出65、127.350秒，batch可点击及合并产出通过。最新失败是测试previewDone命中底层完成，前台QL未关闭，随后分享按钮hitpoint{-1,-1}；全局同名按钮与底层navigationBar.exists不能证明前台关闭/恢复。后续必须真实关闭QL、等待其消失，再实际打开/关闭native分享，不弱化原完整处理断言。
- `DocumentUIPreviewReturn.xcresult`43342退出65、96.258秒，1失败/0通过/0跳过；真实QL关闭/消失和处理页恢复条件已通过，Share实际tap及底层关闭变不可点击通过，随后前台Close候选等待超时。当前app文字树为空remote层，需核对真实分享owner/公共控件树并完成native关闭及处理页恢复，不以底层被遮挡独立判整段分享通过；完整PDF方法及全部输出仍未通过。
- `DocumentUIPreviewContent.xcresult`完整PDF26820退出0/.exit0、276.591秒，控制器独立`xcresulttool get test-results summary --format json`退出0确认Passed/totalTestCount1/passedTests1/failedTests0/skippedTests0。覆盖逐输入选择/密码/顺序、真实合并、实际QL PDF内容加载与关闭、SharingUIService实际collection/caption、PopoverDismissRegion真实关闭并等待popover/owner消失及PDF恢复、分割、144dpi导出、移除密码。临时owner诊断方法已删除，仍6个正式测试；全部实际产物内容和最新完整六项尚待运行。
- `DocumentUIImageComplete.xcresult`完整图片44527退出0/.exit0、254.968秒，控制器读取终态日志及独立`xcresulttool get test-results summary --format json`退出0确认Passed/totalTestCount1/passedTests1/failedTests0/skippedTests0。覆盖JPEG质量0.6、显式frame1、全部帧提取、逐行选择/count2/批量菜单真实可点击、合成顺序与指定目录/名称；全部实际输出内容仍待独立重读。最终generic Device构建83666的`document-ui-final-device-v2.exit`为0，完整日志仅既有supported-platforms提示；真实设备运行和最新完整六项尚未验收。
- 最终产物验证须在完整六项终态后重新查询真实容器：执行现有`--verify`，另用`cmp`核对源fixtures的全部七项PDF/图片输入与容器对应文件字节一致，并核对分割、按页导出、按帧提取、导入导出的结果目录准确条目数。现有verifier仅检查指定条目及部分原文件，不能独自证明没有多余输出或所有原文件保持完整；已通知原实施者补齐实际命令证据，不修改产品或重复已通过方法。
- `DocumentUIFullFinal.xcresult`71766终止0/.exit0、1041.298秒，控制器独立xcresulttool退出0确认Passed/totalTestCount6/passedTests6/failedTests0/skippedTests0；覆盖同一版本下六个正式方法，无临时诊断或跳过。实际产物67668退出133于JPEG纯色参考值；控制器独立Pillow数字解码确认原PNG、GIF及对应JPEG/选帧/提取/合成像素相符，原红(255,38,0)、蓝(4,51,255)，原绝对纯色前提错误。只能改为比较真实输入像素及明确JPEG小误差，不能仅放宽单个绿色阈值；修正后的完整`--verify`尚待执行。
- 最终`document-ui-actual-outputs-final.exit`为0，完整log确认PDF文字/顺序/分割/解密/dpi、图片质量/帧/提取/合成、取消清理和原文件检查通过。控制器核对修正仅测试参考像素：JPEG每通道差≤2，PNG提取/合成等于真实原PNG/GIF对应像素，四个结果目录准确集合保留；另独立cmp七输入均退出0，独立Pillow两原GIF帧/提取帧与两合成对应像素相等，退出0。Task3最终提交及独立审查尚待完成。
- Task3最终9f32757已普通推送，控制器核对HEAD=origin/main；document_ui_review规格符合、质量Approved，无Critical/Important。七项跨任务核验已记录，未运行平台和专项仍保留；M1既有平台提示/坏PDF诊断交整体审查。阶段整体审查尚无最终判定。
- 整体审查With fixes：PDF按页导出遗漏可见annotation。实际序列化输入的服务产物RED133/蓝像素0应800；修复为PDFPage.draw后完整PDFSmoke GREEN0，PNG两页800、JPEG两页3196，已知位置/尺寸/非零原点/旋转/原字节/进度通过。最终Simulator48247/Device4141均实际exit0；Device提前启动被主动中断的75保留为执行错误，不作为编译失败。唯一scoped re-review正在执行，Git因自动审批两次拒绝保持未提交；此前6项UI结果对应9f32757，未声称新批注修复已重跑UI或真机。
- 唯一scoped re-review完整最终报告确认I1 ADDRESSED、无新增问题；其源码/diff核对、实际测试证据与系统PDFKit接口说明一致，控制器完整读取且原审查者恢复确认。既有M1仍为非阻断诊断；cb7e7e5提交和普通push均退出0，控制器核对HEAD=origin/main。完整Shu仍未完成，没有重跑未改动的UI或宣称iOS18/26、真机与视觉验收通过。

## 媒体阶段必要检查（尚未实施）

- 精确LAME3.100.3包由SwiftPM校验下载，核对实际头文件和Mac/Simulator/Device slices；tag与manifest存在仅是前置证据。
- AudioSmoke/VideoSmoke/VideoAnimationSmoke真实生成输入并重读PCM/帧内容、时长、采样率/声道、轨道/方向及GIF/WebP时长/循环，覆盖原文件保护、边界、同名、取消与清理。
- 新hosted ShuReplicaRuntimeTests直接调用相同产品服务，实际运行testAudioCodecs/testVideoContainersAndEdits/testVideoAnimations；Mac通过或iOS编译不能替代iOS方法通过。当前目标尚未配置或执行。
- Media UI方法从真实Documents输入验证表单、参数/轨道、输出、错误重试与取消/关闭重开；统计实际总数、通过、失败、跳过，未经授权不做视觉验收。

## 图片服务实施（2026-10-01）

- `swift run --scratch-path DerivedData/ImagePackage ImageSmoke DerivedData/TestRuns/ImageComplete` 退出 0；主代理读取完整 `DerivedData/image-complete.log`，最终通过输出包含六 codec、帧内容/时长/循环、选帧、提取、方向、白底、合成、冲突、校验、边界、取消与清理。实际测试及历史 RED 命令详见本阶段 task-2-report.md。
- PDFSmoke、ArchiveSmoke、FileStoreSmoke、FileBatchSmoke、WorkspaceCategorySmoke、DownloadRequestSmoke、真实 localhost 下 DownloadManagerSmoke 均由实施者执行退出 0；未重复套件。PDF 坏/零页拒绝夹具的 CoreGraphics 诊断仍保留。
- generic Simulator 和 generic Device 顺序构建退出 0；主代理读取完整 `DerivedData/image-simulator.log`、`DerivedData/image-device.log`，均只有既有 supported-platforms 提示。27cc40e / 939f672 已普通推送；独立规格与质量审查通过，UI 尚待 Task 3。
- 最终兼容补强 ccf23be / 日志补记12265da已普通推送。ImageLoopBaseline（未改服务）与ImageLoopGreen、两轮Pillow12.3.0各16件独立GIF解码、最终Simulator构建均退出0；父代理读取完整对应log，image_loop_review确认M2 ADDRESSED，无新增问题。无扩展GIF全局属性实际为1、正次已归一化为总播放次数；原I1由原审查者撤回。错误样本前置133未记为服务RED，真正缺全局属性fallback分支未在本机实际诱发。
- 独立新设备 bootstatus Finished、应用及 runner 顺序安装退出 0。单项导航 test-without-building session56245退出65，实际方法执行423.458秒，失败位置 Tests/ShuReplicaUITests.swift:79，SearchField无匹配；另有诊断采集超时600秒。`xcresulttool get test-results summary` 退出0：result=Failed、totalTestCount=1、failedTests=1、passedTests=0、skippedTests=0。原始日志 DerivedData/functional-navigation-20261001.log，结果包 FunctionalNavigation-20261001.xcresult。没有判定整个导航方法通过，也未截图/读取图像。

## PDF 服务实施（2026-10-01）

- `swiftc -module-cache-path DerivedData/ModuleCache ShuReplica/WorkspaceCategory.swift ShuReplica/FileStore.swift ShuReplica/PDFService.swift Tests/PDFSmoke.swift -o DerivedData/PDFSmoke && DerivedData/PDFSmoke DerivedData/TestRuns/PDFFinal`：退出 0，真实合并/分割顺序、文字/几何/整页栅格、加密、PNG/JPEG、进度、同名、非法输入/路径边界、只读目标失败、取消与清理断言通过。owner-only 错误密码断言修复前退出 133。坏/零页夹具触发 CoreGraphics 诊断，不宣称输出无警告。
- 最终 generic Simulator 构建退出 0；2026-09-30 五项既有自检与 ArchiveSmoke 退出 0。完整命令、历史 RED/GREEN 和限制在 `.superpowers/sdd/2026-09-30-shu-pdf-image/task-1-report.md`；实现 3d1ee23、哈希补记 67d6953 已普通推送。独立规格与质量审查通过，PDF UI 尚未接入。
- 内部符号链接后跟 `..` 回归：PDFInternalLinkRed 退出 133，增加标准化前原路径分量拒绝后 PDFTraversalGreen 退出 0；最终 Simulator build 退出 0。四个入口外部路径及内部输入/目标、原文件与哨兵字节、输出/暂存清理断言通过。e48284b / 164ca77 已普通推送；独立修复复查确认 ADDRESSED，无新增问题。未声称初始无法复现的越界推测成立。

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
