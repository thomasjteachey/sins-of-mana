-- Probe: how deep the equip screen's stack goes (its page is $0A00-$0AFF, direct-page variables at
-- the bottom, the stack from the top): every stack write (address within 24 bytes below/at S) into
-- $0A40-$0ABF -> build/stackhit.txt, one line per new lowest address, with the PC; plus any stack
-- write at or below $0A7F (the variables the icon palette counter $0A79 belongs to).
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "stackhit.txt", "w")
local frame, low, n = 0, 0x10000, 0
local function nl(s) out:write(s .. string.char(10)); out:flush() end
local function hit(a, v)
  if not PROBE_ON then return end
  local s = emu.getState()
  local sp = s["cpu.sp"]
  local adr = a & 0xFFFF
  if sp < 0x0A00 or sp >= 0x0B00 or adr < sp - 2 or adr > sp + 24 then return end
  if adr < low then
    low = adr
    nl(string.format("f%d new lowest stack write %04X=%02X S=%04X at %02X:%04X", frame, adr, v or -1, sp, s["cpu.k"], s["cpu.pc"]))
  end
  if adr <= 0x0A7F and n < 200 then
    n = n + 1
    nl(string.format("f%d INTO VARIABLES %04X=%02X S=%04X at %02X:%04X", frame, adr, v or -1, sp, s["cpu.k"], s["cpu.pc"]))
  end
end
emu.addMemoryCallback(hit, emu.callbackType.write, 0x000A40, 0x000ABF)
emu.addMemoryCallback(hit, emu.callbackType.write, 0x7E0A40, 0x7E0ABF)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
end, emu.eventType.endFrame)
