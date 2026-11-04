-- Probe: who yields to the scheduler ($C0:4A6C) in frames FROM_G..TO_G after the first press,
-- with the 24 bytes above the stack pointer (return addresses) -> build/yield.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
FROM_G, TO_G = 11, 16
pcall(dofile, ROOTB .. "probe_yield_cfg.lua")
local out = io.open(ROOTB .. "yield.txt", "w")
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
local frame, armed, startF = 0, false, 0
emu.addMemoryCallback(function()
  if not armed then return end
  local rel = frame - startF
  if rel < FROM_G or rel > TO_G then return end
  local s = emu.getState()
  local sp = s["cpu.sp"]
  local t = {}
  for i = 1, 24 do t[#t + 1] = string.format("%02X", r8(sp + i)) end
  out:write(string.format("F+%d yield A=%04X X=%04X D=%04X S=%04X stack %s\n", rel, s["cpu.a"], s["cpu.x"], s["cpu.d"], sp,
    table.concat(t, " ")))
end, emu.callbackType.exec, 0xC04A6C, 0xC04A6C)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  local pad = r8(0x4218) | (r8(0x4219) << 8)
  if pad ~= 0 and not armed then armed = true; startF = frame end
  out:flush()
end, emu.eventType.endFrame)
