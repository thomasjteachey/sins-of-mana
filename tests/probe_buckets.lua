-- Probe: per frame, instructions executed in a few code buckets -> build/buckets.txt.
-- Buckets: dz = E8:C48B-C510 (zero-run + XOR tile decoder), dv = E8:C41C-C47F (bitplane
-- pass), d2 = C2:3B00-3CFF (field decoder), tx = C0:EA00-F1FF (text engine), id = task
-- scheduler / idle (C0:4A00-4FFF, C0:5E00-5FFF), ot = everything else.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "buckets.txt", "w")
local b = {dz = 0, dv = 0, d2 = 0, tx = 0, id = 0, ot = 0}
local frame = 0
emu.addMemoryCallback(function(a)
  if not PROBE_ON then return end
  if a >= 0xE8C48B and a <= 0xE8C510 then b.dz = b.dz + 1
  elseif a >= 0xE8C41C and a <= 0xE8C47F then b.dv = b.dv + 1
  elseif a >= 0xC23B00 and a <= 0xC23CFF then b.d2 = b.d2 + 1
  elseif a >= 0xC0EA00 and a <= 0xC0F1FF then b.tx = b.tx + 1
  elseif (a >= 0xC04A00 and a <= 0xC04FFF) or (a >= 0xC05E00 and a <= 0xC05FFF) then b.id = b.id + 1
  else b.ot = b.ot + 1 end
end, emu.callbackType.exec, 0x000000, 0xFFFFFF)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  local pad = emu.read(0x4218, emu.memType.snesMemory) | (emu.read(0x4219, emu.memType.snesMemory) << 8)
  out:write(string.format("%d pad=%04X dz=%d dv=%d d2=%d tx=%d id=%d ot=%d\n", frame, pad, b.dz, b.dv, b.d2, b.tx, b.id, b.ot))
  out:flush()
  b = {dz = 0, dv = 0, d2 = 0, tx = 0, id = 0, ot = 0}
end, emu.eventType.endFrame)
