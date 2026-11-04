-- Probe: log each slot's bar (offset, row/col, 3 cells) when it changes, and whether our
-- tiles are in VRAM (BG3 tiles $001-$005) every 60 frames.
local last, f = {}, 0
emu.addEventCallback(function()
  if not PROBE_ON then return end
  f = f + 1
  for slot = 0, 15 do
    local off = emu.read16(0x7E4700 + slot * 2, emu.memType.snesMemory)
    local line = "none"
    if off >= 0x140 and off < 0x5C0 then
      local t = {}
      for c = 0, 2 do t[#t + 1] = string.format("%04X", emu.read16(0x7E4000 + off + c * 2, emu.memType.snesMemory)) end
      line = string.format("row%d col%d %s code=%04X", off // 64, (off % 64) // 2, table.concat(t, ","),
        emu.read16(0x7E4720 + slot * 2, emu.memType.snesMemory))
    end
    if last[slot] ~= line then note(string.format("f%d slot%d %s", f, slot, line)); last[slot] = line end
  end
  if f % 60 == 0 then
    local s = 0
    for i = 0x10, 0x5F do s = s + emu.read(i, emu.memType.snesVideoRam) end
    note(string.format("f%d vram tiles 1-5 byte sum=%d", f, s))
  end
end, emu.eventType.endFrame)
