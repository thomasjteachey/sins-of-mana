-- Probe: when the game writes the map number ($7E:0627), write WARP_G instead (after frame 3),
-- and log every write -> build/warp.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
WARP_G = WARP_G or 0x18
pcall(dofile, ROOTB .. "probe_warp_cfg.lua")
local out = io.open(ROOTB .. "warp.txt", "w")
local frame = 0
local function cb(addr, value)
  if not PROBE_ON or frame < 3 then return end
  local s = emu.getState()
  out:write(string.format("F%d write %02X by %02X:%04X -> %02X", frame, value, s["cpu.k"], s["cpu.pc"], WARP_G) .. string.char(10))
  out:flush()
  return WARP_G
end
for _, a in ipairs({0x7E0627, 0x000627, 0x800627}) do
  emu.addMemoryCallback(cb, emu.callbackType.write, a, a)
end
emu.addEventCallback(function() if PROBE_ON then frame = frame + 1 end end, emu.eventType.endFrame)
