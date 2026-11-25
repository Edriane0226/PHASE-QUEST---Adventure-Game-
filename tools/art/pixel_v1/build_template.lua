-- Empty starting files: prop, large prop, character and shadow.
local M = dofile(app.params["root"] .. "/tools/art/pixel_v1/lib.lua")
local function make(rel, w, h, tags)
  local n = 0
  for _, t in ipairs(tags) do n = n + t[2] end
  local s = M.sprite(w, h, n)
  local f = 1
  for _, t in ipairs(tags) do
    for k = f, f + t[2] - 1 do s.frames[k].duration = t[3] / 1000 end
    M.tag(s, f, f + t[2] - 1, t[1])
    f = f + t[2]
  end
  s.gridBounds = Rectangle(0, 0, 40, 20)
  M.save(s, rel)
end
local prop = { { "idle_state", 2, 250 }, { "to_next_from_state", 3, 120 }, { "idle_next", 2, 250 }, { "use", 3, 100 }, { "wrong", 3, 100 }, { "solved", 4, 120 } }
make("_template/prop_128.aseprite", 128, 128, prop)
make("_template/prop_192.aseprite", 192, 192, prop)
make("_template/character_64.aseprite", 64, 64, { { "idle_south", 4, 250 }, { "walk_south", 4, 120 }, { "run_south", 4, 90 } })
make("_template/shadow_128.aseprite", 128, 128, { { "idle_state", 1, 250 }, { "idle_next", 1, 250 } })
