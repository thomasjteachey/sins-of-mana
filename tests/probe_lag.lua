-- Probe: count how many frames the sprite builder (hook site $FD:6E24) ran 0, 1, 2+ times,
-- and the party HP at the end. Print the summary when $7E:1FFF = AA.
local per, hist, frames, done = 0, {}, 0, false
emu.addMemoryCallback(function() per = per + 1 end, emu.callbackType.exec, 0xFD6E24, 0xFD6E24)
emu.addEventCallback(function()
  if not PROBE_ON then per = 0; return end
  frames = frames + 1
  local k = per > 2 and 2 or per
  hist[k] = (hist[k] or 0) + 1
  per = 0
  if not done and emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA then
    done = true
    note(string.format("frames=%d builder runs: 0x=%d 1x=%d 2x+=%d", frames, hist[0] or 0, hist[1] or 0, hist[2] or 0))
  end
end, emu.eventType.endFrame)
