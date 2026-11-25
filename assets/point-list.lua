local function pointLiteral(p)
  return string.format("{%d, %d, 0x%06X}", p.x, p.y, p.c)
end

return {
  name = "Lua 点色列表",
  formats = {
    settingsRule = {title = "Lua 点色列表设置", args = {}},

    multiPosFormatRule = function(p)
      -- 取色时宿主会把各点的返回值直接拼接到剪贴板。
      return pointLiteral(p) .. ",\n"
    end,

    makeScriptRules = {
      function(poslist)
        local points = {}
        for i, p in ipairs(poslist) do
          points[i] = pointLiteral(p)
        end
        return "{" .. table.concat(points, ", ") .. "}"
      end,
    },
  },
}
