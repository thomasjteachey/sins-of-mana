-- Probe: reads of the spell table ($D1:9936, 17 bytes per spell id, MP byte first) -> build/spellread.txt:
-- frame, PC, spell id, byte offset (changes only per PC+id+offset+frame).
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "spellread.txt", "w")
local frame = 0
local function cb(a)
  if not PROBE_ON then return end
  local s = emu.getState()
  local rel = (a & 0xFFFF) - 0x9936
  local id, off = rel // 17, rel % 17
  out:write(string.format("f%d PC=%02X:%04X id=%02X off=%d X=%04X Y=%04X D=%04X", frame, s["cpu.k"], s["cpu.pc"], id, off, s["cpu.x"], s["cpu.y"], s["cpu.d"]) .. string.char(10))
  out:flush()
end
emu.addMemoryCallback(cb, emu.callbackType.read, 0xD19936 - 17, 0xD19936 + 17 * 0x90)
emu.addMemoryCallback(cb, emu.callbackType.read, 0x519936 - 17, 0x519936 + 17 * 0x90)
emu.addEventCallback(function() if PROBE_ON then frame = frame + 1 end end, emu.eventType.endFrame)
