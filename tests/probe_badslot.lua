-- Probe: simulate the bad icon-palette counter seen in the user's state 5: at the first call of
-- the icon palette copy ($E8:C18F) set [D+$79] = $042E, then report the field's tile block 0
-- ($7E:8C00-$8C0F) and the counter after the call -> build/badslot.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "badslot.txt", "w")
local frame, done, after = 0, false, -1
local function nl(s) out:write(s .. string.char(10)); out:flush() end
local function hex(a, n)
  local t = {}
  for i = 0, n - 1 do t[#t + 1] = string.format("%02X", emu.read(a + i, emu.memType.snesMemory)) end
  return table.concat(t, " ")
end
local D = 0
emu.addMemoryCallback(function()
  if not PROBE_ON or done then return end
  done = true
  D = emu.getState()["cpu.d"]
  emu.write16(0x7E0000 + D + 0x79, 0x042E, emu.memType.snesMemory)
  nl(string.format("f%d set [%04X+79] = 042E; block 0 before: %s", frame, D, hex(0x7E8C00, 16)))
  after = frame + 2
end, emu.callbackType.exec, 0xE8C18F, 0xE8C18F)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if frame == after then
    nl(string.format("f%d block 0 after:  %s", frame, hex(0x7E8C00, 16)))
    nl(string.format("f%d counter now %04X", frame, emu.read16(0x7E0000 + D + 0x79, emu.memType.snesMemory)))
  end
end, emu.eventType.endFrame)
