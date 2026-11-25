# 验证工具用法

从技能目录运行下列命令，脚本及样例文件也可用绝对路径。日常使用只需 Java，JAR 内含 LuaJ、兼容格式辅助函数和创建模板。

```sh
java -jar picker-format.jar new "首点定位.lua" --name "首点定位"
java -jar picker-format.jar check examples/relative-points.lua --case examples/relative-points.json
java -jar picker-format.jar check examples/relative-points.lua --case examples/relative-points.json --host auto
```

`--host` 可传 macOS 的 `.app`、含应用 JAR 的目录或 `XXTColorPicker.jar`。自动查找支持环境变量 `XXTCOLORPICKER_JAR`。宿主检查要求图形桌面、包含重新加载菜单的版本和兼容 JVM。每个用例在独立进程和临时工作目录中启动，使用内存剪贴板和临时配置。宿主会执行提交的 Lua，包括其顶层代码和用例指定的动作；对你准备在取色器里运行的脚本使用此模式。

## 用例

文件可以是一个 JSON 对象，也可以是按顺序执行的对象数组。一条最小的输出验收样例如下。

```json
{
  "points": [[100, 50, "0x00000A"]],
  "expect": {"generateClipboard": "{{100, 50, 0x00000A}}"}
}
```

| 字段 | 用法 |
| --- | --- |
| `name` | 可选，用例名称。 |
| `points` | 必填，顺序填入各取色槽的 `[x,y,rgb]` 数组。空数组表示未取色。RGB 支持 0–16777215 或带 0x 前缀的十六进制字符串。 |
| `regions` | 可选，`{"a":[x,y],"s":[x,y],"x":[x,y],"c":[x,y]}`。未给出的寄存器从原点开始。 |
| `settings` | 可选，按控件名覆盖默认值，保持布尔、数字、字符串类型。 |
| `hover` | 可选，传给光标回调的 `[x,y,rgb]`。缺省使用首点，空列表使用黑色原点。 |
| `actions` | 生成结果后按顺序执行。`{"type":"doubleClick","row":2}` 双击第 2 行。`{"type":"menu","row":2}` 列出菜单，加 `"item":1` 点击第 1 项。 |
| `expect` | 可选，按以下字段逐项比较，字符串精确区分大小写、空格和换行。省略时仍会执行规则、检查结构和返回值，并打印实际结果。 |

## 阅读结果

- `picked` 是取色槽文本数组，`pickClipboard` 是逐点规则拼接后的剪贴板。用例按宿主「导入点列表、重建剪贴板」的路径填充。
- `rows` 是生成时的行列数组，`generateClipboard` 是刚生成时的剪贴板。短行按其实际内容报告，省略右侧空列。
- `menus` 记录每次打开菜单时从上到下的项目名称。`afterRows` 和 `clipboard` 是全部指定操作后的结果。
- `hoverBottom` 与 `hoverZoom` 分别记录脚本显式提供的画布下方状态栏文本和右侧面板顶部信息行文本。
- `executed` 记录实际调用的规则，结合 `errors` 和 `unverified` 判断是否完成。`notRun` 标出该样例没有触发的已知规则。动态菜单的项只有求值后才能枚举。
- 退出码 0 表示本次执行的检查通过，1 表示脚本、用例或断言失败，2 表示存在未验证项。独立模式能验证纯 Lua 运算、模拟剪贴板和样例寄存器。独立模式中 `TR` 返回原文。涉及本地化控件键时，用宿主模式再核对当前语言。脚本提供图像字节时，独立模式可运行 `thresholdImageData` 和 `binaryzationImageData`。当前画布的像素、特定 Java 界面、文件对话框、外部模块或设备动作需要相应宿主条件。缺少条件时保留未验证项。宿主模式遇到等待输入的窗口会记录标题；需要人选择文件或操作设备的效果另行验证。

这个完整用例同时覆盖两列结果、相对偏移、配置和菜单操作：[relative-points.json](../examples/relative-points.json)。

## 从源码构建

工具源码和 Lua 探针在 `tools/src/` 和 `tools/lua/`。用 JDK 9+ 和 Python 3 调用 [build.py](../tools/build.py)，传入匹配版本的取色器源码目录与完整应用 JAR。例如在 macOS 可使用 `/Applications/XXTColorPicker.app/Contents/Resources/Java/XXTColorPicker.jar`。构建会生成技能根目录的 `picker-format.jar`，第三方许可在 JAR 的 `META-INF/licenses/`。运行已构建的工具无需源码。修改工具后可在技能目录运行 `python3 tools/test_cli.py --host auto` 复验创建、拒绝覆盖、坏脚本定位和两种运行模式。
