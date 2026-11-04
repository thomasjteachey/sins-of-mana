-- Probe: the BG3 text printer's colour choice (C4:56DF..5709): which branch (palette 1 green,
-- palette 3 red, palette 4 white) with DP $32/$36 and $3156 -> build/namepal.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "namepal.txt", "w")
local frame, seen, order = 0, {}, {}
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
local function hit(what)
  if not PROBE_ON then return end
  local s = emu.getState()
  local d = s["cpu.d"]
  local k = string.format("%s D=%04X [32]=%02X [36]=%02X [3156]=%02X", what, d, r8(0x7E0000 + d + 0x32), r8(0x7E0000 + d + 0x36), r8(0x7E3156))
  if not seen[k] then seen[k] = 0; order[#order + 1] = k end
  if seen[k] == 0 then out:write(string.format("F%d first: %s\n", frame, k)); out:flush() end
  seen[k] = seen[k] + 1
end
emu.addMemoryCallback(function() hit("pal1 green") end, emu.callbackType.exec, 0xC456FF, 0xC456FF)
emu.addMemoryCallback(function() hit("pal3 red  ") end, emu.callbackType.exec, 0xC456F5, 0xC456F5)
emu.addMemoryCallback(function() hit("pal4 white") end, emu.callbackType.exec, 0xC456FA, 0xC456FA)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
end, emu.eventType.endFrame)
