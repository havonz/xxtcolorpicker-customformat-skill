---
name: xxtcolorpicker-customformat
description: 为 XXTColorPicker（XXT 取色器）设计、编写或修改可导入的自定义格式 Lua 脚本。适用于按目标样例定制点色文本、生成代码、设置项和结果行交互、图片二值化预览、在格式中调用 Java，以及排查格式已加载但输出不符的问题。普通设备端 XXTouch 自动化脚本由相应的设备脚本工作流处理。
---

# XXTColorPicker 自定义格式设计

## 从用户要粘贴的结果开始

用户提到「右键」「双击」「右边那一行」或「放大镜」时，先按[画布与右侧面板操作指南](references/picker-interactions.md)定位控件。比如点色槽的文本框、紧邻的色块和「生成代码」下方的结果行，各有独立的双击行为。位置会改变实现且描述仍有歧义时，再问用户点的是哪一个。

先判断用户要改变哪个动作的结果。按数字键取色就要复制的内容，由点色规则控制。取完一组点再点「生成代码」的内容，由生成规则控制。这两个动作可以输出不同格式。

用户给了目标文本、函数调用或原脚本时，直接按样例工作。保留其中的字段顺序、引号、分隔符、颜色位数和换行。需求只有“帮我设计一个格式”时，先问一句「这段结果最终要粘到哪里？能贴一条你希望得到的结果吗？」对方还没想好，可以用同一对点对照展示绝对坐标和相对偏移，由用途决定。比如两点坐标为 `(100, 50)`、`(97, 55)`，第二点的绝对坐标是 `97, 55`，相对首点则是 `-3, 5`。只追问会改变输出的歧义。

按用户目标选择交付物。讨论设计时给出样例输入和精确输出；需要脚本时直接交付完整的 `.lua` 文件；修改已有格式时沿用它的文件名、显示名称、设置键和其余规则，除非这些本身就是修改目标。

## 创建和修改文件

可执行工具 [picker-format.jar](picker-format.jar) 随技能提供。用 Java 8 或更高版本运行。命令中 JAR 的相对路径以本技能目录为基准；在用户项目目录执行时给 JAR 传绝对路径。脚本路径使用用户的项目或交付目录。

```sh
java -jar picker-format.jar new "/目标目录/我的点阵.lua" --name "我的点阵"
java -jar picker-format.jar check "/目标目录/我的点阵.lua"
```

用户要新格式时，执行 `new`，再直接编辑生成的文件实现其需求。创建工具会保留已有同名文件。用户要改现有文件时，直接编辑指定文件并检查。随附[最小模板](assets/point-list.lua)与[带交互的完整示例](examples/relative-points.lua)展示两种不同复杂度。

- 桌面取色器使用 LuaJ，按 Lua 5.2 编写。需要输出设备端代码时，在生成规则中返回目标代码字符串。
- 模块返回 `{name = "...", formats = {...}}`。保留带 `title`、`args` 的 `settingsRule` 和显式返回字符串的 `multiPosFormatRule`。按数字键取色走这条逐点规则，剪贴板直接拼接返回值。
- 点击「生成代码」走 `makeScriptRules`。需要访问首点时先处理空列表。目标输出要求相对坐标时再计算偏移。第一条规则返回字符串会自动复制，返回数组则显示多列。
- 编写或解释回调时，查阅[逐项回调手册](references/format-api.md)。其中包含真实调用时机、参数、返回值、默认动作和当前宿主没有调用入口的旧字段。

图像预览用 `thresholdImageData`（固定阈值或 Otsu）或 `binaryzationImageData`（色偏或颜色相似度）。桌面回调可通过 `Java.class`、`Java.new` 调用 Java 方法。需要相关功能时，先读[图像接口与 Java 调用](references/image-and-java.md)，其中包含参数、实现和内建格式的阅读索引。生成点阵或找色代码可参考 [X_Y_Color.lua](references/builtin/X_Y_Color.lua)，生成 OCR 二值化参数或双击预览可参考 [XXT-Bin-Dict.lua](references/builtin/XXT-Bin-Dict.lua)。

## 用实际数据验收

用户提供了输出样例时，把样例输入和期望写入临时用例并执行检查。没有指定样例时，工具自带空列表、单点、带负偏移的两点。格式有操作菜单或双击行为时，在用例中明确触发对应行及菜单项。用例结构和报告字段见[验证工具说明](references/validation.md)。

```sh
java -jar picker-format.jar check examples/relative-points.lua --case examples/relative-points.json
java -jar picker-format.jar check examples/relative-points.lua --case examples/relative-points.json --host auto
```

检查结果不符时，按报告的文件、回调、输入及实际输出修正后重跑。独立模式报告宿主依赖时，使用本机兼容的 XXTColorPicker 执行宿主检查。退出码 2 表示有项目未验证，交付时列明具体缺项。对仅讨论方案的请求可直接用样例解释。

交付时给出实际生成的 Lua 文件、一组输入与输出、已验证的操作。将文件放入应用工作目录的 `scripts/colorpicker/customformats/`，可用「自定格式」右键菜单中的「从资源管理器查看」定位。随后点击「重新加载自定格式列表」并选中该格式。旧输出仍在时查看日志，加载失败会保留模块的上一可用版本。
