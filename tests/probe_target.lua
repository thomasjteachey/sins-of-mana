-- Probe: per-frame target slot ($7F:F255), menu script depth ($7F:F260) and HDMA enables ($7F:0032) -> build/target.txt (changes only).
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "target.txt", "w")
local frame, last = 0, ""
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  local r = function(a) return emu.read(a, emu.memType.snesMemory) end
  local s = string.format("F255=%02X F260=%02X hdma=%02X", r(0x7FF255), r(0x7FF260), r(0x7F0032))
  if s ~= last then out:write("f" .. frame .. " " .. s .. string.char(10)); out:flush(); last = s end
end, emu.eventType.endFrame)
