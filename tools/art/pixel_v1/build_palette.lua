-- Writes the .gpl, the palette strip, the Aseprite palette and the review sheet.
local M = dofile(app.params["root"] .. "/tools/art/pixel_v1/lib.lua")
local out = M.src .. "/palette"
app.fs.makeAllDirectories(out)

local names = {}
for _, g in ipairs(M.data.groups) do for n = 1, #g do names[#names + 1] = g.name .. n end end
local f = assert(io.open(out .. "/phase_quest_master.gpl", "wb"))
f:write("GIMP Palette\nName: Phase Quest master v" .. M.data.version .. "\nColumns: 5\n# " .. M.count .. " colours. Index 0 (transparent) is not listed.\n")
for i, name in ipairs(names) do
  local r, g, b = M.rgb(M.hex[i])
  f:write(string.format("%3d %3d %3d\t%s\n", r, g, b, name))
end
f:close()

-- One pixel per colour, in index order.
local strip = Image(M.count, 1, ColorMode.RGB)
for i = 1, M.count do
  local r, g, b = M.rgb(M.hex[i])
  strip:drawPixel(i - 1, 0, app.pixelColor.rgba(r, g, b, 255))
end
strip:saveAs(out .. "/phase_quest_master.png")
M.palette():saveAs(out .. "/phase_quest_master.aseprite-palette.png")

-- Zone subsets and meaning pairs for the validator.
local function expand(list)
  local r = {}
  for _, item in ipairs(list) do
    local n, a, b = item:match("^(%a+)(%d)%-(%d)$")
    for k = tonumber(a), tonumber(b) do r[#r + 1] = '"' .. n .. k .. '"' end
  end
  return "[" .. table.concat(r, ",") .. "]"
end
local s, keys = {}, {}
for k in pairs(M.data.subsets) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do s[#s + 1] = string.format('    "%s": %s', k, expand(M.data.subsets[k])) end
local m = {}
for _, p in ipairs(M.data.meaning) do m[#m + 1] = string.format('    ["%s","%s","%s"]', p[1], p[2], p[3]) end
f = assert(io.open(out .. "/phase_quest_master.json", "wb"))
f:write('{\n  "version": ' .. M.data.version .. ',\n  "subsets": {\n' .. table.concat(s, ",\n") .. '\n  },\n  "meaning": [\n' .. table.concat(m, ",\n") .. "\n  ]\n}\n")
f:close()

-- Review sheet. Not a game asset, so it may use any colour and size.
local FONT = { A="757555", B="656560", C="344430", D="655560", E="746470", F="746440", G="345530", H="557555", I="722270", K="556655", L="444470", M="577555", N="655555", O="755570", P="656440", Q="755710", R="656550", S="346160", T="722220", U="555570", V="555520", W="555775", X="552550", Y="552220", Z="712470", ["0"]="755570", ["1"]="262270", ["2"]="617470", ["3"]="617170", ["4"]="557110", ["5"]="746160", ["6"]="347570", ["7"]="711220", ["8"]="757570", ["9"]="757160" }
local px = app.pixelColor.rgba
local W, H = 300, 312
local sheet = Image(W, H, ColorMode.RGB)
sheet:clear(px(38, 40, 50, 255))
local function rect(x, y, w, h, c) for yy = y, y + h - 1 do for xx = x, x + w - 1 do sheet:drawPixel(xx, yy, c) end end end
local function text(x, y, str, c)
  for ch in str:upper():gmatch(".") do
    local g = FONT[ch]
    if g then
      for row = 1, 5 do
        local bits = tonumber(g:sub(row, row))
        for col = 0, 2 do if bits & (4 >> col) ~= 0 then sheet:drawPixel(x + col, y + row - 1, c) end end
      end
    end
    x = x + 4
  end
end
local light = px(233, 231, 219, 255)
local function lin(v) v = v / 255; return v <= 0.04045 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
local function srgb(v) v = math.max(0, math.min(1, v)); v = v <= 0.0031308 and v * 12.92 or 1.055 * v ^ (1 / 2.4) - 0.055; return math.floor(v * 255 + 0.5) end
local CVD = {
  { "PROTAN", { 0.152286, 1.052583, -0.204868, 0.114503, 0.786281, 0.099216, -0.003882, -0.048116, 1.051998 } },
  { "DEUTAN", { 0.367322, 0.860646, -0.227968, 0.280085, 0.672501, 0.047413, -0.011820, 0.042940, 0.968881 } },
  { "TRITAN", { 1.255528, -0.076749, -0.178779, -0.078411, 0.930809, 0.147602, 0.004733, 0.691367, 0.303900 } },
}
local function seen(r, g, b, k)
  local R, G, B = lin(r), lin(g), lin(b)
  return srgb(k[1] * R + k[2] * G + k[3] * B), srgb(k[4] * R + k[5] * G + k[6] * B), srgb(k[7] * R + k[8] * G + k[9] * B)
end
text(8, 6, "PHASE QUEST MASTER V" .. M.data.version, light)
local y = 18
for _, g in ipairs(M.data.groups) do
  text(8, y + 6, g.name, light)
  for n, hex in ipairs(g) do
    local r, gg, b = M.rgb(hex)
    local x = 40 + (n - 1) * 32
    rect(x, y, 31, 16, px(r, gg, b, 255))
    text(x + 1, y + 10, hex, (r * 3 + gg * 6 + b) > 1300 and px(20, 20, 31, 255) or light)
  end
  y = y + 18
end
y = y + 4
for _, view in ipairs(CVD) do
  text(8, y + 4, view[1], light)
  for i = 1, M.count do
    local r, g, b = M.rgb(M.hex[i])
    local a, c, d = seen(r, g, b, view[2])
    rect(40 + (i - 1) * 5, y, 5, 12, px(a, c, d, 255))
  end
  y = y + 14
end
y = y + 4
text(8, y, "MEANING PAIRS", light)
y = y + 8
for k, p in ipairs(M.data.meaning) do
  local col, row = (k - 1) % 2, (k - 1) // 2
  local x, yy = 8 + col * 146, y + row * 7
  for j = 2, 3 do
    local r, g, b = M.rgb(M.hex[M.id[p[j]]])
    rect(x + (j - 2) * 12, yy, 11, 6, px(r, g, b, 255))
  end
  text(x + 27, yy, (p[1]:gsub(" / ", " ")), light)
end
local big = Image(W * 4, H * 4, ColorMode.RGB)
for yy = 0, H * 4 - 1 do for xx = 0, W * 4 - 1 do big:drawPixel(xx, yy, sheet:getPixel(xx // 4, yy // 4)) end end
big:saveAs(app.params["review"] .. "/palette-sheet.png")
print("PALETTE colours=" .. M.count)
