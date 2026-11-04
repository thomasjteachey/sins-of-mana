-- Probe: dump OAM (544 bytes) and sprite VRAM settings, and find the WRAM
-- buffer the game copies into OAM (search WRAM for the OAM contents).
local done = false
emu.addEventCallback(function()
  if not PROBE_ON or done then return end
  done = true
  local oam = {}
  for i = 0, 543 do oam[i] = emu.read(i, emu.memType.snesSpriteRam) end
  -- visible sprites
  local lines = {}
  for i = 0, 127 do
    local x, y, t, a = oam[i * 4], oam[i * 4 + 1], oam[i * 4 + 2], oam[i * 4 + 3]
    local hb = oam[512 + (i >> 2)] >> ((i & 3) * 2) & 3
    lines[#lines + 1] = string.format("%3d:%3d,%3d t%02X a%02X h%d", i, x + ((hb & 1) * 256), y, t, a, hb >> 1)
  end
  note("OAM: " .. table.concat(lines, " | "))
  -- search WRAM for the first 16 OAM bytes
  local pat = {}
  for i = 0, 15 do pat[i] = oam[i] end
  for base = 0, 0x1FFFF - 16 do
    local ok = true
    for i = 0, 15 do
      if emu.read(base + i, emu.memType.snesWorkRam) ~= pat[i] then ok = false; break end
    end
    if ok then note(string.format("OAM copy candidate at $7E+%05X", base)) end
  end
  local s = emu.getState()
  local keys = {}
  for k, v in pairs(s) do
    if string.find(k, "ppu.oamBase") or string.find(k, "ppu.oamMode") or string.find(k, "ppu.oamAddressOffset") or string.find(k, "ppu.bgMode") then
      keys[#keys + 1] = k .. "=" .. tostring(v)
    end
  end
  note("ppu: " .. table.concat(keys, " "))
end, emu.eventType.endFrame)
