-- Probe: at frame OAM_F (default 3), write OAM (544 bytes) and work RAM (128 KB) of the same
-- moment to build/ram/oam_now.bin and build/ram/wram_now.bin.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/ram/"
local frame = 0
local F = OAM_F or 3
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if frame ~= F then return end
  local o = io.open(ROOTB .. "oam_now.bin", "wb")
  for i = 0, 543 do o:write(string.char(emu.read(i, emu.memType.snesSpriteRam))) end
  o:close()
  local w = io.open(ROOTB .. "wram_now.bin", "wb")
  local t = {}
  for i = 0, 0x1FFFF do
    t[#t + 1] = string.char(emu.read(i, emu.memType.snesWorkRam))
    if #t == 4096 then w:write(table.concat(t)); t = {} end
  end
  w:write(table.concat(t))
  w:close()
end, emu.eventType.endFrame)
