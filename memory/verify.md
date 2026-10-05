# 验证标准

## IPA 自动 Release（2026-10-05）

- 使用真实临时 Git 仓库验证无 tag 返回 v0.0.1、数字排序递增、非正式 tag 忽略、同提交轻量/附注 tag 复用、无 Git 仓库明确失败。
- 本地构建 iphoneos Release，运行正式打包脚本；使用 Python zipfile/plistlib 校验 IPA 完整性、Payload/Happu.app、版本、构建号、编译时间和非空 arm64 Mach-O。
- GitHub 工作流须触发 main 应用相关推送，contents:write、串行排队；上传完成后发布，失败不公开空 Release，重跑复用 tag/恢复草稿。
- 读取远端工作流终态及 Release 资产，以实际结论报告。IPA 无 Apple 分发签名，供侧载工具重新签名；不声称真机安装或签名验证通过。
- 当前证据：6项版本测试 RED exit1、GREEN exit0；独立审查的旧版本恢复覆盖 Latest 由2项 RED→GREEN 修复，完整9项通过。暂存内容导出的 Release Device 构建 exit0，实际 IPA ZIP/版本/构建号/arm64 校验及元数据2项通过。错误版本拒绝、不生成 IPA。YAML、全部 shell step 和 Python 编译检查通过；构建保留5项原有 API 弃用警告。证据位于 ignored DerivedData/HappuRelease/。
- 远端有效终态：Actions 37285352308 completed/success，云端构建/校验/上传/公开全部success，v0.0.1 tag 指向 fb2e25031e83bc1807f8cd605a8a878d38531f60。Release为非草稿，资产Happu-0.0.1.ipa为uploaded/1,075,036 bytes且为Latest；实际公开链接下载exit0、元数据2项通过、0.0.1/build1/arm64确认。SHA-256为5b91580037153f96e81d96fcf81c1c07261627420bde037895fd2f917bf39a22，与GitHub digest相同。

## Happu 更名与编译时间（2026-10-05）

- 真实 XCUITest 验证首页 Happu、下载目录返回标题及关于应用名称，编译时间存在且重启不变。
- 更名后普通签名测试构建和 generic Device 编译成功；最终应用 Info.plist 显示 Happu，并含有效 UTC 构建时间。
- 连续两次构建实际写入不同时间，应用重启显示同一编译值；Debug/Release 均使用该构建阶段。
- 保留用户媒体和工程改动；不运行截图或图像检查。只暂存本次差异及文件更名，历史日志/会话不重写。
- 当前结果：实际应用包元数据 RED exit1/2失败，修改后 Debug/Release 各 GREEN exit0/2通过；初轮 UI 未产生方法结果、TERM exit143。签名 build-for-testing、增量 build 与严格签名校验 exit0；NameGreen.xcresult Passed/3通过0失败0跳过，runtimeWarnings为空。增量时间07:01:28Z→07:08:43Z，UI重启前后显示2026-10-05 15:01:28不变。
- Release Device首次exit0但有5条SwiftCompile异常诊断，保留release-device.log；最终release-final.log exit0/BUILD SUCCEEDED、无error，实际arm64应用包有效。关闭签名，不代表真机/设备签名验证。当前用户模拟器安装/启动exit0、Xcode已打开新工程；只读审查无待修问题。机械检测exit0/[]，未进行截图或图像检查。

## 文件首页调整（2026-10-05）

- 真实 XCUITest 确认“工作区”“所有文件”“共享”入口移除，下载位于工具配置之后，并能打开 Downloads、新建目录、返回后再次访问及删除。
- 运行现有导航、选择、下载管理和网络共享入口回归；普通签名 Simulator 构建成功。已有媒体等修改保持原样，不宣称视觉验证。
- 文档交互输入及输出统一准备在应用 Documents/文稿/DocumentUITests；现有准备器可传入该路径，本次已创建真实输入，未重跑完整文档流程。
- 修改前 FileHomeRed exit65/1失败；初轮 FileHomeGreen exit65/4通过1失败0跳过，运行警告为空。初轮失败为测试长按清理目录时进入目录，改用已存在的批量删除流程；最终 FileHomeFinal exit0/2通过0失败0跳过，运行警告为空，覆盖首页完整流程及强化搜索选择回归。五个唯一相关方法均取得成功终态，未虚构单个5/0/0结果包。
- 当前 iPhone 18 Pro（AF847C96-0AAE-4682-B1B4-45A9DFA161EC）安装及启动 exit0；测试设备为 ShuReplicaFunctional（4DA3B41E-303F-4B8E-A77C-340A5DC1A7BD），两者运行 iOS27。没有截图及真机证据。

