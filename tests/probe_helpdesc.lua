-- Probe: what GetHelpDesc ($56:803E, src/main.asm) works out each time the help box is
-- printed -> build/helpdesc.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "helpdesc.txt", "w")
local frame = 0
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local ch = r8(0x7E0561)
  local rec = r16(0x7E2040 + ch * 2)
  local dp = {}
  for i = 0x3C, 0x4F do dp[#dp + 1] = string.format("%02X", r8(0x7E0500 + i)) end
  local d = emu.getState()["cpu.d"]
  local dd = {}
  for i = 0x3C, 0x41 do dd[#dd + 1] = string.format("%02X", r8(0x7E0000 + d + i)) end
  out:write(string.format("   D=%04X  [D+3C..41]=%s [D+61]=%02X  [0A3C..41]=%02X %02X %02X %02X %02X %02X [0A61]=%02X" .. string.char(10), d, table.concat(dd, " "), r8(0x7E0000 + d + 0x61),
    r8(0x7E0A3C), r8(0x7E0A3D), r8(0x7E0A3E), r8(0x7E0A3F), r8(0x7E0A40), r8(0x7E0A41), r8(0x7E0A61)))
  out:write(string.format("F%d entry char=%d rec=%04X curX=%d curY=%d slot($40)=%d dp3C..4F=%s ents=%04X,%04X,%04X\n",
    frame, ch, rec, r8(0x7F0128), r8(0x7F0129), r8(0x7E0540), table.concat(dp, " "),
    r16(0x7E2040), r16(0x7E2042), r16(0x7E2044)))
end, emu.callbackType.exec, 0x56803E, 0x56803E)
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local s = emu.getState()
  local sp = s["cpu.sp"]
  out:write(string.format("   haveItem item=%02X slot=%d rec=%04X\n", s["cpu.a"] & 0xFF, r16(sp + 1), r16(sp + 3)))
end, emu.callbackType.exec, 0x5680C5, 0x5680C5)
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local s = emu.getState()
  out:write(string.format("   name string FB:%04X -> desc %04X\n", s["cpu.x"], s["cpu.a"]))
end, emu.callbackType.exec, 0x5680EA, 0x5680EA)
emu.addEventCallback(function() if PROBE_ON then frame = frame + 1 end; out:flush() end, emu.eventType.endFrame)
