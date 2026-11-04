-- Probe: at the end of the run (poke $7E:1FFF=AA), log PPU display state and dump VRAM/CGRAM.
local done = false
emu.addEventCallback(function()
  if not PROBE_ON or done or emu.read(0x1FFF, emu.memType.snesWorkRam) ~= 0xAA then return end
  done = true
  local s = emu.getState()
  local keys = {}
  for k, v in pairs(s) do
    if string.find(k, "^ppu%.") and not string.find(k, "^ppu%.layers") and not string.find(k, "window") and type(v) ~= "table" then
      keys[#keys + 1] = k .. "=" .. tostring(v)
    end
  end
  table.sort(keys)
  note(table.concat(keys, " "))
  local name = os.getenv("VRAM_NAME") or "vram_probe"
  local t = {}
  for i = 0, 0xFFFF do t[#t + 1] = emu.read(i, emu.memType.snesVideoRam) end
  local parts = {}
  for i = 1, #t, 4096 do parts[#parts + 1] = string.char(table.unpack(t, i, math.min(i + 4095, #t))) end
  local f = io.open("C:/Projects/Gamedev/sins of mana/build/ram/" .. name .. ".bin", "wb"); f:write(table.concat(parts)); f:close()
end, emu.eventType.endFrame)
