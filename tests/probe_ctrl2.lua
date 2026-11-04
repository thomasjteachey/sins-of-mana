-- Probe: writes to $00:094B / $7E:094B (DP access) and reads of party HP (+$92) by the HUD task (D=$0900).
local seen, list = {}, {}
local function add(k) if not seen[k] then seen[k] = true; list[#list + 1] = k end end
for _, a in ipairs({0x00094A, 0x00094B, 0x7E094B}) do
  emu.addMemoryCallback(function(addr, value)
    if not PROBE_ON then return end
    local s = emu.getState()
    add(string.format("W %06X=%02X @%02X:%04X D=%04X", addr, value, s["cpu.k"], s["cpu.pc"], s["cpu.d"]))
  end, emu.callbackType.write, a, a)
end
for _, rec in ipairs({0xF060, 0xF360, 0xF660}) do
  emu.addMemoryCallback(function(addr, value)
    if not PROBE_ON then return end
    local s = emu.getState()
    if s["cpu.d"] == 0x0900 then
      add(string.format("R HP %06X @%02X:%04X X=%04X Y=%04X", addr, s["cpu.k"], s["cpu.pc"], s["cpu.x"], s["cpu.y"]))
    end
  end, emu.callbackType.read, 0x7F0000 + rec + 0x92, 0x7F0000 + rec + 0x93)
end
emu.addEventCallback(function()
  if PROBE_ON and emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA then
    for _, l in ipairs(list) do note(l) end
    note(string.format("now 094B=%02X", emu.read(0x094B, emu.memType.snesWorkRam)))
    emu.write(0x1FFF, 0, emu.memType.snesWorkRam)
  end
end, emu.eventType.endFrame)
