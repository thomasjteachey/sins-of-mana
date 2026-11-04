-- Probe: force the icon drawer's DMA-budget wait ($C4:4DA6 LDA #$0958 : JSL $E8CCF7) by setting the
-- budget counter $7F:0010 high, then log writes to the equip screen's icon counter ($0A79/$0A7A, also
-- $0579/$057A) and the counter value at each icon palette copy ($E8:C18F) -> build/forcewait.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "forcewait.txt", "w")
local frame, n, forced = 0, 0, 0
local function nl(s) out:write(s .. string.char(10)); out:flush() end
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  forced = forced + 1
  emu.write16(0x7F0010, 0x1700, emu.memType.snesMemory)
  nl(string.format("f%d forcing the budget wait (#%d)", frame, forced))
end, emu.callbackType.exec, 0xC44DA6, 0xC44DA6)
local function wr(a, v)
  if not PROBE_ON or n > 400 then return end
  n = n + 1
  local s = emu.getState()
  nl(string.format("f%d write %04X=%02X at %02X:%04X D=%04X S=%04X", frame, a & 0xFFFF, v or -1, s["cpu.k"], s["cpu.pc"],
    s["cpu.d"], s["cpu.sp"]))
end
for _, a in ipairs({0x000579, 0x000A79, 0x7E0579, 0x7E0A79}) do
  emu.addMemoryCallback(wr, emu.callbackType.write, a, a + 1)
end
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local s = emu.getState()
  nl(string.format("f%d CALL E8:C18F D=%04X [79]=%04X", frame, s["cpu.d"], r16(0x7E0000 + s["cpu.d"] + 0x79)))
end, emu.callbackType.exec, 0xE8C18F, 0xE8C18F)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
end, emu.eventType.endFrame)
