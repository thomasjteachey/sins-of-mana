-- Probe: log code that writes the equip-screen cursor index ($7E:053E)
-- and the stack at that moment (to see the call chain).
emu.addMemoryCallback(function(addr, value)
  if not PROBE_ON then return end
  local s = emu.getState()
  local sp = s["cpu.sp"]
  local stack = {}
  for i = 1, 24 do stack[#stack + 1] = string.format("%02X", emu.read(sp + i, emu.memType.snesMemory)) end
  note(string.format("write $%06X = %02X  pc=%02X:%04X  A=%04X X=%04X Y=%04X  S=%04X stack: %s",
    addr, value, s["cpu.k"], s["cpu.pc"], s["cpu.a"], s["cpu.x"], s["cpu.y"], sp, table.concat(stack, " ")))
end, emu.callbackType.write, 0x053E, 0x053F, emu.cpuType.snes, emu.memType.snesWorkRam)
