-- Probe: every call of the text print entry $C0:EADA (A = string bank, Y = address, X = text
-- window record) with the return address of its caller -> build/printlog.txt (frames PL_F0+).
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "printlog.txt", "w")
local frame = 0
local F0 = PL_F0 or 1
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
emu.addMemoryCallback(function()
  if not PROBE_ON or frame < F0 then return end
  local s = emu.getState()
  local sp = s["cpu.sp"]
  -- JSL $C0075C -> JML/JMP into $C0:EADA: return address of the JSL is 3 bytes at sp+1
  local rl, rh, rb = r8(sp + 1), r8(sp + 2), r8(sp + 3)
  out:write(string.format("F%d print bank %02X addr %04X X=%04X D=%04X  ret %02X:%02X%02X",
    frame, s["cpu.a"] & 0xFF, s["cpu.y"], s["cpu.x"], s["cpu.d"], rb, rh, rl) .. string.char(10))
  out:flush()
end, emu.callbackType.exec, 0xC0EADA, 0xC0EADA)
emu.addEventCallback(function() if PROBE_ON then frame = frame + 1 end end, emu.eventType.endFrame)
