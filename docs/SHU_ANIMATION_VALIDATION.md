# 视频转动图服务验收

媒体Task3提供GIF/WebP服务。媒体操作页面属于Task4；本记录不代表完整复刻已完成。

## 当前实现

- VideoAnimationService顺序采样指定区间，应用视频显示方向。帧率1–30，循环0–65535；0无限循环，正数沿用图片服务的总播放次数语义。
- 质量为原画、最佳、极高、高、中、低，最长边分别为原尺寸、1280、960、720、480、320，不放大小输入。颜色提供原色编码器量化、216色web-safe、Rec.709灰度和亮度0.5阈值黑白。WebP编码质量为1。
- 按累计边界量化GIF百分之一秒/WebP千分之一秒时长，保留重复帧与最后一帧。总长误差不超过0.01/0.001秒；尾帧无法表示时开始前拒绝，要求调整区间或帧率。
- 单帧4000万像素、所有帧8000万像素、1000帧及WebP宽高16383限制在开始采样前校验。PNG暂存帧按需读取；编码和验证逐帧释放，不积存所有未压缩CGImage。
- 采样、编码、验证均计入真实进度；取消和失败清理唯一暂存目录。同名自动编号，保留原输入及已有文件；清理失败明确报告。
- 逐帧重读同时核对64×64预乘RGBA缩略图的平均通道误差不超过32，允许GIF调色板和WebP有损误差；核对尺寸、元数据及内容后发布。这是编码内容合理性检查，不承诺有损编码逐像素一致。
- 最终移动及暂存清理后分别检查取消，撤回本次实际编号输出；清理失败同样撤回，撤回失败明确报告结果路径。

采样使用[Apple AVAssetImageGenerator时间容差接口](https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/requestedtimetolerancebefore)。原生返回值仍需检查实际时间；非整秒首帧早于区间时，在一个源帧时长内重新定位。取得的帧必须位于区间内并满足误差界限；无法满足时明确失败。

## 固定WebP依赖

`Vendor/ShuWebP`来自libwebp-Xcode1.6.0固定提交`2b5256c29ff4e20f2a0d5ee863b62b1a22144434`。与原始缓存源码比较，仅`muxedit.c`和`mux.h`增加保留单帧动画封装入口；保留全部许可证，其他源码、sharpyuv和头文件映射一致。

标准MuxCleanup会将覆盖画布的单帧动画改为静态图并移除时长和循环。新入口省略此清理，仍使用原库的块写出和MuxValidate；只有新API的一帧动画调用该入口。原有静态、多帧转换继续使用标准入口。来源及维护代价见`Vendor/ShuWebP/README.md`。

## 已取得的证据

| 检查 | 实际结果 |
|---|---|
| 编译后stub行为RED | image-stream-red.log /14882退出133，animation-red.log /40687退出1 |
| 单帧WebP元数据RED/GREEN | image-stream-mux-red2.log /91384退出133；image-stream-green.log /94529完整退出0 |
| 累计时长RED/GREEN | image-stream-timing-red.log /22965编译后总时长断言失败；image-stream-final.log /63348退出0 |
| 非整秒采样RED/GREEN | animation-range-diagnosis.log /80826退出1，请求0.13/实际0.1；animation-range-green.log /87438完整48项退出0 |
| 当前Happu Mac动图 | animation-happu-final.log /38559退出0，48输出及全部边界通过 |
| 当前Happu完整图片 | image-happu-release.log /14425退出0，含逐帧回调、重复/单帧、透明单帧、累计时长、参数/资源拒绝、编码与验证回调失败、取消清理 |
| 相关媒体回归 | animation-video-regression.log /99822完整13项及扩展/边界退出0；animation-audio-regression.log /89847完整33项及边界退出0 |
| 当前Happu Simulator/Device | animation-happu-simulator.log /90774、animation-happu-device.log /13993均退出0/BUILD SUCCEEDED |
| 当前Happu签名测试构建 | animation-happu-testing.log /4704退出0/TEST BUILD SUCCEEDED |
| 当前Happu hosted iOS | animation-happu-runtime.log /5108退出0；AnimationHappuRuntime.xcresult结构化Passed/1通过/0失败/0跳过，内部48/48，arm64 iOS27.0，22.956秒，runtimeWarnings=[] |
| 更名前hosted iOS | animation-runtime.log /20881退出0；AnimationRuntime.xcresult为1通过/0失败/0跳过，内部48/48，arm64 iOS27.0，18.101秒，runtimeWarnings=[] |

当前Happu模块已完成三构建及hosted运行，更名前结果保持其原有范围。全部日志和xcresult位于忽略的DerivedData，不读取视觉附件或截图。功能已本地提交7d3a2eb，单次animation_review初审With fixes；root修复两项Important并补充真实用例，最终运行通过，未派第二审查者。

## 单次审查修复

- R1最终发布取消：animation-publish-red2.log /22171编译后退出1；第一轮29234因测试变量重名编译失败，不计行为RED。保留真实重名旧文件，输出移动后Progress取消、Task取消和暂存清理失败须撤回新文件；撤回失败明确抛出错误。
- R2内容验证：image-content-red.log /62123编译后退出133/Expected rejection；实现归一化内容核对后image-review-green.log /46143完整退出0，补强单帧变化、三帧顺序变化和低质量编码后image-review-final.log /93652完整通过。
- animation-review-green.log /31479为完整48及新增发布/清理边界退出0；Task取消补强后的animation-review-final.log与前项由93652顺序执行，整体退出0。
- 共享发布改动相关完整Audio33和Video13及边界由90287顺序运行，整体退出0，日志audio-review-green.log/video-review-green.log。Simulator15596及Device9243退出0，签名69654/75694退出0。
- 最终hosted69636退出0/TEST EXECUTE SUCCEEDED；AnimationReviewRuntime.xcresult独立summaryPassed/1通过/0失败/0跳过/runtimeWarnings=[]，内部48及新增Progress/Task取消、清理失败验证通过，方法28.378秒。普通签名codesign --verify --deep --strict退出0。

## 验证边界

- 48输出矩阵包括两种格式，1/10/29/30fps，0/1/4循环，六种质量、四种颜色，非整秒及单帧短区间。实际解码核对帧数、颜色时间标记、带方向的空间标记、灰度亮度/黑白阈值、尺寸及累计时长。
- 验证拒绝非法参数、零量化尾帧、总像素/帧数超限、路径和符号链接；取消覆盖采样、编码、验证及100%发布前边界，并核对无输出、无暂存及原文件完整。
- 原始日志保留API、PointerUI和Fig系统诊断；结构化runtimeWarnings为空不代表无系统日志。先前Device构建虽退出0但带五项异常SwiftCompile诊断，已重新取得明确BUILD SUCCEEDED，原日志保留。
- 单次原生采样、ImageIO完成及WebP封装的取消可能等待调用返回。真机、iOS18/26运行、媒体页面和视觉尚未验证。
