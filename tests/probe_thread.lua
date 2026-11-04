-- Probe: log the cast time pushed at $D0:FB12 (X), then each frame log bytes
-- of the thread page $7E:0D00-$0DFF that changed, while Duran casts.
local prev, active, frames = nil, false, 0
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local s = emu.getState()
  note(string.format("cast time pushed: X=%d (D=%04X, VM sp ($02)=%04X)", s["cpu.x"], s["cpu.d"],
    emu.read16(s["cpu.d"] + 2, emu.memType.snesMemory)))
  active = true
end, emu.callbackType.exec, 0xD0FB12, 0xD0FB12)
emu.addEventCallback(function()
  if not active then return end
  frames = frames + 1
  if frames > 30 then return end
  local cur = {}
  for i = 0, 0xFF do cur[i] = emu.read(0x0D00 + i, emu.memType.snesWorkRam) end
  if prev then
    local ch = {}
    for i = 0, 0xFF do if cur[i] ~= prev[i] then ch[#ch + 1] = string.format("%02X:%02X>%02X", i, prev[i], cur[i]) end end
    note(string.format("f%02d state %02X  %s", frames, emu.read(0x1ED60, emu.memType.snesWorkRam), table.concat(ch, " ")))
  end
  prev = cur
end, emu.eventType.endFrame)
