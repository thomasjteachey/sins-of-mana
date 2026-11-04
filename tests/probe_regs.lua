-- Probe: for one frame after $7E:1FFF = AA, log writes to BG3/screen registers with scanline,
-- and HDMA channel setup ($43x0/$43x1) for enabled channels.
local stage, lines = 0, {}
local regs = {0x2105, 0x2109, 0x2111, 0x2112, 0x212C, 0x212D, 0x2130, 0x2131, 0x2132, 0x420C, 0x4200, 0x2126, 0x2127, 0x2123, 0x2124, 0x2125}
for _, base in ipairs({0x000000, 0x800000}) do
  for _, r in ipairs(regs) do
    emu.addMemoryCallback(function(a, v)
      if stage ~= 2 then return end
      local s = emu.getState()
      lines[#lines + 1] = string.format("L%d %04X=%02X", s["ppu.scanline"] or -1, a & 0xFFFF, v)
    end, emu.callbackType.write, base + r, base + r)
  end
end
emu.addEventCallback(function()
  if not PROBE_ON then return end
  if stage == 2 then
    note("REGS " .. table.concat(lines, " "))
    local h = {}
    for ch = 0, 7 do
      h[#h + 1] = string.format("ch%d:%02X>%02X", ch, emu.read(0x4300 + ch * 16, emu.memType.snesMemory), emu.read(0x4301 + ch * 16, emu.memType.snesMemory))
    end
    note("HDMACH " .. table.concat(h, " ") .. string.format(" shadow0032=%02X", emu.read(0x7F0032, emu.memType.snesMemory)))
    stage = 3; return
  end
  if stage == 1 then stage = 2; return end
  if stage == 0 and emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA then stage = 1 end
end, emu.eventType.endFrame)
