-- Assembles exported tiles and the example into one picture for people to look at. Not a game asset.
local root = app.params["root"]
local M = dofile(root .. "/tools/art/pixel_v1/lib.lua")
local px = app.pixelColor
local function load(name) return Image { fromFile = root .. "/assets/pixel_v1/" .. name .. ".png" } end
local W, H = 480, 250
local out = Image(W, H, ColorMode.RGB)
local function stamp(img, pal, sx, sy, w, h, dx, dy, shade)
  for y = 0, h - 1 do for x = 0, w - 1 do
    local i = img:getPixel(sx + x, sy + y)
    if i ~= 0 and dx + x >= 0 and dx + x < W and dy + y >= 0 and dy + y < H then
      local r, g, b = M.rgb(M.hex[i])
      if shade then
        local old = out:getPixel(dx + x, dy + y)
        r, g, b = (px.rgbaR(old) * 7 + r * 3) // 10, (px.rgbaG(old) * 7 + g * 3) // 10, (px.rgbaB(old) * 7 + b * 3) // 10
      end
      out:drawPixel(dx + x, dy + y, px.rgba(r, g, b, 255))
    end
  end end
end
out:clear(px.rgba(43, 47, 63, 255))
local function plateau(biome, ox, oy, n, lift)
  local cap, edge, side = load("tiles/" .. biome .. "_cap"), load("tiles/" .. biome .. "_edge"), load("tiles/" .. biome .. "_side")
  local r = M.rng(55)
  local function high(x, y) return x >= 1 and x <= n - 2 and y >= 1 and y <= n - 2 and lift > 0 end
  local function land(x, y) return x >= 0 and y >= 0 and x < n and y < n end
  for s = 0, 2 * n - 2 do for x = 0, n - 1 do
    local y = s - x
    if land(x, y) then
      local up = high(x, y) and 20 * lift or 0
      local px0, py0 = ox + (x - y) * 20 - 20, oy + (x + y) * 10 - 10 - up
      local function lower(a, b) return not land(a, b) or ((high(x, y) and 1 or 0) > (high(a, b) and 1 or 0)) end
      -- x+1 is the lower right (SE) neighbour, y+1 the lower left (SW).
      local se, sw, nw, ne = lower(x + 1, y), lower(x, y + 1), lower(x - 1, y), lower(x, y - 1)
      local depth = (high(x, y) and land(x + 1, y) and land(x, y + 1)) and lift or 1
      for d = 0, depth - 1 do
        if sw then local v = r(4); stamp(side, nil, v * 40, 0, 40, 40, px0, py0 + d * 20) end
        if se then local v = 4 + r(4); stamp(side, nil, v * 40, 0, 40, 40, px0, py0 + d * 20) end
      end
      local k = r(8)
      stamp(cap, nil, k * 40, 0, 40, 20, px0, py0)
      local mask = (ne and 1 or 0) + (se and 2 or 0) + (sw and 4 or 0) + (nw and 8 or 0)
      stamp(edge, nil, (mask % 8) * 40, (mask // 8) * 24, 40, 24, px0, py0)
    end
  end end
end
plateau("snow", 130, 40, 6, 1)
plateau("grass", 300, 30, 4, 1)
plateau("lab", 400, 130, 4, 1)
local ice, shadow = load("example/ice_barrier_example"), load("example/ice_barrier_example_shadow")
for k, f in ipairs({ { 0, 0, 130, 78 } }) do
  stamp(shadow, nil, 0, 0, 128, 128, f[3] - 64, f[4] - 104, true)
  stamp(ice, nil, f[1] * 128, f[2] * 128, 128, 128, f[3] - 64, f[4] - 104)
end
for k, f in ipairs({ { 5, 0 }, { 2, 1 }, { 7, 1 } }) do
  stamp(ice, nil, f[1] * 128, f[2] * 128, 128, 128, (k - 1) * 100 + 230 - 64, 222 - 104)
end
local Z = 3
local big = Image(W * Z, H * Z, ColorMode.RGB)
for y = 0, H * Z - 1 do for x = 0, W * Z - 1 do big:drawPixel(x, y, out:getPixel(x // Z, y // Z)) end end
big:saveAs(app.params["review"] .. "/assembled-3x.png")
print("WROTE review/assembled-3x.png")