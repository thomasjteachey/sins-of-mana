-- Probe: during battle, log JSR targets executed in bank $D0 (with D and the
-- word at D+$34, the current character's battle record pointer).
local counts, frames = {}, 0
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frames = frames + 1
  if frames == 120 then
    local keys = {}
    for k, v in pairs(counts) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return counts[a] > counts[b] end)
    for i = 1, math.min(40, #keys) do note(string.format("%-40s x%d", keys[i], counts[keys[i]])) end
  end
end, emu.eventType.endFrame)

emu.addMemoryCallback(function(addr)
  if not PROBE_ON or frames >= 120 then return end
  local op = emu.read(addr, emu.memType.snesMemory)
  if op ~= 0x20 then return end
  local s = emu.getState()
  local target = emu.read16(addr + 1, emu.memType.snesMemory)
  local d = s["cpu.d"]
  local p34 = emu.read16(d + 0x34, emu.memType.snesMemory)
  local key = string.format("JSR D0:%04X from %04X D=%04X [34]=%04X", target, addr & 0xFFFF, d, p34)
  counts[key] = (counts[key] or 0) + 1
end, emu.callbackType.exec, 0xD08000, 0xD0FFFF)
