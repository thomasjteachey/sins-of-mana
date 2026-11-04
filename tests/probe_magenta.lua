-- Probe: paint CGRAM 24-31 (BG3 palettes 6-7) magenta in the game's palette copy
-- ($7E:4830-$483F) every frame, so any use of those colours shows up in screenshots.
emu.addEventCallback(function()
  if not PROBE_ON then return end
  for i = 0, 15, 2 do
    emu.write(0x4830 + i, 0x1F, emu.memType.snesWorkRam)
    emu.write(0x4831 + i, 0x7C, emu.memType.snesWorkRam)
  end
end, emu.eventType.startFrame)
