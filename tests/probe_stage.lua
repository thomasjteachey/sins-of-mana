-- Probe: stage the ice cave battle (build/states/icecave.mss) for a screenshot that shows
-- every bar feature at once. From frame STAGE_F to STAGE_F+10 it keeps writing:
--   enemy hate (revenge bars: green / yellow / red), one raised and one lowered enemy stat
--   (bar arrows), party stat changes (HUD icons: raised, lowered, Lucid Barrier), and an
--   enemy "cast" (state $0A + cast book entry) because no enemy here casts for real.
local STAGE_F = STAGE_G or 326
pcall(dofile, "C:/Projects/Gamedev/sins of mana/build/probe_stage_cfg.lua")
STAGE_F = STAGE_G or STAGE_F
local frame, tick0 = 0, nil
local function w8(a, v) emu.write(a - 0x7E0000, v, emu.memType.snesWorkRam) end
local function w16(a, v) w8(a, v & 0xFF); w8(a + 1, (v >> 8) & 0xFF) end
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if frame < STAGE_F or frame > STAGE_F + (STAGE_LEN_G or 10) then return end
  w8(0x7FE280, 20)          -- enemy $E160 hate 20/63  (green)
  w8(0x7FDF80, 55)          -- enemy $DE60 hate 55/100 (yellow)
  w8(0x7FCF80, 50)          -- enemy $CE60 hate 50/63  (red)
  w8(0x7FE225, 0x40)        -- $E160 attack raised  -> green up arrow
  w8(0x7FDF26, 0x08)        -- $DE60 defense lowered -> red down arrow
  w8(0x7FF125, 0x58); w8(0x7FF126, 0x94); w8(0x7FF127, 0x54)   -- party: mixed, Lucid Barrier
  w8(0x7FF425, 0x48)
  w8(0x7FF725, 0x04); w8(0x7FF726, 0x08)
  if not tick0 then tick0 = r16(0x7F00C6) end
  w16(0x7E2810, (tick0 - 70) & 0xFFFF)   -- cast book, entity slot 4 ($DE60): start
  w16(0x7E2812, 200)                     -- expected length
  w8(0x7FDE60, 0x0A)                     -- state: casting
end, emu.eventType.endFrame)
-- the enemy's own update rewrites its state during the frame: set it again right where
-- the bar code starts reading ($CB:E40B, Bars' code after the sprite builder)
emu.addMemoryCallback(function()
  if not PROBE_ON or frame < STAGE_F or frame > STAGE_F + (STAGE_LEN_G or 10) then return end
  w8(0x7FDE60, 0x0A)
end, emu.callbackType.exec, 0xCBE40B, 0xCBE40B)
