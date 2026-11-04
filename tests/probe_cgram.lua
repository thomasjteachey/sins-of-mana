-- Probe: CGRAM entries 0-31 (BG3 palettes 0-7, shared with BG1/BG2 palette 0-1 in mode 1)
-- every frame for FRAMES_G frames -> build/cgram.txt: per entry, how many distinct values
-- it took and the values themselves.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
FRAMES_G = 240
pcall(dofile, ROOTB .. "probe_cgram_cfg.lua")
local out = io.open(ROOTB .. "cgram.txt", "w")
local frame, seen, order = 0, {}, {}
for i = 0, 31 do seen[i] = {}; order[i] = {} end
local function cg(i) return emu.read(i * 2, emu.memType.snesCgRam) | (emu.read(i * 2 + 1, emu.memType.snesCgRam) << 8) end
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if frame > FRAMES_G then return end
  for i = 0, 31 do
    local v = cg(i)
    if not seen[i][v] then seen[i][v] = 0; order[i][#order[i] + 1] = v end
    seen[i][v] = seen[i][v] + 1
  end
  if frame == FRAMES_G then
    for i = 0, 31 do
      local vals = {}
      for _, v in ipairs(order[i]) do vals[#vals + 1] = string.format("%04X(%d)", v, seen[i][v]) end
      out:write(string.format("pal %d col %d (cgram %2d): %d values: %s\n", i // 4, i % 4, i, #order[i], table.concat(vals, " ")))
    end
    out:flush()
  end
end, emu.eventType.endFrame)
