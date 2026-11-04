-- Probe: per frame, log the brightness pointer $7F:00A0, the brightness byte it points to,
-- and every CPU write to that byte (with the PC that wrote it).
local frames = 0
local last = nil
local ptr = nil
local writes = {}
local ref = nil
local function watch(p)
  if ref then emu.removeMemoryCallback(ref, emu.callbackType.write, 0x7F0000 + ptr, 0x7F0000 + ptr) end
  ptr = p
  ref = emu.addMemoryCallback(function(addr, value)
    local s = emu.getState()
    writes[#writes + 1] = string.format("%02X@%02X:%04X", value, s["cpu.k"], s["cpu.pc"])
  end, emu.callbackType.write, 0x7F0000 + p, 0x7F0000 + p)
end
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frames = frames + 1
  local p = emu.read16(0x7F00A0, emu.memType.snesMemory)
  if p ~= ptr then watch(p) end
  local v = emu.read(0x7F0000 + p, emu.memType.snesMemory)
  local line = string.format("ptr=%04X val=%02X", p, v)
  if line ~= last or #writes > 0 then
    note(string.format("f%04d %s %s", frames, line, table.concat(writes, " ")))
    last = line
  end
  writes = {}
end, emu.eventType.endFrame)
