-- Probe: stack pointer at TickBars entry (hook $FD:6E24) and the lowest S seen inside the bar
-- code and the DMA allocator; also S/D seen in the original sprite builder.
local entryMin, entryMax, inMin, dps = 0xFFFF, 0, 0xFFFF, {}
local done = false
emu.addMemoryCallback(function()
  local s = emu.getState()
  local sp = s["cpu.sp"]
  if sp < entryMin then entryMin = sp end
  if sp > entryMax then entryMax = sp end
end, emu.callbackType.exec, 0xFD6E24, 0xFD6E24)
local function track() local sp = emu.getState()["cpu.sp"]; if sp < inMin then inMin = sp end end
emu.addMemoryCallback(track, emu.callbackType.exec, 0xCBE400, 0xCBE7FF)
emu.addMemoryCallback(track, emu.callbackType.exec, 0xC0206A, 0xC020EB)
emu.addMemoryCallback(track, emu.callbackType.exec, 0xC02230, 0xC02262)
emu.addEventCallback(function()
  if not done and PROBE_ON and emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA then
    done = true
    note(string.format("S at hook: %04X-%04X  lowest S inside bars/alloc: %04X", entryMin, entryMax, inMin))
  end
end, emu.eventType.endFrame)
