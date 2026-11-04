-- Probe: track VWF tile allocation in the equip screen.
-- $C4:4850 = layout window printer (sets $57 = $59 start tile, $18 = $1C)
-- $C4:491E = print one string; $C4:494C = string finished
-- $C4:9D8E = help-box layout print (saves/restores $59 and $1C)
local function w(a) return emu.read16(a, emu.memType.snesWorkRam) end
local function log(tag)
  if not PROBE_ON then return end
  local s = emu.getState()
  note(string.format("%-10s $57=%04X $59=%04X $1C=%04X $18=%04X $1E=%04X $10=%04X $20=%04X $2E=%04X Y=%04X",
    tag, w(0x557), w(0x559), w(0x51C), w(0x518), w(0x51E), w(0x510), w(0x520), w(0x52E), s["cpu.y"]))
end
emu.addMemoryCallback(function() log("layout") end, emu.callbackType.exec, 0xC44850, 0xC44850)
emu.addMemoryCallback(function() log("string") end, emu.callbackType.exec, 0xC4491E, 0xC4491E)
emu.addMemoryCallback(function() log("  end") end, emu.callbackType.exec, 0xC4494C, 0xC4494C)
emu.addMemoryCallback(function() log("HELP9D8E") end, emu.callbackType.exec, 0xC49D8E, 0xC49D8E)
emu.addMemoryCallback(function() log("name9D6E") end, emu.callbackType.exec, 0xC49D6E, 0xC49D6E)
