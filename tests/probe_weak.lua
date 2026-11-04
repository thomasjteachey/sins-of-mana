-- Probe: enemy weakness state per frame (changes only) -> build/weak.txt: text task $0428/$042E,
-- window HDMA $7F:0032, !WeakRec/!WeakDP/!WeakOn/!WeakX ($7E:28F6/28F8/28FA/28FC).
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "weak.txt", "w")
local frame, last = 0, ""
local function w(a) return emu.read(a, emu.memType.snesMemory) | (emu.read(a + 1, emu.memType.snesMemory) << 8) end
emu.addMemoryCallback(function()
  if PROBE_ON then out:write(string.format("f%d   name op, $0428=%04X", frame, w(0x7E0428)) .. string.char(10)) end
end, emu.callbackType.exec, 0xC46A6A, 0xC46A6A)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  local s = string.format("0428=%04X 0032=%02X rec=%04X dp=%04X on=%04X x=%04X", w(0x7E0428), emu.read(0x7F0032, emu.memType.snesMemory), w(0x7E28F6), w(0x7E28F8), w(0x7E28FA), w(0x7E28FC))
  if s ~= last then out:write("f" .. frame .. " " .. s .. string.char(10)); out:flush(); last = s end
end, emu.eventType.endFrame)