## 网络共享自动上传（2026-10-05）

- 真实 Chrome 通过文件选择和 CDP 原生文件拖放操作页面，访问同一 NetworkSharingService；检查实际磁盘字节，无 mock。
- 验证选择即上传、拖入即上传、目录层级、空目录、特殊名称、105个同级文件完整读取、混合拖放、目录合并、同名拒绝覆盖及文件/目录冲突。
- 验证读取/上传忙碌状态、批次目标目录固定、逐项错误与恢复；更新真实 WKWebView 上传回归。
- 运行 HTTP/DAV/资源既有检查和 iOS 相关构建/测试，以实际退出码及 xcresult 为依据。未授权截图，不进行视觉检查。
- 最终证据：Chrome8组exit0（network-auto-reviewed.log）；Mac各组exit0；NetworkAutoUploadIsolated为5/0/0，最终网页NetworkAutoUploadReviewed为1/0/0，两命令exit0、运行警告为空。generic Device关闭签名编译exit0，普通设备签名缺少Development Team。只读审查问题已关闭。

## 视频Task2（2026-10-05服务验证通过）

- 四容器、高中低缩放与不放大、方向/帧内容、音轨/区间信号、时间偏移、多轨选择、路径/无覆盖/取消/清理真实验证；Mac与iOS hosted结果分别记录。普通签名Simulator/Device/build-for-testing依次运行，不进行视觉检查。
- 有效RED93405退出1（video-red4.log，编译后正常输入触达stub）。ProRes兼容性问题23571退出1（video-complete3.log），修复后37910退出0；发布完成取消63724退出1（video-publish-red.log），修复后24701退出0。
- 最终Mac87522退出0（video-final-mjpeg-mac.log），13项主要操作、extended/boundaries及ProRes→MP4/MotionJPEG→3GP两个不兼容原质量转码通过；音频59157完整33项/图片36862/归档70786回归退出0。Simulator99195、当前产品Device28603、最终普通签名build-for-testing69813退出0。
- 最终iOS76484退出0，video-runtime-mjpeg.log/VideoRuntimeMJPEG.xcresult及summary已读取：Passed，total1/pass1/fail0/skip0，arm64 iOS27.0，方法215.559秒，内部13/13/0/0且extended/boundaries完整通过。原生HAL初始化延迟和两条QoS运行警告保留；没有真机或iOS18/26运行与页面/视觉证据。
- iOS64708与重启后2034均进入视频方法后等待音频锁，精确TERM自有测试进程均退出143；前者音频方法33项通过仅为日志证据。中断xcresult缺Info.plist，xcresulttool不能汇总，不能把中断包记为有效结构化通过结果。重启后先有Metal夹具初始化延迟，完成后再次进入音频等待。Mac和iOS原生调用栈及宿主默认Apple Virtual Sound Device信息已保存，未重启系统音频服务或弱化测试。
- 独立初审R1短剪辑信号检查与R2逐轨时间验证已补强；最终Mac通过。M1方向断言有向比较仍列为媒体整体验收待补。原质量按实际保留轨道判断native兼容，同名沿用自动编号；没有用推测的静音重编码问题冒充实际RED。

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

## 媒体阶段必要检查（Task1实施中）

- 精确LAME3.100.3包由SwiftPM校验下载，核对实际头文件和Mac/Simulator/Device slices；tag与manifest存在仅是前置证据。
- 隔离下载及实际headers/slices已核查；Mac probe实际启动134，rpath问题尚待本任务解决。最终裸swift run须触达真实服务断言，不能把编译/dyld失败冒充RED；iOS app须实际嵌入加载框架并运行hosted方法。
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

## 音频 Task1 最终验证（2026-10-03）

