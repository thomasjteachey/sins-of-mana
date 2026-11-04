-- Probe: per frame, the auto-joypad result ($4218/$4219) and party objects' x positions,
-- to count frames from a press to the first movement.
local f = 0
emu.addEventCallback(function()
  if not PROBE_ON then return end
  f = f + 1
  local j = emu.read(0x4218, emu.memType.snesMemory) | (emu.read(0x4219, emu.memType.snesMemory) << 8)
  local xs = {}
  for slot = 0, 2 do
    local rec = emu.read16(0x7E2040 + slot * 2, emu.memType.snesMemory)
    local obj = rec ~= 0 and emu.read16(0x7F0000 + rec + 4, emu.memType.snesMemory) or 0
    xs[#xs + 1] = obj ~= 0 and tostring(emu.read16(0x7F0000 + obj + 0x83, emu.memType.snesMemory)) or "-"
  end
  if f >= 20 and f <= 45 then note(string.format("f%d joy=%04X x=%s", f, j, table.concat(xs, ","))) end
end, emu.eventType.endFrame)
