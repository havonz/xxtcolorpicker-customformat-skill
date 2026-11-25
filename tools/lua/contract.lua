-- The same probes wrap the submitted callbacks in both runtimes, including errors the UI catches.
return function(module, fixture, report)
  local known, called = {}, {}
  local function need(ok, message)
    if not ok then error(message, 0) end
  end
  local function array(t, path)
    need(type(t) == "table", path .. " 应为数组")
    for k in pairs(t) do
      need(type(k) == "number" and k >= 1 and k <= #t and k == math.floor(k), path .. " 应为连续数组")
    end
    for i = 1, #t do need(t[i] ~= nil, path .. " 有空项") end
    return t
  end
  need(type(module) == "table" and type(module.name) == "string", "模块应返回含字符串 name 的表")
  local f = module.formats
  need(type(f) == "table", "formats 应为表")
  need(type(f.settingsRule) == "table", "formats.settingsRule 缺失")
  local spec = f.settingsRule
  array(spec.args, "settingsRule.args")
  need(type(spec.title) == "string", "settingsRule.title 应为字符串，配置按钮会读取它")
  local settings = {}
  for i, arg in ipairs(spec.args) do
    local path = "settingsRule.args["..i.."]"
    need(type(arg) == "table" and type(arg[1]) == "string", path.." 需要控件名称")
    local kind = type(arg[2])
    need(kind == "number" or kind == "boolean" or kind == "string", path.." 默认值类型无效")
    need(settings[arg[1]] == nil, path.." 设置键重复："..arg[1])
    if arg[3] ~= nil then
      array(arg[3], path.."[3]")
      if kind == "number" then
        local range = arg[3]
        need(type(range[1])=="number" and type(range[2])=="number" and range[1]<=range[2], path.." 滑块范围无效")
        need(range[3]==nil or type(range[3])=="number" and range[3]>0, path.." 步长无效")
      elseif kind == "string" then
        for _, v in ipairs(arg[3]) do need(type(v)=="string", path.." 候选项需要字符串") end
        need(arg[4]==nil or type(arg[4])=="boolean", path.." 可编辑开关需要布尔值")
      else error(path.." 复选框不接收候选值", 0) end
    end
    settings[arg[1]] = arg[2]
  end
  for key, value in pairs(fixture.settings or {}) do
    need(type(value)==type(settings[key]), "样例设置不存在或类型不符："..key)
    settings[key] = value
  end

  local function wrapped(fn, path, check)
    need(type(fn)=="function", path.." 应为函数")
    known[path]=true
    return function(...)
      called[path]=true
      local ok, value = pcall(fn, ...)
      if ok and check then ok, value = pcall(check, value) end
      if not ok then
        local msg=path.." · "..tostring(value)
        local list=tostring(value):find("未验证：",1,true) and report.unverified or report.errors
        list[#list+1]=msg
        error(msg, 0)
      end
      return value
    end
  end
  local function text(v)
    need(type(v)=="string", "应返回字符串，实际为 "..type(v))
    return v
  end
  local function cells(v)
    if type(v)=="string" then return v end
    array(v,"结果行")
    need(#v>0,"空行缺少结果列")
    local row={}
    for i,item in ipairs(v) do
      local kind=type(item)
      need(kind=="string" or kind=="number" or kind=="boolean","第 "..i.." 列应为可显示的标量")
      row[i]=tostring(item)
    end
    return row
  end
  f.multiPosFormatRule = wrapped(f.multiPosFormatRule,"multiPosFormatRule",text)
  for _, key in ipairs({"mouseTrackInfoBottomRule","mouseTrackInfoZoomRule"}) do
    if f[key] ~= nil then f[key]=wrapped(f[key],key,text) end
  end
  for _, key in ipairs({"singlePosFormatRule","testRules","rightClickRules"}) do
    if f[key] ~= nil then report.notRun[#report.notRun+1]=key.."（当前内置流程没有调用入口）" end
  end

  local function menuItems(items, path)
    array(items,path)
    local result = {}
    for i, item in ipairs(items) do
      local key = path.."["..i.."]"
      need(type(item)=="table", key.." 应为菜单项")
      local name = item.name
      if type(name)=="function" then name=wrapped(name,key..".name",text)
      else need(name==nil or type(name)=="string", key..".name 类型错误") end
      result[i]={name=name,action=wrapped(item.action,key..".action")}
    end
    return result
  end
  if f.makeScriptRules == nil then f.makeScriptRules={} end
  for i, rule in ipairs(array(f.makeScriptRules,"makeScriptRules")) do
    local path="makeScriptRules["..i.."]"
    if type(rule)=="function" then
      f.makeScriptRules[i]=wrapped(rule,path,cells)
    else
      need(type(rule)=="table",path.." 应为函数或含 maker 的表")
      rule.maker=wrapped(rule.maker,path..".maker",cells)
      if rule.doubleClick ~= nil then rule.doubleClick=wrapped(rule.doubleClick,path..".doubleClick") end
      if type(rule.menu)=="function" then
        rule.menu=wrapped(rule.menu,path..".menu",function(v) return menuItems(v,path..".menu") end)
      elseif rule.menu ~= nil then rule.menu=menuItems(rule.menu,path..".menu") end
    end
  end
  return settings, function()
    local names={}
    for k in pairs(known) do names[#names+1]=k end
    table.sort(names)
    for _, k in ipairs(names) do
      local list=called[k] and report.executed or report.notRun
      list[#list+1]=k
    end
  end
end
