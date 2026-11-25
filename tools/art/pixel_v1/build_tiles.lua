-- Isometric caps, edge masks and cube sides for one biome.
-- Cap rows are 2,6..38,38..6,2 pixels wide, so a (20,10) lattice fills with no gap or overlap.
-- Edge bits follow the terrain code: NE 1, SE 2, SW 4, NW 8.
local M = dofile(app.params["root"] .. "/tools/art/pixel_v1/lib.lua")
local B = ({
  snow  = { zone = "gardens", base = "snow4", mark = "snow5", low = "snow3", rim = "snow5", lip = "snow5", under = "snow2", dark = "snow3",
            left = { "earth3", "earth4", "earth2", "earth2" }, right = { "earth2", "earth3", "earth1", "earth1" } },
  grass = { zone = "vale", base = "leaf4", mark = "leaf5", low = "leaf3", rim = "leaf5", lip = "leaf4", under = "leaf2", dark = "leaf3",
            left = { "earth3", "earth4", "earth2", "earth2" }, right = { "earth2", "earth3", "earth1", "earth1" } },
  lab   = { zone = "laboratory", base = "ink7", mark = "ink8", low = "ink6", rim = "ink8", lip = "ink8", under = "ink4", dark = "ink6",
            left = { "ink5", "ink6", "ink4", "ink4" }, right = { "ink4", "ink5", "ink3", "ink3" } },
})[app.params["biome"] or "snow"]
local biome = app.params["biome"] or "snow"

local function half(y) return y < 10 and 2 * y + 1 or 2 * (19 - y) + 1 end
local function inside(x, y) return y >= 0 and y <= 19 and x >= 20 - half(y) and x <= 19 + half(y) end
-- Lowest cap row in a column. The sides hang from here.
local function foot(x)
  for y = 19, 0, -1 do if inside(x, y) then return y end end
  return 9
end

-- Caps: eight variants. Marks are clusters of 2-6 px and stay off the border.
do
  local s = M.sprite(40, 20, 8)
  for f = 1, 8 do
    local c = M.canvas(s)
    for y = 0, 19 do for x = 0, 39 do if inside(x, y) then c.put("body", x, y, B.base) end end end
    local r = M.rng(701 + f * 97)
    local used = {}
    local function cluster(colour, n)
      local x, y = 6 + r(28), 3 + r(14)
      local shape = ({ { { 0, 0 }, { 1, 0 } }, { { 0, 0 }, { 1, 0 }, { 2, 0 } }, { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 1, 1 } },
        { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 3, 0 }, { 1, 1 }, { 2, 1 } } })[n]
      for _, p in ipairs(shape) do
        local X, Y = x + p[1], y + p[2]
        for _, e in ipairs({ { 2, 0 }, { -2, 0 }, { 0, 1 }, { 0, -1 }, { 0, 0 } }) do
          if not inside(X + e[1], Y + e[2]) or used[(Y + e[2]) * 40 + X + e[1]] then return end
        end
      end
      for _, p in ipairs(shape) do
        used[(y + p[2]) * 40 + x + p[1]] = true
        c.put("detail", x + p[1], y + p[2], colour)
      end
    end
    -- Variants 1 and 2 stay calm, 3-6 carry some marks, 7 and 8 are the busiest.
    local amount = ({ 1, 2, 3, 3, 4, 4, 5, 6 })[f]
    for k = 1, amount do cluster(B.mark, 1 + r(4)); if k % 2 == 0 then cluster(B.low, 1 + r(2)) end end
    c.commit(f, 100)
  end
  M.tag(s, 1, 8, "variant_cap")
  M.save(s, "tiles/" .. biome .. "_cap.aseprite")
end

-- Edge overlays: sixteen masks in one tag, frame = mask.
do
  local s = M.sprite(40, 24, 16)
  for mask = 0, 15 do
    local c = M.canvas(s)
    local r = M.rng(4001 + mask * 13)
    for y = 0, 19 do
      local l, rr = 20 - half(y), 19 + half(y)
      if y < 10 then
        if mask & 8 ~= 0 then c.put("body", l, y, B.rim); c.put("body", l + 1, y, B.rim) end
        if mask & 1 ~= 0 then c.put("body", rr, y, B.rim); c.put("body", rr - 1, y, B.rim) end
      end
    end
    for x = 1, 38 do
      local side = x <= 19 and 4 or 2
      if mask & side ~= 0 then
        local y = foot(x)
        c.put("body", x, y - 1, B.lip)
        c.put("body", x, y, B.lip)
        -- The lip hangs over the side. Runs of three columns avoid a comb.
        local drop = ({ 1, 1, 2, 1, 2, 3, 2, 1 })[(x // 3) % 8 + 1]
        for k = 1, drop do c.put("body", x, y + k, k == drop and (side == 4 and B.dark or B.under) or (side == 4 and B.lip or B.dark)) end
      end
    end
    c.commit(mask + 1, 100)
  end
  M.tag(s, 1, 16, "mask_edge")
  M.save(s, "tiles/" .. biome .. "_edge.aseprite")
end

-- Cube sides: four left (SW) and four right (SE) variants. Each is 20 columns by 20 rows,
-- repeats every (20,10) along the cliff and every 20 rows down.
do
  local s = M.sprite(40, 40, 8)
  for f = 1, 8 do
    local leftside = f <= 4
    local k = leftside and B.left or B.right
    local c = M.canvas(s)
    local r = M.rng(9001 + f * 31)
    local x0, x1 = leftside and 1 or 19, leftside and 20 or 38
    local function at(u, v) -- u along the face, v down it
      local x = x0 + (u % 20)
      return x, (x >= 1 and x <= 38 and foot(x) or 9) + 1 + (v % 20)
    end
    for u = 0, 19 do for v = 0, 19 do local x, y = at(u, v); c.put("body", x, y, k[1]) end end
    -- Broken strata, two rows per cube, shifted per variant.
    for _, v in ipairs({ 6, 14 }) do
      local start, len = r(20), 9 + r(5)
      for u = start, start + len do local x, y = at(u, v); c.put("detail", x, y, k[3]) end
    end
    -- Stones: light top, dark underside.
    for n = 1, 2 do
      local u, v = r(17), ({ 1, 9, 16 })[r(3) + 1]
      for d = 0, 2 do
        local x, y = at(u + d, v); c.put("detail", x, y, k[2])
        local X, Y = at(u + d, v + 1); c.put("detail", X, Y, d < 2 and k[2] or k[4])
      end
    end
    c.commit(f, 100)
  end
  M.tag(s, 1, 4, "variant_left")
  M.tag(s, 5, 8, "variant_right")
  M.save(s, "tiles/" .. biome .. "_side.aseprite")
end
