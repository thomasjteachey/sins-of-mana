-- Probe: paint CGRAM 20-31 (BG palette 1 colours 4-15 = BG3 palettes 5-7, the window
-- colours) in the game's palette copy with unique colours R31 G0 B(entry), every frame, so
-- screenshots show which entries are on screen (tools: count pixels per colour).
emu.addEventCallback(function()
  if not PROBE_ON then return end
  for k = 20, 31 do
    local v = 31 | (k << 10)
    emu.write(0x4800 + k * 2, v & 0xFF, emu.memType.snesWorkRam)
    emu.write(0x4801 + k * 2, v >> 8, emu.memType.snesWorkRam)
  end
end, emu.eventType.startFrame)
