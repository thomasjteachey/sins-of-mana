-- Probe: reset the console at frame RESET_F (default 5); cartridge save RAM is kept, so a
-- state with the user's saves leads to a title screen with Continue available.
local frame = 0
local F = RESET_F or 5
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if frame == F then emu.reset() end
end, emu.eventType.endFrame)
