-- Probe: count casts started (Duran state -> $0A) and spells fired (-> $04) during the run.
local started, fired, last = 0, 0, nil
emu.addEventCallback(function()
  if not PROBE_ON then return end
  local st = emu.read(0x1ED60, emu.memType.snesWorkRam)
  if st == 0x0A and last ~= 0x0A then started = started + 1 end
  if st == 0x04 and last ~= 0x04 then fired = fired + 1 end
  last = st
  CAST_STATS = string.format("casts started %d, spells fired %d", started, fired)
end, emu.eventType.endFrame)
emu.addEventCallback(function()
  if CAST_STATS and emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA and not CAST_DONE then
    CAST_DONE = true; note(CAST_STATS)
  end
end, emu.eventType.endFrame)
