-- PX-04: terrain sets for snow, grass and lab, plus shared water and bridge tiles.
-- Cap rows are 2,6..38,38..6,2 pixels wide, so a (20,10) lattice fills with no gap or overlap.
-- Edge bits follow the terrain code: NE 1, SE 2, SW 4, NW 8. The look was approved in PX-03.
local M = dofile(app.params["root"] .. "/tools/art/pixel_v1/lib.lua")

local function half(y) return y < 10 and 2 * y + 1 or 2 * (19 - y) + 1 end
local function inside(x, y) return y >= 0 and y <= 19 and x >= 20 - half(y) and x <= 19 + half(y) end
local head, foot = {}, {}
for x = 0, 39 do
  head[x], foot[x] = 9, 10
  for y = 0, 19 do if inside(x, y) then head[x] = y; break end end
  for y = 19, 0, -1 do if inside(x, y) then foot[x] = y; break end end
end
local function depth(x, y, bit)
  if bit == 8 then return x <= 19 and y - head[x] or 99 end
  if bit == 1 then return x >= 20 and y - head[x] or 99 end
  if bit == 4 then return x <= 19 and foot[x] - y or 99 end
  return x >= 20 and foot[x] - y or 99
end
-- A soft wave: neighbours differ by one row at most, so a border has no teeth. It ends as it begins.
local WAVE = {
  { 0, 0, 0, 1, 1, 2, 2, 2, 1, 1, 1, 2, 2, 1, 1, 0, 0, 0, 0, 0 },
  { 0, 0, 1, 1, 1, 2, 2, 1, 1, 0, 0, 1, 1, 2, 2, 2, 1, 1, 0, 0 },
}
local function ragged(x, low, high, seed)
  local u = x <= 19 and x or 39 - x
  return low + WAVE[seed % 2 + 1][u + 1] * (high - low) // 2
end

-- A tip between two bordered sides is closed, so no loose pixels are left in it.
local function tip(x, mask) return mask & 12 == 12 and x <= 11 or mask & 3 == 3 and x >= 28 end

