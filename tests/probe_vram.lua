-- Probe: when $7E:1FFF = AA, dump VRAM, CGRAM, OAM and PPU layer settings to build/ram/<VRAM_NAME>_*.
local done = false
local function dump(memType, size, path)
  local t, parts = {}, {}
  for i = 0, size - 1 do t[#t + 1] = emu.read(i, memType) end
  for i = 1, #t, 4096 do parts[#parts + 1] = string.char(table.unpack(t, i, math.min(i + 4095, #t))) end
  local f = io.open(path, "wb"); f:write(table.concat(parts)); f:close()
end
emu.addEventCallback(function()
  if not PROBE_ON or done or emu.read(0x1FFF, emu.memType.snesWorkRam) ~= 0xAA then return end
  done = true
  local name = "C:/Projects/Gamedev/sins of mana/build/ram/" .. (os.getenv("VRAM_NAME") or "scene")
  dump(emu.memType.snesVideoRam, 0x10000, name .. "_vram.bin")
  dump(emu.memType.snesCgRam, 0x200, name .. "_cgram.bin")
  dump(emu.memType.snesSpriteRam, 0x220, name .. "_oam.bin")
  local s = emu.getState()
  local keys = {}
  for k, v in pairs(s) do
    if (string.find(k, "^ppu%.layers") or string.find(k, "^ppu%.oam") or string.find(k, "^ppu%.bg")) and type(v) ~= "table" then
      keys[#keys + 1] = k .. "=" .. tostring(v)
    end
  end
  table.sort(keys)
  note(table.concat(keys, " "))
end, emu.eventType.endFrame)
