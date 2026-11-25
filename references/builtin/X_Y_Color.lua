-- Please do not modify this file.
-- This file will restore to its initial state when the software starts.
-- If you need to make any changes, please make a copy first and then make the alterations.

-- 请不要修改本文件
-- 本文件会在软件启动时恢复初始状态
-- 如需修改，请拷贝一份再做改动

require("scripts.colorpicker.customformats")

local orientations_map = {
	[TR("Home On Bottom")] = 0,
	[TR("Home On Right")] = 1,
	[TR("Home On Left")] = 2,
	[TR("Home On Top")] = 3,
}

local JOptionPane = Java.class("javax.swing.JOptionPane")
local ImageIcon = Java.class("javax.swing.ImageIcon")
local File = Java.class("java.io.File")

return {
	name = "X, Y, Color",
	description = TR("X, Y, Color"),
	formats = {
		settingsRule = {
			title = TR("Parameter settings for the custom format [X, Y, Color]"),
			args = {
				{TR("Default Color Similarity"),
				 85, -- 默认值为数字，且第三个参数用一个表描述范围则用一个 Slider（滑动条） 描述
				 {
					 10,  -- Slider 的最小值
					 100, -- Slider 的最大值
				 },
				},
				{TR("Aligning Using Spaces"), true}, -- 默认值是布尔类型则控件用 CheckBox（勾选框） 描述
				{TR("Using Line Break"), true},
				{TR("Color Offset Mode"), false},
				{TR("Default Color Offset"), 101010}, -- 默认值是字符串或者数字且没有第三个参数则用 TextFeild（文本框） 描述
				{TR("XXTDo Action"),
				 TR("Tap the last point in the PosColor list"),
				 {
					 TR("Tap the first point in the PosColor list"),
					 TR("Tap the last point in the PosColor list"),
					 TR("Tap point A"),
					 TR("Tap point S"),
					 TR("Tap point X"),
					 TR("Tap point C"),
					 TR("Execute Custom Code"),
				 },
				},
				{TR("XXTDo Action Custom Code"), "local ui = type(self.group) == 'table' and self.group[1] or self;touch.tap(ui[#ui][1], ui[#ui][2])"},
                {TR("Default OCR Language"), '"zh-Hans"'},
				{TR("Orientation During Testing"),
				 TR("Home On Bottom"),
				 {
					 TR("Home On Bottom"),
					 TR("Home On Right"),
					 TR("Home On Left"),
					 TR("Home On Top"),
				 },
                },
                {TR("Path for saving small images"), Java.new(File, ""):getAbsolutePath()},
				{TR("After saving the small image, gen code to the clipboard"), '#NAME# = image.load_file(XXT_RES_PATH.."/#FILENAME#");'},
				--{TR("Small Images Scale"),
				-- 100,
				-- {
				--	 1,   -- Slider 的最小值
				--	 100, -- Slider 的最大值
				-- },
				--},
			},
		},
		singlePosFormatRule = (function(p, a, s, x, c, set)
			local fmt = string.format("%4d, %4d, 0x%06x ", p.x, p.y, p.c)
			if not toboolean(set[TR("Aligning Using Spaces")]) then
				fmt = fmt:gsub(" ", "")
			end
			return fmt
		end),
		multiPosFormatRule = (function(p, a, s, x, c, set)
			local fmt = string.format(" %4d, %4d, 0x%06x \n", p.x, p.y, p.c)
			if not toboolean(set[TR("Using Line Break")]) then
				fmt = fmt:gsub("\n", ""):gsub("\t", "")
			end
			if not toboolean(set[TR("Aligning Using Spaces")]) then
				fmt = fmt:gsub(" ", "")
			end
			return fmt
		end),
		mouseTrackInfoBottomRule = (function(p, a, s, x, c, set)
			return string.format("XY: (%4d, %4d)      Color: 0x%06x      RGB: (%3d, %3d, %3d)", p.x, p.y, p.c, p.r, p.g, p.b)
		end),
		mouseTrackInfoZoomRule = (function(p, a, s, x, c, set)
			return string.format("(%4d,%4d):0x%06x:(%3d,%3d,%3d)", p.x, p.y, p.c, p.r, p.g, p.b)
		end),
		makeScriptRules = {
			{
				maker = function(poslist, set)
					if #poslist < 1 then
						return "{}: "..TR("Need to take at least 1 PosColor")
					end
                    local is_co_mode = toboolean(set[TR("Color Offset Mode")])
                    local buf = {"{\n"}
					for _,currentPos in ipairs(poslist) do
						if is_co_mode then
							buf[#buf + 1] = string.format("\t{%4d, %4d, {0x%06x, 0x%06x} },\n", currentPos.x, currentPos.y, currentPos.c, (tonumber(set[TR("Default Color Offset")], 16) or 0x101010))
						else
							buf[#buf + 1] = string.format("\t{%4d, %4d, 0x%06x },\n", currentPos.x, currentPos.y, currentPos.c)
						end
					end
                    buf[#buf + 1] = "}"
					local ret = table.concat(buf)
					if not toboolean(set[TR("Using Line Break")]) then
						ret = ret:gsub("\n", ""):gsub("\t", "")
					end
					if not toboolean(set[TR("Aligning Using Spaces")]) then
						ret = ret:gsub(" ", "")
					end
					return ret
				end,
				menu = {
					{
						name = TR("Format Readme"),
						action = function(s, idx, poslist, set)
							alert(TR("A general point color table, used in various script frameworks, which requires developers to parse and use it themselves"), TR("Format Readme"))
						end,
					},
				},
			},
			{
				maker = function(poslist, set)
					if #poslist < 1 then
						return TR("Need to take at least 1 PosColor")
					end
                    local is_co_mode = toboolean(set[TR("Color Offset Mode")])
                    local buf = {}
					for _,currentPos in ipairs(poslist) do
						if is_co_mode then
							buf[#buf + 1] = string.format("{%4d, %4d, {0x%06x, 0x%06x} },\n", currentPos.x, currentPos.y, currentPos.c, (tonumber(set[TR("Default Color Offset")], 16) or 0x101010))
						else
							buf[#buf + 1] = string.format("{%4d, %4d, 0x%06x },\n", currentPos.x, currentPos.y, currentPos.c)
						end
					end
					local ret = table.concat(buf)
					if not toboolean(set[TR("Using Line Break")]) then
						ret = ret:gsub("\n", ""):gsub("\t", "")
					end
					if not toboolean(set[TR("Aligning Using Spaces")]) then
						ret = ret:gsub(" ", "")
					end
					return ret
				end,
				menu = {
					{
						name = TR("Format Readme"),
						action = function(s, idx, poslist, set)
							alert(TR("A general point color table, used in various script frameworks, which requires developers to parse and use it themselves"), TR("Format Readme"))
						end,
					},
				},
			},
			{
				maker = function(poslist, set)
					if #poslist < 1 then
						return "XXTDo: "..TR("Need to take at least 1 PosColor")
					end
					local fmt = "\t\t\t{ %4d, %4d, 0x%06x},\n"
					local cen, act, ret
					local cen_buf, act_buf, ret_buf
                    ret_buf = {string.format("{name = '__UI_%s__', group = {\n\t\t", os.date('%Y%m%d%H%M%S'))}
					cen_buf = {"{\n"}
					for _,currentPos in ipairs(poslist) do
						cen_buf[#cen_buf + 1] = string.format(fmt, currentPos.x, currentPos.y, currentPos.c)
					end
					cen_buf[#cen_buf + 1] = "\t\t},"
					cen = table.concat(cen_buf)
					if not toboolean(set[TR("Aligning Using Spaces")]) then
						cen = cen:gsub(" ", "")
					end
					if not toboolean(set[TR("Using Line Break")]) then
						cen = cen:gsub("\n", ""):gsub("\t", "")
					end
					ret_buf[#ret_buf + 1] = cen
					ret_buf[#ret_buf + 1] = "\n\t},\n\trun = function(self, index, parent)"
					-- {TR("Tap the first point in the PosColor list"), TR("Tap the last point in the PosColor list"), TR("Tap point A"), TR("Tap point S"), TR("Tap point X"), TR("Tap point C"), TR("Execute Custom Code")},
					act_buf = {"\n\t\t"}
					if set[TR("XXTDo Action")] == TR("Tap the first point in the PosColor list") then
						act_buf[#act_buf + 1] = string.format("touch.tap(%d, %d)", poslist[1].x, poslist[1].y)
					elseif set[TR("XXTDo Action")] == TR("Tap the last point in the PosColor list") then
						act_buf[#act_buf + 1] = string.format("touch.tap(%d, %d)", poslist[#poslist].x, poslist[#poslist].y)
					elseif set[TR("XXTDo Action")] == TR("Tap point A") then
						act_buf[#act_buf + 1] = string.format("touch.tap(%d, %d)", poslist.a.x, poslist.a.y)
					elseif set[TR("XXTDo Action")] == TR("Tap point S") then
						act_buf[#act_buf + 1] = string.format("touch.tap(%d, %d)", poslist.s.x, poslist.s.y)
					elseif set[TR("XXTDo Action")] == TR("Tap point X") then
						act_buf[#act_buf + 1] = string.format("touch.tap(%d, %d)", poslist.x.x, poslist.x.y)
					elseif set[TR("XXTDo Action")] == TR("Tap point C") then
						act_buf[#act_buf + 1] = string.format("touch.tap(%d, %d)", poslist.c.x, poslist.c.y)
					end
					if set[TR("XXTDo Action")] == TR("Execute Custom Code") then
						act_buf[#act_buf + 1] = string.format("%s", set[TR("XXTDo Action Custom Code")] or "")
						act_buf[#act_buf + 1] = "\n\t"
						act = table.concat(act_buf)
					else
						act_buf[#act_buf + 1] = "\n\t"
						act = table.concat(act_buf)
						if not toboolean(set[TR("Using Line Break")]) then
							act = act:gsub("\n", ""):gsub("\t", "")
						end
					end
					ret_buf[#ret_buf + 1] = act
					if not toboolean(set[TR("Using Line Break")]) then
						ret_buf[#ret_buf + 1] = " " -- 不是换行格式在 end 前加个空格
					end
					ret_buf[#ret_buf + 1] = "end,\n},\n"
					ret = table.concat(ret_buf)
					return ret
				end,
				menu = {
					{
						name = TR("Format Readme"),
						action = function(s, idx, poslist, set)
							alert(TR("Generate an interface trigger for use by the XXTDo\nUse with the XXTDo"), TR("Format Readme"))
						end,
					},
					{
						name = TR("Test On Device"),
						action = function(s, idx, poslist, set)
							local buf = {string.format("local o = %d;screen.init(o);nLog('[TEST]: screen.init('..o..')')\n", tonumber(orientations_map[set[TR("Orientation During Testing")]]) or 0)}
							buf[#buf + 1] = [[success, XXTDo = pcall(require, 'XXTDo')
							if not success then
							    XXT_HOME_PATH = XXT_HOME_PATH or '/var/mobile/Media/1ferver'
								local XXTDoPath = XXT_HOME_PATH..'/lua/XXTDo.lua'
								nLog("[TEST] XXTDo: "..]] buf[#buf + 1] = string.format("%q", TR("Testing code changes requires XXTDo.lua")) buf[#buf + 1] = [[)
								local ip, port = nLog()
								local success, c, h, r = pcall(http.get, string.format('http://%s:%d/XXTDo.lua', ip, port))
								if success and c == 200 then
									file.writes(XXTDoPath, r)
									nLog("[TEST] XXTDo: "..string.format(]] buf[#buf + 1] = string.format("%q", TR("Automatically importing XXTDo.lua to device path '%s'")) buf[#buf + 1] = [[, XXTDoPath))
									success, XXTDo = pcall(require, 'XXTDo')
									if not success then
										os.remove(XXTDoPath)
										nLog("[TEST] XXTDo: "..string.format(]] buf[#buf + 1] = string.format("%q", TR("Automatic import of XXTDo.lua failed\nPlease manually import XXTDo.lua to the device path '%s'")) buf[#buf + 1] = [[, XXTDoPath))
										os.exit()
									end
								else
									nLog("[TEST] XXTDo: "..string.format(]] buf[#buf + 1] = string.format("%q", TR("Automatic import of XXTDo.lua failed\nPlease manually import XXTDo.lua to the device path '%s'")) buf[#buf + 1] = [[, XXTDoPath))
									os.exit()
								end
							end
							nLog("[TEST] XXTDo: "..]] buf[#buf + 1] = string.format("%q", TR("The timeout is set to 5 seconds. If no match is found within the timeout, the matching loop will be exited")) buf[#buf + 1] = [[)
							XXTDo.runloop{name = "XXTColorPicker-TestOnDevice",
							log = nLog, timeout_s = 5, timeout_run = function() XXTDo.breakloop() end, error = function(errmsg) nLog("[TEST] XXTDo: RuntimeError: ", json.decode(errmsg)) os.exit() end,]]
							buf[#buf + 1] = s
							buf[#buf + 1] = "}"
							local code = table.concat(buf)
							if load(code) then
								Java.newThread(function()
									uploadScriptAndRun(code)
								end):start()
							else
								alertError(TR("Please generate custom code as required"), TR("Cannot Test"))
							end
						end,
					},
				},
			},
			{
				maker = function(poslist, set)
					if #poslist < 1 then
						return "is_colors: "..TR("Need to take at least 1 PosColor")
					end
					local buf = {"if (screen.is_colors({\n"}
					for i,currentPos in ipairs(poslist) do
						buf[#buf + 1] = string.format("\t{%4d, %4d, 0x%06x },\n", currentPos.x, currentPos.y, currentPos.c)
					end
					buf[#buf + 1] = "}, "
					buf[#buf + 1] = set[TR("Default Color Similarity")]..")) then"
					local ret = table.concat(buf)
					if not toboolean(set[TR("Using Line Break")]) then
						ret = ret:gsub("\n", ""):gsub("\t", "")
					end
					if not toboolean(set[TR("Aligning Using Spaces")]) then
						ret = ret:gsub(" ", "")
					end
					return ret
				end,
				menu = {
					{
						name = TR("Format Readme"),
						action = function(s, idx, poslist, set)
							alert(TR("This format is dedicated to the function screen.is_colors defined by XXTouch"), TR("Format Readme"))
						end,
					},
					{
						name = TR("Test On Device"),
						action = function(s, idx, poslist, set)
                            local buf = {string.format("local o = %d;screen.init(o);nLog('[TEST]: screen.init('..o..')')\n", tonumber(orientations_map[set[TR("Orientation During Testing")]]) or 0)}
                            buf[#buf + 1] = isColorCodeDefine
                            buf[#buf + 1] = s
                            buf[#buf + 1] = [[
									nLog("[TEST] screen.is_colors results: true")
								else
									nLog("[TEST] screen.is_colors results: false")
								end
							]]
							local code = table.concat(buf)
							if load(code) then
								Java.newThread(function()
									uploadScriptAndRun(code)
								end):start()
							else
								alertError(TR("Please generate custom code as required"), TR("Cannot Test"))
							end
						end,
					},
				},
			},
			{
				maker = function(poslist, set)
					if #poslist < 1 then
						return "find_color-1: "..TR("Need to take at least 1 PosColor")
					end
                    local is_co_mode = toboolean(set[TR("Color Offset Mode")])
					local buf = {"x, y = screen.find_color({\n"}
                    for _,currentPos in ipairs(poslist) do
                        if is_co_mode then
                            buf[#buf + 1] = string.format("{%4d, %4d, {0x%06x, 0x%06x} },\n", currentPos.x, currentPos.y, currentPos.c, (tonumber(set[TR("Default Color Offset")], 16) or 0x101010))
                        else
                            buf[#buf + 1] = string.format("{%4d, %4d, 0x%06x },\n", currentPos.x, currentPos.y, currentPos.c)
                        end
                    end
					if is_co_mode then
						buf[#buf + 1] = "}"
					else
						buf[#buf + 1] = "}, "
						buf[#buf + 1] = tostring(tonumber(set[TR("Default Color Similarity")]) or 90)
					end
					if not (0 == poslist.x.x and 0 == poslist.x.y and 0 == poslist.c.x and 0 == poslist.c.y) then
                        buf[#buf + 1] = string.format(", %4d, %4d, %4d, %4d", poslist.x.x, poslist.x.y, poslist.c.x, poslist.c.y)
                    end
					buf[#buf + 1] = ")"
					local ret = table.concat(buf)
					if not toboolean(set[TR("Using Line Break")]) then
						ret = ret:gsub("[\n\t]", "")
					end
					if not toboolean(set[TR("Aligning Using Spaces")]) then
						ret = ret:gsub(" ", "")
					end
					return ret
				end,
				menu = function(s, idx, poslist, set)
					if load(s) then
						return {
							{
								name = TR("Format Readme"),
								action = function(s, idx, poslist, set)
									alert(TR("This format is specially used for the function screen.find_color defined by XXTouch\nAll coordinates captured are absolute coordinates"), TR("Format Readme"))
								end,
							},
							{
								name = TR("Test On Device"),
								action = function(s, idx, poslist, set)
									local code = string.format("local o = %d;screen.init(o);nLog('[TEST]: screen.init('..o..')')\n", tonumber(orientations_map[set[TR("Orientation During Testing")]]) or 0)
									code = code .. s ..[[
										nLog("[TEST] screen.find_color results: "..tostring(x)..", "..tostring(y))
									]]
									if load(code) then
										Java.newThread(function()
											uploadScriptAndRun(code)
										end):start()
									else
										alertError(TR("Please generate custom code as required"), TR("Cannot Test"))
									end
								end,
							},
						}
					end
				end,
			},
			{
				maker = function(poslist, set)
					if #poslist < 1 then
						return "find_color-2: "..TR("Need to take at least 1 PosColor")
					end
                    local is_co_mode = toboolean(set[TR("Color Offset Mode")])
					local buf = {"x, y = screen.find_color({\n"}
					local firstPos
					for i,currentPos in ipairs(poslist) do
						if (1 == i) then
							firstPos = currentPos
							if is_co_mode then
								buf[#buf + 1] = string.format("\t{%4d, %4d, {0x%06x, 0x%06x} },\n", 0, 0, firstPos.c, (tonumber(set[TR("Default Color Offset")], 16) or 0x101010))
							else
								buf[#buf + 1] = string.format("\t{%4d, %4d, 0x%06x },\n", 0, 0, firstPos.c)
							end
						else
							buf[#buf + 1] = string.format("\t{%4d, %4d, 0x%06x },\n", currentPos.x - firstPos.x, currentPos.y - firstPos.y, currentPos.c)
						end
					end
					if is_co_mode then
						buf[#buf + 1] = "}"
					else
						buf[#buf + 1] = "}, "
						buf[#buf + 1] = tostring(tonumber(set[TR("Default Color Similarity")]) or 90)
					end
					if not (0 == poslist.x.x and 0 == poslist.x.y and 0 == poslist.c.x and 0 == poslist.c.y) then
                        buf[#buf + 1] = string.format(", %4d, %4d, %4d, %4d", poslist.x.x, poslist.x.y, poslist.c.x, poslist.c.y)
                    end
					buf[#buf + 1] = ")"
					local ret = table.concat(buf)
					if not toboolean(set[TR("Using Line Break")]) then
						ret = ret:gsub("[\n\t]", "")
					end
					if not toboolean(set[TR("Aligning Using Spaces")]) then
						ret = ret:gsub(" ", "")
					end
					return ret
				end,
				menu = function(s, idx, poslist, set)
					if load(s) then
						return {
							{
								name = TR("Format Readme"),
								action = function(s, idx, poslist, set)
									alert(TR("This format is specially used for the function screen.find_color defined by XXTouch\nOnly relative coordinates are captured"), TR("Format Readme"))
								end,
							},
							{
								name = TR("Test On Device"),
								action = function(s, idx, poslist, set)
									local code = string.format("local o = %d;screen.init(o);nLog('[TEST]: screen.init('..o..')')\n", tonumber(orientations_map[set[TR("Orientation During Testing")]]) or 0)
									code = code .. s ..[[
										nLog("[TEST] screen.find_color results: "..tostring(x)..", "..tostring(y))
									]]
									if load(code) then
										Java.newThread(function()
											uploadScriptAndRun(code)
										end):start()
									else
										alertError(TR("Please generate custom code as required"), TR("Cannot Test"))
									end
								end,
							},
						}
					end
				end,
			},
			{
				maker = function(poslist, set)
					local tl = poslist.x
					local br = poslist.c
					if br.x <= tl.x and br.y <= tl.y then
						return "ocr_text: "..TR("Please use [Ctrl + left mouse button] to select an rect on the image")
					end
					return string.format("txt, info = screen.ocr_text(%d, %d, %d, %d, %s)", tl.x, tl.y, br.x, br.y, set[TR("Default OCR Language")])
				end,
				menu = {
					{
						name = TR("Format Readme"),
						action = function(s, idx, poslist, set)
							alert(TR("This format is specially used for the screen.ocr_text screen text recognition function defined by XXTouch\nUse [Ctrl + left mouse button] to select the text area that needs to be recognized"), TR("Format Readme"))
						end,
					},
					{
						name = TR("Test On Device"),
						action = function(s, idx, poslist, set)
							local code = string.format("local o = %d;screen.init(o);nLog('[TEST]: screen.init('..o..')')\n", tonumber(orientations_map[set[TR("Orientation During Testing")]]) or 0)
							code = code .. s ..[[
								nLog("[TEST] screen.ocr_text results: ", txt, info)
							]]
							if load(code) then
								Java.newThread(function()
									uploadScriptAndRun(code)
								end):start()
							else
								alertError(TR("Please generate custom code as required"), TR("Cannot Test"))
							end
						end,
					},
				},
			},
			{
				maker = function(poslist, set)
					local a = poslist.a
					local s = poslist.s
					local x = poslist.x
					local c = poslist.c
                    local ex, ey = getImageSize()
                    find_image_preview_data = nil
					find_image_preview_data_hex = nil
					if a.x~=s.x and a.y~=s.y and a.x > 0 and a.y > 0 and s.x < ex and s.y < ey then
						--					local function s2h(s,cp)return(string.gsub(s,"(.)",function(c)return string.format("\\x%02x%s",string.byte(c),cp or"")end))end
						--					return 'local x, y = screen.find_image( -- '..string.format("TR: %d, %d | BR: %d, %d", a.x, a.y, s.x, s.y)..'\n"'..s2h(getRectPNGData(a.x, a.y, s.x, s.y))..'"\n, 95, __这里替换成区域__)'
						local noerr, data = pcall(getRectPNGData, a.x, a.y, s.x, s.y)
                        if noerr then
                            find_image_preview_data = data
						    find_image_preview_data_hex = data:toHex(false, "\\x")
							if (not (x.x==x.y and c.x==c.y)) and -- 区域不为 0, 0, 0, 0
									x.x~=c.x and x.y~=c.y and x.x > 0 and x.y > 0 and --[[c.x < ex and c.y < ey and--]]
									x.x<=a.x and x.y<=a.y and c.x>=s.x and c.y>=s.y -- XC选区范围大于AS选区
							then
								return 'x, y = screen.find_image( -- '..string.format("TL: %d, %d | BR: %d, %d", a.x, a.y, s.x, s.y)..'\n"'..find_image_preview_data_hex..'"\n, 95, '..string.format("%d, %d, %d, %d)", x.x, x.y, c.x, c.y)
							else
								return 'x, y = screen.find_image( -- '..string.format("TL: %d, %d | BR: %d, %d", a.x, a.y, s.x, s.y)..'\n"'..find_image_preview_data_hex..'"\n, 95, __RECT__)'
							end
						else
							alertError(data)
							return TR("Code generation failed")
						end
					else
						return "find_image: "..TR("Please use [Shift + left mouse button] to select an rect on the image")
					end
				end,
				menu = {
					{
						name = TR("Format Readme"),
						action = function(s, idx, poslist, set)
							alert(TR("This format is specially used for the function screen.find_image defined by XXTouch to find images in area or full screen\nUse [Shift + left mouse button] to select the image block to be found\nUse [Ctrl + left mouse button] to select the image search area"), TR("Format Readme"))
						end,
					},
					{
						name = TR("Copy `image.load_data([data])`"),
						action = function(s, idx, poslist, set)
                            if find_image_preview_data_hex then
                                copyText("image.load_data(\"" .. find_image_preview_data_hex .. "\")")
                            else
                                alertError(TR("Please use [Shift + left mouse button] to select an rect on the image"))
                            end
						end,
					},
					{
						name = TR("Preview Image"),
						action = function(s, idx, poslist, set)
                            if find_image_preview_data then
                                JOptionPane:showMessageDialog(nil, Java.new(ImageIcon, find_image_preview_data), TR("Preview Image"), JOptionPane.PLAIN_MESSAGE)
                            else
                                alertError(TR("Please use [Shift + left mouse button] to select an rect on the image"))
                            end
						end,
					},
					{
						name = TR("Test On Device"),
						action = function(s, idx, poslist, set)
							local code = string.format("local o = %d;screen.init(o);nLog('[TEST]: screen.init('..o..')')\n", tonumber(orientations_map[set[TR("Orientation During Testing")]]) or 0)
							code = code .. s ..[[
							nLog("[TEST] screen.find_image results: "..tostring(x)..", "..tostring(y))
							]]
							if load(code) then
								Java.newThread(function()
									uploadScriptAndRun(code)
								end):start()
							else
								alertError(TR("Please generate custom code as required"), TR("Cannot Test"))
							end
						end,
					},
				},
			},
            {
			    -- maker 是指点击 生成代码 按钮时，会触发的动作，它的返回值文本将设为列表中该项的文本内容，它的参数为 (点色列表及区域, 配置选项)
                maker = function (poslist, set)
                    return TR("Use [Shift + left mouse button] to select the area") .. "\n> " .. TR("Double-click to crop the small image") .. " <"
                end,
                -- doubleClick 是在鼠标双击列表中该项会触发的动作，它的参数为 (当前项的文本内容, 当前项在列表中的序号, 点色列表及区域, 配置选项)
                doubleClick = function (s, idx, poslist, set)
                    local a = poslist.a
                    local s = poslist.s
                    local ex, ey = getImageSize()
					if a.x~=s.x and a.y~=s.y and a.x >= 0 and a.y >= 0 and s.x < ex and s.y < ey then
						local ok, data = pcall(getRectPNGData, a.x, a.y, s.x, s.y)
                        if ok then
                            local name = JOptionPane:showInputDialog(nil, Java.new(ImageIcon, data), TR("Please enter the name of the saved small image"), JOptionPane.PLAIN_MESSAGE)
                            if not name then
                                return
                            end
							--local scale = tonumber(set[TR("Small Images Scale")]) or 100
							--if scale < 100 then
							--	data = scaleImageData(data, scale/100)
							--end
                            if name == '' then
                                name = os.date('IMG_%Y%m%d%H%M%S')
                            end
                            local fn = name..".png"
                            local code = set[TR("After saving the small image, gen code to the clipboard")]
                            if code:find("#FILENAME#", 1, true) or code:find("#NAME#", 1, true) or code:find("#IMAGEDATAHEX#", 1, true) then
								code = code:gsub("#FILENAME#", fn):gsub("#NAME#", name)
								if code:find("#IMAGEDATAHEX#", 1, true) then
									code = code:gsub("#IMAGEDATAHEX#", data:toHex(false, "\\x"))
								end
								copyText(code)
                            end
                            local dir = set[TR("Path for saving small images")]
                            if dir:sub(-1) ~= "/" and dir:sub(-1) ~= "\\" then
                                dir = dir .. "/"
                            end
                            local path = dir..fn
                            local f, err = io.open(path, "wb")
                            if not f then
                                alertError(err, TR("Unable to save small image"))
                                return
                            end
                            f:write(data)
                            f:close()
                            printLog(TR("The small image has been saved as: ")..path)
						else
							alertError(xdata)
						end
					else
						alertError(TR("Please use [Shift + left mouse button] to select an rect on the image"))
					end
                end,
                -- menu 是在鼠标右键列表中该项会触发的动作，它的参数为 (当前项的文本内容, 当前项在列表中的序号, 点色列表及区域, 配置选项)
                menu = {
					{
						name = TR("Format Readme"),
						action = function(s, idx, poslist, set)
							alert(TR("This format is used to extract small images and save them as files. \nThe option `Path for saving small images` can be configured to specify the path for saving the small images. \nThe option `After saving the small image, generate code to the clipboard` can be configured to specify the format for generating the code after saving the small image."), TR("Format Readme"))
						end,
					},
					{
						name = TR("Open small images folder"),
						action = function(s, idx, poslist, set)
                            openFolder(set[TR("Path for saving small images")])
						end,
					},
					{
						name = TR("Path for saving small images"),
						action = function(s, idx, poslist, set)
                            local path = JOptionPane:showInputDialog(nil, TR("Path for saving small images"), TR("Path for saving small images"), JOptionPane.PLAIN_MESSAGE, nil, nil, set[TR("Path for saving small images")])
                            if not path then
                                return
                            end
                            set[TR("Path for saving small images")] = path
                            saveCustomFormatConfig(set)
						end,
					},
					{
						name = TR("After saving the small image, gen code to the clipboard"),
						action = function(s, idx, poslist, set)
                            local code = JOptionPane:showInputDialog(nil, table.concat({
								TR("#NAME# is used to represent the name of the small image"),
								TR("#FILENAME# is used to represent the file name of the small image"),
								TR("#IMAGEDATAHEX# is used to represent the hex-data of the small image"),
							}, "\n"), TR("After saving the small image, gen code to the clipboard"), JOptionPane.PLAIN_MESSAGE, nil, nil, set[TR("After saving the small image, gen code to the clipboard")])
                            if not code then
                                return
                            end
                            set[TR("After saving the small image, gen code to the clipboard")] = code
                            saveCustomFormatConfig(set)
						end,
					},
					--{
					--	name = TR("Config"),
					--	action = function(s, idx, poslist, set)
					--		local outset = dialogConfig("Small Images", {
					--			{TR("Path for saving small images"), set[TR("Path for saving small images")]},
					--			{TR("After saving the small image, gen code to the clipboard"), set[TR("After saving the small image, gen code to the clipboard")]},
					--		})
					--		saveCustomFormatConfig(outset)
					--	end,
					--},
                },
			},
		},
	},
}