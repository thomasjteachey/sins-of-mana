-- Probe: master clocks per glyph in each phase of the text engine, after the first press,
-- for FRAMES_G frames -> build/glyphcost.txt.
--   load  = glyph entry ($C0:ECF6/$ECFE) .. blit section ($C0:EF81)
--   blit  = $C0:EF81 .. glyph routine's RTL ($C0:F007)
--   gap   = RTL .. next glyph entry (string decoding, caller loop; capped at 20000 clocks)
-- Clocks include anything that interrupts (NMI), so they are upper bounds.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
FRAMES_G = 60
pcall(dofile, ROOTB .. "probe_glyphcost_cfg.lua")
local out = io.open(ROOTB .. "glyphcost.txt", "w")
local function clk() return emu.getState()["masterClock"] end
local armed, frames = false, 0
local t0, t1, t2 = nil, nil, nil
local n, load, blit, gap, gapn, shifted = 0, 0, 0, 0, 0, 0
local function entry()
  if not armed then return end
  local c = clk()
  if t2 and c - t2 < 20000 then gap = gap + (c - t2); gapn = gapn + 1 end
  t0, t1, t2 = c, nil, nil
end
emu.addMemoryCallback(entry, emu.callbackType.exec, 0xC0ECF6, 0xC0ECF6)
emu.addMemoryCallback(entry, emu.callbackType.exec, 0xC0ECFE, 0xC0ECFE)
emu.addMemoryCallback(function()
  if armed and t0 and not t1 then t1 = clk(); load = load + (t1 - t0) end
end, emu.callbackType.exec, 0xC0EF81, 0xC0EF81)
emu.addMemoryCallback(function()
  if armed and t0 and not t1 then shifted = shifted + 1 end
end, emu.callbackType.exec, 0xC0EDC6, 0xC0EDC6)
emu.addMemoryCallback(function()
  if armed and t1 and not t2 then t2 = clk(); blit = blit + (t2 - t1); n = n + 1 end
end, emu.callbackType.exec, 0xC0F007, 0xC0F007)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  local pad = emu.read(0x4218, emu.memType.snesMemory) | (emu.read(0x4219, emu.memType.snesMemory) << 8)
  if pad ~= 0 and not armed then armed = true end
  if armed then
    frames = frames + 1
    if frames == FRAMES_G then
      out:write(string.format("glyphs=%d shifted=%d  per glyph: load=%d blit=%d gap=%d (master clocks; 1 frame = 357368)\n",
        n, shifted, n > 0 and load // n or 0, n > 0 and blit // n or 0, gapn > 0 and gap // gapn or 0))
      out:flush()
    end
  end
end, emu.eventType.endFrame)
