-- Probe: value changes of the menu script variables $7F:F200-$F2CF, sampled at frame end -> build/vmvars.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "vmvars.txt", "w")
local frame, prev = 0, {}
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  local parts = {}
  for a = 0x7FF200, 0x7FF2CF do
    local v = emu.read(a, emu.memType.snesMemory)
    if prev[a] ~= nil and prev[a] ~= v then parts[#parts + 1] = string.format("%04X:%02X>%02X", a & 0xFFFF, prev[a], v) end
    prev[a] = v
  end
  if #parts > 0 and #parts < 40 then out:write("f" .. frame .. " " .. table.concat(parts, " ") .. string.char(10)) end
  out:flush()
end, emu.eventType.endFrame)
