-- Probe: log the item-name lookup at $C4:9EE8 (LDA $0101,X -> item index)
-- and the final name string address handed to $C4:9D6E (Y).
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local s = emu.getState()
  local db = s["cpu.dbr"]
  local x = s["cpu.x"]
  local v = emu.read((db << 16) + 0x0101 + x, emu.memType.snesMemory)
  note(string.format("lookup  DB=%02X X=%04X Y=%04X idx=%02X  $24=%04X $26=%04X  D=%04X",
    db, x, s["cpu.y"], v,
    emu.read16(0x0524, emu.memType.snesMemory), emu.read16(0x0526, emu.memType.snesMemory), s["cpu.d"]))
end, emu.callbackType.exec, 0xC49EE8, 0xC49EE8)

emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local s = emu.getState()
  local sp = s["cpu.sp"]
  local r1 = emu.read16(sp + 1, emu.memType.snesMemory)
  local r2 = emu.read16(sp + 3, emu.memType.snesMemory)
  note(string.format("name    Y=%04X X=%04X  ret=%04X,%04X", s["cpu.y"], s["cpu.x"], r1, r2))
end, emu.callbackType.exec, 0xC49D6E, 0xC49D6E)
