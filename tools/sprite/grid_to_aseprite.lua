-- Builds an .aseprite (frames, tags, one layer) from a text spec, then exports its packed PNG sheet
-- and an 8x preview. Run through `python tools/sprite/sprite.py build <spec.txt> <out.aseprite>`.
--
-- Spec: "key = rrggbb" palette lines (Endesga 32 or the sprite's own ramps), "size = WxH", then "---";
-- after it, "@TAG ms" starts an animation tag (GlobalAnimationNames: IDLE, WALK, ATTACK, START_ATTACK,
-- STOP_ATTACK, DEATH) whose frames last ms each; every frame is H rows of W chars, frames are separated by
-- blank lines; "." and unknown keys are transparent. "# ..." lines are comments.

local SEPARATOR = "---"
local PREVIEW_SCALE = 8
local PREVIEW_GAP = 2
local GRASS = Color{ r = 0x43, g = 0x91, b = 0x48 }
local SAND = Color{ r = 0xe4, g = 0xa6, b = 0x72 }

local spec_path = app.params.spec
local out_path = app.params.out
local reference_path = app.params.reference

local function fail(message)
  print("ERROR: " .. message)
  os.exit(1)
end

local function parse(text)
  local palette, frames, tags = {}, {}, {}
  local width, height
  local in_grid, current, tag = false, nil, nil

  local function close_frame()
    if current and #current > 0 then
      if #current ~= height then fail(string.format("frame %d has %d rows, expected %d", #frames + 1, #current, height)) end
      frames[#frames + 1] = { rows = current, ms = tag and tag.ms or 100 }
      if tag then tag.to = #frames end
    end
    current = nil
  end

  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    line = line:gsub("\r", ""):gsub("%s+$", "")
    if line:match("^#") then
      -- comment
    elseif not in_grid then
      if line == SEPARATOR then
        in_grid = true
      else
        local w, h = line:match("^size%s*=%s*(%d+)x(%d+)$")
        local key, hex = line:match("^(%S)%s*=%s*#?(%x%x%x%x%x%x)$")
        if w then width, height = tonumber(w), tonumber(h)
        elseif key then palette[key] = Color{ r = tonumber(hex:sub(1, 2), 16), g = tonumber(hex:sub(3, 4), 16), b = tonumber(hex:sub(5, 6), 16) } end
      end
    else
      local name, ms = line:match("^@(%S+)%s*(%d*)$")
      if name then
        close_frame()
        tag = { name = name, from = #frames + 1, to = #frames, ms = tonumber(ms) or 100 }
        tags[#tags + 1] = tag
      elseif line == "" then
        close_frame()
      else
        if not width then fail("size = WxH is missing") end
        if #line > width then fail(string.format("row wider than %d: %s", width, line)) end
        current = current or {}
        current[#current + 1] = line
      end
    end
  end
  close_frame()
  if #frames == 0 then fail("no frames") end
  return palette, frames, tags, width, height
end

local file = io.open(spec_path, "r")
if not file then fail("cannot read " .. spec_path) end
local palette, frames, tags, width, height = parse(file:read("a"))
file:close()

local sprite = Sprite(width, height, ColorMode.RGB)
for i = 2, #frames do sprite:newEmptyFrame() end
local layer = sprite.layers[1]
layer.name = "body"

for i, frame in ipairs(frames) do
  local image = Image(width, height, ColorMode.RGB)
  for y, row in ipairs(frame.rows) do
    for x = 1, #row do
      local color = palette[row:sub(x, x)]
      if color then image:drawPixel(x - 1, y - 1, color) end
    end
  end
  sprite:newCel(layer, i, image, Point(0, 0))
  sprite.frames[i].duration = frame.ms / 1000
end

for _, t in ipairs(tags) do
  if t.to >= t.from then
    local tag = sprite:newTag(t.from, t.to)
    tag.name = t.name
  end
end

-- palette: the spec's colours only, so the Aseprite file opens with them ready
local keys = {}
for key, _ in pairs(palette) do keys[#keys + 1] = key end
table.sort(keys)
local pal = Palette(#keys + 1)
pal:setColor(0, Color{ r = 0, g = 0, b = 0, a = 0 })
for i, key in ipairs(keys) do pal:setColor(i, palette[key]) end
sprite:setPalette(pal)

sprite:saveAs(out_path)

-- packed sheet like the existing ones (ceil(sqrt(n)) columns, rows), next to the .aseprite
local sheet_path = out_path:gsub("%.aseprite$", ".png")
local columns = math.ceil(math.sqrt(#frames))
local rows = math.ceil(#frames / columns)
local sheet = Image(columns * width, rows * height, ColorMode.RGB)
for i = 1, #frames do
  local cell = Image(width, height, ColorMode.RGB)
  cell:drawSprite(sprite, i)
  sheet:drawImage(cell, Point(((i - 1) % columns) * width, ((i - 1) // columns) * height))
end
sheet:saveAs(sheet_path)

-- preview: every frame on grass (top) and sand (bottom), plus the reference's first frame at the end
local reference
if reference_path and reference_path ~= "" then
  local ref_sprite = app.open(reference_path)
  if ref_sprite then
    reference = Image(ref_sprite.width, ref_sprite.height, ColorMode.RGB)
    reference:drawSprite(ref_sprite, 1)
    ref_sprite:close()
  end
end

local cell_w = math.max(width, reference and reference.width or 0) + PREVIEW_GAP
local cell_h = math.max(height, reference and reference.height or 0) + PREVIEW_GAP
local count = #frames + (reference and 1 or 0)
local preview = Image(count * cell_w, 2 * cell_h, ColorMode.RGB)
for y = 0, preview.height - 1 do
  local color = y < cell_h and GRASS or SAND
  for x = 0, preview.width - 1 do preview:drawPixel(x, y, color) end
end
for i = 1, count do
  local cell
  if i <= #frames then
    cell = Image(width, height, ColorMode.RGB)
    cell:drawSprite(sprite, i)
  else
    cell = reference
  end
  for band = 0, 1 do
    preview:drawImage(cell, Point((i - 1) * cell_w + 1, band * cell_h + cell_h - cell.height - 1), 255, BlendMode.NORMAL)
  end
end
preview:resize(preview.width * PREVIEW_SCALE, preview.height * PREVIEW_SCALE)
local preview_path = out_path:gsub("%.aseprite$", ".preview.png")
preview:saveAs(preview_path)

local tag_text = {}
for _, t in ipairs(tags) do tag_text[#tag_text + 1] = string.format("%s %d-%d", t.name, t.from, t.to) end
print(string.format("saved %s (%dx%d, %d frames, %d colours; %s), %s, %s", out_path, width, height, #frames, #keys,
  table.concat(tag_text, ", "), sheet_path, preview_path))
