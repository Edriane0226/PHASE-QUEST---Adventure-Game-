-- Worked example: the five-state ice barrier. Shows the pipeline; PX-03 decides the final look.
-- Cell 128x128, ground pivot 64,104, footprint 76x36, as in the current catalogue.
local M = dofile(app.params["root"] .. "/tools/art/pixel_v1/lib.lua")
local CX, CY, HW, HH = 64, 104, 38, 19

-- Half width of a diamond row with clean 2:1 steps.
local function reach(dy) local d = HH - math.abs(dy); return d < 0 and -1 or d * 2 end

-- Wobble of the melting top. Corners melt first, so the outline rounds off.
local function wobble(dx, melt)
  if melt == 0 then return 0 end
  local corner = (math.abs(dx) / HW) ^ 4 * 2.2
  return math.floor(melt * (0.7 + 0.6 * math.sin(dx * 0.21 + 0.6) + corner) + 0.5)
end

local function block(c, height, melt, glint)
  local drop = {}
  for x = CX - HW, CX + HW do drop[x] = wobble(x - CX, melt) end
  local top = {} -- first row of each column
  local rim = {} -- row where the top face meets the side
  for x = CX - HW, CX + HW do
    local edge = HH - math.abs(x - CX) // 2
    local h = math.max(2, height - drop[x])
    top[x] = CY - edge - h
    rim[x] = CY + edge - h
  end
  for x = CX - HW, CX + HW do
    local edge = HH - math.abs(x - CX) // 2
    local bottom = CY + edge
    for y = top[x], bottom do
      local colour
      if y <= rim[x] then
        colour = "ice5"
      else
        local left = x < CX
        colour = left and "ice4" or "ice3"
        -- Deeper tone low on the faces, with a stepped border, so shading is not a parallel band.
        local deep = bottom - 5 - ((x - CX + 64) // 7 % 3) * 2
        if y > deep then colour = left and "ice3" or "ice2" end
      end
      c.put("body", x, y, colour)
    end
    -- Selective outline: lit top-left, dark bottom and right.
    c.put("outline", x, top[x], x <= CX and "snow5" or "ice3")
    c.put("outline", x, bottom, x < CX - 1 and "ice2" or "ice1")
  end
  for x = CX - HW + 1, CX + HW - 1 do -- inner lip between top and sides
    if rim[x] < CY + HH - math.abs(x - CX) // 2 - 1 then c.put("detail", x, rim[x], x <= CX and "snow5" or "ice4") end
  end
  for y = top[CX - HW], CY do c.put("outline", CX - HW, y, "ice2"); end
  for y = top[CX + HW], CY do c.put("outline", CX + HW, y, "ice1"); end
  for y = rim[CX] + 1, CY + HH - 1 do if height > 12 then c.put("detail", CX, y, "ice2") end end
  -- Glint: a two pixel wide streak on the left face, moved one step by the shimmer frame.
  if height > 20 then
    local gx = CX - 27 + glint * 3
    for k = 0, math.min(14, height - 16) do
      local y = rim[gx] + 5 + k
      c.put("detail", gx + (k // 4), y, "ice5"); c.put("detail", gx + (k // 4) + 1, y, "ice5")
    end
    for k = 0, 5 do local y = rim[gx] + 8 + k; c.put("detail", gx + 5 + (k // 4), y, "ice5"); c.put("detail", gx + 6 + (k // 4), y, "ice5") end
    -- Frozen cracks: singles only, no doubles.
    local crack = { { 14, 8 }, { 15, 9 }, { 16, 10 }, { 16, 11 }, { 17, 12 }, { 18, 13 }, { 18, 14 }, { 17, 15 }, { 16, 16 }, { 19, 15 }, { 20, 16 } }
    for _, p in ipairs(crack) do
      local x, y = CX + p[1], rim[CX + p[1]] + p[2]
      if y < CY + HH - math.abs(p[1]) // 2 - 8 then c.put("detail", x, y, "ice2") end
    end
  end
  -- Top face: frost patches and one sheen line toward the light.
  for _, p in ipairs({ { -14, 2 }, { -13, 2 }, { -12, 2 }, { -11, 2 }, { -13, 3 }, { -12, 3 }, { 6, -3 }, { 7, -3 }, { 8, -3 }, { 7, -2 }, { 12, 4 }, { 13, 4 }, { 14, 4 } }) do
    local x = CX + p[1]
    local y = CY - math.max(2, height - drop[x]) + p[2]
    if y > top[x] + 1 and y < rim[x] - 1 then c.put("detail", x, y, p[1] < 0 and "snow5" or "ice4") end
  end
end

local function puddle(c, rx, phase, thin)
  local ry = math.min(rx // 2, 19)
  if rx < 4 then return end
  local function wet(dx, dy)
    if math.abs(dy) > ry then return false end
    local w = math.floor(rx * math.sqrt(math.max(0, 1 - (dy / (ry + 0.5)) ^ 2)) + 0.5) - ((dy + ry) // 3 % 2)
    return math.abs(dx) <= w
  end
  for dy = -ry, ry do
    for dx = -rx, rx do
      if wet(dx, dy) then
        local edge = not (wet(dx - 1, dy) and wet(dx + 1, dy) and wet(dx, dy - 1) and wet(dx, dy + 1))
        c.put("body", CX + dx, CY + 4 + dy, edge and (dy > 0 and "ice2" or "ice4") or (thin and "ice4" or "ice3"))
      end
    end
  end
  -- Moving glints show that this is liquid.
  for k, g in ipairs({ { -0.5, -0.3, 7 }, { 0.15, 0.1, 9 }, { -0.25, 0.5, 6 } }) do
    local gx, gy = CX + math.floor(rx * g[1]) + phase * 3, CY + 4 + math.floor(ry * g[2])
    local len = math.min(g[3], rx // 4)
    for i = 0, len do
      local inside = math.abs(gx + i - CX) < rx * math.sqrt(math.max(0, 1 - ((gy - CY - 4) / ry) ^ 2)) - 3
      if inside then c.put("detail", gx + i, gy, thin and "ice5" or (k == 1 and "ice5" or "ice4")) end
    end
  end
end

local function drops(c, n, phase)
  local spots = { { -30, 8 }, { -18, 16 }, { 22, 14 }, { 31, 6 } }
  for k = 1, n do
    local p = spots[k]
    local y = CY + p[2] - 12 + ((phase * 4 + k * 3) % 10)
    c.put("detail", CX + p[1], y, "ice5"); c.put("detail", CX + p[1], y + 1, "ice5")
  end
end

local frames = {}
local tags = {}
local function clip(name, ms, list)
  tags[#tags + 1] = { name, #frames + 1, #frames + #list }
  for _, fn in ipairs(list) do frames[#frames + 1] = { fn, ms } end
end
local function ice(h, m, g, p, d) return function(c) if p > 0 then puddle(c, p, g, false) end; block(c, h, m, g); if d > 0 then drops(c, d, g) end end end
local function pool(r, g, thin) return function(c) puddle(c, r, g, thin) end end
clip("idle_solid", 400, { ice(46, 0, 0, 0, 0), ice(46, 0, 1, 0, 0) })
clip("to_melting_early_from_solid", 120, { ice(45, 1, 0, 40, 1), ice(42, 2, 1, 42, 2), ice(39, 3, 0, 43, 3) })
clip("idle_melting_early", 250, { ice(37, 3, 0, 44, 2), ice(37, 3, 1, 44, 2) })
clip("to_melting_late_from_melting_early", 120, { ice(33, 4, 1, 44, 3), ice(28, 4, 0, 45, 4), ice(23, 5, 1, 45, 4) })
clip("idle_melting_late", 250, { ice(20, 5, 0, 46, 2), ice(20, 5, 1, 46, 2) })
clip("to_liquid_from_melting_late", 120, { ice(14, 5, 0, 46, 3), ice(8, 4, 1, 46, 2), ice(4, 2, 0, 46, 0) })
clip("idle_liquid", 250, { pool(46, 0, false), pool(46, 1, false) })
clip("to_cleared_from_liquid", 150, { pool(42, 0, false), pool(36, 1, true), pool(30, 0, true) })
clip("idle_cleared", 400, { pool(26, 0, true), pool(26, 1, true) })

local s = M.sprite(128, 128, #frames)
for i, fr in ipairs(frames) do
  local c = M.canvas(s)
  fr[1](c)
  c.commit(i, fr[2])
end
for _, t in ipairs(tags) do M.tag(s, t[2], t[3], t[1]) end
M.save(s, "example/ice_barrier_example.aseprite")

-- Shadow: hard pixels, one colour, cast down and right. The engine sets its strength.
local sh = M.sprite(128, 128, 5)
for i, st in ipairs({ { 46, "solid" }, { 37, "melting_early" }, { 20, "melting_late" }, { 0, "liquid" }, { 0, "cleared" } }) do
  local c = M.canvas(sh)
  if st[1] > 0 then
    local len = st[1] // 4
    for dy = -HH, HH do
      local w = reach(dy)
      for dx = -w, w + len do c.put("body", CX + dx, CY + dy + 2, "ink1") end
    end
  else
    for dx = -3, 3 do c.put("body", CX + dx, CY + 4, "ink1") end
  end
  c.commit(i, 250)
  M.tag(sh, i, i, "idle_" .. st[2])
end
M.save(sh, "example/ice_barrier_example_shadow.aseprite")
