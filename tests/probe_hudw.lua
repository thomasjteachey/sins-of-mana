-- Probe: log distinct PCs writing the bottom HUD block's HP cells (BG3 copy row 23-24, cols 11-20)
-- with registers, after $7E:1FFF = 1 (armed by a poke).
local seen, list = {}, {}
emu.addMemoryCallback(function(addr, value)
  if not PROBE_ON or emu.read(0x1FFF, emu.memType.snesWorkRam) ~= 1 then return end
  local s = emu.getState()
  local k = string.format("%02X:%04X", s["cpu.k"], s["cpu.pc"])
  if not seen[k] then
    seen[k] = true
    list[#list + 1] = string.format("W %06X=%02X @%s A=%04X X=%04X Y=%04X D=%04X DB=%02X S=%04X", addr, value, k, s["cpu.a"], s["cpu.x"], s["cpu.y"], s["cpu.d"], s["cpu.dbr"], s["cpu.sp"])
  end
end, emu.callbackType.write, 0x7E4000 + (23 * 32 + 11) * 2, 0x7E4000 + (24 * 32 + 20) * 2 + 1)
emu.addEventCallback(function()
  if PROBE_ON and emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA then
    for _, l in ipairs(list) do note(l) end
    emu.write(0x1FFF, 0, emu.memType.snesWorkRam)
  end
end, emu.eventType.endFrame)
