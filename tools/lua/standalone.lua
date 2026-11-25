return function(source, file, moduleName, fixture, compat, audit, report, classExists, absolutePath)
  local clipboard=""
  local function point(x,y,c)
    return {x,y,c,x=x,y=y,c=c,r=math.floor(c/65536),g=math.floor(c/256)%256,b=c%256,undef=false}
  end
  local function copy(t)
    local result={}
    for k,v in pairs(t) do result[k]=v end
    return result
  end
  local points,regions={},{}
  local filled=0
  for i,a in ipairs(fixture.points) do
    points[i]=point(table.unpack(a))
    points[i].idx=i==10 and 0 or i
    points[i].num=i
  end
  for _,key in ipairs({"a","s","x","c"}) do
    local xy=(fixture.regions or {})[key] or {0,0}
    regions[key]={xy[1],xy[2],x=xy[1],y=xy[2]}
    -- Without a fixture image the picker returns zero RGB at valid region coordinates.
    points[key]=point(xy[1],xy[2],0)
  end
  for _,key in ipairs({"x","y"}) do
    local a,s=points.a,points.s
    a[key],s[key]=math.min(a[key],s[key]), math.max(a[key],s[key])
  end
  local cursor=point(table.unpack(fixture.hover or fixture.points[1] or {0,0,0}))
  local env={assert=assert,error=error,ipairs=ipairs,pairs=pairs,next=next,type=type,
    tonumber=tonumber,tostring=tostring,select=select,unpack=table.unpack,pcall=pcall,xpcall=xpcall,
    setmetatable=setmetatable,getmetatable=getmetatable,rawget=rawget,rawset=rawset,
    rawlen=rawlen,rawequal=rawequal,math=math,table=table,string=string,bit32=bit32,coroutine=coroutine,
    os={date=os.date,time=os.time,difftime=os.difftime,clock=os.clock},_VERSION=_VERSION}
  env._G=env
  env.TR=function(s) return s end
  env.copyText=function(s) clipboard=s end
  env.clipText=function() return clipboard end
  env.printLog=print
  env.print=print
  env.load=function(chunk,name,mode,e) return load(chunk,name,mode or "t",e or env) end
  env.getCurrentPos=function() return copy(cursor) end
  env.getCurrentXY=function() return cursor.x,cursor.y,cursor.c end
  env.getPosASXC=function() return regions.a,regions.s,regions.x,regions.c end
  env.getPosList=function()
    local list={}
    for i=1,filled do list[i]=copy(points[i]) end
    for _,k in ipairs({"a","s","x","c"}) do list[k]=copy(points[k]) end
    return list
  end
  for _,k in ipairs({"a","s","x","c"}) do
    env["getReg"..k:upper()]=function() return regions[k].x,regions[k].y end
    env["getPos"..k:upper()]=function() return point(regions[k].x,regions[k].y,0) end
  end
  local function unavailable(name)
    return function()
      local msg="未验证："..name.." 需要宿主或额外依赖"
      local seen=false
      for _,s in ipairs(report.unverified) do if s==msg then seen=true end end
      if not seen then report.unverified[#report.unverified+1]=msg end
      error(msg,2)
    end
  end
  for name in ("alert alertInfo alertError alertWarn alertShowImageData openFolder getImageSize getColor getColorRGB getPixel getRectPNGData getRectPNGDataHex getRectJPEGData getRectJPEGDataHex getImagesTabPane getConnectedDeviceAPI capture uploadScriptAndRun moveMouseToXY loadImageData loadImageFile dialogConfig dofile loadfile"):gmatch("%S+") do
    env[name]=unavailable(name)
  end
  env.io=setmetatable({}, {__index=function(_,k) return unavailable("io."..k) end})
  setmetatable(env.os,{__index=function(_,k) return unavailable("os."..k) end})
  env.Java=setmetatable({
    class=function(name)
      if not classExists(name) then unavailable("Java.class("..name..")")() end
      return setmetatable({className=name},{__index=function(_,k) return unavailable(name.."."..k)() end})
    end,
    new=function(kind,path)
      local name=type(kind)=="table" and kind.className or kind
      if name=="java.io.File" and type(path)=="string" then
        return setmetatable({getAbsolutePath=function() return absolutePath(path) end},
          {__index=function(_,k) return unavailable(name.."."..k)() end})
      end
      return unavailable("Java.new("..tostring(name)..")")()
    end
  },{__index=function(_,k) return unavailable("Java."..k) end})
  env.package={loaded={}}
  env.require=function(name)
    if env.package.loaded[name] then return env.package.loaded[name] end
    if name~="scripts.colorpicker.customformats" then return unavailable("require("..name..")")() end
    local result=assert(load(compat,"@customformats.lua","t",env))()
    env.package.loaded[name]=result or true
    return env.package.loaded[name]
  end
  local format=assert(load(source,"@"..file,"t",env))(moduleName,file)
  local set,finish=audit(format,fixture,report)
  env.loadCustomFormatConfig=function() return copy(set) end
  env.saveCustomFormatConfig=function(changes)
    for k,v in pairs(changes) do if set[k]~=nil then set[k]=v end end
  end
  local f=format.formats
  local function run()
    -- Each wrapped rule records its own error. Independent stages can still produce useful evidence.
    for rule,field in pairs({mouseTrackInfoBottomRule="hoverBottom",mouseTrackInfoZoomRule="hoverZoom"}) do
      if f[rule] then
        local ok,v=pcall(f[rule],copy(cursor))
        if ok then report[field]=v end
      end
    end
    local picksOk,rawOk=true,true
    local picked,raw={},{}
    local pickSettings=copy(set)
    for i,p in ipairs(points) do
      local sample=copy(p)
      sample.idx,sample.num,sample.undef=nil,nil,nil
      local ok,v=pcall(f.multiPosFormatRule,sample,regions.a,regions.s,regions.x,regions.c,pickSettings)
      if ok then picked[i]=v:match("^%s*(.-)%s*$") else picksOk=false end
      filled=i
    end
    for i,p in ipairs(points) do
      local sample=copy(p)
      sample.idx,sample.num=nil,nil
      local ok,v=pcall(f.multiPosFormatRule,sample,regions.a,regions.s,regions.x,regions.c,copy(set))
      if ok then raw[i]=v else rawOk=false end
    end
    if picksOk then report.picked=picked end
    if rawOk then clipboard=table.concat(raw); report.pickClipboard=clipboard end
    local rows={}
    local width,complete,clipKnown=0,true,rawOk
    local genPoints,genSettings=env.getPosList(),copy(set)
    for i,r in ipairs(f.makeScriptRules) do
      local fn=type(r)=="function" and r or r.maker
      local ok,v=pcall(fn,genPoints,genSettings)
      if ok then
        if i==1 and type(v)=="string" then clipboard=v; clipKnown=true end
        rows[i]=type(v)=="string" and {v} or copy(v)
        width=math.max(width,#rows[i])
      else
        complete=false
        if i==1 then clipKnown=false end
      end
    end
    if clipKnown then report.generateClipboard=clipboard end
    -- Failed makers can shift the UI's row-to-action mapping.
    if not complete then return end
    report.rows={}
    for i,r in ipairs(rows) do report.rows[i]=copy(r) end
    env.setMakerResult=function(i,value)
      if not rows[i] then return false,"index out of range" end
      assert(type(value)=="string","setMakerResult 需要字符串")
      rows[i]={value}
      return true
    end
    report.menus={}
    for _,a in ipairs(fixture.actions or {}) do
      local row=assert(rows[a.row],"结果行不存在 "..a.row)
      local rule=f.makeScriptRules[a.row]
      if type(rule)=="function" then rule={} end
      local ctx=row[width]
      if a.type=="doubleClick" then
        if rule.doubleClick then
          local ret=rule.doubleClick(ctx,a.row,env.getPosList(),copy(set))
          if type(ret)=="string" then rows[a.row]={ret} end
        else clipboard=ctx or "" end
      else
        local items=type(rule.menu)=="function" and rule.menu(ctx,a.row,env.getPosList(),copy(set)) or rule.menu or {}
        local names={}
        local menuPoints,menuSettings=env.getPosList(),copy(set)
        for i,m in ipairs(items) do
          names[i]=type(m.name)=="function" and m.name(ctx,a.row,menuPoints,menuSettings) or m.name or "(unnamed)"
        end
        report.menus[#report.menus+1]=names
        if a.item then assert(items[a.item],"菜单项不存在 "..a.item).action(ctx,a.row,env.getPosList(),copy(set)) end
      end
    end
    report.afterRows,report.clipboard=rows,clipboard
  end
  local ok,err=pcall(run)
  finish()
  if not ok then error(err,0) end
end
