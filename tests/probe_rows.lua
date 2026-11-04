-- Probe: at $7E:1FFF = AA, print BG3 rows 28-31 (shadow vs VRAM) as tile numbers.
local done = false
emu.addEventCallback(function()
  if not PROBE_ON or done or emu.read(0x1FFF, emu.memType.snesWorkRam) ~= 0xAA then return end
  done = true
  for r = 28, 31 do
    local s, v = {}, {}
    for c = 0, 21 do
      local a = (r * 32 + c) * 2
      s[#s + 1] = string.format("%04X", emu.read16(0x7E4000 + a, emu.memType.snesMemory))
      v[#v + 1] = string.format("%04X", emu.read(0xB000 + a, emu.memType.snesVideoRam) | (emu.read(0xB000 + a + 1, emu.memType.snesVideoRam) << 8))
    end
    note(string.format("row%d shadow %s", r, table.concat(s, " ")))
    note(string.format("row%d vram   %s", r, table.concat(v, " ")))
  end
end, emu.eventType.endFrame)
