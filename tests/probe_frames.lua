-- Probe: from $7E:1FFF = AA on, for 6 frames log slot y values and the ready table (one line each).
local n = -1
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
emu.addEventCallback(function()
  if not PROBE_ON then return end
  if n < 0 and emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA then n = 0 end
  if n < 0 or n >= 6 then return end
  local t = {}
  for k = 0, 2 do t[#t + 1] = string.format("s%d y=%d", k, r16(0x7E2878 + k * 2)) end
  local p, e = 0x7E0000 + r16(0x7E2844), {}
  for i = 1, 12 do
    local c = emu.read(p, emu.memType.snesMemory); if c == 0 then break end
    e[#e + 1] = string.format("%d:%04X", c, r16(p + 3)); p = p + 5
  end
  note(string.format("F%d %s | %s | busy22=%d busy21=%d", n, table.concat(t, " "), table.concat(e, " "),
    emu.read(0x7E28C0 + 22, emu.memType.snesMemory), emu.read(0x7E28C0 + 21, emu.memType.snesMemory)))
  n = n + 1
end, emu.eventType.endFrame)
