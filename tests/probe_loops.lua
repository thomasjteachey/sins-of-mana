-- Probe: count main-loop passes (sprite builder hook site $FD:6E24) while Duran is casting.
local count, last, frames, f0 = 0, nil, 0, 0
emu.addMemoryCallback(function()
  if PROBE_ON and last == 0x0A then count = count + 1 end
end, emu.callbackType.exec, 0xFD6E24, 0xFD6E24)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frames = frames + 1
  local st = emu.read(0x1ED60, emu.memType.snesWorkRam)
  if st == 0x0A and last ~= 0x0A then count = 0; f0 = frames end
  if last == 0x0A and st ~= 0x0A then note(string.format("cast: %d frames, %d loop passes", frames - f0, count)) end
  last = st
end, emu.eventType.endFrame)
