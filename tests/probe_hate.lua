-- Probe: log code that writes the enemy hate value ($7F:DA80) and its registers.
emu.addMemoryCallback(function(addr, value)
  if not PROBE_ON then return end
  local s = emu.getState()
  note(string.format("write $%06X = %02X  pc=%02X:%04X  A=%04X X=%04X Y=%04X D=%04X DB=%02X  [D+34]=%04X",
    addr, value, s["cpu.k"], s["cpu.pc"], s["cpu.a"], s["cpu.x"], s["cpu.y"], s["cpu.d"], s["cpu.dbr"],
    emu.read16(s["cpu.d"] + 0x34, emu.memType.snesMemory)))
end, emu.callbackType.write, 0x1DA80, 0x1DA81, emu.cpuType.snes, emu.memType.snesWorkRam)
