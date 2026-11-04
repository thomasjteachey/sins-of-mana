-- Probe: paint CGRAM 21-23 (BG3 palette 5, colours 1-3) magenta in the game's palette copy
-- ($7E:482A-$482F) every frame, so any use of those colours shows up in screenshots.
emu.addEventCallback(function()
  if not PROBE_ON then return end
  for i = 0, 5, 2 do
    emu.write(0x482A + i, 0x1F, emu.memType.snesWorkRam)
    emu.write(0x482B + i, 0x7C, emu.memType.snesWorkRam)
  end
end, emu.eventType.startFrame)
