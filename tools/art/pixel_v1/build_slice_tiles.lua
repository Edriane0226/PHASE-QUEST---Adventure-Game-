-- PX-03 vertical slice: textured snow ground, path, water and shore.
-- Same lattice as build_tiles.lua: cap rows 2,6..38,38..6,2; edge bits NE 1, SE 2, SW 4, NW 8.
local M = dofile(app.params["root"] .. "/tools/art/pixel_v1/lib.lua")

local function half(y) return y < 10 and 2 * y + 1 or 2 * (19 - y) + 1 end
local function inside(x, y) return y >= 0 and y <= 19 and x >= 20 - half(y) and x <= 19 + half(y) end
local head, foot = {}, {}
for x = 0, 39 do
  head[x], foot[x] = 9, 10
  for y = 0, 19 do if inside(x, y) then head[x] = y; break end end
  for y = 19, 0, -1 do if inside(x, y) then foot[x] = y; break end end
end
-- Distance in rows from a pixel to each side of the diamond.
local function depth(x, y, bit)
  if bit == 8 then return x <= 19 and y - head[x] or 99 end
  if bit == 1 then return x >= 20 and y - head[x] or 99 end
  if bit == 4 then return x <= 19 and foot[x] - y or 99 end
  return x >= 20 and foot[x] - y or 99
end
-- An irregular border with runs of 2-4 columns. It starts and ends at the same depth, so cells join.
local function ragged(x, low, high, seed)
  -- A soft wave: neighbours differ by one row at most, so the border has no teeth.
  local u = x <= 19 and x or 39 - x
  local wave = ({ 0, 0, 0, 1, 1, 2, 2, 2, 1, 1, 1, 2, 2, 1, 1, 0, 0, 0, 0, 0 })
  local other = ({ 0, 0, 1, 1, 1, 2, 2, 1, 1, 0, 0, 1, 1, 2, 2, 2, 1, 1, 0, 0 })
  local d = ((seed % 2 == 0) and wave or other)[u + 1]
  return low + d * (high - low) // 2
end

