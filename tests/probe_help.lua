-- Probe: when the equip help string ($FB:1855) is requested, log the variables
-- a description lookup would rely on.
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local s = emu.getState()
  if s["cpu.y"] ~= 0x1855 then return end
  local function w(a) return emu.read16(a, emu.memType.snesWorkRam) end
  local function b(a) return emu.read(a, emu.memType.snesWorkRam) end
  note(string.format("help print: D=%04X DB=%02X  $61=%04X $3E=%04X $40=%04X $46=%04X $20=%04X $4A=%04X  cursor x,y=%d,%d",
    s["cpu.d"], s["cpu.dbr"], w(0x561), w(0x53E), w(0x540), w(0x546), w(0x520), w(0x54A),
    b(0x10128), b(0x10129)))
end, emu.callbackType.exec, 0x407960, 0x407960)

-- Also log every cursor placement ($C4:84E9 entry, X = position table).
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local s = emu.getState()
  local function w(a) return emu.read16(a, emu.memType.snesWorkRam) end
  note(string.format("cursor   : table=%04X $3E=%04X $40=%04X $46=%04X $61=%04X",
    s["cpu.x"], w(0x53E), w(0x540), w(0x546), w(0x561)))
end, emu.callbackType.exec, 0xC484E9, 0xC484E9)
