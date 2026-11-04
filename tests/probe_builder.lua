-- Probe: count sprite-builder hook runs per 30-frame window.
local n, f = 0, 0
emu.addMemoryCallback(function() n = n + 1 end, emu.callbackType.exec, 0xFD6E24, 0xFD6E24)
emu.addEventCallback(function()
  if not PROBE_ON then n = 0; return end
  f = f + 1
  if f % 30 == 0 then note(string.format("f%d builder runs in last 30 frames: %d", f, n)); n = 0 end
end, emu.eventType.endFrame)
