-- Reports facts about one .aseprite source for the export manifest.
local M = dofile(app.params["root"] .. "/tools/art/pixel_v1/lib.lua")
local s = app.activeSprite or app.sprite
local bad = {}
if s.colorMode ~= ColorMode.INDEXED then bad[#bad + 1] = "not indexed" end
if s.transparentColor ~= 0 then bad[#bad + 1] = "transparent index is not 0" end
local p = s.palettes[1]
if #p ~= M.count + 1 then bad[#bad + 1] = "palette has " .. #p .. " entries, expected " .. (M.count + 1)
else
  for i = 1, M.count do
    local r, g, b = M.rgb(M.hex[i])
    local c = p:getColor(i)
    if c.red ~= r or c.green ~= g or c.blue ~= b or c.alpha ~= 255 then bad[#bad + 1] = "palette entry " .. i .. " changed"; break end
  end
end
local allowed = { body = true, detail = true, outline = true }
for _, l in ipairs(s.layers) do
  if not allowed[l.name] then bad[#bad + 1] = "layer name " .. l.name end
  if l.opacity ~= 255 or l.blendMode ~= BlendMode.NORMAL then bad[#bad + 1] = "layer " .. l.name .. " is not plain" end
  if not l.isVisible then bad[#bad + 1] = "layer " .. l.name .. " is hidden" end
end
for _, c in ipairs(s.cels) do if c.opacity ~= 255 then bad[#bad + 1] = "cel opacity in frame " .. c.frameNumber; break end end
if #s.tags == 0 then bad[#bad + 1] = "no tags" end
local covered = 0
for _, t in ipairs(s.tags) do covered = covered + t.toFrame.frameNumber - t.fromFrame.frameNumber + 1 end
if covered ~= #s.frames then bad[#bad + 1] = "tags cover " .. covered .. " of " .. #s.frames .. " frames" end
print("AUDIT " .. (#bad == 0 and "ok" or table.concat(bad, "; ")))
