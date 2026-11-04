-- Probe: per frame, log the PC at end of frame, how many times TickBars ran,
-- whether QueueUpload/the DMA allocator ran, and the stack pointer.
local frames, tick, alloc, cast = 0, 0, 0, 0
emu.addMemoryCallback(function() tick = tick + 1 end, emu.callbackType.exec, 0x56A000, 0x56A000)
emu.addMemoryCallback(function() alloc = alloc + 1 end, emu.callbackType.exec, 0xC00560, 0xC00560)
emu.addMemoryCallback(function()
  cast = cast + 1
  local s = emu.getState()
  note(string.format("  CastStart called: X=%04X D=%04X S=%04X", s["cpu.x"], s["cpu.d"], s["cpu.sp"]))
end, emu.callbackType.exec, 0xD0FB12, 0xD0FB12)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frames = frames + 1
  local s = emu.getState()
  if frames >= 40 and frames <= 140 then
    note(string.format("f%03d pc=%02X:%04X S=%04X D=%04X  tickbars=%d alloc=%d", frames, s["cpu.k"], s["cpu.pc"],
      s["cpu.sp"], s["cpu.d"], tick, alloc))
  end
  tick, alloc = 0, 0
end, emu.eventType.endFrame)
