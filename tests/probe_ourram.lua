-- Probe: writes into the mod's RAM ($7E:2800-$2BFF) counted by PC, and every write to the three
-- spots found corrupted in the user's state 5 ($7E:8C00-$8C0F, $7E:FB30-$FB3F, $7F:2B20-$2B2F)
-- -> build/ourram.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "ourram.txt", "w")
local frame, counts, first, nspot = 0, {}, {}, 0
local function nl(s) out:write(s .. string.char(10)); out:flush() end
emu.addMemoryCallback(function(a, v)
  if not PROBE_ON then return end
  local s = emu.getState()
  local key = string.format("%02X:%04X", s["cpu.k"], s["cpu.pc"])
  counts[key] = (counts[key] or 0) + 1
  if not first[key] then first[key] = string.format("f%d %06X=%02X", frame, a, v or -1) end
end, emu.callbackType.write, 0x7E2800, 0x7E2BFF)
local function spot(a, v)
  if not PROBE_ON or nspot > 200 then return end
  nspot = nspot + 1
  local s = emu.getState()
  nl(string.format("SPOT f%d %06X=%02X at %02X:%04X X=%04X Y=%04X D=%04X DB=%02X", frame, a, v or -1, s["cpu.k"], s["cpu.pc"],
    s["cpu.x"], s["cpu.y"], s["cpu.d"], s["cpu.dbr"]))
end
emu.addMemoryCallback(spot, emu.callbackType.write, 0x7E8C00, 0x7E8C0F)
emu.addMemoryCallback(spot, emu.callbackType.write, 0x7EFB30, 0x7EFB3F)
emu.addMemoryCallback(spot, emu.callbackType.write, 0x7F2B20, 0x7F2B2F)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if frame % 120 == 0 then
    local keys = {}
    for k in pairs(counts) do keys[#keys + 1] = k end
    table.sort(keys)
    local f = io.open(ROOTB .. "ourram_pcs.txt", "w")
    for _, k in ipairs(keys) do f:write(string.format("%s %6d  first %s", k, counts[k], first[k]) .. string.char(10)) end
    f:close()
  end
end, emu.eventType.endFrame)
