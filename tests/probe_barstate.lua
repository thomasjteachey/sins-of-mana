-- Probe: per frame, the bar engine's slot table (owners, codes, x, y, seen) and the HUD
-- icon bookkeeping -> build/barstate_<BS_TAG>.txt (BS_TAG from build/probe_bs_cfg.lua).
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
BS_TAG = "x"
pcall(dofile, ROOTB .. "probe_bs_cfg.lua")
local out = io.open(ROOTB .. "barstate_" .. BS_TAG .. ".txt", "w")
local frame = 0
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if frame > 40 then return end
  local t = {}
  for i = 0, 7 do
    t[#t + 1] = string.format("%04X:%04X@%d,%d", r16(0x7E2848 + i * 2), r16(0x7E2858 + i * 2), r16(0x7E2868 + i * 2), r16(0x7E2878 + i * 2))
  end
  local h = {}
  for i = 0, 37 do h[#h + 1] = string.format("%04X", r16(0x7E2A00 + i * 2)) end
  out:write(string.format("F%d seen=%04X act=%d %s | hud %s\n", frame, r16(0x7E2888), r16(0x7E2846), table.concat(t, " "), table.concat(h, "")))
  out:flush()
end, emu.eventType.endFrame)
