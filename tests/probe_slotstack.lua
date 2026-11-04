-- Probe: deepest stack write into the equip screen's page ($0A40-$0ABF) inside SlotHelpRedraw
-- ($56:8129 .. its .back $56:814F) and outside it -> build/slotstack.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "slotstack.txt", "w")
pcall(dofile, ROOTB .. "probe_slotstack_cfg.lua")
local ENTRY, BACK = SLOT_ENTRY or 0x568129, SLOT_BACK or 0x56814F
local frame, inside, calls = 0, false, 0
local low = {[true] = 0x10000, [false] = 0x10000}
local where = {[true] = "", [false] = ""}
local function nl(s) out:write(s .. string.char(10)); out:flush() end
emu.addMemoryCallback(function()
  if PROBE_ON then inside = true; calls = calls + 1 end
end, emu.callbackType.exec, ENTRY, ENTRY)
emu.addMemoryCallback(function()
  if PROBE_ON then inside = false end
end, emu.callbackType.exec, BACK, BACK)
local function hit(a, v)
  if not PROBE_ON then return end
  local s = emu.getState()
  local sp = s["cpu.sp"]
  local adr = a & 0xFFFF
  if sp < 0x0A00 or sp >= 0x0B00 or adr < sp - 2 or adr > sp + 24 then return end
  if adr < low[inside] then
    low[inside] = adr
    where[inside] = string.format("f%d S=%04X at %02X:%04X", frame, sp, s["cpu.k"], s["cpu.pc"])
    nl(string.format("%s: new lowest %04X (%s)", inside and "inside SlotHelpRedraw" or "outside", adr, where[inside]))
  end
end
emu.addMemoryCallback(hit, emu.callbackType.write, 0x000A40, 0x000ABF)
emu.addMemoryCallback(hit, emu.callbackType.write, 0x7E0A40, 0x7E0ABF)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if frame % 60 == 0 then
    nl(string.format("f%d calls %d  lowest inside %04X  outside %04X", frame, calls, low[true], low[false]))
  end
end, emu.eventType.endFrame)
