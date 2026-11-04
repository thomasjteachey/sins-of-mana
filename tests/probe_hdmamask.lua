-- Probe: the game's HDMA mask copy $7F:0032 per frame, and for each enabled channel its
-- control/target ($43x0/$43x1) -> build/hdmamask.txt (one line per change).
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "hdmamask.txt", "w")
local frame, last = 0, nil
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  local m = r8(0x7F0032)
  local s = string.format("mask %02X", m)
  for c = 0, 7 do
    if (m >> c) & 1 == 1 then
      s = s .. string.format("  ch%d:%02X->21%02X", c, r8(0x4300 + c * 16), r8(0x4301 + c * 16))
    end
  end
  if s ~= last then out:write(string.format("F%d %s\n", frame, s)); out:flush(); last = s end
end, emu.eventType.endFrame)
