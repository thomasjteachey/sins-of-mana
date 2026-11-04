-- Probe: log every write to $7F:00A0-00A1 (brightness pointer) with PC, registers and stack.
emu.addMemoryCallback(function(addr, value)
  if not PROBE_ON then return end
  local s = emu.getState()
  local st = {}
  for i = 1, 12 do st[#st + 1] = string.format("%02X", emu.read(0x7E0000 + s["cpu.sp"] + i, emu.memType.snesMemory)) end
  note(string.format("write %06X=%02X at %02X:%04X A=%04X X=%04X Y=%04X D=%04X DB=%02X S=%04X stack=%s",
    addr, value, s["cpu.k"], s["cpu.pc"], s["cpu.a"], s["cpu.x"], s["cpu.y"], s["cpu.d"], s["cpu.dbr"], s["cpu.sp"],
    table.concat(st, " ")))
end, emu.callbackType.write, 0x7F00A0, 0x7F00A1)
