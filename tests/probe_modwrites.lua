-- Probe: for 3 frames, log RAM writes made by code in banks $40/$41 (mod code):
-- unique (pc, address) pairs with the last value.
local frames, seen, order = 0, {}, {}
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frames = frames + 1
  if frames == 4 then
    for _, k in ipairs(order) do note(k .. " last=" .. string.format("%02X", seen[k].v) .. " n=" .. seen[k].n) end
  end
end, emu.eventType.endFrame)
emu.addMemoryCallback(function(addr, value)
  if not PROBE_ON or frames < 1 or frames > 3 then return end
  local s = emu.getState()
  local k = s["cpu.k"]
  if k ~= 0x40 and k ~= 0x41 then return end
  local key = string.format("pc %02X:%04X -> %05X", k, s["cpu.pc"], addr & 0x1FFFF)
  if not seen[key] then seen[key] = { n = 0, v = 0 }; order[#order + 1] = key end
  seen[key].n = seen[key].n + 1
  seen[key].v = value
end, emu.callbackType.write, 0x00000, 0x1FFFF, emu.cpuType.snes, emu.memType.snesWorkRam)