local function caps(name, frames, tags, base, paint)
  local s = M.sprite(40, 20, frames)
  for f = 1, frames do
    local c = M.canvas(s)
    for y = 0, 19 do for x = 0, 39 do if inside(x, y) then c.put("body", x, y, base) end end end
    local used = {}
    -- A cluster is placed whole or not at all, clear of the border and of other clusters.
    local function stamp(x, y, shape)
      for _, p in ipairs(shape) do
        for _, e in ipairs({ { 2, 0 }, { -2, 0 }, { 0, 1 }, { 0, -1 }, { 0, 0 } }) do
          local X, Y = x + p[1] + e[1], y + p[2] + e[2]
          if not inside(X, Y) or used[Y * 40 + X] then return false end
        end
      end
      for _, p in ipairs(shape) do
        used[(y + p[2]) * 40 + x + p[1]] = true
        c.put("detail", x + p[1], y + p[2], p[3])
      end
      return true
    end
    paint(f, stamp, M.rng(1201 + f * 131 + #name * 17))
    c.commit(f, tags.ms or 100)
  end
  for _, t in ipairs(tags) do M.tag(s, t[2], t[3], t[1]) end
  M.save(s, "slice/" .. name .. ".aseprite")
end
local function edges(name, paint)
  local s = M.sprite(40, 24, 16)
  for mask = 0, 15 do
    local c = M.canvas(s)
    if mask > 0 then paint(c, mask) end
    c.commit(mask + 1, 100)
  end
  M.tag(s, 1, 16, "mask_edge")
  M.save(s, "slice/" .. name .. ".aseprite")
end

-- Shapes: wind ripples follow the light, crust chips are small, dimples are soft hollows.
local function ripple(a, b) return { { 0, 1, a }, { 1, 0, a }, { 2, 0, a }, { 3, 0, a }, { 4, 0, a }, { 5, 1, a }, { 2, 1, b }, { 3, 1, b }, { 4, 1, b } } end
local function chip(a) return { { 0, 0, a }, { 1, 0, a }, { 2, 0, a } } end
local function dimple(a) return { { 0, 0, a }, { 1, 0, a }, { 2, 0, a }, { 3, 0, a }, { 1, 1, a }, { 2, 1, a } } end
local function speck(a) return { { 0, 0, a }, { 1, 0, a } } end

-- Base snow: two calm, two rippled, two crusted, two with dimples.
caps("snow_cap", 8, { { "variant_cap", 1, 8 } }, "snow4", function(f, stamp, r)
  if f <= 2 then stamp(9 + r(18), 5 + r(8), speck("snow5")) end
  if f == 2 then stamp(10 + r(16), 4 + r(10), speck("snow3")) end
  if f == 3 or f == 4 then
    stamp(8 + r(6), 8 + r(3), ripple("snow5", "snow3"))
    stamp(20 + r(6), 5 + r(3), ripple("snow5", "snow3"))
    if f == 4 then stamp(16 + r(6), 12 + r(2), ripple("snow5", "snow3")) end
  end
  if f == 5 or f == 6 then
    for _ = 1, 5 do stamp(6 + r(26), 3 + r(13), chip("snow5")) end
    stamp(6 + r(26), 4 + r(11), speck("snow3"))
  end
  if f >= 7 then
    stamp(8 + r(14), 6 + r(5), dimple("snow3"))
    stamp(18 + r(8), 4 + r(9), chip("snow5"))
    if f == 8 then stamp(12 + r(10), 11 + r(3), dimple("snow3")) end
  end
end)
-- Patch, warmer: a wind drift.
caps("snow_drift", 4, { { "variant_cap", 1, 4 } }, "snow5", function(f, stamp, r)
  if f >= 2 then stamp(8 + r(16), 6 + r(6), chip("snow4")) end
  if f >= 3 then stamp(8 + r(10), 9 + r(4), ripple("snow4", "snow4")) end
  if f == 4 then stamp(18 + r(8), 4 + r(4), chip("snow4")) end
end)
-- Patch, cooler: a shaded hollow.
caps("snow_hollow", 4, { { "variant_cap", 1, 4 } }, "snow3", function(f, stamp, r)
  if f >= 2 then stamp(8 + r(16), 5 + r(8), chip("snow4")) end
  if f >= 3 then stamp(10 + r(10), 8 + r(5), dimple("snow2")) end
  if f == 4 then stamp(18 + r(8), 5 + r(4), chip("snow4")) end
end)
-- Base snow creeping over a patch from each marked side.
edges("snow_over", function(c, mask)
  for y = 0, 19 do for x = 0, 39 do
    if inside(x, y) then
      for k, bit in ipairs({ 1, 2, 4, 8 }) do
        if mask & bit ~= 0 and depth(x, y, bit) <= ragged(x, 1, 5, k * 3 + mask) then c.put("body", x, y, "snow4") end
      end
    end
  end end
end)
-- Packed path.
caps("path_cap", 6, { { "variant_cap", 1, 6 } }, "earth4", function(f, stamp, r)
  for _ = 1, 1 + f // 2 do stamp(7 + r(24), 4 + r(12), chip("earth3")) end
  if f % 2 == 0 then stamp(8 + r(18), 5 + r(9), { { 0, 0, "earth5" }, { 1, 0, "earth5" }, { 2, 0, "earth5" }, { 0, 1, "earth3" }, { 1, 1, "earth3" }, { 2, 1, "earth3" } }) end
  if f >= 4 then stamp(10 + r(14), 8 + r(5), dimple("snow4")) end
  if f == 6 then stamp(8 + r(20), 4 + r(6), speck("earth5")) end
end)
-- Snow banks on the path: a bank behind casts a thin shade, a bank in front shows a lit lip.
edges("path_over", function(c, mask)
  for y = 0, 19 do for x = 0, 39 do
    if inside(x, y) then
      for k, bit in ipairs({ 8, 1, 4, 2 }) do
        if mask & bit ~= 0 then
          local d, limit = depth(x, y, bit), ragged(x, 2, 6, k * 5 + mask)
          if d <= limit then c.put("body", x, y, d == limit and (bit == 4 or bit == 2) and "snow5" or "snow4")
          elseif d == limit + 1 and (bit == 8 or bit == 1) then c.put("detail", x, y, "snow2")
          end
        end
      end
    end
  end end
  -- A bank always wins over the shade of its neighbour.
  for y = 0, 19 do for x = 0, 39 do
    if inside(x, y) then
      for k, bit in ipairs({ 8, 1, 4, 2 }) do
        if mask & bit ~= 0 and depth(x, y, bit) <= ragged(x, 2, 6, k * 5 + mask) then c.put("detail", x, y, nil) end
      end
    end
  end end
end)

-- Water: three variants, four frames each. Marks slide, so it reads as liquid. The last one is nearly still.
local function dash(n, colour) local t = {}; for k = 0, n - 1 do t[#t + 1] = { k, 0, colour } end; return t end
caps("water_cap", 12, { { "loop_water_a", 1, 4 }, { "loop_water_b", 5, 8 }, { "loop_water_c", 9, 12 }, ms = 180 }, "ice3", function(f, stamp)
  local v, t = (f - 1) // 4, (f - 1) % 4
  local slide = ({ 0, 1, 2, 1 })[t + 1]
  if v == 0 then
    stamp(9 + slide, 7, dash(5, "ice4"))
    stamp(18 - slide, 12, dash(7, "ice2"))
    if t % 2 == 1 then stamp(24, 6, speck("ice5")) end
  elseif v == 1 then
    stamp(14 - slide, 11, dash(4, "ice2"))
    if t == 2 then stamp(20, 6, dash(3, "ice5")) end
  elseif t == 1 or t == 2 then stamp(17 + t, 9, speck("ice4")) end
end)
caps("water_deep", 8, { { "loop_water_a", 1, 4 }, { "loop_water_b", 5, 8 }, ms = 180 }, "ice2", function(f, stamp)
  local v, t = (f - 1) // 4, (f - 1) % 4
  local slide = ({ 0, 1, 2, 1 })[t + 1]
  if v == 0 then stamp(10 + slide, 9, dash(6, "ice3")); if t == 3 then stamp(22, 6, speck("ice4")) end
  elseif t ~= 2 then stamp(20 - slide, 12, dash(4, "ice3")) end
end)
-- Shallow water over deep water.
edges("water_over", function(c, mask)
  for y = 0, 19 do for x = 0, 39 do
    if inside(x, y) then
      for k, bit in ipairs({ 1, 2, 4, 8 }) do
        if mask & bit ~= 0 and depth(x, y, bit) <= ragged(x, 2, 6, k + mask) then c.put("body", x, y, "ice3") end
      end
    end
  end end
end)
-- Shore on a water cell. Behind (NE, NW): the foot of the bank in shade, then broken ice shelf and foam.
edges("shore", function(c, mask)
  for y = 0, 19 do for x = 0, 39 do
    if inside(x, y) then
      local best
      for k, bit in ipairs({ 8, 1 }) do
        if mask & bit ~= 0 then
          local d, limit = depth(x, y, bit), ragged(x, 3, 5, k * 7 + mask)
          local colour = d <= limit and "ice1" or (d == limit + 1 and "ice2") or nil
          if d == limit + 3 and (x // 4 + k) % 3 ~= 0 then colour = "ice5" end
          if colour and (not best or colour == "ice1") then best = colour end
        end
      end
      for k, bit in ipairs({ 4, 2 }) do
        if mask & bit ~= 0 and depth(x, y, bit) <= ragged(x, 1, 3, k * 7 + mask) then best = "snow3" end
      end
      if best then c.put("body", x, y, best) end
    end
  end end
end)
-- Shadow band on the ground at the foot of a cliff.
edges("snow_foot", function(c, mask)
  for y = 0, 19 do for x = 0, 39 do
    if inside(x, y) then
      local best
      for k, bit in ipairs({ 8, 1, 4, 2 }) do
        if mask & bit ~= 0 then
          local wide = bit == 8 and 2 or (bit == 1 and 4 or 1)
          local d, limit = depth(x, y, bit), ragged(x, wide, wide + 2, k * 3 + mask)
          if d <= limit then best = d <= 1 and "snow1" or (best == "snow1" and best or "snow2")
          elseif d <= limit + 2 and not best then best = "snow3" end
        end
      end
      if best then c.put("body", x, y, best) end
    end
  end end
end)
-- Raised cap: lit rim behind, soft lip in front that hangs over the side.
edges("snow_edge", function(c, mask)
  for x = 1, 38 do
    local back = x <= 19 and 8 or 1
    if mask & back ~= 0 then
      c.put("body", x, head[x], "snow5")
      if (x // 3) % 4 ~= 1 then c.put("body", x, head[x] + 1, "snow5") end
    end
    local front = x <= 19 and 4 or 2
    if mask & front ~= 0 then
      local drop = ({ 1, 2, 3, 2, 2, 4, 3, 1, 2, 3 })[(x // 2 + (front == 2 and 3 or 0)) % 10 + 1]
      for k = -2, drop do
        local colour = "snow5"
        if k == drop then colour = front == 4 and "snow3" or "snow2" elseif front == 2 and k >= 1 then colour = "snow4" end
        c.put("body", x, foot[x] + k, colour)
      end
    end
  end
end)

-- Cliff sides: shade under the lip, a course of stones, then soil with strata and a darker foot.
do
  local s = M.sprite(40, 40, 8)
  for f = 1, 8 do
    local left = f <= 4
    local soil, dark, stone, lit, deep = "earth3", "earth2", "ink5", "ink6", "ink4"
    if not left then soil, dark, stone, lit, deep = "earth2", "earth1", "ink4", "ink5", "earth1" end
    local c = M.canvas(s)
    local r = M.rng(5501 + f * 47)
    local x0 = left and 1 or 19
    local function at(u, v) local x = x0 + (u % 20); return x, foot[x] + 1 + (v % 20) end
    local function px(u, v, colour) local x, y = at(u, v); c.put("detail", x, y, colour) end
    for u = 0, 19 do for v = 0, 19 do
      local x, y = at(u, v)
      c.put("body", x, y, (v <= 2 or v >= 18) and dark or soil)
    end end
    -- Stones: widths 5,7,4,4 in a turned order, so the course never repeats in step.
    local widths = ({ { 6, 5, 4, 5 }, { 4, 6, 5, 5 }, { 5, 4, 7, 4 }, { 7, 5, 4, 4 } })[(f - 1) % 4 + 1]
    local u = r(4)
    for k, w in ipairs(widths) do
      -- Every second stone only: the plain soil between them keeps the cliff calm (PX-03 approval).
      if (k + f) % 2 == 0 then
        local top = 5 + f % 2
        local tall = 5 + (k * f) % 2
        for a = 0, w - 2 do
          for b = 0, tall - 1 do
            local corner = (a == 0 or a == w - 2) and (b == 0 or b == tall - 1)
            if not corner then px(u + a, top + b, b == 0 and lit or (b == tall - 1 and deep or stone)) end
          end
        end
        for a = 1, w - 2 do px(u + a, top + tall, dark) end
      end
      u = u + w
    end
    -- Strata and pebbles in the soil below.
    local start = r(20)
    for a = 0, 7 + r(4) do px(start + a, 14, dark) end
    start = r(20)
    for a = 0, 4 + r(3) do px(start + a, 16, dark) end
    start = r(17)
    px(start, 13, lit); px(start + 1, 13, lit); px(start, 12, left and "earth3" or "earth2")
    c.commit(f, 100)
  end
  M.tag(s, 1, 4, "variant_left")
  M.tag(s, 5, 8, "variant_right")
  M.save(s, "slice/snow_side.aseprite")
end

-- Corners of a cliff, drawn over the two faces. Outer: lit arris with stepped quoins. Inner: a dark crease.
do
  local s = M.sprite(40, 40, 2)
  local c = M.canvas(s)
  for v = 0, 19 do
    local y = 20 + v
    local quoin = v >= 4 and v <= 10
    c.put("body", 18, y - 1, quoin and "ink6" or (v <= 2 and "earth2" or "earth3"))
    c.put("body", 19, y, quoin and "ink6" or "earth3")
    c.put("body", 20, y, quoin and "ink4" or "earth1")
    c.put("body", 21, y - 1, quoin and "ink4" or "earth2")
  end
  for _, v in ipairs({ 3, 11 }) do for x = 17, 22 do c.put("detail", x, 20 + v - math.max(0, math.abs(x * 2 - 39) // 4), "earth1") end end
  c.put("detail", 18, 25, "ink6"); c.put("detail", 17, 25, "ink6")
  c.commit(1, 250)
  local d = M.canvas(s)
  for v = 0, 19 do
    d.put("body", 19, v, "earth1"); d.put("body", 20, v, "earth1")
    if v % 6 < 4 then d.put("body", 21, v, "earth1") end
    if v % 7 < 3 then d.put("body", 18, v, "earth2") end
  end
  d.commit(2, 250)
  M.tag(s, 1, 1, "idle_outer")
  M.tag(s, 2, 2, "idle_inner")
  M.save(s, "slice/snow_corner.aseprite")
end

-- Decals: a few marks for the detail layer.
do
  local s = M.sprite(40, 40, 5)
  local function frame(f, list)
    local c = M.canvas(s)
    for _, p in ipairs(list) do c.put("body", p[1], p[2], p[3]) end
    c.commit(f, 250)
  end
  local tuft = {}
  for _, b in ipairs({ { 15, 26, 8, -1 }, { 18, 27, 11, 0 }, { 21, 26, 9, 1 }, { 24, 27, 6, 1 }, { 13, 27, 5, -1 } }) do
    for k = 0, b[3] - 1 do
      local x = b[1] + (k * b[4]) // 4
      tuft[#tuft + 1] = { x, b[2] - k, k > b[3] - 4 and "earth4" or "earth3" }
      if k < b[3] - 3 then tuft[#tuft + 1] = { x + 1, b[2] - k, "earth2" } end
    end
  end
  for x = 12, 26 do tuft[#tuft + 1] = { x, 28, x % 4 == 0 and "snow5" or "snow3" } end
  frame(1, tuft)
  local stones = {}
  for _, p in ipairs({ { 13, 24, 5 }, { 21, 27, 4 }, { 25, 22, 3 } }) do
    for a = 0, p[3] - 1 do
      stones[#stones + 1] = { p[1] + a, p[2] - 2, "snow5" }
      stones[#stones + 1] = { p[1] + a, p[2] - 1, "ink5" }
      stones[#stones + 1] = { p[1] + a, p[2], a == 0 and "ink5" or "snow3" }
    end
  end
  frame(2, stones)
  local twig = {}
  for k = 0, 13 do twig[#twig + 1] = { 13 + k, 27 - k // 2, "earth2" }; if k < 12 then twig[#twig + 1] = { 14 + k, 28 - k // 2, "snow3" } end end
  for k = 0, 4 do twig[#twig + 1] = { 19 + k, 24 - k, "earth3" } end
  twig[#twig + 1] = { 13, 26, "snow5" }; twig[#twig + 1] = { 14, 26, "snow5" }
  frame(3, twig)
  local prints = {}
  for k = 0, 3 do
    local x, y = 10 + k * 5, 27 - k * 3 + (k % 2) * 3
    for a = 0, 2 do prints[#prints + 1] = { x + a, y, "snow3" }; prints[#prints + 1] = { x + a, y + 1, "snow3" } end
    prints[#prints + 1] = { x, y + 2, "snow5" }; prints[#prints + 1] = { x + 1, y + 2, "snow5" }
  end
  frame(4, prints)
  local icicles = {}
  for _, p in ipairs({ { 8, 14, 7 }, { 12, 16, 4 }, { 15, 17, 9 }, { 25, 17, 6 }, { 29, 15, 8 }, { 33, 13, 4 } }) do
    for k = 0, p[3] do
      icicles[#icicles + 1] = { p[1], p[2] + k, k > p[3] - 2 and "snow3" or "snow5" }
      if k < p[3] - 3 then icicles[#icicles + 1] = { p[1] + 1, p[2] + k, "snow3" } end
    end
  end
  frame(5, icicles)
  for f, n in ipairs({ "tuft", "stones", "twig", "prints", "icicles" }) do M.tag(s, f, f, "idle_" .. n) end
  M.save(s, "slice/snow_decal.aseprite")
end
