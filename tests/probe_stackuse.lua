-- Probe: which instructions read $03C0-$03EF (the stack area our bar code dips into)?
-- Logs each distinct PC once with its opcode byte.
local seen, done, list = {}, false, {}
emu.addMemoryCallback(function(addr)
  if not PROBE_ON then return end
  local s = emu.getState()
  local pc = (s["cpu.k"] << 16) | s["cpu.pc"]
  if not seen[pc] then
    seen[pc] = true
    local op = emu.read(pc, emu.memType.snesMemory)
    list[#list + 1] = string.format("%06X op=%02X addr=%04X S=%04X D=%04X", pc, op, addr & 0xFFFF, s["cpu.sp"], s["cpu.d"])
  end
end, emu.callbackType.read, 0x000380, 0x0003C7)
emu.addEventCallback(function()
  if not done and PROBE_ON and emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA then
    done = true
    for _, l in ipairs(list) do note(l) end
    note("distinct readers: " .. #list)
  end
end, emu.eventType.endFrame)
