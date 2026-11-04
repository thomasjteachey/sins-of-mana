-- Probe: bar code cost per frame (NMI time excluded), CastStart calls by caster slot, frames
-- with an enemy cast bar, and HDMA-enabled frames. Summary when $7E:1FFF = AA.
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
local function clk() return emu.getState()["masterClock"] end
local t0, n0, nmiIn, tot, mx, frames = nil, nil, 0, 0, 0, 0
local casts, enemyCastFrames, hdmaFrames, done = {}, 0, 0, false
emu.addMemoryCallback(function() t0 = clk(); nmiIn = 0 end, emu.callbackType.exec, 0xCBE40B, 0xCBE40B)
emu.addMemoryCallback(function()
  if t0 then local d = clk() - t0 - nmiIn; tot = tot + d; if d > mx then mx = d end; if d > 45000 then note("SPIKE f" .. frames .. " " .. d) end; t0 = nil end
end, emu.callbackType.exec, 0xCBE57D, 0xCBE57D)
emu.addMemoryCallback(function() if t0 then n0 = clk() end end, emu.callbackType.exec, 0xC033A8, 0xC033A8)
emu.addMemoryCallback(function() if n0 then nmiIn = nmiIn + (clk() - n0); n0 = nil end end, emu.callbackType.exec, 0xC03434, 0xC03434)
emu.addMemoryCallback(function()
  local s = emu.getState()
  local rec = (emu.read16(s["cpu.d"] + 0x34, emu.memType.snesMemory) - 0x90) & 0xFFFF
  local slot = "?"
  for i = 0, 15 do if r16(0x7E2040 + i * 2) == rec then slot = tostring(i) end end
  casts[slot] = (casts[slot] or 0) + 1
end, emu.callbackType.exec, 0x56A000, 0x56A000)
emu.addEventCallback(function()
  if not PROBE_ON then tot = 0; mx = 0; return end
  frames = frames + 1
  for k = 0, 7 do
    local own = r16(0x7E2848 + k * 2)
    if own ~= 0 and (own & 1) == 1 and ((own & 0x7FFF) >> 1) >= 3 then enemyCastFrames = enemyCastFrames + 1; break end
  end
  if r16(0x7E2846) ~= 0 and ((r16(0x7F00C6) - r16(0x7E2842)) & 0xFFFF) < 3 then hdmaFrames = hdmaFrames + 1 end
  if not done and emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA then
    done = true
    local c = {}
    for k, v in pairs(casts) do c[#c + 1] = "slot" .. k .. "=" .. v end
    note(string.format("BARS2 frames=%d cost avg=%d max=%d casts{%s} enemy_cast_bar_frames=%d hdma_frames=%d",
      frames, tot // frames, mx, table.concat(c, ","), enemyCastFrames, hdmaFrames))
  end
end, emu.eventType.endFrame)
