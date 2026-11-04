-- Probe: reads of the enemy records (entity slots 3-5: $7F:E160, $DE60, $CE60) at offsets +$90..+$1FF between
-- ER_F0 and ER_F1 -> build/elemreads.txt: offset, PC, count, value (to find element weakness fields).
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
pcall(dofile, ROOTB .. "probe_elemreads_cfg.lua")
local F0, F1 = ER_F0 or 455, ER_F1 or 530
local frame, seen = 0, {}
local recs = {0xE160, 0xDE60, 0xCE60}
for _, rec in ipairs(recs) do
  emu.addMemoryCallback(function(a)
    if not PROBE_ON or frame < F0 or frame > F1 then return end
    local s = emu.getState()
    local key = string.format("+%03X %02X:%04X", (a & 0xFFFF) - rec, s["cpu.k"], s["cpu.pc"])
    seen[key] = (seen[key] or 0) + 1
  end, emu.callbackType.read, 0x7F0000 + rec, 0x7F0000 + rec + 0x2FF)
end
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if frame == F1 + 1 then
    local out = io.open(ROOTB .. "elemreads.txt", "w")
    local keys = {}
    for k in pairs(seen) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do out:write(string.format("%s x%d", k, seen[k]) .. string.char(10)) end
    out:close()
  end
end, emu.eventType.endFrame)
