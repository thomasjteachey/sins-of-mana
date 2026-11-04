-- Probe: per icon drawn by the graphics task ($C1:D96A...): its buffer address ($32 in the
-- task's direct page) and whether an NMI happened while its 4 upload jobs were being queued
-- ($C1:D9E1 .. $C1:DA1D) -> build/iconjobs.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "iconjobs.txt", "w")
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
local nmis, startN, frame = 0, nil, 0
emu.addMemoryCallback(function() nmis = nmis + 1 end, emu.callbackType.exec, 0xC033A8, 0xC033A8)
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local s = emu.getState()
  local d = s["cpu.d"]
  startN = nmis
  out:write(string.format("F%d icon buffer=%02X%02X vram=%02X%02X", frame, r8(d + 0x33), r8(d + 0x32), r8(d + 0x0D), r8(d + 0x0C)))
end, emu.callbackType.exec, 0xC1D9E1, 0xC1D9E1)
emu.addMemoryCallback(function()
  if not PROBE_ON or not startN then return end
  out:write(string.format(" nmi_during_queue=%d\n", nmis - startN))
  startN = nil
end, emu.callbackType.exec, 0xC1DA1D, 0xC1DA1D)
emu.addEventCallback(function()
  if PROBE_ON then frame = frame + 1 end
  out:flush()
end, emu.eventType.endFrame)
