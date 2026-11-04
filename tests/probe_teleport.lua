-- Probe: move the party leader (entity slot 0's sprite object +$83 x, +$87 ground y) to the
-- positions in TP_G, one every 60 frames (written for frames k*60+2 .. k*60+8), so screenshots
-- taken late in each 60-frame step show that part of the map. Logs the positions reached.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
TP_G = TP_G or {}
pcall(dofile, ROOTB .. "probe_tp_cfg.lua")
local out = io.open(ROOTB .. "teleport.txt", "w")
local frame = 0
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
local function w16(a, v)
  emu.write(a - 0x7E0000, v & 0xFF, emu.memType.snesWorkRam)
  emu.write(a - 0x7E0000 + 1, (v >> 8) & 0xFF, emu.memType.snesWorkRam)
end
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  local k = (frame - 1) // 60 + 1
  local f = (frame - 1) % 60
  local p = TP_G[k]
  if p and f >= 2 and f <= 8 then
    for s = 0, 2 do
      local rec = r16(0x7E2040 + s * 2)
      if rec ~= 0 then
        local obj = r16(0x7F0000 + rec + 4)
        if obj ~= 0 then
          w16(0x7F0000 + obj + 0x83, p[1] + s * 8)
          w16(0x7F0000 + obj + 0x87, p[2])
        end
      end
    end
  end
  if p and f == 50 then
    local rec = r16(0x7E2040)
    local obj = r16(0x7F0000 + rec + 4)
    out:write(string.format("step %d want %d,%d at %d,%d camera %d,%d", k, p[1], p[2], r16(0x7F0000 + obj + 0x83),
      r16(0x7F0000 + obj + 0x87), r16(0x7F032A), r16(0x7F032C)) .. string.char(10))
    out:flush()
  end
end, emu.eventType.endFrame)
