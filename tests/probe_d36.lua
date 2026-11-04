-- Probe: writes to $7E:0436 (DP $36 of the D=$0400 HUD printer) with PC and value, and
-- each printer colour pick (C4:56DF) with the destination cell -> build/d36.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "d36.txt", "w")
local frame, seen = 0, {}
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
emu.addMemoryCallback(function(addr, value)
  if not PROBE_ON then return end
  local s = emu.getState()
  local k = string.format("W0436 %02X:%04X val=%02X", s["cpu.k"], s["cpu.pc"], value)
  if not seen[k] then seen[k] = true; out:write(string.format("F%d %s\n", frame, k)); out:flush() end
end, emu.callbackType.write, 0x7E0436, 0x7E0436)
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local s = emu.getState()
  local k = string.format("print Y=%04X [32]=%02X [36]=%02X", s["cpu.y"], r8(0x7E0432), r8(0x7E0436))
  if not seen[k] then seen[k] = true; out:write(string.format("F%d %s\n", frame, k)); out:flush() end
end, emu.callbackType.exec, 0xC456DF, 0xC456DF)
emu.addEventCallback(function() if PROBE_ON then frame = frame + 1 end end, emu.eventType.endFrame)
