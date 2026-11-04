-- Probe: after the cast time is pushed ($D0:FB12), log WRAM writes of a given
-- byte value (VAL env, hex) for 40 frames, with the writing PC.
local val = tonumber(os.getenv("VAL") or "C7", 16)
local armed, frames, n = false, 0, 0
emu.addMemoryCallback(function()
  if PROBE_ON then armed = true; note("armed") end
end, emu.callbackType.exec, 0xD0FB12, 0xD0FB12)
emu.addEventCallback(function() if armed then frames = frames + 1 end end, emu.eventType.endFrame)
emu.addMemoryCallback(function(addr, value)
  if not armed or frames > 40 or n > 40 or value ~= val then return end
  n = n + 1
  local s = emu.getState()
  note(string.format("f%02d write %05X = %02X pc=%02X:%04X X=%04X Y=%04X D=%04X", frames, addr & 0x1FFFF, value,
    s["cpu.k"], s["cpu.pc"], s["cpu.x"], s["cpu.y"], s["cpu.d"]))
end, emu.callbackType.write, 0x00000, 0x1FFFF, emu.cpuType.snes, emu.memType.snesWorkRam)
