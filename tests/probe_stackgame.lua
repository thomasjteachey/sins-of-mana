-- Probe: lowest S (above $0200, i.e. not the NMI stack) reached by any code, and where.
local minS, where, done = 0xFFFF, "", false
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local s = emu.getState()
  local sp = s["cpu.sp"]
  if sp >= 0x0200 and sp < 0x0400 and sp < minS then minS = sp; where = string.format("%02X:%04X", s["cpu.k"], s["cpu.pc"]) end
end, emu.callbackType.exec, 0x000000, 0xFFFFFF)
emu.addEventCallback(function()
  if not done and PROBE_ON and emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA then
    done = true
    note(string.format("lowest S %04X at %s", minS, where))
  end
end, emu.eventType.endFrame)