local folder = "terrain/"
local function caps(name, frames, tags, base, paint)
  local s = M.sprite(40, 20, frames)
  for f = 1, frames do
    local c = M.canvas(s)
    for y = 0, 19 do for x = 0, 39 do if inside(x, y) then c.put("body", x, y, base) end end end
    local used = {}
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
    paint(f, stamp, M.rng(1201 + f * 131 + #name * 17), c)
    c.commit(f, tags.ms or 100)
  end
  for _, t in ipairs(tags) do M.tag(s, t[2], t[3], t[1]) end
  M.save(s, folder .. name .. ".aseprite")
end
local function edges(name, paint)
  local s = M.sprite(40, 24, 16)
  for mask = 0, 15 do
    local c = M.canvas(s)
    if mask > 0 then paint(c, mask) end
    c.commit(mask + 1, 100)
  end
  M.tag(s, 1, 16, "mask_edge")
  M.save(s, folder .. name .. ".aseprite")
end
local function over(name, colour)
  edges(name, function(c, mask)
    for y = 0, 19 do for x = 0, 39 do
      if inside(x, y) then
        for k, bit in ipairs({ 1, 2, 4, 8 }) do
          if mask & bit ~= 0 and depth(x, y, bit) <= ragged(x, 1, 5, k + mask) then c.put("body", x, y, colour) end
        end
        if tip(x, mask) then c.put("body", x, y, colour) end
      end
    end end
  end)
end
local function ripple(a, b) return { { 0, 1, a }, { 1, 0, a }, { 2, 0, a }, { 3, 0, a }, { 4, 0, a }, { 5, 1, a }, { 2, 1, b }, { 3, 1, b }, { 4, 1, b } } end
local function dash(n, colour) local t = {}; for k = 0, n - 1 do t[#t + 1] = { k, 0, colour } end; return t end
local function dimple(a) return { { 0, 0, a }, { 1, 0, a }, { 2, 0, a }, { 3, 0, a }, { 1, 1, a }, { 2, 1, a } } end
local function blade(a, b) return { { 0, 1, a }, { 1, 0, a }, { 2, 1, b }, { 3, 0, b } } end

local SET = {
  snow = { base = "snow4", light = "snow5", dark = "snow3", deep = "snow2", deepest = "snow1", warm = "snow5", cool = "snow3", lip = "snow5",
    path = "earth4", path_dark = "earth3", path_light = "earth5", path_fleck = "snow4",
    soil = { "earth3", "earth2" }, soil_dark = { "earth2", "earth1" }, stone = { "ink5", "ink4" }, stone_lit = { "ink6", "ink5" }, stone_deep = { "ink4", "earth1" } },
  grass = { base = "leaf4", light = "leaf5", dark = "leaf3", deep = "leaf2", deepest = "leaf1", warm = "leaf5", cool = "leaf3", lip = "leaf4",
    path = "earth4", path_dark = "earth3", path_light = "earth5", path_fleck = "leaf4",
    soil = { "earth3", "earth2" }, soil_dark = { "earth2", "earth1" }, stone = { "earth4", "earth3" }, stone_lit = { "earth5", "earth4" }, stone_deep = { "earth2", "earth1" } },
  lab = { base = "ink7", light = "ink8", dark = "ink6", deep = "ink5", deepest = "ink4", warm = "ink8", cool = "ink6", lip = "ink8",
    path = "ink5", path_dark = "ink4", path_light = "ink6", path_fleck = "ink6",
    soil = { "ink5", "ink4" }, soil_dark = { "ink4", "ink3" }, stone = { "ink6", "ink5" }, stone_lit = { "ink7", "ink6" }, stone_deep = { "ink4", "ink3" } },
}

for _, biome in ipairs({ "snow", "grass", "lab" }) do
  local B = SET[biome]
  -- Base caps: 1-2 calm, the others carry a few marks.
  caps(biome .. "_cap", 8, { { "variant_cap", 1, 8 } }, B.base, function(f, stamp, r)
    if biome == "snow" then
      if f <= 2 then stamp(9 + r(18), 5 + r(8), dash(2, B.light)) end
      if f == 3 or f == 4 then stamp(8 + r(6), 8 + r(3), ripple(B.light, B.dark)); stamp(20 + r(6), 5 + r(3), ripple(B.light, B.dark)) end
      if f == 5 or f == 6 then for _ = 1, 4 do stamp(6 + r(26), 3 + r(13), dash(3, B.light)) end end
      if f >= 7 then stamp(8 + r(14), 6 + r(5), dimple(B.dark)); stamp(18 + r(8), 4 + r(9), dash(3, B.light)) end
    elseif biome == "grass" then
      if f <= 2 then stamp(9 + r(18), 5 + r(8), blade(B.dark, B.dark)) end
      if f == 3 or f == 4 then for _ = 1, 4 do stamp(6 + r(24), 3 + r(12), blade(B.dark, B.dark)) end; stamp(10 + r(16), 4 + r(10), dash(2, B.light)) end
      if f == 5 or f == 6 then for _ = 1, 5 do stamp(6 + r(26), 3 + r(13), dash(2, B.light)) end; stamp(8 + r(20), 5 + r(8), blade(B.dark, B.light)) end
      if f >= 7 then stamp(8 + r(14), 6 + r(5), dimple(B.dark)); stamp(18 + r(8), 4 + r(9), blade(B.dark, B.light)); stamp(8 + r(8), 9 + r(4), blade(B.dark, B.light)) end
    else
      -- Panels: one seam in each direction, with rivets. Seams stay inside, so tiles never draw a grid.
      if f == 2 then stamp(10 + r(14), 6 + r(7), dash(2, B.light)) end
      if f == 3 or f == 4 then for k = 0, 5 do stamp(10 + k * 2, 9 + k, { { 0, 0, B.dark }, { 1, 0, B.dark } }) end; local t = {}; for k = 0, 6 do t[#t + 1] = { 2 * k, k, B.dark }; t[#t + 1] = { 2 * k + 1, k, B.dark } end; stamp(13, 6, t) end
      if f == 5 or f == 6 then local t = {}; for k = 0, 6 do t[#t + 1] = { 2 * k, -k, B.dark }; t[#t + 1] = { 2 * k + 1, -k, B.dark } end; stamp(13, 13, t); stamp(8, 9, dash(2, B.light)) end
      if f >= 7 then stamp(8 + r(10), 7 + r(5), dash(4, B.light)); stamp(20 + r(8), 6 + r(8), dash(3, B.dark)) end
    end
  end)
  caps(biome .. "_patch_a", 4, { { "variant_cap", 1, 4 } }, B.warm, function(f, stamp, r)
    if f >= 2 then stamp(8 + r(16), 6 + r(6), dash(3, B.base)) end
    if f >= 3 then stamp(8 + r(10), 9 + r(4), biome == "grass" and blade(B.base, B.base) or ripple(B.base, B.base)) end
    if f == 4 then stamp(18 + r(8), 4 + r(4), dash(3, B.base)) end
  end)
  caps(biome .. "_patch_b", 4, { { "variant_cap", 1, 4 } }, B.cool, function(f, stamp, r)
    if f >= 2 then stamp(8 + r(16), 5 + r(8), dash(3, B.base)) end
    if f >= 3 then stamp(10 + r(10), 8 + r(5), dimple(B.deep)) end
    if f == 4 then stamp(18 + r(8), 5 + r(4), biome == "grass" and blade(B.base, B.deep) or dash(3, B.base)) end
  end)
  over(biome .. "_over", B.base)

  caps(biome .. "_path", 6, { { "variant_cap", 1, 6 } }, B.path, function(f, stamp, r)
    for _ = 1, 1 + f // 2 do stamp(7 + r(24), 4 + r(12), dash(3, B.path_dark)) end
    if f % 2 == 0 then stamp(8 + r(18), 5 + r(9), { { 0, 0, B.path_light }, { 1, 0, B.path_light }, { 2, 0, B.path_light }, { 0, 1, B.path_dark }, { 1, 1, B.path_dark }, { 2, 1, B.path_dark } }) end
    if f >= 4 then stamp(10 + r(14), 8 + r(5), dimple(B.path_fleck)) end
  end)
  -- The ground on the path: a bank behind casts a thin shade, a bank in front shows a lit lip.
  edges(biome .. "_path_over", function(c, mask)
    local bank = {}
    for y = 0, 19 do for x = 0, 39 do
      if inside(x, y) then
        for k, bit in ipairs({ 8, 1, 4, 2 }) do
          if mask & bit ~= 0 then
            local d, limit = depth(x, y, bit), ragged(x, 2, 6, k + mask)
            if tip(x, mask) and (bit == 8 or bit == 1) then bank[y * 40 + x] = B.base
            elseif d <= limit then bank[y * 40 + x] = (d == limit and (bit == 4 or bit == 2)) and B.light or (bank[y * 40 + x] or B.base) end
          end
        end
      end
    end end
    for y = 0, 19 do for x = 0, 39 do
      if inside(x, y) then
        if bank[y * 40 + x] then c.put("body", x, y, bank[y * 40 + x])
        else
          for k, bit in ipairs({ 8, 1 }) do
            if mask & bit ~= 0 and depth(x, y, bit) == ragged(x, 2, 6, k + mask) + 1 then c.put("detail", x, y, B.deep) end
          end
        end
      end
    end end
  end)

  edges(biome .. "_foot", function(c, mask)
    for y = 0, 19 do for x = 0, 39 do
      if inside(x, y) then
        local best
        for k, bit in ipairs({ 8, 1, 4, 2 }) do
          if mask & bit ~= 0 then
            local wide = bit == 8 and 1 or (bit == 1 and 3 or 1)
            local u = x <= 19 and x or 39 - x
            local d, limit = depth(x, y, bit), wide + 1 + ((u // 4 + k) % 3 == 0 and 1 or 0)
            if d <= limit then best = (d <= 1 and B.deepest) or (best == B.deepest and best) or B.deep
            elseif d <= limit + 2 and not best then best = B.dark end
          end
        end
        if best then c.put("body", x, y, best) end
      end
    end end
  end)
  edges(biome .. "_edge", function(c, mask)
    for x = 1, 38 do
      local back = x <= 19 and 8 or 1
      if mask & back ~= 0 then
        c.put("body", x, head[x], B.light)
        if (x // 3) % 4 ~= 1 then c.put("body", x, head[x] + 1, B.light) end
      end
      local front = x <= 19 and 4 or 2
      if mask & front ~= 0 then
        local table_of = biome == "lab" and { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 } or (biome == "grass" and { 1, 3, 2, 4, 2, 3, 1, 3, 4, 2 } or { 1, 2, 3, 2, 2, 4, 3, 1, 2, 3 })
        local drop = table_of[(x // 2 + (front == 2 and 3 or 0)) % 10 + 1]
        for k = -2, drop do
          local colour = k <= -1 and B.light or B.lip
          if k == drop then colour = front == 4 and B.dark or B.deep elseif front == 2 and k >= 1 then colour = biome == "grass" and B.dark or B.base end
          c.put("body", x, foot[x] + k, colour)
        end
      end
    end
  end)

  -- Cliff sides: four left, four right.
  do
    local s = M.sprite(40, 40, 8)
    for f = 1, 8 do
      local left = f <= 4
      local n = left and 1 or 2
      local soil, dark, stone, lit, deep = B.soil[n], B.soil_dark[n], B.stone[n], B.stone_lit[n], B.stone_deep[n]
      local c = M.canvas(s)
      local r = M.rng(5501 + f * 47)
      local x0 = left and 1 or 19
      local function px(u, v, colour) local x = x0 + (u % 20); c.put("detail", x, foot[x] + 1 + (v % 20), colour) end
      for u = 0, 19 do for v = 0, 19 do
        local x = x0 + u
        -- Walls stack: one thin, broken stratum closes each cube, so a tall cliff has no heavy bands.
        c.put("body", x, foot[x] + 1 + v, (v == 19 and (u + f) % 7 ~= 2 or v == 18 and (u * 3 + f) % 11 < 3) and dark or soil)
      end end
      if biome == "lab" then
        -- Plates: one long seam and two rivets.
        for u = 0, 19 do if u % 10 ~= 4 then px(u, 10, dark) end end
        for v = 3, 9 do px(3 + (f % 4) * 4, v, dark) end
        for _, u in ipairs({ 1 + f % 4, 12 + f % 3 }) do px(u, 5, lit); px(u + 1, 5, lit); px(u, 6, deep); px(u + 1, 6, deep) end
        for u = 0, 7 do px(5 + f + u, 14, lit) end
      else
        local widths = ({ { 6, 5, 4, 5 }, { 4, 6, 5, 5 }, { 5, 4, 7, 4 }, { 7, 5, 4, 4 } })[(f - 1) % 4 + 1]
        local u = r(4)
        for k, w in ipairs(widths) do
          if (k + f) % 4 == 0 and f % 4 ~= 3 then
            local top, tall = 5 + f % 2, 4 + (k * f) % 2
            for a = 0, w - 2 do for b = 0, tall - 1 do
              local corner = (a == 0 or a == w - 2) and (b == 0 or b == tall - 1)
              if not corner then px(u + a, top + b, b == 0 and lit or (b == tall - 1 and deep or stone)) end
            end end
            for a = 1, w - 2 do px(u + a, top + tall, dark) end
          end
          u = u + w
        end
        local start = r(20)
        for a = 0, 8 + r(5) do px(start + a, 12, dark) end
        start = r(20)
        for a = 0, 5 + r(3) do px(start + a, 15, dark) end
        start = r(17)
        px(start, 14, lit); px(start + 1, 14, lit)
      end
      c.commit(f, 100)
    end
    M.tag(s, 1, 4, "variant_left")
    M.tag(s, 5, 8, "variant_right")
    M.save(s, folder .. biome .. "_side.aseprite")
  end
  do
    local s = M.sprite(40, 40, 2)
    local c = M.canvas(s)
    for v = 0, 19 do
      local y = 20 + v
      c.put("body", 18, y - 1, (v >= 5 and v <= 9) and B.stone_lit[1] or B.soil[1])
      c.put("body", 19, y, (v >= 5 and v <= 9) and B.stone_lit[1] or B.soil[1])
      c.put("body", 20, y, B.soil_dark[2])
    end
    c.commit(1, 250)
    local d = M.canvas(s)
    for v = 0, 19 do
      d.put("body", 19, v, B.soil_dark[2]); d.put("body", 20, v, B.soil_dark[2])
      if v % 6 < 4 then d.put("body", 21, v, B.soil_dark[2]) end
    end
    d.commit(2, 250)
    M.tag(s, 1, 1, "idle_outer")
    M.tag(s, 2, 2, "idle_inner")
    M.save(s, folder .. biome .. "_corner.aseprite")
  end
  -- Ramps on a path cell: up to the NE or up to the NW neighbour, one cube higher.
  do
    local s = M.sprite(40, 40, 2)
    for f = 1, 2 do
      local c = M.canvas(s)
      local function flip(x) return f == 1 and x or 39 - x end
      for x = 0, 39 do
        local top = x >= 20 and head[x] or math.max(0, math.floor(30 - 1.5 * x))
        local low = foot[x] + 20
        local slope = x >= 20 and math.floor(39 - 1.5 * (x - 20)) or low
        for y = top, low do
          if x >= 20 and y > slope then
            local v = y - slope
            c.put("body", flip(x), y, f == 1 and (v <= 1 and B.soil_dark[2] or B.soil[2]) or (v <= 1 and B.soil_dark[1] or B.soil[1]))
          else
            -- Five treads. Lines of one height run along the back edge, two pixels across for one down.
            local line = (30 + x // 2) - y
            local k = line % 8
            c.put("body", flip(x), y, k <= 1 and line > 1 and B.path_dark or (k == 7 and B.path_light or B.path))
          end
        end
      end
      c.commit(f, 250)
    end
    M.tag(s, 1, 1, "idle_ne")
    M.tag(s, 2, 2, "idle_nw")
    M.save(s, folder .. biome .. "_ramp.aseprite")
  end
  -- Decals for the detail layer, six per biome, standing at 20,28.
  do
    local s = M.sprite(40, 40, 6)
    local function frame(f, list)
      local c = M.canvas(s)
      for _, p in ipairs(list) do c.put("body", p[1], p[2], p[3]) end
      c.commit(f, 250)
    end
    local function tuft(tip, stem, ground, light)
      local t = {}
      for _, b in ipairs({ { 15, 26, 8, -1 }, { 18, 27, 11, 0 }, { 21, 26, 9, 1 }, { 24, 27, 6, 1 }, { 13, 27, 5, -1 } }) do
        for k = 0, b[3] - 1 do
          local x = b[1] + (k * b[4]) // 4
          t[#t + 1] = { x, b[2] - k, k > b[3] - 4 and tip or stem }
          if k < b[3] - 3 then t[#t + 1] = { x + 1, b[2] - k, stem } end
        end
      end
      for x = 12, 26 do t[#t + 1] = { x, 28, x % 4 == 0 and light or ground } end
      return t
    end
    local function stones(top, side, ground)
      local t = {}
      for _, p in ipairs({ { 13, 24, 5 }, { 21, 27, 4 }, { 25, 22, 3 } }) do
        for a = 0, p[3] - 1 do t[#t + 1] = { p[1] + a, p[2] - 2, top }; t[#t + 1] = { p[1] + a, p[2] - 1, side }; t[#t + 1] = { p[1] + a, p[2], a == 0 and side or ground } end
      end
      return t
    end
    local function flowers(colour, heart)
      local t = {}
      for _, p in ipairs({ { 14, 24 }, { 20, 27 }, { 25, 23 } }) do
        for k = 1, 3 do t[#t + 1] = { p[1], p[2] + k, "leaf2" }; t[#t + 1] = { p[1] + 1, p[2] + k, "leaf2" } end
        for _, e in ipairs({ { -1, 0 }, { 0, -1 }, { 1, -1 }, { 2, 0 }, { 0, 1 }, { 1, 1 } }) do t[#t + 1] = { p[1] + e[1], p[2] + e[2], colour } end
        t[#t + 1] = { p[1], p[2], heart }; t[#t + 1] = { p[1] + 1, p[2], heart }
      end
      return t
    end
    local function lines(list) local t = {}; for _, l in ipairs(list) do for k = 0, l[4] - 1 do t[#t + 1] = { l[1] + k * l[3], l[2] + k // 2 * (l[5] or 1), l[6] } end end; return t end
    if biome == "snow" then
      frame(1, tuft("earth4", "earth3", "snow3", "snow5")); frame(2, stones("snow5", "ink5", "snow3"))
      frame(3, lines({ { 13, 27, 1, 14, -1, "earth2" }, { 14, 28, 1, 12, -1, "snow3" }, { 19, 24, 1, 6, -1, "earth2" } }))
      frame(4, lines({ { 8, 26, 1, 8, 1, "snow5" }, { 10, 28, 1, 8, 1, "snow3" }, { 22, 24, 1, 6, 1, "snow5" } }))
      frame(5, stones("snow5", "ink5", "snow3"))
      frame(6, tuft("leaf3", "leaf2", "snow3", "snow5"))
    elseif biome == "grass" then
      frame(1, tuft("leaf5", "leaf2", "leaf3", "leaf4")); frame(2, flowers("amber4", "snow5")); frame(3, flowers("red4", "amber4"))
      frame(4, flowers("snow5", "amber4")); frame(5, stones("snow5", "earth4", "leaf3")); frame(6, tuft("leaf4", "leaf2", "leaf3", "leaf5"))
    else
      frame(1, lines({ { 10, 24, 1, 20, 1, "ink5" }, { 10, 25, 1, 20, 1, "ink8" } }))
      frame(2, lines({ { 14, 24, 1, 12, 1, "ink4" }, { 14, 26, 1, 12, 1, "ink4" }, { 14, 28, 1, 10, 1, "ink4" }, { 14, 25, 1, 12, 1, "ink6" } }))
      frame(3, lines({ { 12, 27, 1, 10, -1, "snow5" }, { 18, 28, 1, 8, -1, "snow4" }, { 14, 24, 1, 6, 1, "snow5" } }))
      frame(4, stones("ink8", "ink5", "ink6"))
      frame(5, lines({ { 9, 28, 1, 22, -1, "violet3" }, { 9, 29, 1, 22, -1, "ink5" } }))
      frame(6, lines({ { 16, 26, 1, 8, 1, "snow4" }, { 18, 24, 1, 4, 1, "snow5" } }))
    end
    for f, n in ipairs({ "a", "b", "c", "d", "e", "f" }) do M.tag(s, f, f, "idle_" .. n) end
    M.save(s, folder .. biome .. "_decal.aseprite")
  end
end

-- ------------------------------------------------------------------ water
caps("water_cap", 12, { { "loop_water_a", 1, 4 }, { "loop_water_b", 5, 8 }, { "loop_water_c", 9, 12 }, ms = 180 }, "ice3", function(f, stamp)
  local v, t = (f - 1) // 4, (f - 1) % 4
  local slide = ({ 0, 1, 2, 1 })[t + 1]
  if v == 0 then
    stamp(9 + slide, 7, dash(5, "ice4")); stamp(18 - slide, 12, dash(7, "ice2"))
    if t % 2 == 1 then stamp(24, 6, dash(2, "ice5")) end
  elseif v == 1 then
    stamp(14 - slide, 11, dash(4, "ice2"))
    if t == 2 then stamp(20, 6, dash(3, "ice5")) end
  elseif t == 1 or t == 2 then stamp(17 + t, 9, dash(2, "ice4")) end
end)
caps("water_deep", 8, { { "loop_water_a", 1, 4 }, { "loop_water_b", 5, 8 }, ms = 180 }, "ice2", function(f, stamp)
  local v, t = (f - 1) // 4, (f - 1) % 4
  local slide = ({ 0, 1, 2, 1 })[t + 1]
  if v == 0 then stamp(10 + slide, 9, dash(6, "ice3")); if t == 3 then stamp(22, 6, dash(2, "ice4")) end
  elseif t ~= 2 then stamp(20 - slide, 12, dash(4, "ice3")) end
end)
-- Beside a bank: a dark, broken reflection that slides sideways.
caps("water_reflect", 8, { { "loop_water_a", 1, 4 }, { "loop_water_b", 5, 8 }, ms = 180 }, "ice3", function(f, stamp)
  local v, t = (f - 1) // 4, (f - 1) % 4
  local slide = ({ 0, 1, 2, 1 })[t + 1]
  stamp(12 + slide + v * 3, 5, dash(9 - v * 2, "ice2"))
  stamp(19 - slide - v * 2, 8, dash(7, "ice2"))
  stamp(11 + slide * 2, 11, dash(6, "ice2"))
  stamp(20 - slide, 14, dash(4, "ice2"))
  if t == 2 then stamp(24, 11, dash(2, "ice5")) end
end)
over("water_over", "ice3")

-- ------------------------------------------------------------------ bridge
-- Boards across the deck. Frames 1-4: boards along the NE axis. Frames 5-8: along the SE axis.
caps("bridge_cap", 8, { { "variant_cap", 1, 8 } }, "earth3", function(f, _, r, c)
  -- A line of constant p = x - 2y (or x + 2y) follows one grid axis. Gaps sit at a third and two thirds of the cell.
  for y = 0, 19 do for x = 0, 39 do
    if inside(x, y) then
      local p = f <= 4 and ((x - 19) // 2 + (y - 10)) or ((x - 19) // 2 - (y - 10))
      if (p + 20) % 10 == 3 then c.put("detail", x, y, "earth2") end
    end
  end end
  local x, y = 12 + r(12), 7 + r(5)
  if f % 4 == 1 then c.put("detail", x, y, "earth4"); c.put("detail", x + 1, y, "earth4"); c.put("detail", x + 2, y, "earth4") end
  if f % 4 == 2 then c.put("detail", x, y, "earth5"); c.put("detail", x + 1, y, "earth5") end
end)
