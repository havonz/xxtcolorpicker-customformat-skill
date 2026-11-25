-- Please do not modify this file.
-- This file will restore to its initial state when the software starts.
-- If you need to make any changes, please make a copy first and then make the alterations.

-- 请不要修改本文件
-- 本文件会在软件启动时恢复初始状态
-- 如需修改，请拷贝一份再做改动

require("scripts.colorpicker.customformats")

local JOptionPane = Java.class("javax.swing.JOptionPane")
local ImageIcon = Java.class("javax.swing.ImageIcon")
local File = Java.class("java.io.File")

return {
	name = "XXT-Bin-Dict",
	description = TR("XXT Binaryzation Dictionary"),
	formats = {
		settingsRule = {
			title = TR("Parameter settings for the custom format [XXT-Bin-Dict]"),
			args = {
				{TR("Aligning Using Spaces"), false},
				{TR("Using Line Break"), false},
				{TR("White Background"), false},
				{TR("Default Color Offset"), "101010"},
				{TR("Default Color Similarity"),
				 90,
				 {
					 1,   -- Slider 的最小值
					 100, -- Slider 的最大值
				 },
				},
				{TR("Color Similarity Algorithm"),
				 	TR("XXT Default"),
					{TR("XXT Default"), TR("Manhattan Algorithm"), TR("Euclidean Algorithm")},
				},
				{TR("Default OCR Language"), '"zh-Hans"'},
				{TR("Binaryization Preview Arguments"), ""},
				{TR("Path for saving small images"), Java.new(File, ""):getAbsolutePath()},
				{TR("After saving the small image, gen code to the clipboard"), '{"#NAME#", #BINOPT#, image.load_file(XXT_RES_PATH.."/#FILENAME#")};'},
				--{TR("Small Images Scale"),
				-- 50,
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
						return "COffMode: "..TR("Need to take at least 1 PosColor")
					end
					local fmt = "\t{0x%06x, 0x%06x},\n"
					local buf = {
						"{\n"
					}
					if set[TR("White Background")] then
						buf[#buf + 1] = "\twhite_background = true,\n"
					end
					for _,currentPos in ipairs(poslist) do
						buf[#buf + 1] = string.format(fmt, currentPos.c, tonumber(set[TR("Default Color Offset")], 16) or 0x101010)
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
							alert(TR("Color offset mode binaryization arguments"), TR("Format Readme"))
						end,
					},
					{
						name = function(s, idx, poslist, set)
							local tl = poslist.x
							local br = poslist.c
							return string.format("txt, info = screen.ocr_text(%d, %d, %d, %d, %s, %s)", tl.x, tl.y, br.x, br.y, set[TR("Default OCR Language")], s)
						end,
						action = function(s, idx, poslist, set)
							local tl = poslist.x
							local br = poslist.c
							copyText(string.format("txt, info = screen.ocr_text(%d, %d, %d, %d, %s, %s)", tl.x, tl.y, br.x, br.y, set[TR("Default OCR Language")], s))
						end,
					},
					{
						name = function(s, idx, poslist, set)
							return string.format("txt, info = img:ocr_text(%s, %s)", set[TR("Default OCR Language")], s)
						end,
						action = function(s, idx, poslist, set)
							copyText(string.format("txt, info = img:ocr_text(%s, %s)", set[TR("Default OCR Language")], s))
						end,
					},
				},
			},
			{
				maker = function(poslist, set)
					if #poslist < 1 then
						return "CSimMode: "..TR("Need to take at least 1 PosColor")
					end
					local fmt = "\t{0x%06x, %d},\n"
					local algos = {
						[TR("XXT Default")] = 0;
						[TR("Manhattan Algorithm")] = 1;
						[TR("Euclidean Algorithm")] = 2;
					}
					local buf = {
						"{\n"
					}
					if set[TR("White Background")] then
						buf[#buf + 1] = "\twhite_background = true,\n"
					end
					buf[#buf + 1] = "\tcsim_mode = true,\n"
					local algo = algos[set[TR("Color Similarity Algorithm")]]
					if type(algo) == "number" and (algo ~= 0) then
						buf[#buf + 1] = "\tcsim_algorithm = "..algos[set[TR("Color Similarity Algorithm")]]..",\n"
					end
					for _,currentPos in ipairs(poslist) do
						buf[#buf + 1] = string.format(fmt, currentPos.c, tonumber(set[TR("Default Color Similarity")]) or 90)
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
							alert(TR("Color similarity binaryzation arguments"), TR("Format Readme"))
						end,
					},
					{
						name = function(s, idx, poslist, set)
							local tl = poslist.x
							local br = poslist.c
							return string.format("txt, info = screen.ocr_text(%d, %d, %d, %d, %s, %s)", tl.x, tl.y, br.x, br.y, set[TR("Default OCR Language")], s)
						end,
						action = function(s, idx, poslist, set)
							local tl = poslist.x
							local br = poslist.c
							copyText(string.format("txt, info = screen.ocr_text(%d, %d, %d, %d, %s, %s)", tl.x, tl.y, br.x, br.y, set[TR("Default OCR Language")], s))
						end,
					},
					{
						name = function(s, idx, poslist, set)
							return string.format("txt, info = img:ocr_text(%s, %s)", set[TR("Default OCR Language")], s)
						end,
						action = function(s, idx, poslist, set)
							copyText(string.format("txt, info = img:ocr_text(%s, %s)", set[TR("Default OCR Language")], s))
						end,
					},
				},
			},
			{
				maker = function(poslist, set)
					return (" "):rep(5)
				end,
				doubleClick = function(s, idx, poslist, set)
				end,
			},
			{
				maker = function(poslist, set)
					return TR("Binaryization Preview Arguments")..":\n"..set[TR("Binaryization Preview Arguments")]
				end,
				doubleClick = function(s, idx, poslist, set)
					local ret = JOptionPane:showInputDialog(nil, TR("Supports the following styles: blablabla..."), TR("Binaryization Preview Arguments"), JOptionPane.PLAIN_MESSAGE, nil, nil, set[TR("Binaryization Preview Arguments")])
					if type(ret) ~= 'string' then
						return
					end
					set[TR("Binaryization Preview Arguments")] = ret
					saveCustomFormatConfig(set)
					return TR("Binaryization Preview Arguments")..":\n"..ret
				end,
				menu = {
					{
						name = TR("Format Readme"),
						action = function(s, idx, poslist, set)
							alert(TR("Used to set the arguments for performing binaryzation"), TR("Format Readme"))
						end,
					},
					{
						name = function(s, idx, poslist, set)
							local tl = poslist.x
							local br = poslist.c
							return string.format("txt, info = screen.ocr_text(%d, %d, %d, %d, %s, %s)", tl.x, tl.y, br.x, br.y, set[TR("Default OCR Language")], set[TR("Binaryization Preview Arguments")])
						end,
						action = function(s, idx, poslist, set)
							local tl = poslist.x
							local br = poslist.c
							copyText(string.format("txt, info = screen.ocr_text(%d, %d, %d, %d, %s, %s)", tl.x, tl.y, br.x, br.y, set[TR("Default OCR Language")], set[TR("Binaryization Preview Arguments")]))
						end,
					},
					{
						name = function(s, idx, poslist, set)
							return string.format("txt, info = img:ocr_text(%s, %s)", set[TR("Default OCR Language")], set[TR("Binaryization Preview Arguments")])
						end,
						action = function(s, idx, poslist, set)
							copyText(string.format("txt, info = img:ocr_text(%s, %s)", set[TR("Default OCR Language")], set[TR("Binaryization Preview Arguments")]))
						end,
					},
				},
			},
			{
				maker = function(poslist, set)
					return TR("Set the arguments and then") .. "\n> " .. TR("Double-click to perform binaryzation") .. " <"
				end,
				doubleClick = function(s, idx, poslist, set)
					local binaryOptStr = set[TR("Binaryization Preview Arguments")]
					local ok, binaryOpt
					if binaryOptStr == "auto" then
						binaryOpt = -1
					else
						local func, err = load("return "..binaryOptStr)
						if not func then
							func, err = load([[return "]]..binaryOptStr..[["]])
							if not func then
								alertError(TR("Bad format, Please set valid Binaryzation Preview Arguments").."\n\n"..binaryOptStr, TR("Binaryization Error"))
								return
							end
						end
						ok, binaryOpt = pcall(func)
						if not ok then
							func, err = load([[return "]]..binaryOptStr..[["]])
							if not func then
								alertError(TR("Bad format, Please set valid Binaryzation Preview Arguments").."\n\n"..binaryOptStr, TR("Binaryization Error"))
								return
							end
							ok, binaryOpt = pcall(func)
							if not ok then
								alertError(TR("Bad format, Please set valid Binaryzation Preview Arguments").."\n\n"..binaryOptStr, TR("Binaryization Error"))
								return
							end
						end
						if type(binaryOpt) ~= "string" and type(binaryOpt) ~= "table" and type(binaryOpt) ~= "number" then
							alertError(TR("Bad format, Please set valid Binaryzation Preview Arguments").."\n\n"..binaryOptStr, TR("Binaryization Error"))
							return
						end
						if type(binaryOpt) ~= "number" then
							if type(binaryOpt) == "string" then
								local ret = {}
								for _, v in ipairs(binaryOpt:split(",")) do
									local co = v:split('-')
									if #co == 2 then
										local c = tonumber(co[1], 16)
										local o = tonumber(co[2], 16)
										if c and o then
											ret[#ret + 1] = { c, o }
										end
									end
								end
								binaryOpt = ret
							end
							if #binaryOpt < 1 then
								alertError(TR("Bad format, Please set valid Binaryzation Preview Arguments").."\n\n"..binaryOptStr, TR("Binaryization Error"))
								return
							end
						else
							if binaryOpt < 0 or binaryOpt > 255 then
								alertError(TR("Bad format, Please set valid Binaryzation Preview Arguments").."\n\n"..binaryOptStr.."\n\nmust be 0 ~ 255", TR("Binaryization Error"))
								return
							end
						end
					end
					local ex, ey = getImageSize()
					local ok, data = pcall(getRectPNGData, 0, 0, ex-1, ey-1)
					if not ok then
						alertError(TR("Please use [Shift + left mouse button] to select an rect on the image"))
						return
					end
					printLog(TR("Performing binaryzation..."))
					if type(binaryOpt) == "number" then
						Java.newThread(function()
							loadImageData(thresholdImageData(data, binaryOpt))
							printLog(TR("Binaryzation completed"))
						end):start()
					else
						Java.newThread(function()
							loadImageData(binaryzationImageData(data, binaryOpt))
							printLog(TR("Binaryzation completed"))
						end):start()
					end
				end,
				menu = {
					{
						name = TR("Format Readme"),
						action = function(s, idx, poslist, set)
							alert(TR("Double-click to perform binaryzation"), TR("Format Readme"))
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
							if code:find("#FILENAME#", 1, true) or code:find("#NAME#", 1, true) or code:find("#BINOPT#", 1, true) or code:find("#IMAGEDATAHEX#", 1, true) then
								local binaryOptStr = set[TR("Binaryization Preview Arguments")]
								if binaryOptStr == "auto" then
									binaryOptStr = '"auto"'
								else
									local func = load("return "..binaryOptStr)
									if not func then
										binaryOptStr = string.format("%q", binaryOptStr)
									else
										local ok, binaryOpt = pcall(func)
										if not ok or (type(binaryOpt) ~= "table" and type(binaryOpt) ~= "number") then
											binaryOptStr = string.format("%q", binaryOptStr)
										end
									end
								end
								code = code:gsub("#FILENAME#", fn):gsub("#NAME#", name):gsub("#BINOPT#", binaryOptStr)
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
								TR("#BINOPT# is used to represent the binaryzation option of the small image"),
							}, "\n"), TR("After saving the small image, gen code to the clipboard"), JOptionPane.PLAIN_MESSAGE, nil, nil, set[TR("After saving the small image, gen code to the clipboard")])
							if not code then
								return
							end
							set[TR("After saving the small image, gen code to the clipboard")] = code
							saveCustomFormatConfig(set)
						end,
					},
				},
			},
		},
	},
}