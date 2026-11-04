-- Probe: per-frame timeline for menu timing -> build/menu_timeline.txt.
-- Per frame: last value written to $2100 (bit 7 = forced blank, low 4 bits = brightness),
-- where the main code was when the NMI hit (idle loop = the frame's work was done),
-- NMIs this frame, game tick delta ($7F:00C6), joypad. Screenshots every SHOT_EVERY
-- frames to build/shots/menu/ (folder must exist).
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
pcall(dofile, ROOTB .. "probe_menu_cfg.lua")
local SHOT_EVERY = SHOT_EVERY_G or 5
local SHOT_MAX = SHOT_MAX_G or 100000
local out = io.open(ROOTB .. "menu_timeline.txt", "w")
local frame, ini, nmipc, nmis, lastTick = 0, 0, "-", 0, nil
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
emu.addMemoryCallback(function(addr, value)
  ini = value
end, emu.callbackType.write, 0x2100, 0x2100)
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local sp = emu.getState()["cpu.sp"]
  local p = 0x7E0000 + sp
  local pc = r8(p + 2) | (r8(p + 3) << 8)
  local pb = r8(p + 4)
  nmipc = string.format("%02X:%04X", pb, pc)
  nmis = nmis + 1
end, emu.callbackType.exec, 0xC033A8, 0xC033A8)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  local t = emu.read16(0x7F00C6, emu.memType.snesMemory)
  local d = lastTick and ((t - lastTick) & 0xFFFF) or 0
  lastTick = t
  local pad = r8(0x4218) | (r8(0x4219) << 8)
  out:write(string.format("%d ini=%02X nmi=%s n=%d tick+%d pad=%04X\n", frame, ini & 0xFF, nmipc, nmis, d, pad))
  out:flush()
  nmis = 0; nmipc = "-"
  if frame % SHOT_EVERY == 0 and frame <= SHOT_MAX then
    local f = io.open(ROOTB .. "shots/menu/" .. string.format("m%05d.png", frame), "wb")
    if f then f:write(emu.takeScreenshot()); f:close() end
  end
end, emu.eventType.endFrame)
