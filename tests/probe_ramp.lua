-- Probe: reads of the window-colour ramp table ($FD:4E80-$FD:4FFF) with PC, and the CPU state at
-- the first read of each frame -> build/ramp.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "ramp.txt", "w")
local frame, n, seen = 0, 0, {}
local function nl(s) out:write(s .. string.char(10)); out:flush() end
emu.addMemoryCallback(function(a)
  if not PROBE_ON or n > 600 then return end
  local s = emu.getState()
  local key = string.format("%02X:%04X", s["cpu.k"], s["cpu.pc"])
  n = n + 1
  if not seen[key .. frame] then
    seen[key .. frame] = true
    nl(string.format("f%d read %06X at %s A=%04X X=%04X Y=%04X D=%04X DB=%02X P=%02X", frame, a, key, s["cpu.a"], s["cpu.x"],
      s["cpu.y"], s["cpu.d"], s["cpu.dbr"], s["cpu.ps"]))
  end
end, emu.callbackType.read, 0xFD4E80, 0xFD4FFF)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
end, emu.eventType.endFrame)
