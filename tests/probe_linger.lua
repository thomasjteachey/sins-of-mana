-- Probe: per-frame level-up panel state after the stat is confirmed -> build/linger.txt.
-- PanelOn, PanelMiss, the window corners in the BG3 copy ($7E:4000, (row,col) 6,1 / 6,16 / 21,1 / 21,16),
-- the palette of the stat labels (rows 10-20, column 2) and screen mode registers seen by the CPU.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "linger.txt", "w")
local frame = 0
pcall(dofile, ROOTB .. "probe_linger_cfg.lua")
local F0, F1 = LINGER_FROM or 300, LINGER_TO or 640
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
local function cell(row, col) return r16(0x7E4000 + (row * 32 + col) * 2) end
local last = ""
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if frame < F0 or frame > F1 then return end
  local pal = {}
  for r = 10, 20, 2 do pal[#pal + 1] = tostring((cell(r, 2) >> 10) & 7) end
  local s = string.format("on %d miss %d sig %04X corners %03X %03X %03X %03X labels %s",
    r16(0x7E28E0), r16(0x7E28EA), r16(0x7E28E2),
    cell(6, 1) & 0x3FF, cell(6, 16) & 0x3FF, cell(21, 1) & 0x3FF, cell(21, 16) & 0x3FF, table.concat(pal))
  if s ~= last then
    out:write(string.format("%4d %s", frame, s) .. string.char(10))
    out:flush()
    last = s
  end
end, emu.eventType.endFrame)
