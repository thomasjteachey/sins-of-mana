-- Probe: (1) frames where a bar cell is on screen but BG3 tiles $001-$005 in VRAM don't hold
-- our graphics, (2) frames where tiles $006-$008 aren't zero, (3) bar code cost.
dofile("C:/Projects/Gamedev/sins of mana/build/ram/bartiles_expected.lua")
local f, bad, badFirst, extra, shown = 0, 0, nil, 0, 0
local t0, tot, mx, n0, nmiIn = nil, 0, 0, nil, 0
local function clk() return emu.getState()["masterClock"] end
emu.addMemoryCallback(function() t0 = clk() end, emu.callbackType.exec, 0xCBE40B, 0xCBE40B)
local function leave() if t0 then local d = clk() - t0 - nmiIn; nmiIn = 0; tot = tot + d; if d > mx then mx = d end; t0 = nil end end
emu.addMemoryCallback(leave, emu.callbackType.exec, 0xCBE41B, 0xCBE41B)
emu.addMemoryCallback(leave, emu.callbackType.exec, 0xCBE5D9, 0xCBE5D9)
emu.addMemoryCallback(function() if t0 then n0 = clk() end end, emu.callbackType.exec, 0xC033A8, 0xC033A8)
emu.addMemoryCallback(function() if n0 then nmiIn = nmiIn + (clk() - n0); n0 = nil end end, emu.callbackType.exec, 0xC03434, 0xC03434)
emu.addEventCallback(function()
  if not PROBE_ON then tot = 0; mx = 0; return end
  f = f + 1
  local any = false
  for slot = 0, 15 do
    local off = emu.read16(0x7E4700 + slot * 2, emu.memType.snesMemory)
    if off >= 0x140 and off < 0x5C0 then any = true end
  end
  if any then
    shown = shown + 1
    for i = 1, 80 do
      if emu.read(0x0F + i, emu.memType.snesVideoRam) ~= EXPECTED[i] then
        bad = bad + 1; if not badFirst then badFirst = f end; break
      end
    end
  end
  for i = 0x60, 0x8F do if emu.read(i, emu.memType.snesVideoRam) ~= 0 then extra = extra + 1; break end end
  if emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA then
    note(string.format("BARCHECK frames=%d bars_shown=%d tiles_wrong=%d (first f%s) tiles6-8_nonzero=%d cost avg=%d max=%d",
      f, shown, bad, tostring(badFirst), extra, tot // f, mx))
    emu.write(0x1FFF, 0, emu.memType.snesWorkRam)
  end
end, emu.eventType.endFrame)
