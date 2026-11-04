-- Probe: log distinct PCs that read/write $7E:094B and $7F:0E17 (with D register).
local seen, list = {}, {}
local function cb(kind, a)
  return function(addr, value)
    if not PROBE_ON then return end
    local s = emu.getState()
    local k = string.format("%s %06X @%02X:%04X D=%04X", kind, addr, s["cpu.k"], s["cpu.pc"], s["cpu.d"])
    if not seen[k] then seen[k] = true; list[#list + 1] = k .. string.format(" v=%02X", value or 0) end
  end
end
for _, a in ipairs({0x7E094B, 0x7F0E17}) do
  emu.addMemoryCallback(cb("W", a), emu.callbackType.write, a, a)
  emu.addMemoryCallback(cb("R", a), emu.callbackType.read, a, a)
end
emu.addEventCallback(function()
  if PROBE_ON and emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA then
    for _, l in ipairs(list) do note(l) end
    emu.write(0x1FFF, 0, emu.memType.snesWorkRam)
  end
end, emu.eventType.endFrame)
