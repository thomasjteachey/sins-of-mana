-- Probe: who reads Duran's capstone fields (record $7F:F060 + $150 marker, + $C8 effect) and the
-- capstone strings ($FB:1E77-1E7C through the mod's redirect hook $40:7960) -> build/capread.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "capread.txt", "w")
local frame, seen = 0, {}
local function note(k) if not seen[k] then seen[k] = true; out:write(string.format("F%d %s\n", frame, k)); out:flush() end end
emu.addMemoryCallback(function(addr)
  if not PROBE_ON then return end
  local s = emu.getState()
  note(string.format("read %06X by %02X:%04X", addr, s["cpu.k"], s["cpu.pc"]))
end, emu.callbackType.read, 0x7FF1B0, 0x7FF1B0)
emu.addMemoryCallback(function(addr)
  if not PROBE_ON then return end
  local s = emu.getState()
  note(string.format("read %06X by %02X:%04X", addr, s["cpu.k"], s["cpu.pc"]))
end, emu.callbackType.read, 0x7FF128, 0x7FF128)
emu.addEventCallback(function() if PROBE_ON then frame = frame + 1 end end, emu.eventType.endFrame)
