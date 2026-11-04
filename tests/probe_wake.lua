-- Probe: log code that writes the enemy hate value ($7F:DA80) and its registers.
emu.addMemoryCallback(function(addr, value)
  if not PROBE_ON then return end
  local s = emu.getState()
  note(string.format("write $%06X = %02X  pc=%02X:%04X  A=%04X X=%04X Y=%04X D=%04X DB=%02X  [D+34]=%04X",
    addr, value, s["cpu.k"], s["cpu.pc"], s["cpu.a"], s["cpu.x"], s["cpu.y"], s["cpu.d"], s["cpu.dbr"],
    emu.read16(s["cpu.d"] + 0x34, emu.memType.snesMemory)))
end, emu.callbackType.write, 0x0ACD3, 0x0ACD4, emu.cpuType.snes, emu.memType.snesWorkRam)
-- also: report when Duran's state leaves $0A, with the global counter
local last = nil
emu.addEventCallback(function()
  if not PROBE_ON then return end
  local st = emu.read(0x1ED60, emu.memType.snesWorkRam)
  if last == 0x0A and st ~= 0x0A then
    note(string.format("cast ended: state %02X, counter $7F:00C6 = %d, $7E:ACD3 = %d", st,
      emu.read16(0x100C6, emu.memType.snesWorkRam), emu.read16(0xACD3, emu.memType.snesWorkRam)))
  end
  if last ~= 0x0A and st == 0x0A then
    note(string.format("cast started: counter = %d", emu.read16(0x100C6, emu.memType.snesWorkRam)))
  end
  last = st
end, emu.eventType.endFrame)
