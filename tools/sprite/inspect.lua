-- Prints a sprite's size, frame durations (ms), tags, layers and the colours used (flattened, all frames).
-- Run through `python tools/sprite/sprite.py info <file.aseprite>`.
local spr = app.open(app.params.file)
local out = {}
local function p(s) out[#out+1]=s end
p(string.format("%s  %dx%d  mode=%s  frames=%d", app.fs.fileName(spr.filename), spr.width, spr.height, tostring(spr.colorMode), #spr.frames))
local durs = {}
for _,f in ipairs(spr.frames) do durs[#durs+1]=math.floor(f.duration*1000+0.5) end
p("  durations(ms): "..table.concat(durs,","))
for _,t in ipairs(spr.tags) do p(string.format("  tag %s %d-%d %s", t.name, t.fromFrame.frameNumber, t.toFrame.frameNumber, tostring(t.aniDir))) end
local function walk(layers, pre) for _,l in ipairs(layers) do p("  layer "..pre..l.name..(l.isVisible and "" or " (hidden)")); if l.isGroup then walk(l.layers, pre.."  ") end end end
walk(spr.layers, "")
-- unique colours over all frames (flattened)
local used = {}
local img = Image(spr.width, spr.height, ColorMode.RGB)
for _,f in ipairs(spr.frames) do
  img:clear(); img:drawSprite(spr, f.frameNumber)
  for it in img:pixels() do local v=it(); if app.pixelColor.rgbaA(v)>0 then local key=string.format("%02x%02x%02x%s",app.pixelColor.rgbaR(v),app.pixelColor.rgbaG(v),app.pixelColor.rgbaB(v), app.pixelColor.rgbaA(v)<255 and ("@"..app.pixelColor.rgbaA(v)) or ""); used[key]=(used[key] or 0)+1 end end
end
local keys={} for k,_ in pairs(used) do keys[#keys+1]=k end table.sort(keys)
p("  colours("..#keys.."): "..table.concat(keys," "))
print(table.concat(out,"\n"))
