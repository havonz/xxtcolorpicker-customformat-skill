# XXTColorPicker 自定义格式 Skill

把你想复制的点色文本或代码样例发给 Agent，它就能生成可导入 XXTColorPicker 的 Lua 自定义格式脚本，并用样例数据验证实际输出。随包的工具需要 Java 8 或更高版本，独立验证无需安装取色器。

## 让 Agent 直接安装

把下面整段复制给支持 Skills 的 Agent：

```text
请帮我安装 xxtcolorpicker-format 技能。下载这个 GitHub 仓库最新正式版的安装包：
https://github.com/havonz/xxtcolorpicker-customformat-skill/releases/latest/download/xxtcolorpicker-format.zip
如果 GitHub Release 附件暂时无法下载，请从同一仓库的 Tags 页选择最新的正式版本标签，下载该标签的 ZIP。

解压到临时目录，把包含 SKILL.md 的目录以 xxtcolorpicker-format 为名放进你当前使用的个人 skills 目录。
如果你是 Codex，请安装到 $CODEX_HOME/skills；未设置 CODEX_HOME 时使用 ~/.codex/skills。
安装完成后，SKILL.md 应位于 skills/xxtcolorpicker-format/SKILL.md。如果已有指向开发仓库的符号链接，请保留并直接验证它。
进入安装后的技能目录，运行 java -jar picker-format.jar check examples/relative-points.lua --case examples/relative-points.json。
告诉我实际安装路径和验证结果。如果当前环境缺少 Java，请注明工具尚未验证。
```

也可以手动[下载最新安装包](https://github.com/havonz/xxtcolorpicker-customformat-skill/releases/latest/download/xxtcolorpicker-format.zip)，或从[版本标签页](https://github.com/havonz/xxtcolorpicker-customformat-skill/tags)下载 ZIP。安装后，在新对话中试试：

> 使用 $xxtcolorpicker-format 帮我做一个多点取色格式。第一个点保留绝对坐标，其他点输出相对首点的偏移，颜色用六位大写十六进制。点击「生成代码」时复制整个 Lua 表。

## 使用与验证

在技能目录运行：

```sh
java -jar picker-format.jar new "我的点阵.lua" --name "我的点阵"
java -jar picker-format.jar check "我的点阵.lua"
```

将生成的脚本放入取色器工作目录的 `scripts/colorpicker/customformats/`，右键点击「自定格式」并选择「重新加载自定格式列表」。需要验证真实菜单、取色或结果行交互时，给 `check` 加上 `--host auto`。[回调手册](references/format-api.md) · [样例与验证说明](references/validation.md)

## 发布 ZIP

提交到 `main` 或创建 Pull Request 时，GitHub Actions 会打包当前提交，解压后运行包内的命令行回归测试。发布新版本时，在准备发布的提交上推送版本标签，例如：

```sh
git tag v0.1.1
git push origin v0.1.1
```

推送 `v*` 标签后，CI 将同一次运行验证通过的 `xxtcolorpicker-format.zip` 上传到对应的 GitHub Release。固定的最新版本下载地址可供 Agent 长期使用。[发布工作流](https://github.com/havonz/xxtcolorpicker-customformat-skill/actions/workflows/release.yml) · [历史版本](https://github.com/havonz/xxtcolorpicker-customformat-skill/releases)
