-- Probe: writes to the equip screen's icon-palette counter (D+$79, for D = $0500 and $0A00) with PC,
-- and every call of the icon palette loader $E8:C18F with D and the counter -> build/dp79.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "dp79.txt", "w")
local frame, n = 0, 0
local function nl(s) out:write(s .. string.char(10)); out:flush() end
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
local function wr(a, v)
  if not PROBE_ON or n > 3000 then return end
  n = n + 1
  local s = emu.getState()
  nl(string.format("f%d write %04X=%02X at %02X:%04X D=%04X", frame, a & 0xFFFF, v or -1, s["cpu.k"], s["cpu.pc"], s["cpu.d"]))
end
emu.addMemoryCallback(wr, emu.callbackType.write, 0x000579, 0x00057A)
emu.addMemoryCallback(wr, emu.callbackType.write, 0x000A79, 0x000A7A)
emu.addMemoryCallback(wr, emu.callbackType.write, 0x7E0579, 0x7E057A)
emu.addMemoryCallback(wr, emu.callbackType.write, 0x7E0A79, 0x7E0A7A)
emu.addMemoryCallback(function()
  if not PROBE_ON or n > 3000 then return end
  n = n + 1
  local s = emu.getState()
  local d = s["cpu.d"]
  nl(string.format("f%d CALL E8:C18F D=%04X [79]=%04X", frame, d, r16(0x7E0000 + d + 0x79)))
end, emu.callbackType.exec, 0xE8C18F, 0xE8C18F)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
end, emu.eventType.endFrame)
