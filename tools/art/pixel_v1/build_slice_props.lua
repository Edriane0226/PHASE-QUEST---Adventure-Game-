-- PX-03 vertical slice: pine, rocks, shelter, lantern and the five-state ice barrier, with their shadows.
-- Light from the top left. Pivots and footprints follow the current catalogue.
local M = dofile(app.params["root"] .. "/tools/art/pixel_v1/lib.lua")

local function poly(c, layer, points, colour)
  for y = 0, c.h - 1 do
    local cross, n = {}, #points
    for k = 1, n do
      local a, b = points[k], points[k % n + 1]
      if (a[2] <= y and b[2] > y) or (b[2] <= y and a[2] > y) then cross[#cross + 1] = a[1] + (y - a[2]) / (b[2] - a[2]) * (b[1] - a[1]) end
    end
    table.sort(cross)
    for k = 1, #cross - 1, 2 do for x = math.ceil(cross[k] - 0.001), math.floor(cross[k + 1] + 0.001) do c.put(layer, x, y, colour) end end
  end
end
-- An isometric block standing on (cx, cy): half width hw, height up. paint(face, u, v, w, h) gives a colour.
-- Columns step 2:1. The top diamond has hw + 1 columns on each side of the axis.
local function block(c, cx, cy, hw, up, paint, layer)
  layer = layer or "body"
  for dx = -hw, hw do
    local e = (hw - math.abs(dx)) // 2
    for y = cy - e - up, cy + e - up do
      local colour = paint("top", dx, y - (cy - up), hw, up)
      if colour then c.put(layer, dx + cx, y, colour) end
    end
    for v = 1, up do
      local colour = paint(dx < 0 and "left" or "right", dx, v, hw, up)
      if colour then c.put(layer, dx + cx, cy + e - up + v, colour) end
    end
  end
end
-- Repeatable scatter: true for about one pixel group in n.
local function scatter(x, y, seed, n)
  local h = (x * 374761393 + y * 668265263 + seed * 2147483647) & 0x7fffffff
  h = ((h ~ (h >> 13)) * 1274126177) & 0x7fffffff
  return (h >> 7) % n == 0
end
local function write(name, w, h, frames)
  local s = M.sprite(w, h, #frames)
  local open
  for i, fr in ipairs(frames) do
    local c = M.canvas(s)
    fr[3](c)
    c.commit(i, fr[2])
    if not open or open[1] ~= fr[1] then
      if open then M.tag(s, open[2], i - 1, open[1]) end
      open = { fr[1], i }
    end
  end
  M.tag(s, open[2], #frames, open[1])
  M.save(s, "slice/" .. name .. ".aseprite")
end
-- Shadow sheet: a contact shadow and a directional cast shadow. Hard pixels, one colour.
local function shadows(name, w, h, cx, cy, hw, reach, shape)
  local function diamond(c, x0, y0, half, grow)
    for dy = -half // 2, half // 2 do
      local span = half - math.abs(dy) * 2
      for dx = -span, span do c.put("body", x0 + dx + (grow or 0), y0 + dy, "ink1") end
    end
  end
  write(name .. "_shadow", w, h, {
    { "idle_contact", 250, function(c) diamond(c, cx, cy + 1, hw + 2) end },
    { "idle_cast", 250, function(c) shape(c, cx, cy, reach, diamond) end },
  })
end

-- ------------------------------------------------------------------ pine
-- Four stacked blocks of needles under snow. Upper blocks lean one pixel, so it sways.
local function pine(lean, crumbs)
  return function(c)
    local function shift(k) return k <= 1 and 0 or (k == 2 and lean[1] or lean[2]) end
    block(c, 64, 104, 5, 26, function(face, u, v)
      if face == "top" then return "earth2" end
      if face == "left" then return (v * 3 + u) % 7 == 0 and "leaf1" or "earth2" end
      return (u % 3 == 0) and "earth2" or "leaf1"
    end)
    local tiers = { { 27, 79, 13 }, { 20, 63, 13 }, { 13, 48, 12 }, { 7, 35, 11 } }
    for k, t in ipairs(tiers) do
      local hw, cy, up = t[1], t[2], t[3]
      local cx = 64 + shift(k)
      block(c, cx, cy, hw, up, function(face, u, v)
        if face == "top" then
          -- Snow: lit on the left, one broken cool area on the right.
          local cool = u > hw // 3 + (v * 5 % 3) or (u > 0 and v > hw // 3)
          return cool and "snow3" or "snow5"
        end
        local drip = ({ 3, 4, 2, 5, 3, 2, 4, 6, 3, 2 })[((u + 40) // 2 + k * 3) % 10 + 1]
        if v <= drip - 1 then return face == "left" and (v == drip - 1 and "snow3" or "snow5") or "snow3" end
        -- Needle clumps: short strokes in loose groups, with dark gaps under them.
        local col = (u + 64) // 4
        local row = v + (col % 2) * 2
        local clump, gap = scatter(col, row // 4, k, 2), scatter(col, row // 4, k + 9, 4)
        if face == "left" then
          if clump and row % 4 <= 1 and (u + 64) % 4 <= 2 then return "leaf3" end
          if (gap and row % 4 == 3) or v >= up - 1 then return "leaf1" end
          return "leaf2"
        end
        if clump and not gap and row % 4 <= 1 and (u + 64) % 4 >= 1 then return "leaf2" end
        return "leaf1"
      end)
      -- Saw-tooth hem: needles hang below the block.
      for dx = -hw, hw do
        local e = (hw - math.abs(dx)) // 2
        local hang = ({ 0, 1, 2, 1, 0, 2, 3, 1 })[((dx + 64) // 2 + k) % 8 + 1]
        for q = 1, hang do c.put("body", cx + dx, cy + e + q, dx < 0 and (q == hang and "leaf1" or "leaf2") or "leaf1") end
      end
    end
    for _, p in ipairs(crumbs) do c.put("detail", p[1], p[2], "snow5"); c.put("detail", p[1], p[2] + 1, "snow5") end
  end
end
write("tree_pine", 128, 128, {
  { "idle", 250, pine({ 0, 0 }, {}) },
  { "idle", 250, pine({ 0, 1 }, {}) },
  { "idle", 250, pine({ 1, 1 }, { { 87, 88 } }) },
  { "idle", 250, pine({ 0, 0 }, { { 87, 97 }, { 44, 94 } }) },
})
shadows("tree_pine", 128, 128, 64, 104, 10, 1, function(c, cx, cy)
  for k = 0, 44 do
    local w = k < 12 and 3 or math.max(2, 17 - math.abs(k - 22) // 2 - (k % 9 > 6 and 3 or 0))
    for q = -w // 2, w // 2 do c.put("body", cx + k + 4, cy + k // 3 + q, "ink1") end
  end
end)

-- ------------------------------------------------------------------ rocks
local function stone(c, cx, cy, hw, up, seed)
  block(c, cx, cy, hw, up, function(face, u, v)
    if face == "top" then return (u > 1 and v > 1) and "snow3" or "snow5" end
    local drip = ({ 2, 3, 1, 2, 4, 2 })[((u + 60) // 2 + seed) % 6 + 1]
    if v <= drip - 1 then return face == "left" and "snow5" or "snow3" end
    local chipped = scatter((u + 60) // 3, (v + ((u + 60) // 3 % 2)) // 2, seed, 7)
    if face == "left" then return chipped and "ink6" or (v > up - 3 and "ink4" or "ink5") end
    return (chipped and "ink5") or (v > up - 4 and "ink3" or "ink4")
  end)
  for v = 3, up - 1 do c.put("body", cx, cy + hw // 2 - up + v, v % 5 == 2 and "ink5" or "ink6") end
  for dx = -hw, hw do c.put("body", cx + dx, cy + (hw - math.abs(dx)) // 2, "ink3") end
  for v = 0, up - 4 do c.put("body", cx + hw, cy - v, "ink3") end
end
write("rocks", 128, 128, { { "idle", 1000, function(c)
  stone(c, 66, 92, 13, 24, 1)
  stone(c, 50, 101, 12, 14, 2)
  stone(c, 80, 103, 11, 11, 4)
end } })
shadows("rocks", 128, 128, 66, 102, 26, 1, function(c, cx, cy, _, diamond)
  diamond(c, cx + 12, cy + 2, 24); diamond(c, cx + 22, cy, 18)
end)

-- ------------------------------------------------------------------ shelter
-- Footprint 108 x 54, walls 34, hip roof. A window on the lit wall and a door on the other.
local function shelter(warm, flick)
  return function(c)
    local cx, cy, hw, up = 96, 122, 50, 40
    block(c, cx, cy, hw, up, function(face, u, v)
      if face == "top" then return "earth1" end
      local w = face == "left" and u + hw or hw - u
      if v > up - 6 then -- stone footing
        local joint = (w + (v % 2) * 4) % 8 == 0
        if face == "left" then return joint and "ink3" or (v == up - 5 and "ink6" or "ink5") end
        return joint and "ink3" or (v == up - 5 and "ink5" or "ink4")
      end
      local plank = v % 6
      local nail = (w % 17 == 4) and plank == 3
      if face == "left" then
        if plank == 0 then return "earth2" end
        if nail then return "earth1" end
        return plank == 1 and "earth4" or "earth3"
      end
      if plank == 0 then return "earth1" end
      return nail and "earth1" or (plank == 1 and "earth3" or "earth2")
    end)
    -- Corner post.
    for v = 2, up do
      c.put("detail", cx - 2, cy + hw // 2 - up + v - 1, "earth4"); c.put("detail", cx - 1, cy + hw // 2 - up + v - 1, "earth3")
      c.put("detail", cx, cy + hw // 2 - up + v, "earth2"); c.put("detail", cx + 1, cy + hw // 2 - up + v - 1, "earth1")
    end
    -- Window: frame, four panes, sill with snow.
    local function wall(u, v) local e = (hw - math.abs(u)) // 2; return cx + u, cy + e - up + v end
    for u = -36, -17 do for v = 12, 28 do
      local x, y = wall(u, v)
      local frame = u <= -35 or u >= -18 or v <= 13 or v >= 27 or u == -27 or u == -26 or v == 20
      local pane
      if warm then
        pane = (v < 20 and "amber4" or "amber3")
        if (u + v + flick * 3) % 11 < 4 then pane = "amber5" end
      else
        pane = (u + v) % 9 < 3 and "ice3" or "ice2"
      end
      c.put("detail", x, y, frame and (v <= 12 and "earth4" or "earth1") or pane)
    end end
    for u = -38, -15 do local x, y = wall(u, 29); c.put("detail", x, y, "snow5"); c.put("detail", x, y + 1, "snow3") end
    -- Door: planks, dark frame, handle, light under it when warm.
    for u = 14, 33 do for v = 12, up - 1 do
      local x, y = wall(u, v)
      local frame = u <= 15 or u >= 32 or v <= 13
      c.put("detail", x, y, frame and "earth1" or ((u % 5 == 0) and "earth1" or (u % 5 == 1 and "earth3" or "earth2")))
    end end
    for k = 0, 1 do local x, y = wall(29, 27 + k); c.put("detail", x, y, "amber4"); c.put("detail", x + 1, y, "amber3") end
    if warm then for u = 16, 31 do local x, y = wall(u, up); c.put("detail", x, y, flick == 1 and "amber3" or "amber4") end end
    -- Roof: two visible planes of snow with a warm lit side and a cool side, over a dark eave.
    local ex, ey, peak = hw + 7, cy - up, 38
    local W, F, E, P = { cx - ex, ey + 2 }, { cx, ey + ex // 2 + 2 }, { cx + ex, ey + 2 }, { cx, ey - peak }
    poly(c, "detail", { { W[1], W[2] + 4 }, { F[1], F[2] + 5 }, { E[1], E[2] + 4 }, E, F, W }, "earth1")
    poly(c, "outline", { W, F, P }, "snow5")
    poly(c, "outline", { F, E, P }, "snow3")
    -- Where the snow is thin, courses show in short broken runs that follow the eaves.
    local function roof(dx, y)
      local rise = P[2] - (P[2] - W[2]) / ex * math.abs(dx)
      return y > rise + 2 and y < ey + (ex - math.abs(dx)) // 2
    end
    for k, run in ipairs({ { 12, 8, 11 }, { 24, 24, 15 }, { 34, 6, 13 }, { 46, 30, 16 }, { 54, 12, 12 }, { 60, 38, 10 } }) do
      for q = 0, run[3] do
        local dx = -run[2] - q
        local y = P[2] + run[1] - (run[2] + q) // 2
        for e = 0, (q % 6 < 4) and 1 or 0 do
          if roof(dx, y + e) then c.put("outline", cx + dx, y + e, "snow4") end
          if roof(-dx - 4, y + 5 + e) then c.put("outline", cx - dx - 4, y + 5 + e, "snow4") end
        end
      end
    end
    -- Ridge: a bright arris that breaks where snow has slid.
    for y = P[2] + 1, F[2] - 1 do
      if (y // 5) % 4 ~= 2 then c.put("outline", cx, y, "snow5"); c.put("outline", cx + 1, y, "snow4") end
    end
    -- Eave: snow lip with drips and icicles, longer under the cool side.
    for dx = -ex, ex do
      local e = (ex - math.abs(dx)) // 2
      local y = ey + 2 + e
      local drop = ({ 1, 2, 2, 3, 1, 2, 4, 2, 1, 3 })[((dx + 80) // 3) % 10 + 1]
      for q = 0, drop do c.put("outline", cx + dx, y + q, dx < 0 and (q == drop and "snow3" or "snow5") or "snow3") end
    end
    for _, p in ipairs({ { -44, 7 }, { -30, 5 }, { -11, 8 }, { 10, 6 }, { 24, 9 }, { 41, 5 } }) do
      local y = ey + 4 + (ex - math.abs(p[1])) // 2
      for q = 0, p[2] do
        c.put("outline", cx + p[1], y + q, q > p[2] - 3 and "ice3" or "snow5")
        if q < p[2] - 3 then c.put("outline", cx + p[1] + 1, y + q, "snow3") end
      end
    end
    -- Chimney through the cool plane, with a snow cap.
    block(c, cx + 25, ey - 4, 6, 24, function(face, u, v)
      if face == "top" then return "snow5" end
      if v <= 2 then return face == "left" and "snow5" or "snow3" end
      local joint = v % 5 == 0 or (u + v // 5 * 3) % 6 == 0
      if face == "left" then return joint and "ink3" or "ink5" end
      return joint and "ink3" or "ink4"
    end, "outline")
    for k = -8, 8 do
      local y = ey - 3 + (8 - math.abs(k)) // 2
      c.put("outline", cx + 25 + k, y, k < 0 and "snow5" or "snow4")
      c.put("outline", cx + 25 + k, y + 1, "snow3")
    end
  end
end
write("shelter", 192, 160, {
  { "idle_cold", 1000, shelter(false, 0) },
  { "idle_warm", 400, shelter(true, 0) },
  { "idle_warm", 300, shelter(true, 1) },
  { "idle_warm", 400, shelter(true, 2) },
})
shadows("shelter", 192, 160, 96, 122, 50, 1, function(c, cx, cy)
  poly(c, "body", { { cx, cy + 25 }, { cx + 50, cy }, { cx + 82, cy + 8 }, { cx + 88, cy + 14 }, { cx + 44, cy + 36 }, { cx + 30, cy + 36 } }, "ink1")
end)

-- ------------------------------------------------------------------ lantern
local function lantern(on, flick)
  return function(c)
    for y = 62, 104 do
      c.put("body", 62, y, "earth2"); c.put("body", 63, y, "earth2"); c.put("body", 64, y, "earth1"); c.put("body", 65, y, "earth1")
      if y % 9 == 2 then c.put("detail", 62, y, "earth1") end
    end
    for k = 0, 13 do c.put("body", 60 + k, 62, "earth2"); c.put("body", 60 + k, 63, "earth1") end
    for k = 0, 2 do c.put("body", 66 + k, 66 - k, "earth1"); c.put("body", 66 + k, 67 - k, "earth1") end
    for k = 0, 13 do c.put("detail", 60 + k, 61, "snow5") end
    for k = 1, 6 do c.put("detail", 60 + k, 60, "snow5") end
    for x = 59, 68 do c.put("detail", x, 105, "snow5"); if x > 60 and x < 67 then c.put("detail", x, 104, "snow5") end end
    -- Lamp: cap, glass, base.
    for x = 69, 76 do c.put("body", x, 67, "earth1"); c.put("body", x, 79, "earth1") end
    for y = 64, 65 do c.put("body", 72, y, "earth1"); c.put("body", 73, y, "earth1") end
    for x = 70, 75 do c.put("body", x, 66, "earth1"); c.put("body", x, 80, "earth1") end
    for y = 68, 78 do for x = 70, 75 do
      local colour = "earth2"
      if on then
        local core = math.abs(x * 2 - 145) <= 3 and math.abs(y - 73 + flick) <= 3
        colour = core and "amber5" or (math.abs(y - 73) <= 4 and "amber4" or "amber3")
      end
      c.put("body", x, y, colour)
    end end
    for y = 68, 78 do c.put("outline", 69, y, "earth1"); c.put("outline", 76, y, "earth1") end
  end
end
write("lantern", 128, 128, {
  { "idle_off", 1000, lantern(false, 0) },
  { "idle_on", 200, lantern(true, 0) }, { "idle_on", 160, lantern(true, 1) }, { "idle_on", 240, lantern(true, 0) }, { "idle_on", 160, lantern(true, -1) },
})
shadows("lantern", 128, 128, 64, 104, 5, 1, function(c, cx, cy)
  for k = 0, 34 do for q = 0, 1 do c.put("body", cx + k + 2, cy + k // 3 + q, "ink1") end end
  for k = 34, 42 do for q = -2, 3 do c.put("body", cx + k, cy + k // 3 + q, "ink1") end end
end)

-- ------------------------------------------------------------------ ice barrier, five states
local CX, CY, HW, HH = 64, 104, 38, 19
local function wobble(dx, melt)
  if melt == 0 then return 0 end
  local corner = (math.abs(dx) / HW) ^ 4 * 2.4
  return math.floor(melt * (0.6 + 0.35 * math.sin(dx * 0.17 + 0.9) + 0.25 * math.sin(dx * 0.41) + corner) + 0.5)
end
-- Bubbles and cracks belong to the ice, so they move down with it as the top melts.
local CRACKS = { { { -22, 14 }, { -21, 15 }, { -21, 16 }, { -20, 17 }, { -19, 18 }, { -19, 19 }, { -18, 20 }, { -20, 20 }, { -21, 21 }, { -17, 21 }, { -16, 22 } },
  { { 14, 9 }, { 15, 10 }, { 16, 11 }, { 16, 12 }, { 17, 13 }, { 18, 14 }, { 18, 15 }, { 17, 16 }, { 16, 17 }, { 19, 16 }, { 20, 17 }, { 21, 17 } } }
local BUBBLES = { { -30, 24 }, { -27, 29 }, { -12, 12 }, { -9, 16 }, { 8, 22 }, { 11, 27 }, { 27, 12 }, { 30, 18 }, { 24, 30 } }
local function ice(c, height, melt, glint)
  local top, rim = {}, {}
  for x = CX - HW, CX + HW do
    local edge = HH - math.abs(x - CX) // 2
    local h = math.max(2, height - wobble(x - CX, melt))
    top[x], rim[x] = CY - edge - h, CY + edge - h
  end
  for x = CX - HW, CX + HW do
    local left = x < CX
    local bottom = CY + HH - math.abs(x - CX) // 2
    for y = top[x], bottom do
      local colour
      if y <= rim[x] then colour = "ice5"
      else
        colour = left and "ice4" or "ice3"
        local deep = bottom - 6 - ((x - CX + 64) // 6 % 4) * 2
        if y > deep then colour = left and "ice3" or "ice2" end
        -- A pale slab of trapped air, stepped, only on tall ice.
        if height > 26 and left and (x - CX + (y - rim[x]) + 60) % 47 < 8 and y < deep - 4 then colour = "ice5" end
        if height > 26 and not left and (x - CX + (y - rim[x])) % 41 < 6 and y < deep - 4 then colour = "ice4" end
      end
      c.put("body", x, y, colour)
    end
    c.put("outline", x, top[x], x <= CX and "snow5" or "ice4")
    c.put("outline", x, bottom, x < CX - 1 and "ice2" or "ice1")
    if rim[x] < bottom - 1 then c.put("detail", x, rim[x], x <= CX and "snow5" or "ice4") end
  end
  for y = top[CX - HW], CY do c.put("outline", CX - HW, y, "ice2") end
  for y = top[CX + HW], CY do c.put("outline", CX + HW, y, "ice1") end
  if height > 12 then
    for y = rim[CX] + 1, CY + HH - 1 do c.put("detail", CX, y, y % 7 == 3 and "ice3" or "ice5") end
  end
  for k, line in ipairs(CRACKS) do for _, p in ipairs(line) do
    local x, y = CX + p[1], rim[CX + p[1]] + p[2]
    if y < CY + HH - math.abs(p[1]) // 2 - 7 then c.put("detail", x, y, k == 1 and "ice2" or "ice1") end
  end end
  for _, p in ipairs(BUBBLES) do
    local x, y = CX + p[1], rim[CX + p[1]] + p[2]
    if y < CY + HH - math.abs(p[1]) // 2 - 5 then c.put("detail", x, y, "snow5"); c.put("detail", x + 1, y, "snow5"); c.put("detail", x, y + 1, p[1] < 0 and "ice3" or "ice2"); c.put("detail", x + 1, y + 1, p[1] < 0 and "ice3" or "ice2") end
  end
  -- Shimmer: a two pixel streak crosses the lit face in four steps.
  if height > 18 and glint > 0 then
    local gx = CX - 34 + glint * 8
    for k = 0, math.min(17, height - 12) do
      local x = gx + k // 4
      c.put("detail", x, rim[x] + 4 + k, "snow5"); c.put("detail", x + 1, rim[x] + 4 + k, "snow5")
    end
  end
  -- Frost on top: two soft clusters toward the light.
  for _, p in ipairs({ { -18, 1 }, { -17, 1 }, { -16, 1 }, { -15, 1 }, { -14, 1 }, { -17, 2 }, { -16, 2 }, { -15, 2 }, { -5, -5 }, { -4, -5 }, { -3, -5 }, { -2, -5 }, { -4, -4 }, { -3, -4 }, { 13, 2 }, { 14, 2 }, { 15, 2 }, { 14, 3 } }) do
    local x = CX + p[1]
    local y = (top[x] + rim[x]) // 2 + p[2]
    if y > top[x] + 1 and y < rim[x] - 1 then c.put("detail", x, y, p[1] < 5 and "snow5" or "ice4") end
  end
end
-- A puddle with an uneven shore. It never leaves the ground plane.
local function puddle(c, rx, phase, thin)
  if rx < 4 then return end
  local ry = math.min(rx // 2, 18)
  local function wet(dx, dy)
    if math.abs(dy) > ry then return false end
    local w = rx * math.sqrt(math.max(0, 1 - (dy / (ry + 0.5)) ^ 2))
    w = w + ({ 0, 2, 3, 1, -1, -3, -2, 0 })[(dy + ry) // 3 % 8 + 1] * (dx < 0 and 1 or -1)
    return math.abs(dx) <= math.floor(w + 0.5)
  end
  for dy = -ry, ry do for dx = -rx - 4, rx + 4 do
    if wet(dx, dy) then
      local shore = not (wet(dx - 1, dy) and wet(dx + 1, dy) and wet(dx, dy - 1) and wet(dx, dy + 1))
      c.put("body", CX + dx, CY + 4 + dy, shore and (dy > 1 and "ice1" or "ice5") or (thin and "ice4" or "ice3"))
      if not shore and not wet(dx, dy - 3) then c.put("body", CX + dx, CY + 4 + dy, "ice2") end
    end
  end end
  for k, g in ipairs({ { -0.55, -0.25, 8 }, { 0.12, 0.15, 10 }, { -0.2, 0.55, 6 } }) do
    local gx, gy = math.floor(rx * g[1]) + phase * 3, math.floor(ry * g[2])
    for i = 0, math.min(g[3], rx // 4) do if wet(gx + i - 3, gy) and wet(gx + i + 3, gy) then c.put("detail", CX + gx + i, CY + 4 + gy, k == 2 and "snow5" or "ice5") end end
  end
end
local function drops(c, n, phase)
  for k = 1, n do
    local p = ({ { -31, 6 }, { -17, 15 }, { 21, 13 }, { 32, 5 } })[k]
    local y = CY + p[2] - 12 + ((phase * 4 + k * 3) % 10)
    c.put("detail", CX + p[1], y, "snow5"); c.put("detail", CX + p[1], y + 1, "ice5")
  end
end
local function frozen(h, m, g, p, d) return function(c) if p > 0 then puddle(c, p, g % 2, false) end; ice(c, h, m, g); drops(c, d, g) end end
local function pool(r, g, thin) return function(c) puddle(c, r, g, thin) end end
local f = {}
local function clip(name, ms, list) for _, fn in ipairs(list) do f[#f + 1] = { name, ms, fn } end end
clip("idle_solid", 250, { frozen(46, 0, 0, 0, 0), frozen(46, 0, 1, 0, 0), frozen(46, 0, 2, 0, 0), frozen(46, 0, 3, 0, 0) })
f[1][2] = 900
clip("to_melting_early_from_solid", 140, { frozen(45, 1, 0, 40, 1), frozen(42, 3, 1, 42, 2), frozen(39, 4, 0, 43, 3) })
clip("idle_melting_early", 250, { frozen(37, 4, 0, 44, 2), frozen(37, 4, 1, 44, 2) })
clip("to_melting_late_from_melting_early", 140, { frozen(33, 5, 1, 44, 3), frozen(28, 6, 0, 45, 4), frozen(23, 6, 1, 45, 4) })
clip("idle_melting_late", 250, { frozen(20, 6, 0, 46, 2), frozen(20, 6, 1, 46, 2) })
clip("to_liquid_from_melting_late", 140, { frozen(14, 6, 0, 46, 3), frozen(9, 5, 0, 46, 2), frozen(5, 3, 0, 46, 0) })
clip("idle_liquid", 250, { pool(46, 0, false), pool(46, 1, false) })
clip("to_cleared_from_liquid", 160, { pool(42, 0, false), pool(36, 1, true), pool(30, 0, true) })
clip("idle_cleared", 400, { pool(26, 0, true), pool(26, 1, true) })
write("barrier_direct", 128, 128, f)

local sh = {}
for _, st in ipairs({ { 46, "solid" }, { 37, "melting_early" }, { 20, "melting_late" }, { 0, "liquid" }, { 0, "cleared" } }) do
  sh[#sh + 1] = { "idle_" .. st[2], 250, function(c)
    local long = st[1] // 2
    if st[1] > 0 then
      poly(c, "body", { { CX - 2 * HH, CY + 1 }, { CX, CY - HH + 1 }, { CX + 2 * HH, CY + 1 }, { CX + 2 * HH + long, CY + 1 + long // 4 }, { CX + long, CY + HH + 1 + long // 4 }, { CX, CY + HH + 1 } }, "ink1")
    end
    if st[1] == 0 then for dx = -2, 2 do c.put("body", CX + dx, CY + 4, "ink1") end end
  end }
end
write("barrier_direct_shadow", 128, 128, sh)
