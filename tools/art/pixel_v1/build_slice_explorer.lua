-- PX-03 vertical slice: the explorer, idle and walk in eight directions, redrawn at 1 pixel per world unit.
-- Parts are drawn by name for five directions. West-facing directions mirror the parts first; light and
-- outline are applied afterwards, so the light stays at the top left in all eight.
local M = dofile(app.params["root"] .. "/tools/art/pixel_v1/lib.lua")
local MID, TOP, GROUND = 32, 19, 55

-- h hair, s skin, d skin in shade, e eye, m mouth, w eye light. 19 columns, centre column 10.
local HEAD = {
  south = {
    "........hhh........",
    ".......hhhhh.h.....",
    "....hh.hhhhhhhh....",
    "...hhhhhhhhhhhhhh..",
    "..hhhhhhhhhhhhhhh..",
    ".hhhhhhhhhhhhhhhhh.",
    "..hhhhhhhhhhhhhhhhh",
    "hhhhhhhhhhhhhhhhhh.",
    ".hhhhhhhhhhhhhhhhh.",
    "hhhhhhhshhhhhshhhhh",
    ".hhhhhsshhshhsshhh.",
    "..hhhsssshssssshhh.",
    ".hhssseesssseessh..",
    "..hsdseesssseesdsh.",
    "...ssseesssseesss..",
    "....ssssmmmmssss...",
    ".....ssssmmssss....",
    ".......ddddd.......",
  },
  south_east = {
    ".......hhh.........",
    "......hhhhhh.h.....",
    "...hh.hhhhhhhhh....",
    "..hhhhhhhhhhhhhhh..",
    ".hhhhhhhhhhhhhhhh..",
    "hhhhhhhhhhhhhhhhhh.",
    ".hhhhhhhhhhhhhhhhhh",
    "hhhhhhhhhhhhhhhhhh.",
    ".hhhhhhhhhhhhhhhhh.",
    "hhhhhhhhhshhhhshhhh",
    ".hhhhhhhsshhshsshh.",
    "..hhhhhssssssssshh.",
    ".hhhsshsseessseess.",
    "..hhsdssseessseess.",
    "...hhsssseessseess.",
    ".....ssssssmmmms...",
    "......sssssmmss....",
    "........dddd.......",
  },
  east = {
    "........hhhh.......",
    ".....h.hhhhhh......",
    "...hhhhhhhhhhhh....",
    "..hhhhhhhhhhhhhh...",
    ".hhhhhhhhhhhhhhhh..",
    "hhhhhhhhhhhhhhhhh..",
    ".hhhhhhhhhhhhhhhhh.",
    "hhhhhhhhhhhhhhhhhh.",
    ".hhhhhhhhhhhhhhhhh.",
    "hhhhhhhhhhhhhhhhhh.",
    ".hhhhhhhhhhhhhhssh.",
    "hhhhhhhhhhhshhhssh.",
    "..hhhhhhsshhsseess.",
    ".hhhhhhhsdsssseess.",
    "...hhhhhsssssseesss",
    ".....hhhssssssssss.",
    "......hhsssssssmm..",
    "........ddddddd....",
  },
  north_east = {
    "........hhhh.......",
    "......hhhhhhh.h....",
    "...hhhhhhhhhhhhh...",
    "..hhhhhhhhhhhhhhh..",
    ".hhhhhhhhhhhhhhhhh.",
    "hhhhhhhhhhhhhhhhhh.",
    ".hhhhhhhhhhhhhhhhhh",
    "hhhhhhhhhhhhhhhhhh.",
    ".hhhhhhhhhhhhhhhhhh",
    "hhhhhhhhhhhhhhhhhh.",
    ".hhhhhhhhhhhhhhhhh.",
    "hhhhhhhhhhhhhhhssh.",
    ".hhhhhhhhhhhhhhses.",
    "..hhhhhhhhhhsshses.",
    ".hhhhhhhhhhhsdhsss.",
    "...hhhhhhhhhhhsss..",
    "....hhhhhhhhhhss...",
    "......hhhhhhdd.....",
  },
  north = {
    ".........hhh.......",
    ".......hhhhhh.h....",
    "....hh.hhhhhhhh....",
    "...hhhhhhhhhhhhhh..",
    "..hhhhhhhhhhhhhhh..",
    ".hhhhhhhhhhhhhhhhh.",
    "hhhhhhhhhhhhhhhhhh.",
    ".hhhhhhhhhhhhhhhhhh",
    "hhhhhhhhhhhhhhhhhh.",
    ".hhhhhhhhhhhhhhhhhh",
    "hhhhhhhhhhhhhhhhhh.",
    ".hhhhhhhhhhhhhhhhh.",
    "hhhhhhhhhhhhhhhhhh.",
    ".shhhhhhhhhhhhhhhs.",
    ".sdhhhhhhhhhhhhhds.",
    "...hhhhhhhhhhhhhh..",
    "....hhhhhhhhhhh....",
    ".......hhhhh.......",
  },
}
-- Strands: dark lines between clumps of hair, in head columns and rows.
local STRANDS = {
  south = { { 6, 6 }, { 6, 7 }, { 5, 8 }, { 11, 5 }, { 11, 6 }, { 12, 7 }, { 12, 8 }, { 15, 6 }, { 16, 7 }, { 16, 8 }, { 8, 2 }, { 3, 9 }, { 3, 10 } },
  south_east = { { 5, 6 }, { 5, 7 }, { 4, 8 }, { 3, 9 }, { 10, 5 }, { 10, 6 }, { 11, 7 }, { 11, 8 }, { 15, 6 }, { 16, 7 }, { 5, 10 }, { 4, 11 }, { 7, 2 } },
  east = { { 4, 7 }, { 4, 8 }, { 5, 9 }, { 9, 5 }, { 9, 6 }, { 10, 7 }, { 10, 8 }, { 11, 9 }, { 14, 6 }, { 15, 7 }, { 5, 12 }, { 6, 13 }, { 7, 11 }, { 7, 2 } },
  north_east = { { 4, 7 }, { 4, 8 }, { 5, 9 }, { 9, 5 }, { 9, 6 }, { 10, 7 }, { 10, 8 }, { 14, 6 }, { 15, 7 }, { 6, 12 }, { 7, 13 }, { 8, 14 }, { 11, 11 }, { 12, 12 }, { 4, 13 } },
  north = { { 5, 7 }, { 5, 8 }, { 6, 9 }, { 10, 5 }, { 10, 6 }, { 11, 7 }, { 11, 8 }, { 14, 8 }, { 14, 9 }, { 7, 12 }, { 8, 13 }, { 8, 14 }, { 12, 12 }, { 11, 13 }, { 4, 12 }, { 15, 12 } },
}
-- Loose tips that break the outline of the hair, and the notches between them.
local TIPS = { { 0, 6 }, { 1, 6 }, { -1, 7 }, { 0, 7 }, { 0, 9 }, { -1, 10 }, { 0, 10 }, { 1, 3 }, { 1, 2 }, { 2, 2 }, { 18, 5 }, { 18, 6 }, { 19, 6 }, { 18, 8 }, { 18, 9 }, { 19, 9 }, { 17, 3 }, { 17, 2 }, { 4, 1 }, { 5, 1 }, { 11, 0 }, { 12, 0 }, { 12, 1 } }
local NOTCH = { { 0, 5 }, { 0, 8 }, { 18, 7 }, { 0, 4 }, { 1, 4 }, { 8, 0 } }
-- Light on the hair, always on the left whatever the direction.
local SHINE = { { 4, 4 }, { 5, 4 }, { 6, 4 }, { 3, 5 }, { 4, 5 }, { 7, 3 }, { 8, 3 }, { 9, 4 }, { 3, 6 }, { 6, 5 }, { 11, 3 }, { 12, 3 } }
local CLUMP = { { 3, 4 }, { 7, 4 }, { 8, 4 }, { 5, 5 }, { 7, 5 }, { 8, 5 }, { 4, 6 }, { 5, 6 }, { 7, 6 }, { 2, 7 }, { 3, 7 }, { 4, 7 }, { 2, 8 }, { 3, 8 }, { 6, 8 }, { 7, 7 }, { 9, 3 }, { 10, 3 }, { 10, 4 }, { 12, 4 }, { 13, 4 }, { 12, 5 }, { 13, 5 }, { 9, 7 }, { 9, 8 }, { 13, 7 }, { 13, 8 }, { 14, 5 }, { 15, 6 }, { 3, 10 }, { 4, 10 }, { 4, 11 }, { 6, 11 }, { 6, 12 }, { 9, 10 }, { 9, 11 }, { 12, 10 } }

