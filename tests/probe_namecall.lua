-- Probe: each time the "print monster name" text op runs ($C4:6A6A), the stack (return addresses) -> build/namecall.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "namecall.txt", "w")
local frame = 0
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local s = emu.getState()
  local sp = s["cpu.sp"]
  local b = {}
  for i = 1, 24 do b[#b + 1] = string.format("%02X", emu.read(sp + i, emu.memType.snesMemory)) end
  out:write(string.format("f%d D=%04X DB=%02X S=%04X : %s", frame, s["cpu.d"], s["cpu.dbr"], sp, table.concat(b, " ")) .. string.char(10))
  out:flush()
end, emu.callbackType.exec, 0xC46A6A, 0xC46A6A)
emu.addEventCallback(function() if PROBE_ON then frame = frame + 1 end end, emu.eventType.endFrame)
