-- Probe: while Duran's record +$000 == $0A (casting), dump all WRAM each frame
-- (up to 8 dumps) to build/ram/cast<n>.bin.
local n = 0
emu.addEventCallback(function()
  if not PROBE_ON or n >= 8 then return end
  if emu.read(0x1ED60, emu.memType.snesWorkRam) ~= 0x0A then return end
  local parts = {}
  for base = 0, 0x1FFFF, 0x1000 do
    local chunk = {}
    for i = 0, 0xFFF do chunk[i + 1] = emu.read(base + i, emu.memType.snesWorkRam) end
    parts[#parts + 1] = string.char(table.unpack(chunk))
  end
  local f = io.open("C:/Projects/Gamedev/sins of mana/build/ram/cast" .. n .. ".bin", "wb")
  f:write(table.concat(parts)); f:close()
  n = n + 1
end, emu.eventType.endFrame)
