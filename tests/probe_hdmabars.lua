-- Probe: at frame N (poke $7E:1FFF=AA) dump bar slots, the ready HDMA table and $420C usage.
local done = false
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
emu.addEventCallback(function()
  if not PROBE_ON or done or emu.read(0x1FFF, emu.memType.snesWorkRam) ~= 0xAA then return end
  done = true
  local t = {}
  for k = 0, 7 do
    t[#t + 1] = string.format("[%d own=%04X code=%04X x=%d y=%d]", k, r16(0x7E2848 + k * 2), r16(0x7E2858 + k * 2), r16(0x7E2868 + k * 2), r16(0x7E2878 + k * 2))
  end
  note("SLOTS seen=" .. string.format("%02X", r16(0x7E2888)) .. " active=" .. r16(0x7E2846) .. " " .. table.concat(t, " "))
  local ready = r16(0x7E2844)
  local e = {}
  local p = 0x7E0000 + ready
  for i = 1, 20 do
    local c = emu.read(p, emu.memType.snesMemory)
    if c == 0 then e[#e + 1] = "END"; break end
    e[#e + 1] = string.format("%d:%04X,%04X", c, r16(p + 1), r16(p + 3))
    p = p + 5
  end
  note(string.format("TABLE @%04X stamp=%d ticks=%d %s", ready, r16(0x7E2842), r16(0x7F00C6), table.concat(e, " ")))
end, emu.eventType.endFrame)
