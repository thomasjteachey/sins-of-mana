-- Probe: every frame, check BG3 tiles $001-$008 (VRAM bytes $0010-$008F); log the first change
-- and every frame they are non-zero (summarised). Also report at the end.
local frames, changes, nonzero, last = 0, 0, 0, nil
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frames = frames + 1
  local t = {}
  local nz = false
  for i = 0x10, 0x8F do
    local b = emu.read(i, emu.memType.snesVideoRam)
    t[#t + 1] = b
    if b ~= 0 then nz = true end
  end
  local sig = table.concat(t, ",")
  if last and sig ~= last then
    changes = changes + 1
    if changes <= 5 then note(string.format("f%d tiles 1-8 changed (nonzero=%s)", frames, tostring(nz))) end
  end
  if nz then nonzero = nonzero + 1 end
  last = sig
  if emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA then
    note(string.format("BG3FREE frames=%d changes=%d nonzero_frames=%d", frames, changes, nonzero))
    emu.write(0x1FFF, 0, emu.memType.snesWorkRam)
  end
end, emu.eventType.endFrame)
