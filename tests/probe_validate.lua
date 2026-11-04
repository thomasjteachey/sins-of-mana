-- Probe: per frame while bars are active: our tiles intact in VRAM ($0C00-$0D3F), no
-- on-screen BG3 cell (rows 0-27, VRAM map) uses kana tiles $08A-$0FE except our own
-- $0C0-$0D3 (which only belong in rows 28-31). Plus bar-code cost (NMI excluded).
dofile("C:/Projects/Gamedev/sins of mana/build/ram/bargfx_expected.lua")
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
local f, active, tilesBad, kanaBad, kanaEx, done = 0, 0, 0, 0, nil, false
local t0, n0, nmiIn, tot, mx = nil, nil, 0, 0, 0
local function clk() return emu.getState()["masterClock"] end
emu.addMemoryCallback(function() t0 = clk(); nmiIn = 0 end, emu.callbackType.exec, 0xCBE40B, 0xCBE40B)
emu.addMemoryCallback(function()
  if t0 then local d = clk() - t0 - nmiIn; tot = tot + d; if d > mx then mx = d end; if d > 60000 then note("SPIKE f" .. f .. " " .. d) end; t0 = nil end
end, emu.callbackType.exec, 0xCBE5B9, 0xCBE5B9)
emu.addMemoryCallback(function() if t0 then n0 = clk() end end, emu.callbackType.exec, 0xC033A8, 0xC033A8)
emu.addMemoryCallback(function() if n0 then nmiIn = nmiIn + (clk() - n0); n0 = nil end end, emu.callbackType.exec, 0xC03434, 0xC03434)
emu.addEventCallback(function()
  if not PROBE_ON then tot = 0; mx = 0; return end
  f = f + 1
  if r16(0x7E2846) ~= 0 then
    active = active + 1
    for i = 1, #EXPECTED do
      if emu.read(0x0C00 + i - 1, emu.memType.snesVideoRam) ~= EXPECTED[i] then tilesBad = tilesBad + 1; break end
    end
  end
  for c = 0, 28 * 32 - 1 do
    local v = emu.read(0xB000 + c * 2, emu.memType.snesVideoRam) | (emu.read(0xB001 + c * 2, emu.memType.snesVideoRam) << 8)
    local t = v & 0x3FF
    if t >= 0x8A and t <= 0xFE then kanaBad = kanaBad + 1; kanaEx = kanaEx or string.format("f%d cell r%d c%d = %04X", f, c // 32, c % 32, v); break end
  end
  if not done and emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA then
    done = true
    note(string.format("VALIDATE frames=%d active=%d tiles_wrong=%d kana_on_screen_frames=%d (%s) cost avg=%d max=%d",
      f, active, tilesBad, kanaBad, tostring(kanaEx), tot // f, mx))
  end
end, emu.eventType.endFrame)
