# 图像二值化与 Java 调用

两个函数都在桌面取色器中执行。输入是图像文件的原始**二进制字符串**，例如 `getRectPNGData` 的返回值。成功时返回同尺寸黑白图像的 **PNG 二进制字符串**，可以直接交给 `loadImageData` 打开预览；解码失败会抛出 Lua 错误。如需显式处理失败，使用 `pcall`。十六进制文本需先还原成字节。

## 按灰度分割

`png = thresholdImageData(data, threshold)`

固定阈值通常取 0–255 的整数。每个像素的灰度为 `floor(0.299*r + 0.587*g + 0.114*b + 0.5)`。灰度**严格大于**阈值时输出白色，等于或低于阈值时输出黑色。传 `-1` 启用 Otsu 自动阈值，按整幅图的灰度直方图选择类间方差最大的阈值。例如：

```lua
local w, h = getImageSize()
if w <= 0 or h <= 0 then return end
local data = getRectPNGData(0, 0, w - 1, h - 1)
loadImageData(thresholdImageData(data, -1))
```

内建格式的设置框接受文本 `auto`，脚本在调用前将它转换为数字 `-1`。直接调用接口时传数字。

## 按颜色提取前景

`png = binaryzationImageData(data, options)`（接口拼写为 `binaryzation`）。

`options` 是一个 Lua 表。数字索引项是颜色规则，命中其中任意一条即为前景。默认命中像素为白色、背景为黑色；`white_background = true` 时两者对调。空规则表产生纯背景图。

| 模式 | 规则与匹配条件 |
| --- | --- |
| 色偏，默认 | 每项 `{目标色, RGB色偏}`。三个通道的绝对差都要小于或等于各自的允许值。例如 `{0xFF8000, 0x100804}` 分别允许红差 16、绿差 8、蓝差 4。 |
| 相似度，`csim_mode = true` | 每项 `{目标色, 最低相似度}`。建议用 0–100 整数，得分大于或等于该值即命中。`csim_algorithm` 传 `0` 或省略使用 XXT 算法，`1` 为曼哈顿距离，`2` 为欧氏距离。 |

```lua
local function previewOrange(data)
  local png = binaryzationImageData(data, {
    white_background = true,
    csim_mode = true,
    csim_algorithm = 1,
    {0xFF8000, 90},
    {0xFFAA00, 95},
  })
  loadImageData(png)
end
```

独立工具支持对脚本提供的普通图像字节执行这两个函数。涉及当前画布截图、预览窗口或嵌入 ICC 配置的图像，请在真实取色器中验证。宿主解码时会尝试通过 Apache Commons Imaging 读取嵌入的 ICC 配置并转换到 sRGB，独立工具使用 Java ImageIO 的解码及 RGB 读取路径。[取色器原始实现摘录](native-image-implementation.md) · [独立工具的 Java 实现](../tools/src/picker/ImageData.java)

## Lua 调用 Java

宿主提供 `Java` 桥。用 `Java.class("包名.类名")` 取得类，`Java.new(类, 参数...)` 或 `Java.new("包名.类名", 参数...)` 调用构造器。静态方法通过类调用，实例方法通过对象调用，均使用 Lua 的冒号语法。静态常量使用点号。

```lua
local File = Java.class("java.io.File")
local directory = Java.new(File, "")
local path = directory:getAbsolutePath()  -- 实例方法

local JOptionPane = Java.class("javax.swing.JOptionPane")
JOptionPane:showMessageDialog(nil, path, "取色器工作目录", JOptionPane.INFORMATION_MESSAGE)
```

把弹窗放进双击或菜单动作。处理较大图像时，先在当前回调中取好图像字节，再调用 `Java.newThread(function() ... end):start()` 计算；从后台更新 Swing 界面时，可以用 `Java.dispatchEvent(function() ... end)` 切回界面线程。也可用 `Java.imple("java.lang.Runnable", {run = function() ... end})` 创建接口代理。这些调用使用桌面 JVM 的类和方法。独立验证器只模拟有限调用，使用 Swing 等实际类时请用 `--host auto` 或在取色器中操作。

## 从内建格式中找写法

以下两份文件按 XXTColorPicker 源码版本 `e80bdab` 的 `src/scripts/colorpicker/customformats/` 原样收录，保留宿主的翻译键。改写时复制为新的文件名并修改显示名称，方便与内建格式并用。

| 内建格式 | 建议从哪里读 |
| --- | --- |
| [X_Y_Color.lua](builtin/X_Y_Color.lua) | 搜 `multiPosFormatRule` 看如何控制对齐和换行。搜 `screen.find_color({` 看绝对坐标与相对首点偏移两种输出，以及 X/C 搜索区域。搜 `JOptionPane:showMessageDialog` 看如何用 Java 弹窗预览图像。 |
| [XXT-Bin-Dict.lua](builtin/XXT-Bin-Dict.lua) | 搜 `csim_mode` 看如何用选点生成颜色规则。搜 `thresholdImageData`、`binaryzationImageData` 看双击预览如何按参数选择算法。搜 `screen.ocr_text` 看右键动作如何组合区域和参数生成设备端代码。 |
