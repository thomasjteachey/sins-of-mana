-- Probe: game speed = ticks of $7F:00C6 per frame, master clocks per frame, and the share of
-- frames whose tick didn't advance. Summary when $7E:1FFF = AA.
local frames, ticks, still, last, c0, clocks, done = 0, 0, 0, nil, nil, 0, false
emu.addEventCallback(function()
  if not PROBE_ON then return end
  local t = emu.read16(0x7F00C6, emu.memType.snesMemory)
  local c = emu.getState()["masterClock"]
  if last then
    local d = (t - last) & 0xFFFF
    ticks = ticks + d
    if d == 0 then still = still + 1 end
    frames = frames + 1
    clocks = clocks + (c - c0)
  end
  last, c0 = t, c
  if not done and emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA then
    done = true
    note(string.format("SPEED frames=%d ticks=%d (%.1f%% speed) frames_without_tick=%d clocks/frame=%d",
      frames, ticks, ticks * 100 / frames, still, clocks // frames))
  end
end, emu.eventType.endFrame)
