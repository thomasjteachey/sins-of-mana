-- Probe: ROM data reads made by code in bank $40 between RD_F0 and RD_F1 -> build/romdmg.txt (address, PC, value).
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
pcall(dofile, ROOTB .. "probe_romdmg_cfg.lua")
local F0, F1 = RD_F0 or 455, RD_F1 or 520
local frame, seen = 0, {}
local function cb(a)
  if not PROBE_ON or frame < F0 or frame > F1 then return end
  local s = emu.getState()
  if RD_BANK and s["cpu.k"] ~= RD_BANK then return end
  local key = string.format("%06X %02X:%04X", a, s["cpu.k"], s["cpu.pc"])
  if not seen[key] then seen[key] = emu.read(a, emu.memType.snesMemory) end
end
emu.addMemoryCallback(cb, emu.callbackType.read, 0xC00000, 0xFFFFFF)
emu.addMemoryCallback(cb, emu.callbackType.read, 0x410000, 0x7DFFFF)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if frame == F1 + 1 then
    local out = io.open(ROOTB .. "romdmg.txt", "w")
    local keys = {}
    for k in pairs(seen) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do out:write(string.format("%s = %02X", k, seen[k]) .. string.char(10)) end
    out:close()
  end
end, emu.eventType.endFrame)
