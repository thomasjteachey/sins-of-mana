-- Probe: at $7E:1FFF = AA dump bar slots + ready table, then log BG3 scroll writes (scanline)
-- during the following frame.
local stage, lines = 0, {}
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
for _, base in ipairs({0x000000, 0x800000}) do
  emu.addMemoryCallback(function(a, v)
    if stage ~= 2 then return end
    lines[#lines + 1] = string.format("L%d %04X=%02X", emu.getState()["ppu.scanline"] or -1, a & 0xFFFF, v)
  end, emu.callbackType.write, base + 0x2111, base + 0x2112)
end
emu.addEventCallback(function()
  if not PROBE_ON then return end
  if stage == 2 then note("SCROLLW " .. table.concat(lines, " ")); stage = 3; return end
  if stage == 1 then stage = 2; return end
  if stage == 0 and emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA then
    stage = 1
    local t = {}
    for k = 0, 7 do
      if r16(0x7E2848 + k * 2) ~= 0 then
        t[#t + 1] = string.format("[%d code=%04X x=%d y=%d]", k, r16(0x7E2858 + k * 2), r16(0x7E2868 + k * 2), r16(0x7E2878 + k * 2))
      end
    end
    note("SLOTS " .. table.concat(t, " "))
    local p, e = 0x7E0000 + r16(0x7E2844), {}
    for i = 1, 20 do
      local c = emu.read(p, emu.memType.snesMemory)
      if c == 0 then break end
      e[#e + 1] = string.format("%d:%04X,%04X", c, r16(p + 1), r16(p + 3)); p = p + 5
    end
    note("TABLE " .. table.concat(e, " "))
  end
end, emu.eventType.endFrame)
