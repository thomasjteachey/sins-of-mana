-- Probe: log code that reads Duran's owned-equipment list ($7F:EE61-$7F:EEA0)
-- right after a cursor move (only the first few reads per frame).
local count = 0
emu.addEventCallback(function() count = 0 end, emu.eventType.startFrame)
emu.addMemoryCallback(function(addr, value)
  if not PROBE_ON or count > 12 then return end
  count = count + 1
  local s = emu.getState()
  note(string.format("read $7F:%04X = %02X  pc=%02X:%04X  A=%04X X=%04X Y=%04X  $3E=%02X $40=%02X",
    addr & 0xFFFF, value, s["cpu.k"], s["cpu.pc"], s["cpu.a"], s["cpu.x"], s["cpu.y"],
    emu.read(0x053E, emu.memType.snesWorkRam), emu.read(0x0540, emu.memType.snesWorkRam)))
end, emu.callbackType.read, 0x1EE5D, 0x1EEA0, emu.cpuType.snes, emu.memType.snesWorkRam)
