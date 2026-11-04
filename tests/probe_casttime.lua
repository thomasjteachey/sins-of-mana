-- Probe: log the cast time handed to the script ($D0:FB12, X) and how many
-- frames Duran's state stays $0A.
local start, last = nil, nil
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  note(string.format("pushed cast time X=%d at counter %d", emu.getState()["cpu.x"], emu.read16(0x100C6, emu.memType.snesWorkRam)))
end, emu.callbackType.exec, 0xD0FB12, 0xD0FB12)
local frame = 0
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  local st = emu.read(0x1ED60, emu.memType.snesWorkRam)
  if st == 0x0A and last ~= 0x0A then start = frame end
  if last == 0x0A and st ~= 0x0A then note(string.format("casting state lasted %d frames", frame - start)) end
  last = st
end, emu.eventType.endFrame)
