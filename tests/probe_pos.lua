-- Probe: each frame for a few frames, log the enemy record bytes that look like
-- coordinates plus PPU scroll, to match against where its sprites are drawn.
local frames = 0
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frames = frames + 1
  if frames % 20 ~= 0 or frames > 100 then return end
  local function w(a) return emu.read16(a, emu.memType.snesWorkRam) end
  local rec = 0x1D9F0
  local t = {}
  for off = 0, 0x3E, 2 do t[#t + 1] = string.format("%02X:%04X", off, w(rec + off)) end
  -- first enemy sprite in OAM (entries with attr palette like the knight's)
  local x, y = emu.read(0x10100 + 6 * 4, emu.memType.snesWorkRam), emu.read(0x10101 + 6 * 4, emu.memType.snesWorkRam)
  local s = emu.getState()
  note(string.format("f%d oam6=%d,%d  bg1 h/v=%s/%s  rec: %s", frames, x, y,
    tostring(s["ppu.layers[0].hScroll"]), tostring(s["ppu.layers[0].vScroll"]), table.concat(t, " ")))
end, emu.eventType.endFrame)
