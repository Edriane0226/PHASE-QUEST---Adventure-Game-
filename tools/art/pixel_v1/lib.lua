-- Shared helpers for the batch scripts. Run through tools/art/pixel_v1/build.ps1.
local M = {}
M.root = app.params["root"]
assert(M.root and #M.root > 0, "Pass --script-param root=<project folder with forward slashes>")
M.tools = M.root .. "/tools/art/pixel_v1"
M.src = M.root .. "/art_src/pixel_v1"
M.data = dofile(M.tools .. "/palette.lua")

-- Colour names (snow4) to palette indices.
M.id, M.hex = {}, {}
do
  local i = 0
  for _, g in ipairs(M.data.groups) do
    for n, hex in ipairs(g) do
      i = i + 1
      M.id[g.name .. n] = i
      M.hex[i] = hex
    end
  end
  M.count = i
end

function M.rgb(hex)
  return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

function M.palette()
  local p = Palette(M.count + 1)
  p:setColor(0, Color { r = 0, g = 0, b = 0, a = 0 })
  for i = 1, M.count do
    local r, g, b = M.rgb(M.hex[i])
    p:setColor(i, Color { r = r, g = g, b = b, a = 255 })
  end
  return p
end

-- Bottom to top. Shadows are a separate sprite, never a layer here.
M.layers = { "body", "detail", "outline" }

function M.sprite(w, h, frames)
  local s = Sprite(w, h, ColorMode.INDEXED)
  s:setPalette(M.palette())
  s.transparentColor = 0
  s.layers[1].name = M.layers[1]
  for i = 2, #M.layers do s:newLayer().name = M.layers[i] end
  for f = 2, frames do s:newEmptyFrame(f) end
  return s
end

-- A drawing surface per layer. put() ignores pixels outside the cell.
function M.canvas(spr)
  local c = { w = spr.width, h = spr.height, img = {} }
  for i, name in ipairs(M.layers) do
    local im = Image(spr.width, spr.height, ColorMode.INDEXED)
    im:clear(0)
    c.img[name] = im
  end
  function c.put(layer, x, y, colour)
    if x < 0 or y < 0 or x >= c.w or y >= c.h then return end
    c.img[layer]:drawPixel(x, y, colour and assert(M.id[colour], colour) or 0)
  end
  function c.commit(frame, ms)
    for i, name in ipairs(M.layers) do
      if not c.img[name]:isEmpty() then spr:newCel(spr.layers[i], frame, c.img[name], Point(0, 0)) end
    end
    spr.frames[frame].duration = ms / 1000
  end
  return c
end

function M.tag(spr, from, to, name)
  local t = spr:newTag(from, to)
  t.name = name
end

-- Repeatable noise, so a rebuild gives the same file.
function M.rng(seed)
  local s = seed
  return function(n)
    s = (s * 1103515245 + 12345) & 0x7fffffff
    return (s >> 8) % n
  end
end

-- Saving. A file is replaced only when it is still exactly what a script wrote.
local ledger_path = M.src .. "/generated.json"
local function read(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("a")
  f:close()
  return s
end
local function fingerprint(path)
  local s = read(path)
  if not s then return nil end
  local h = 0xcbf29ce484222325
  for i = 1, #s do h = (h ~ s:byte(i)) * 0x100000001b3 end
  return string.format("%016x-%d", h, #s)
end

function M.save(spr, rel)
  local ledger = {}
  local text = read(ledger_path)
  if text then
    for k, v in text:gmatch('"([^"]+)"%s*:%s*"([^"]+)"') do ledger[k] = v end
  end
  local full = M.src .. "/" .. rel
  local now = fingerprint(full)
  if now and ledger[rel] ~= now then
    print("SKIP hand-edited or unknown: " .. rel)
    spr:close()
    return false
  end
  app.fs.makeAllDirectories(app.fs.filePath(full))
  spr:saveAs(full)
  spr:close()
  ledger[rel] = fingerprint(full)
  local keys, lines = {}, {}
  for k in pairs(ledger) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do lines[#lines + 1] = string.format('  "%s": "%s"', k, ledger[k]) end
  local f = assert(io.open(ledger_path, "wb"))
  f:write("{\n" .. table.concat(lines, ",\n") .. "\n}\n")
  f:close()
  print("WROTE " .. rel)
  return true
end

return M
