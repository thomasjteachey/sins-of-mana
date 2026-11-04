-- Probe: per frame, was HDMA channel 1 on ($420C as last written), did Bars run, panel flag
-- -> build/panelvis.txt (one line per change).
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "panelvis.txt", "w")
local frame, hdma, ran, last = 0, 0, 0, nil
emu.addMemoryCallback(function(a, v) hdma = v end, emu.callbackType.write, 0x420C, 0x420C)
emu.addMemoryCallback(function() ran = ran + 1 end, emu.callbackType.exec, 0xCBE40B, 0xCBE40B)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  local on = emu.read16(0x7E28E0, emu.memType.snesMemory)
  local s = string.format("ch1 %d panel %d bars %d", (hdma >> 1) & 1, on, ran)
  if s ~= last then out:write(string.format("F%d %s", frame, s) .. string.char(10)); out:flush(); last = s end
  ran = 0
end, emu.eventType.endFrame)
