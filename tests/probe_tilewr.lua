-- Probe: who writes the field's metatile table start ($7E:8C00-$8C0F) and what our NMI hook does
-- with HDMA meanwhile -> build/tilewr.txt.
-- Per frame (on change): $420C as last written, !Active, !PanelOn, !Ticks - !Stamp, the game's
-- $2105 copy ($7F:0805); every write to $7E:8C00-$8C0F with frame, scanline, PC and value;
-- $7E:8C00-$8C07 at the end of each frame when it changes.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "tilewr.txt", "w")
local frame, hdma, last, lastTab, nw = 0, 0, "", "", 0
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
local function nl(s) out:write(s .. string.char(10)); out:flush() end
emu.addMemoryCallback(function(a, v) hdma = v end, emu.callbackType.write, 0x420C, 0x420C)
emu.addMemoryCallback(function(a, v)
  if not PROBE_ON or nw > 400 then return end
  nw = nw + 1
  local s = emu.getState()
  nl(string.format("f%d line %d write %06X = %02X at %02X:%04X (420C %02X)", frame, s["ppu.scanline"] or -1, a, v or -1,
    s["cpu.k"], s["cpu.pc"], hdma))
end, emu.callbackType.write, 0x7E8C00, 0x7E8C0F)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  local s = string.format("420C %02X active %d panel %d age %d mode %02X", hdma, r16(0x7E2846), r16(0x7E28E0),
    (r16(0x7F00C6) - r16(0x7E2842)) & 0xFFFF, r8(0x7F0805))
  if s ~= last then nl(string.format("f%d %s", frame, s)); last = s end
  local t = {}
  for i = 0, 7 do t[#t + 1] = string.format("%02X", r8(0x7E8C00 + i)) end
  local tab = table.concat(t, " ")
  if tab ~= lastTab then nl(string.format("f%d table %s", frame, tab)); lastTab = tab end
end, emu.eventType.endFrame)
