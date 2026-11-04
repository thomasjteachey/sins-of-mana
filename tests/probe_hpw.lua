-- Probe: writes to the HP word (+$92) of the enemy records in entity slots 3-5 (ice cave: $E160, $DE60, $CE60)
-- with frame, PC and value -> build/hpw.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "hpw.txt", "w")
local frame = 0
for _, rec in ipairs({0xE160, 0xDE60, 0xCE60}) do
  emu.addMemoryCallback(function(a, v)
    if not PROBE_ON then return end
    local s = emu.getState()
    out:write(string.format("f%d rec %04X +%02X=%02X at %02X:%04X", frame, rec, (a & 0xFFFF) - rec, v or -1, s["cpu.k"], s["cpu.pc"]) .. string.char(10))
    out:flush()
  end, emu.callbackType.write, 0x7F0000 + rec + 0x92, 0x7F0000 + rec + 0x93)
end
emu.addEventCallback(function() if PROBE_ON then frame = frame + 1 end end, emu.eventType.endFrame)
