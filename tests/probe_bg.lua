-- Probe: log BG layer settings and dump all of VRAM (64 KB) to build/ram/vram_all.bin
local done = false
emu.addEventCallback(function()
  if not PROBE_ON or done then return end
  done = true
  local s = emu.getState()
  local keys = {}
  for k, v in pairs(s) do
    if string.find(k, "^ppu%.layers") or k == "ppu.bgMode" or string.find(k, "^ppu%.mainScreenLayers") or string.find(k, "^ppu%.subScreenLayers") or string.find(k, "mode1Bg3Priority") then
      keys[#keys + 1] = k .. "=" .. tostring(v)
    end
  end
  table.sort(keys)
  note(table.concat(keys, "\n"))
  local parts = {}
  for base = 0, 0xFFFF, 0x1000 do
    local chunk = {}
    for i = 0, 0xFFF do chunk[i + 1] = emu.read(base + i, emu.memType.snesVideoRam) end
    parts[#parts + 1] = string.char(table.unpack(chunk))
  end
  local f = io.open("C:/Projects/Gamedev/sins of mana/build/ram/vram_all.bin", "wb")
  f:write(table.concat(parts)); f:close()
end, emu.eventType.endFrame)
