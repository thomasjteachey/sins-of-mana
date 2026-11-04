-- Probe: dump VRAM (64 KB), CGRAM and OAM at frame VRAMAT_FRAME -> build/ram/<VRAMAT_NAME>_vram.bin etc.
-- Config: build/probe_vramat_cfg.lua (VRAMAT_FRAME, VRAMAT_NAME).
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
pcall(dofile, ROOTB .. "probe_vramat_cfg.lua")
local AT, NAME = VRAMAT_FRAME or 10, VRAMAT_NAME or "vramat"
local frame = 0
local function dump(memType, size, path)
  local t, parts = {}, {}
  for i = 0, size - 1 do t[#t + 1] = emu.read(i, memType) end
  for i = 1, #t, 4096 do parts[#parts + 1] = string.char(table.unpack(t, i, math.min(i + 4095, #t))) end
  local f = io.open(path, "wb"); f:write(table.concat(parts)); f:close()
end
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if frame ~= AT then return end
  dump(emu.memType.snesVideoRam, 0x10000, ROOTB .. "ram/" .. NAME .. "_vram.bin")
  dump(emu.memType.snesCgRam, 0x200, ROOTB .. "ram/" .. NAME .. "_cgram.bin")
  dump(emu.memType.snesSpriteRam, 0x220, ROOTB .. "ram/" .. NAME .. "_oam.bin")
end, emu.eventType.endFrame)
