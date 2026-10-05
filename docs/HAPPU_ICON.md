# Happu 应用图标

- 需求：参照 Shu 的羽毛，为 Happu 制作应用图标。
- 图像：白底、蓝紫渐变、羽尖朝右上；简化羽枝与白色留白，无文字、阴影或预制圆角。
- 参考：本地原版 `Payload/Shu.app/AppIcon60x60@3x.png`，仅作造型和色彩参考。
- 生成方式：内置 imagegen；原始图像1254×1254，经系统sips规范为1024×1024不透明PNG。
- 交付文件：`Happu/Assets.xcassets/AppIcon.appiconset/HappuIcon.png`；Debug与Release使用AppIcon，SwiftPM服务目标排除资源目录。
- 验证：Simulator15596与Device9243构建退出0/BUILD SUCCEEDED；签名测试构建69654、补强用例后75694均退出0/TEST BUILD SUCCEEDED。实际包内iPhone/iPad的CFBundlePrimaryIcon/CFBundleIconName为AppIcon，包含AppIcon60x60与AppIcon76x76；小尺寸AppIcon60x60@2x.png为120×120。日志位于忽略的DerivedData/icon-*.log；推送待完成。

## 最终生成提示词

Use case: logo-brand. Create one final iOS app icon artwork for Happu, 1024x1024 square. Reference image is /Users/oyamameek/Documents/Happu/DerivedData/IconReference/shu-reference.jpg, the original Shu feather app icon. Use it only as visual inspiration for a single feather on white with a blue-to-purple gradient, not as an exact copy. Full-bleed opaque clean white square background, no rounded outer corners (iOS applies the mask). Center one elegant contemporary stylized feather, diagonally rising from lower left to upper right, gentle curved shaft, a confident organic asymmetric silhouette, smooth tapered separated barbs and a few clean white negative-space cuts. Feather occupies about 73% of the canvas height, balanced safe margins. Rich royal cobalt and indigo at the upper tip blending into violet and soft magenta toward the lower quill, inspired by the supplied reference. Simplify the feather into a distinctive refined mark with graceful flowing geometry and crisp graphic edges that remain legible at home-screen icon size. Flat vector-like graphic treatment, subtle smooth color gradient only, no photographic textures, no 3D bevel, no shadows, no glow. Just the feather and white background, no letters, no text, no border, no watermark, no additional symbols. Deliver the actual square artwork, not a phone mockup or presentation board.
