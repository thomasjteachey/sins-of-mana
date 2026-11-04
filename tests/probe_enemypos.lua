-- Probe: on the frame of the last step, log screen positions of every entity
-- in the battle table ($7E:2040 slots 0-15) from its sprite object.
emu.addEventCallback(function()
  if not PROBE_ON then return end
  local function w(a) return emu.read16(a, emu.memType.snesWorkRam) end
  local function wf(a) return emu.read16(0x10000 + a, emu.memType.snesWorkRam) end
  local camX, camY = wf(0x032A), wf(0x032C)
  local out = {}
  for i = 0, 15 do
    local rec = w(0x2040 + i * 2)
    if rec ~= 0 then
      local obj = wf(rec + 4)
      local sx = (wf(obj + 0x83) - camX) & 0xFFFF
      local sy = (wf(obj + 0x87) - wf(obj + 0x8B) - camY - 17) & 0xFFFF
      local hate = emu.read(0x10000 + rec + 0x120, emu.memType.snesWorkRam)
      local typ = wf(rec + 0x90) & 0x1FF
      out[#out + 1] = string.format("slot%d rec %04X side %d obj %04X screen %d,%d type %03X hate %d",
        i, rec, emu.read(0x10000 + rec + 1, emu.memType.snesWorkRam), obj, sx, sy, typ, hate)
    end
  end
  POS_LINES = out
end, emu.eventType.endFrame)
emu.addEventCallback(function()
  if POS_LINES and not POS_DONE and emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA then
    POS_DONE = true
    for _, l in ipairs(POS_LINES) do note(l) end
  end
end, emu.eventType.endFrame)