local function canvas() return { g = {} } end
local function set(c, x, y, v) c.g[y * 64 + x] = v end
local function get(c, x, y) return c.g[y * 64 + x] end
local function fill(c, x, y, w, h, v) for j = y, y + h - 1 do for i = x, x + w - 1 do set(c, i, j, v) end end end

local function head(c, dir, dy, blink)
  for r, row in ipairs(HEAD[dir]) do

    assert(#row == 19, dir .. " row " .. r .. " has " .. #row)
    for k = 1, 19 do
      local v = row:sub(k, k)
      if v ~= "." then
        if blink and v == "e" then v = (r == 14) and "e" or "s" end
        set(c, MID - 10 + k, TOP + dy + r - 1, v)
      end
    end
  end
  for _, p in ipairs(NOTCH) do
    local x, y = MID - 9 + p[1], TOP + dy + p[2]
    if get(c, x, y) == "h" then c.g[y * 64 + x] = nil end
  end
  for _, p in ipairs(TIPS) do
    local x, y = MID - 9 + p[1], TOP + dy + p[2]
    local shift = dir == "east" and p[1] > 12 and -1 or 0
    if not get(c, x + shift, y) then set(c, x + shift, y, "h") end
  end
  -- Close pinholes: an empty pixel with hair on three sides is hair.
  for r = 0, 12 do for k = -1, 19 do
    local x, y = MID - 9 + k, TOP + dy + r
    if not get(c, x, y) then
      local n = 0
      for _, e in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do if get(c, x + e[1], y + e[2]) == "h" then n = n + 1 end end
      if n >= 3 then set(c, x, y, "h") end
    end
  end end
  for _, p in ipairs(STRANDS[dir]) do
    local x, y = MID - 10 + p[1], TOP + dy + p[2]
    if get(c, x, y) == "h" then set(c, x, y, "k") end
  end
end
-- One leg seen from the front or the back: hip column, width, sideways and lifted foot.
local function leg(c, x, w, dx, lift, far)
  local bottom = GROUND - lift
  for y = 46, bottom do
    local boot = y > bottom - 5
    local s = y >= 49 and dx or (y == 48 and dx // 2 or 0)
    local wide = boot and w + 1 or w
    for i = 0, wide - 1 do
      local v = boot and (y == bottom - 4 and "Q" or "q") or "p"
      if far then v = ({ Q = "r", q = "r", p = "P" })[v] end
      set(c, x + s + i - (boot and (x < MID and 1 or 0) or 0), y, v)
    end
  end
end
-- One leg seen from the side.
local function stride(c, hip, footx, lift, far)
  local bottom = GROUND - lift
  for y = 46, bottom do
    local t = (y - 46) / (bottom - 46)
    local x = math.floor(hip + (footx - hip) * t + 0.5)
    local boot = y > bottom - 5
    for i = 0, 4 do
      local v = boot and (y == bottom - 4 and "Q" or "q") or "p"
      if far then v = ({ Q = "r", q = "r", p = "P" })[v] end
      set(c, x - 2 + i, y, v)
    end
    if y >= bottom - 1 then for i = 3, 4 do set(c, x + i, y, far and "r" or "q") end end
  end
end
-- An arm hanging from a shoulder: green shoulder, cream roll, hand.
local function arm(c, x, y, dx, dy, w, right)
  w = w or 3
  fill(c, right and x or x + 1, y, w - 1, 3, "g")
  for j = 0, 1 do fill(c, x + dx, y + 3 + j + math.min(dy, 0), w, 1, "c") end
  if dy > 0 then fill(c, x + dx // 2, y + 3, w, 1, "g") end
  for j = 0, 2 do fill(c, x + dx, y + 5 + j + dy - (dy > 0 and 1 or 0), w, 1, "s") end
  if dy > 0 then fill(c, x + dx, y + 4, w, 2, "c") end
end

local function body_front(c, dir, p)
  local dy, back = p.bob, dir == "north" or dir == "north_east"
  local skew = (dir == "south_east" or dir == "north_east") and 1 or 0
  local L, R = p.legs[1], p.legs[2]
  local first, second = { 28, 4, L }, { 33, 4, R }
  if R.far then first, second = second, first end
  if skew == 1 and p.walk then
    local far, near = p.legs[1], p.legs[2]
    stride(c, 33, 33 + far.dx, far.lift, true)
    stride(c, 30, 30 + near.dx, near.lift, false)
  else
    leg(c, first[1] - skew, first[2], first[3].dx or 0, first[3].lift or 0, first[3].far)
    leg(c, second[1] - skew, second[2], second[3].dx or 0, second[3].lift or 0, second[3].far)
  end
  -- Far arm first when the body turns.
  if skew == 1 then arm(c, 36, 38 + dy, p.arms[2].dx or 0, p.arms[2].dy or 0, 2, true) end
  fill(c, 28 - skew, 37 + dy, 9, 9, "g")
  fill(c, 27 - skew, 46 + dy, 11 - skew, 1, "g")
  fill(c, 28 - skew, 44 + dy, 9, 1, "b")
  if not back then
    local bx = 31 + skew
    fill(c, bx, 43 + dy, 3, 3, "B"); set(c, bx + 1, 44 + dy, "b")
    set(c, 32 + skew, 40 + dy, "c"); set(c, 32 + skew, 41 + dy, "G")
  else
    for y = 40, 43 do set(c, 32, y + dy, "G") end
  end
  arm(c, 25 - skew, 38 + dy, p.arms[1].dx or 0, p.arms[1].dy or 0)
  for y = 39, 43 do set(c, 28 - skew, y + dy, "G") end
  if skew == 0 then
    arm(c, 37, 38 + dy, p.arms[2].dx or 0, p.arms[2].dy or 0, 3, true)
    for y = 39, 43 do set(c, 36, y + dy, "G") end
  end
  -- Scarf.
  fill(c, 27, 36 + dy, 11 - skew, 1, "y"); fill(c, 28, 37 + dy, 9, 1, "y")
  if back then
    local kx = dir == "north" and 32 or 30
    fill(c, kx - 1, 37 + dy, 3, 2, "o")
    for k = 0, 3 do set(c, kx - 2 - k // 2, 38 + k + dy, "y"); set(c, kx - 1 - k // 2, 38 + k + dy, "y"); set(c, kx + 2 + k // 2, 38 + k + dy, "y"); set(c, kx + 1 + k // 2, 38 + k + dy, k > 2 and "o" or "y") end
  else
    local cx = 32 + skew
    fill(c, cx - 3, 38 + dy, 7, 1, "y"); fill(c, cx - 2, 39 + dy, 4, 1, "y"); set(c, cx, 40 + dy, "o")
    set(c, cx - 3, 38 + dy, "o"); set(c, cx + 3, 38 + dy, "o"); set(c, cx - 1, 37 + dy, "o")
    if skew == 1 then fill(c, 24, 37 + dy, 3, 2, "y"); set(c, 24, 39 + dy, "o"); set(c, 25, 39 + dy, "y") end
  end
end
local function body_side(c, p)
  local dy = p.bob
  local far, near = p.legs[1], p.legs[2]
  stride(c, 32, 32 + (far.dx or 0), far.lift or 0, true)
  -- Far hand shows in front or behind.
  local fa = p.arms[1].dx or 0
  if fa ~= 0 then fill(c, 31 + fa, 42 + dy, 3, 2, "c"); fill(c, 31 + fa + (fa > 0 and 1 or -1), 44 + dy - (fa > 0 and 1 or 0), 3, 2, "s") end
  stride(c, 32, 32 + (near.dx or 0), near.lift or 0, false)
  fill(c, 28, 37 + dy, 8, 9, "g"); fill(c, 27, 46 + dy, 10, 1, "g"); fill(c, 28, 44 + dy, 8, 1, "b")
  set(c, 35, 44 + dy, "B"); set(c, 35, 43 + dy, "B")
  -- Near arm.
  local a = p.arms[2].dx or 0
  fill(c, 31, 38 + dy, 3, 3, "g")
  fill(c, 31 + a // 2, 41 + dy, 3, 2, "c")
  fill(c, 31 + a, 43 + dy - (a ~= 0 and 0 or 0), 3, 3, "s")
  for y = 38, 41 do set(c, 30, y + dy, "G") end
  for y = 39, 41 do set(c, 34, y + dy, "G") end
  fill(c, 28, 36 + dy, 8, 1, "y"); fill(c, 29, 37 + dy, 7, 1, "y"); fill(c, 34, 38 + dy, 2, 1, "y")
  local tail = p.tail or 0
  fill(c, 26, 37 + dy, 3, 2, "o"); fill(c, 23, 36 + dy + tail, 3, 2, "y"); fill(c, 24, 38 + dy + tail, 2, 1, "y"); set(c, 23, 38 + dy + tail, "o")
end

-- Light, outline and colour.
local BASE = { h = "ink1", k = "ink1", s = "skin5", d = "skin4", e = "ink1", m = "skin1", y = "amber4", o = "skin2", g = "olive1", G = "ink2",
  c = "ink8", b = "skin1", B = "amber4", p = "earth1", P = "earth1", q = "skin1", Q = "skin2", r = "skin1" }
local EDGE = { h = "ink1", k = "ink1", s = "skin2", d = "skin2", y = "skin2", o = "skin2", g = "ink2", G = "ink2", c = "skin2", p = "ink1", P = "ink1",
  q = "ink1", Q = "skin1", r = "ink1", e = "ink1", m = "skin1", b = "skin1", B = "skin2" }
local LIT = { g = "olive1", s = "skin4", y = "amber4", c = "ink8", Q = "skin2", q = "skin1" }
local function render(c, out, mirror, dy)
  local g = c.g
  if mirror then
    local m = {}
    for k, v in pairs(g) do local x, y = k % 64, k // 64; m[y * 64 + 2 * MID - x] = v end
    g = m
  end
  local function at(x, y) return g[y * 64 + x] end
  for k, v in pairs(g) do
    local x, y = k % 64, k // 64
    local colour = BASE[v]
    local right, below = not at(x + 1, y), not at(x, y + 1)
    local left, above = not at(x - 1, y), not at(x, y - 1)
    local layer = "body"
    if right or below then colour, layer = EDGE[v], "outline"
    elseif left or above then colour, layer = LIT[v] or EDGE[v], "outline" end
    out.put(layer, x, y, colour)
  end
  for _, p in ipairs(CLUMP) do
    local x, y = MID - 10 + p[1], TOP + dy + p[2]
    if at(x, y) == "h" and at(x - 1, y) and at(x + 1, y) and at(x, y - 1) and at(x, y + 1) then out.put("detail", x, y, "ink2") end
  end
  for _, p in ipairs(SHINE) do
    local x, y = MID - 10 + p[1], TOP + dy + p[2]
    if at(x, y) == "h" and at(x - 1, y) and at(x, y - 1) and at(x, y + 1) then out.put("detail", x, y, "ink3") end
  end
  -- Boots: one lit column on the left.
  for k, v in pairs(g) do
    local x, y = k % 64, k // 64
    if v == "q" and not (at(x - 1, y) == "q") and at(x, y + 1) then out.put("detail", x + 1, y, "skin2") end
  end
end

local function pose(bob, l1, l2, a1, a2, tail) return { bob = bob, legs = { l1, l2 }, arms = { a1, a2 }, tail = tail } end
local STAND = pose(0, {}, {}, {}, {})
-- Four frames: contact, passing, contact, passing. Arms swing against the legs. The body rises when passing.
local WALK = {
  front = {
    pose(0, { lift = 0 }, { lift = 3, far = true }, { dx = 1, dy = -1 }, { dx = 0, dy = 1 }),
    pose(-1, { lift = 0 }, { lift = 1 }, {}, {}),
    pose(0, { lift = 3, far = true }, { lift = 0 }, { dx = 0, dy = 1 }, { dx = -1, dy = -1 }),
    pose(-1, { lift = 1 }, { lift = 0 }, {}, {}),
  },
  toward = {
    pose(0, { dx = 3, lift = 0 }, { dx = -4, lift = 3 }, { dx = 1, dy = -1 }, { dx = 0, dy = 0 }),
    pose(-1, { dx = 0, lift = 0 }, { dx = 1, lift = 2 }, {}, {}),
    pose(0, { dx = -4, lift = 3 }, { dx = 4, lift = 0 }, { dx = 0, dy = 0 }, { dx = 0, dy = -1 }),
    pose(-1, { dx = 1, lift = 2 }, { dx = 0, lift = 0 }, {}, {}),
  },
  away = {
    pose(0, { dx = 3, lift = 3 }, { dx = -3, lift = 0 }, { dx = 1, dy = -1 }, { dx = 0, dy = 0 }),
    pose(-1, { dx = 0, lift = 1 }, { dx = 0, lift = 0 }, {}, {}),
    pose(0, { dx = -3, lift = 0 }, { dx = 4, lift = 3 }, { dx = 0, dy = 0 }, { dx = 0, dy = -1 }),
    pose(-1, { dx = 0, lift = 0 }, { dx = 0, lift = 1 }, {}, {}),
  },
  side = {
    pose(0, { dx = 6, lift = 0 }, { dx = -6, lift = 1 }, { dx = -5 }, { dx = 5 }, 1),
    pose(-1, { dx = -1, lift = 0 }, { dx = 1, lift = 2 }, {}, {}, 0),
    pose(0, { dx = -6, lift = 1 }, { dx = 6, lift = 0 }, { dx = 5 }, { dx = -5 }, 1),
    pose(-1, { dx = 1, lift = 2 }, { dx = -1, lift = 0 }, {}, {}, 0),
  },
}
local function figure(dir, p, nod, blink)
  local c = canvas()
  if dir == "east" then body_side(c, p) else body_front(c, dir, p) end
  head(c, dir, p.bob + nod, blink)
  return c
end

local DIRS = { { "south", "south" }, { "south_east", "south_east" }, { "east", "east" }, { "north_east", "north_east" }, { "north", "north" },
  { "north_west", "north_east", true }, { "west", "east", true }, { "south_west", "south_east", true } }
local frames = {}
for _, d in ipairs(DIRS) do
  for _, q in ipairs({ { 0, false, 600 }, { 1, false, 420 }, { 0, false, 500 }, { 0, true, 120 } }) do frames[#frames + 1] = { "idle_" .. d[1], d[2], STAND, q[1], q[2], q[3], d[3] } end
end
for _, d in ipairs(DIRS) do
  local set_of = d[2] == "east" and WALK.side or ((d[2] == "south" or d[2] == "north") and WALK.front or (d[2] == "south_east" and WALK.toward or WALK.away))
  for _, p in ipairs(set_of) do p.walk = true; frames[#frames + 1] = { "walk_" .. d[1], d[2], p, 0, false, 120, d[3] } end
end
local s = M.sprite(64, 64, #frames)
for i, f in ipairs(frames) do
  local c = M.canvas(s)
  render(figure(f[2], f[3], f[4], f[5]), c, f[7], f[3].bob + f[4])
  c.commit(i, f[6])
end
for i = 1, #frames, 4 do M.tag(s, i, i + 3, frames[i][1]) end
M.save(s, "slice/explorer.aseprite")

local sh = M.sprite(64, 64, 1)
local c = M.canvas(sh)
for dy = -3, 3 do
  local w = ({ 4, 7, 9, 10, 9, 7, 4 })[dy + 4]
  for dx = -w, w do c.put("body", MID + dx, GROUND + dy, "ink1") end
end
c.commit(1, 250)
M.tag(sh, 1, 1, "idle_contact")
M.save(sh, "slice/explorer_shadow.aseprite")
