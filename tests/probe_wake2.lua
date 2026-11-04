-- Probe: every 25 frames log $7E:0355 (word), $7E:0DB0 (word) and Duran's state; log the frame the cast ends.
local frames, last = 0, nil
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frames = frames + 1
  local st = emu.read(0x1ED60, emu.memType.snesWorkRam)
  local c = emu.read16(0x0355, emu.memType.snesWorkRam)
  local wv = emu.read16(0x0DB0, emu.memType.snesWorkRam)
  if frames % 50 == 0 or (last == 0x0A and st ~= 0x0A) or (last ~= 0x0A and st == 0x0A) then
    note(string.format("f%04d state %02X  $0355=%d  $0DB0=%d  diff=%d", frames, st, c, wv, wv - c))
  end
  last = st
end, emu.eventType.endFrame)
