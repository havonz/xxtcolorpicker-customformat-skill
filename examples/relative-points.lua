local function pointText(x, y, color)
  return string.format("{%d, %d, 0x%06X}", x, y, color)
end

return {
  name = "首点定位与相对点阵",
  formats = {
    settingsRule = {
      title = "点阵设置",
      args = {{"使用相对偏移", true}},
    },
    mouseTrackInfoBottomRule = function(p) return string.format("%d, %d", p.x, p.y) end,
    mouseTrackInfoZoomRule = function(p) return string.format("#%06X", p.c) end,
    multiPosFormatRule = function(p) return pointText(p.x, p.y, p.c) .. ",\n" end,
    makeScriptRules = {
      function(points, set)
        local parts = {}
        for i, p in ipairs(points) do
          local x, y = p.x, p.y
          if i > 1 and set["使用相对偏移"] then
            x, y = x - points[1].x, y - points[1].y
          end
          parts[i] = pointText(x, y, p.c)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
      end,
      {
        maker = function(points) return {"点数", tostring(#points)} end,
        doubleClick = function(text) return text .. " 个点" end,
        menu = function()
          return {{
            name = function(text) return "复制点数 " .. text end,
            action = function(text) copyText("点数=" .. text) end,
          }}
        end,
      },
    },
  },
}