- `swift run --scratch-path DerivedData/MediaPackage AudioSmoke DerivedData/TestRuns/AudioFinalVerification`：原54523实际exit0，33项真实格式/码率/精度/输入内容及全部选轨、范围、六声道、路径、权限、取消和清理边界通过。完整日志`DerivedData/audio-final-verification.log`。
- 最终generic Simulator20826、generic Device92359、build-for-testing73620实际exit0，日志`audio-simulator-final.log`、`audio-device-final.log`、`audio-build-for-testing-final.log`保留于DerivedData。
- 指定Simulator `4DA3B41E-303F-4B8E-A77C-340A5DC1A7BD`安装实际exit0后hosted61280实际exit0。`MediaRuntimeTests/testAudioCodecs()` Passed/5.485秒，内部33/33/0/0；控制器独立xcresulttool实际exit0，`AudioRuntime.xcresult` total1/passed1/failed0/skipped0、arm64 iOS27.0、runtimeWarnings=[]。完整系统诊断与原先未执行方法的Attempt1保留，未替换真实结果。
- ImageSmoke44015及ArchiveSmoke34337共享模块回归实际exit0。未重跑已通过的相同代码测试。
- 已提交并普通推送`759d1bd3a614d389da61764890ef3f5e98b6b02f`，独立审查规格通过/质量Approved、Critical0/Important0，Task1服务验收完成；没有真实设备、音频UI或视觉验证结论，完整复刻未完成。
- 审查CV1补核：现存SwiftPM缓存zip实际SHA256=bcc33a8311c80993a06d363a29f631d74420cf954be8e8ee9e13450a525944ab；workspace-state记录同一远端/版本/checksum。实际头文件与源码SHA256同为b30e4d3f5bb247bad2781758d90604f29cc44dd5bd79fee130aaef7c7d25bcf0，modulemap、许可与iOS arm64/Simulator及Mac arm64+x86_64实际lipo检查exit0。既有原始终态及最终日志保留，没有重新下载或重跑套件。
- CV2作为明确验证限制保留：同卷stat检查实现已核实，真实跨卷测试无第二卷条件，未运行。CV3映射媒体Task4关闭等待/UI及后续真实设备/iOS26交互，不能由Task1模拟器结果代替。Minor M1错误断言精度、M2系统诊断记录到整体审查清单。

## 网络实施计划检查（2026-10-03）

