-- Probe: force the main-screen layer mask (game's $212C copy at $7F:082C) to TM_G each frame.
TM_G = TM_G or 0x15
pcall(dofile, "C:/Projects/Gamedev/sins of mana/build/probe_tm_cfg.lua")
emu.addEventCallback(function()
  if not PROBE_ON then return end
  emu.write(0x1082C, TM_G, emu.memType.snesWorkRam)
end, emu.eventType.startFrame)
