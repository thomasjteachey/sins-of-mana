-- Probe: when a stack write in the equip screen's page goes below STACKDUMP_BELOW (default $0A9A),
-- dump the stack from S to $0AFF with the PC -> build/stackdump.txt (first STACKDUMP_N times).
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "stackdump.txt", "w")
pcall(dofile, ROOTB .. "probe_stackdump_cfg.lua")
local BELOW, N = STACKDUMP_BELOW or 0x0A9A, STACKDUMP_N or 4
local frame, n, lastF = 0, 0, -1
local function nl(s) out:write(s .. string.char(10)); out:flush() end
local function hit(a, v)
  if not PROBE_ON or n >= N then return end
  local s = emu.getState()
  local sp = s["cpu.sp"]
  local adr = a & 0xFFFF
  if sp < 0x0A00 or sp >= 0x0B00 or adr < sp - 2 or adr > sp + 4 or adr >= BELOW then return end
  if frame == lastF then return end
  lastF = frame
  n = n + 1
  local t = {}
  for i = sp + 1, 0x0AFF do t[#t + 1] = string.format("%02X", emu.read(i, emu.memType.snesWorkRam)) end
  nl(string.format("f%d write %04X S=%04X at %02X:%04X D=%04X DB=%02X", frame, adr, sp, s["cpu.k"], s["cpu.pc"], s["cpu.d"],
    s["cpu.dbr"]))
  nl(string.format("  stack %04X..0AFF: %s", sp + 1, table.concat(t, " ")))
end
emu.addMemoryCallback(hit, emu.callbackType.write, 0x000A40, 0x000ABF)
emu.addMemoryCallback(hit, emu.callbackType.write, 0x7E0A40, 0x7E0ABF)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
end, emu.eventType.endFrame)