- 用户已确认设计；三任务计划完成覆盖、接口/类型、五类失败条件与命令自查。现有 Xcode target 为 ShuReplicaRuntimeTests / ShuReplicaUITests，计划使用实际名称。
- 固定提交的连接、服务器、FileRequest、DAV 源码及 Apple TN3179 Markdown 已实际读取；规划参考保存在忽略的 DerivedData/NetworkPlanning，不属于产品依赖。SDK libxml2 module mapping 已核实；网络包编译尚未执行。
- 后续必须取得真实 HTTP/DAV 截断、无覆盖、路径竞争、停止清理与 hosted iOS/WebKit/UI 结果；真实 Wi-Fi、个人热点、权限拒绝和锁屏分别取得设备证据。计划中命令/断言为待执行标准，不能记为通过。
- 没有运行网络产品测试或视觉验证；此前音频验收结果保持原范围，完整复刻尚未完成。
- 官方 SE-0271 文档实际读取，核实 target 资源与 Objective-C SWIFTPM_MODULE_BUNDLE；计划补入本地包资源注册、静态路由和真实字节/MIME/HEAD/cwd 独立性检查。此为打包规则证据，不是当前工具链编译或资源运行通过。
- 2026-10-04普通签名资源验收：`network-signed-build-red.log`实际exit65，ShuNetwork资源包格式不受codesign识别；process资源后`network-signed-green.log`/`network-signed-final-build.log`两次build-for-testing、`network-signed-existing-cache.log`旧缓存普通build均exit0，资源包包含有效_CodeSignature且旧Resources由Xcode删除。`network-processed-assets.log`实际exit0/13/0/0，标准资源包根查找与真实HTTP字节一致。最终signed 8项方法和Device构建尚待终态。
- 网络计划已获第二次“确认”，Task1开始实施；有效RED8008实际exit1，成功编译17.21秒后NETWORK_HTTP_FAILED“网络共享服务尚未实现。”，控制器对应日志核对一致。首次manifest41796失败不计行为RED。扩展RED和产品GREEN、hosted运行及独立审查仍待实际结果。
- 只读实际设备条件核查：devicectl help90190与list40544实际exit0，devices.json outcome=success/jsonVersion5；严格字段检查通过，两个device均reality=simulated/iOS27且bootState=shutdown，没有列出真机。指定UDID需后续重新boot/核实；这不证明Wi-Fi/热点/局域网权限或真机运行。结果在忽略的DerivedData/NetworkPlanning/devices.json。
- 首轮HTTP GREEN3265实际exit0/51/0/0，控制器完整读取attempt4短日志，包含terminate主类/category归属两项新警告；原始日志保留，警告已交实施者处理。组件/清理/取消边界尚未全部通过，iOS仍待验证。
- 60465组件边界RED实际exit1，日志network-task1-boundary-red.log成功编译后NETWORK_HTTP_FAILED component release cleans session。它证明独立组件释放留下隐藏session；原实施者已恢复继续处理，没有用原51项代替新增边界。
- 边界GREEN9828实际exit0，完整短日志network-task1-boundary-green2.log为66/0/0，未见原terminate警告；此前3700实际exit134，原系统ips指向上游stop清理重试时options=nil断言，实施者修复并保留诊断。此Mac结果不能替代待执行的iOS流程或审查。
- 首次generic Simulator65538由实施者收取实际exit0；quiet日志没有BUILD结果标记，UTType弃用及既有LAME signed不strip诊断保留。后续发现chunked整chunk缓冲边界，新增中途写盘真实断言9132运行中；修改后须重新取得最终平台证据，首次构建不是Task1最终验收。
- chunked中途写盘新增RED90662实际exit1：编译41.10秒后真实行为断言失败；修复后47938实际exit0，最终Mac流式日志67/0/0，控制器完整读取RED/GREEN短日志。原9132/73717编译中止不计行为RED；native IO50139的3项实际检查单列。最终iOS构建/hosted及独立审查仍待完成。
- 2026-10-04新增验收：底部文件/网络共享/更多，共享默认根目录，更多可进入现有下载页且复用下载状态；切离共享标签停止服务。真实WKWebView加载根页面后列出FileStore全部分类、下载、共享目录，逐项导航与真实磁盘内容一致；下载展示名与Downloads路径分离。截图未授权，不宣称视觉验证。
- Task1本轮实际Simulator55908/Device73174/build-for-testing47737退出0，原上游UTType及LAME诊断保留；Mac44055退出0/68项，native64302退出0/4项。hosted15152的最终exit/xcresult尚待收取，方法日志成功不代替整个命令结果。root读取Mac/native完整日志，xcresult目前无Info.plist读取得到exit64，不能认定损坏。
- hosted15152最终exit0；NetworkHTTP.xcresult的summary与tests读取exit0，root独立summary核实Passed/total1/pass1/fail0/skip0，iOS27/arm64、testFailures=[]、runtimeWarnings仅QoS1。Task1报告保存完整命令/终态/限制，24541eb/e581739实际提交普通推送；未运行真机网络或视觉验证。
- 独立Task1审查发现R1/R2不满足请求完整性与停止标准，原68项结果不覆盖分段零chunk结束空行和gzip流结束；已交实施者补有界真实请求RED/GREEN，不将静态审查推断记作实测。修复后须取得最终HTTP/hosted及针对性复查。
- 2026-10-04 root最终验证进行中：资源13、DAV30、HTTP98分别真实exit0；Simulator/Device产品构建exit0。资源首次RED为404；Mac资源定位错误来自测试未使用Bundle，其修正后13项通过。DAV HEAD测试改reloadIgnoringLocalCacheData后实际空body，避免GET缓存复用；Destination按已验证的Host解析实际端口。UI入口RED结果包NetworkEntrypointsRed.xcresult实际exit65，断言待独立summary核对；后续真实WKWebView/后台/二维码与最终UI结果尚未完成。地址与二维码单项测试在实现之后补充，不声称这两项已有独立先失败证据。
- SignedFunctionalFinal实际exit65/5通过3失败/无runtimeWarnings：全部5项NetworkRuntimeTests通过；入口自动化在旧清理helper点击文件标签时SIGTERM，复制按钮反馈通过但后台runner读取剪贴板nil，旧导航方法因历史文件多导致新建行不在AX视口失败。新网络方法改正常fresh launch，剪贴板改在前台应用实际粘贴进新建下载链接字段验证；旧导航创建前排唯一目录。保留原结果，不记UI全部通过。
- Web优化验收：沿用真实WKWebView加载资源与XHR/disk检查；补充390/1100视口无横向溢出、长中文名称、当前位置标题、SVG图标、最小44px触控目标、选择后上传按钮与清空恢复状态。新测试编译的async-autoclosure错误已经修正，不计行为RED；NetworkWebPolishRed运行待终态。无截图和视觉验收授权，不导出XCTest视觉附件。
- 最终网络/Web验收（2026-10-05）：WebPolishRed实际exit65目标状态断言失败，Green1实际3pass2UI失败（Web24、DAV37+资源13、旧下载导航搜索选择通过），按真实标题/列表视口修正后FinalConfirmation20007实际exit0，summary Passed/3pass0fail0skip/runtimeWarnings=[]；最终Web25及两原生共享方法通过。结合SignedFunctionalFinal五Runtime通过，全部8个唯一相关方法均取得成功终态，不虚构单个8/0/0结果包。最后Mac编译62760、资源GET/HEAD13及Device68531实际exit0；严格codesign验证独立命令exit0。机械检测一次exit0/[]；独立质量审查无剩余Critical/Important。真机互联、热点、隐私拒绝、物理锁屏与视觉仍未验证。
