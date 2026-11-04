-- Probe: per frame, did Bars run (exec $CB:E40B), screen brightness ($2100), HDMA enabled,
-- CGRAM 21 -> build/gaps.txt. With one party member down (critical digit -> borrowing).
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "gaps.txt", "w")
local frame, ran, bright, hdma = 0, 0, 15, 0
local function w8(a, v) emu.write(a - 0x7E0000, v, emu.memType.snesWorkRam) end
local function w16(a, v) w8(a, v & 0xFF); w8(a + 1, (v >> 8) & 0xFF) end
local function cg(i) return emu.read(i * 2, emu.memType.snesCgRam) | (emu.read(i * 2 + 1, emu.memType.snesCgRam) << 8) end
emu.addMemoryCallback(function() ran = ran + 1 end, emu.callbackType.exec, 0xCBE40B, 0xCBE40B)
emu.addMemoryCallback(function(a, v) bright = v end, emu.callbackType.write, 0x2100, 0x2100)
emu.addMemoryCallback(function(a, v) hdma = v end, emu.callbackType.write, 0x420C, 0x420C)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if frame >= 5 and frame <= 12 then local rec = emu.read16(0x7E2040, emu.memType.snesMemory); if rec ~= 0 then w16(0x7F0000 + rec + 0x92, 0) end end
  if frame >= 5 then local rec = emu.read16(0x7E2042, emu.memType.snesMemory); if rec ~= 0 then w8(0x7F0000 + rec + 0xC5, 0x88) end end
  out:write(string.format("F%d bars %d bright %02X hdma %02X cg21 %04X\n", frame, ran, bright, hdma, cg(21)))
  out:flush()
  ran = 0
end, emu.eventType.endFrame)
