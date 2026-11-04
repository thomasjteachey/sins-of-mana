-- Probe: at each call of the per-object sprite routine ($FD:6E9B, X = object),
-- log the object's position fields and any word in it that points at a
-- battle record ($7F:D9xx-$DFxx), for one frame.
local frames, logged = 0, false
emu.addEventCallback(function()
  if PROBE_ON then frames = frames + 1 end
end, emu.eventType.endFrame)
emu.addMemoryCallback(function()
  if not PROBE_ON or logged then return end
  calls = (calls or 0) + 1
  if calls > 30 then logged = true end
  local s = emu.getState()
  local db, x, d = s["cpu.dbr"], s["cpu.x"], s["cpu.d"]
  local base = (db << 16) + x
  local function w(o) return emu.read16(base + o, emu.memType.snesMemory) end
  local ptrs = {}
  for o = 0, 0xFE, 2 do
    local v = w(o)
    if v >= 0xD000 and v < 0xF800 then ptrs[#ptrs + 1] = string.format("+%02X=%04X", o, v) end
  end
  note(string.format("obj %02X:%04X D=%04X  x83=%d y87=%d z8B=%d  camX=%d camY=%d  ptrs: %s",
    db, x, d, w(0x83), w(0x87), w(0x8B),
    emu.read16(0x1032A, emu.memType.snesWorkRam), emu.read16(0x1032C, emu.memType.snesWorkRam),
    table.concat(ptrs, " ")))
end, emu.callbackType.exec, 0xFD6E9B, 0xFD6E9B)
