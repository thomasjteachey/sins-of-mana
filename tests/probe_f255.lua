-- Probe: reads/writes of $7F:F255 (target slot) with PC and frame ranges -> build/f255.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local frame, seen, order = 0, {}, {}
local function cb(kind)
  return function(a, v)
    if not PROBE_ON then return end
    local s = emu.getState()
    local key = string.format("%s %02X:%04X", kind, s["cpu.k"], s["cpu.pc"])
    local e = seen[key]
    if not e then e = {first = frame, last = frame, n = 0}; seen[key] = e; order[#order + 1] = key end
    e.last = frame; e.n = e.n + 1
  end
end
emu.addMemoryCallback(cb("R"), emu.callbackType.read, 0x7FF255, 0x7FF255)
emu.addMemoryCallback(cb("W"), emu.callbackType.write, 0x7FF255, 0x7FF255)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if frame % 50 == 0 then
    local out = io.open(ROOTB .. "f255.txt", "w")
    for _, k in ipairs(order) do local e = seen[k]; out:write(string.format("%s f%d-f%d x%d", k, e.first, e.last, e.n) .. string.char(10)) end
    out:close()
  end
end, emu.eventType.endFrame)
