-- Probe: a screenshot every frame from FLICK_F0 to FLICK_F1 -> build/shots/fl_<frame>.png, and per
-- frame -> build/flicker.txt: HDMA channel 1 ($420C as last written), Bars runs, panel on / sig / miss,
-- and the first bytes of the HDMA table the NMI was given (!Ready $7E:2844).
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "flicker.txt", "w")
pcall(dofile, ROOTB .. "probe_flicker_cfg.lua")
local F0, F1 = FLICK_F0 or 100, FLICK_F1 or 160
local frame, hdma, ran = 0, 0, 0
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
emu.addMemoryCallback(function(a, v) hdma = v end, emu.callbackType.write, 0x420C, 0x420C)
emu.addMemoryCallback(function() ran = ran + 1 end, emu.callbackType.exec, 0xCBE40B, 0xCBE40B)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if frame >= F0 and frame <= F1 then
    local f = io.open(string.format("%sshots/fl_%04d.png", ROOTB, frame), "wb")
    if f then f:write(emu.takeScreenshot()); f:close() end
    local t = r16(0x7E2844)
    local tb = {}
    for i = 0, 8 do tb[#tb + 1] = string.format("%02X", emu.read(0x7E0000 + t + i, emu.memType.snesMemory)) end
    out:write(string.format("F%d ch1 %d bars %d on %d sig %04X/%04X miss %d ready %04X [%s]", frame, (hdma >> 1) & 1, ran,
      r16(0x7E28E0), r16(0x7E28E2), r16(0x7E28EE), r16(0x7E28EA), t, table.concat(tb, " ")) .. string.char(10))
    out:flush()
  end
  ran = 0
end, emu.eventType.endFrame)
