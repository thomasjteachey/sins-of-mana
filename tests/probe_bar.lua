-- Probe: each frame, log the knight's hate, its bar offset (Book slot 3) and the
-- 4 BG3 copy cells there, plus the same 4 cells as they are in VRAM.
local frames = 0
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frames = frames + 1
  if frames > 14 then return end
  local function w(a) return emu.read16(a, emu.memType.snesWorkRam) end
  local hate = emu.read(0x1DA80, emu.memType.snesWorkRam)
  local off = w(0x4700 + 3 * 2)
  local cells, vcells = {}, {}
  for k = 0, 3 do
    cells[#cells + 1] = string.format("%04X", w(0x4000 + off + k * 2))
    local va = (0x5800 + (off >> 1) + k) * 2
    vcells[#vcells + 1] = string.format("%04X", emu.read16(va, emu.memType.snesVideoRam))
  end
  note(string.format("f%02d hate %3d off %04X copy %s vram %s", frames, hate, off,
    table.concat(cells, " "), table.concat(vcells, " ")))
end, emu.eventType.endFrame)
