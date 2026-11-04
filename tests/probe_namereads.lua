-- Probe: reads of the item-name pointer table copy $D3:9400-$D3:A200 (PC, address, X, Y, DP)
-- -> build/namereads.txt (first 60 distinct).
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "namereads.txt", "w")
local frame, seen, n = 0, {}, 0
emu.addMemoryCallback(function(addr)
  if not PROBE_ON or n > 60 then return end
  local s = emu.getState()
  local sp = s["cpu.sp"]
  local function r8(a) return emu.read(a, emu.memType.snesMemory) end
  local st = {}
  for i = 1, 12 do st[#st + 1] = string.format("%02X", r8(sp + i)) end
  local k = string.format("%02X:%04X reads %06X X=%04X Y=%04X D=%04X stack %s [D+00..0F] %s", s["cpu.k"], s["cpu.pc"], addr, s["cpu.x"], s["cpu.y"], s["cpu.d"], table.concat(st, " "),
    (function() local t = {} for i = 0, 15 do t[#t + 1] = string.format("%02X", r8(s["cpu.d"] + i)) end return table.concat(t, " ") end)())
  if not seen[k] then seen[k] = true; n = n + 1; out:write(string.format("F%d %s", frame, k) .. string.char(10)); out:flush() end
end, emu.callbackType.read, 0xD39400, 0xD3A200)
emu.addEventCallback(function() if PROBE_ON then frame = frame + 1 end end, emu.eventType.endFrame)
