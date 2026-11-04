-- Probe: frame by frame around windows opening/closing while red marks borrow CGRAM 21-23:
-- HDMA enabled for the frame ($420C as last written), CGRAM 21, and the palette of the red
-- icon cells in VRAM -> build/blip.txt. Flags frames where a window shows with our red in
-- CGRAM 21 (window wrong) or a palette-5 icon shows with window colours (icon wrong).
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "blip.txt", "w")
local frame, hdma, bad = 0, 0, 0
local function w8(a, v) emu.write(a - 0x7E0000, v, emu.memType.snesWorkRam) end
local function w16(a, v) w8(a, v & 0xFF); w8(a + 1, (v >> 8) & 0xFF) end
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
local function cg(i) return emu.read(i * 2, emu.memType.snesCgRam) | (emu.read(i * 2 + 1, emu.memType.snesCgRam) << 8) end
local function vram16(w) return emu.read(w * 2, emu.memType.snesVideoRam) | (emu.read(w * 2 + 1, emu.memType.snesVideoRam) << 8) end
emu.addMemoryCallback(function(addr, value) hdma = value end, emu.callbackType.write, 0x420C, 0x420C)
local shown = hdma
emu.addEventCallback(function() shown = hdma end, emu.eventType.startFrame)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if frame >= 5 and frame <= 12 then w16(0x7FF0F2, 0) end   -- member 1 down: a critical digit
  if frame >= 5 then
    w8(0x7FF425, 0x88); w8(0x7FF725, 0x08); w8(0x7FF726, 0x08)   -- lowered stats -> red icons
    w8(0x7FDF26, 0x08)
  end
  -- red icon cells in VRAM (BG3 map at word $5800): any tile $0D4-$0DC with palette 3 or 5
  local p5, p3 = 0, 0
  for _, r in ipairs({1, 2, 23, 24}) do
    for c = 0, 31 do
      local v = vram16(0x5800 + r * 32 + c)
      local t, p = v & 0x3FF, (v >> 10) & 7
      if t >= 0x0D4 and t <= 0x0DC then
        if p == 5 then p5 = p5 + 1 elseif p == 3 then p3 = p3 + 1 end
      end
    end
  end
  local c21 = cg(21)
  local win = (shown & 0x04) ~= 0
  local flag = ""
  if win and c21 ~= 0x5294 then flag = "  <-- WINDOW WRONG"; bad = bad + 1 end
  if p5 > 0 and c21 == 0x5294 then flag = flag .. "  <-- ICON WRONG"; bad = bad + 1 end
  out:write(string.format("F%d hdma %02X cg21 %04X icons p5=%d p3=%d%s\n", frame, shown, c21, p5, p3, flag))
  out:flush()
end, emu.eventType.endFrame)
