-- Probe: for one frame after $7E:1FFF = AA, log every write to $2111/$2112 with scanline and cycle.
local armed, logging, lines = false, false, {}
for _, base in ipairs({0x000000, 0x800000}) do
  emu.addMemoryCallback(function(a, v)
    if not logging then return end
    local s = emu.getState()
    lines[#lines + 1] = string.format("L%d/H%d %04X=%02X", s["ppu.scanline"] or -1, s["ppu.cycle"] or -1, a & 0xFFFF, v)
  end, emu.callbackType.write, base + 0x2111, base + 0x2112)
end
emu.addEventCallback(function()
  if not PROBE_ON then return end
  if logging then
    logging = false
    note("SCROLLW " .. table.concat(lines, " "))
  elseif not armed and emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA then
    armed = true; logging = true
  end
end, emu.eventType.endFrame)
