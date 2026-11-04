-- Probe: who writes the HUD pulse colours in the CGRAM copy ($7E:4800 + 2*entry):
-- entries 2-3, 6-7, 10-11, 14-15 (BG3 palettes 0-3, colours 2-3) -> build/pulsew.txt
-- (PC, entry, value), for 240 frames.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "pulsew.txt", "w")
local frame, seen, order = 0, {}, {}
emu.addMemoryCallback(function(addr, value)
  if not PROBE_ON or frame > 240 then return end
  local s = emu.getState()
  local k = string.format("%02X:%04X  addr %04X (entry %d%s)", s["cpu.k"], s["cpu.pc"], addr & 0xFFFF, ((addr & 0xFFFF) - 0x4800) // 2, (addr & 1) == 1 and " hi" or "")
  if not seen[k] then seen[k] = 0; order[#order + 1] = k end
  seen[k] = seen[k] + 1
end, emu.callbackType.write, 0x7E4804, 0x7E481F)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if frame == 240 then
    for _, k in ipairs(order) do out:write(string.format("%5d  %s\n", seen[k], k)) end
    out:flush()
  end
end, emu.eventType.endFrame)
