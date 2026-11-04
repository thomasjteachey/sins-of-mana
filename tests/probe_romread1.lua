-- Probe: log code that reads one ROM byte (ROM_OFF env = file offset, hex), with registers.
local off = tonumber(os.getenv("ROM_OFF") or "119B68", 16)
local n = 0
emu.addMemoryCallback(function(addr, value)
  if not PROBE_ON or n > 10 then return end
  n = n + 1
  local s = emu.getState()
  note(string.format("read %06X = %02X  pc=%02X:%04X A=%04X X=%04X Y=%04X D=%04X DB=%02X", addr, value,
    s["cpu.k"], s["cpu.pc"], s["cpu.a"], s["cpu.x"], s["cpu.y"], s["cpu.d"], s["cpu.dbr"]))
end, emu.callbackType.read, off, off, emu.cpuType.snes, emu.memType.snesPrgRom)
