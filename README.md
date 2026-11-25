# XXTColorPicker 自定义格式

把一段希望复制的文本或代码发给 Agent，它可以为 XXTColorPicker 写出对应的 Lua 格式。例如，取色时复制一行坐标和颜色，取完一组点后生成找色代码，或按取到的颜色预览黑白图。

## 安装

复制这段话给你的 Agent：

> 请从 https://github.com/havonz/xxtcolorpicker-customformat-skill/releases/latest/download/xxtcolorpicker-customformat.zip 安装 `xxtcolorpicker-customformat` 到你的个人技能目录，让我在新对话中可以使用它。若附件暂时不可用，请从同一仓库的版本标签下载 ZIP。解压后，`xxtcolorpicker-customformat/SKILL.md` 应直接位于技能目录下。

也可以手动解压，把 `xxtcolorpicker-customformat` 文件夹放入 Agent 的技能目录。使用 Codex 时，默认位置是 `~/.codex/skills/`。随包的验证工具需要 Java 8 或更高版本。[下载最新安装包](https://github.com/havonz/xxtcolorpicker-customformat-skill/releases/latest/download/xxtcolorpicker-customformat.zip) · [版本标签](https://github.com/havonz/xxtcolorpicker-customformat-skill/tags)

## 创建和使用格式

安装后，在新对话里试试：

> 用 $xxtcolorpicker-customformat 做一个格式。选中两个点后，我希望复制 `{{100, 50, 0x00000A}, {-3, 5, 0xFF00AB}}`。第一项是首点坐标，后面各项是相对首点的偏移。

拿到 `.lua` 文件后，在取色器中右键点击「自定格式」→「从资源管理器查看」，将文件放入打开的 `scripts/colorpicker/customformats/` 目录。再次右键点击「自定格式」→「重新加载自定格式列表」，在下拉列表中选中新格式，即可取色或生成代码。

取色槽文本、旁边的色块和下方生成结果行有不同的双击行为。可以按位置查阅[画布与右侧面板操作指南](references/picker-interactions.md)。

## 编写自己的格式

- 想改点色文本或生成多点找色代码，可从[点色列表示例](assets/point-list.lua)起步，或查看内建的 [X, Y, Color](references/builtin/X_Y_Color.lua)。
- 想按灰度、色偏或相似度提取前景，可参考内建的 [XXT-Bin-Dict](references/builtin/XXT-Bin-Dict.lua)。[图像接口与 Java 调用](references/image-and-java.md)给出了参数和预览示例。
- 想增加配置项、双击或右键菜单，可查[回调手册](references/format-api.md)。脚本写好后，可以从技能目录运行下面的命令查看实际输出。[更多验证方式](references/validation.md)

```sh
java -jar picker-format.jar check "我的格式.lua"
```
