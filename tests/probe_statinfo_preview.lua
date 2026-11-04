-- Preview: poke the info panel (build/probe_statinfo_cfg.lua: glyph tiles + 5 rows of cells)
-- straight into VRAM every frame: glyphs into BG3 characters, cells into BG3 map rows 1-5
-- (map at VRAM word $5800, columns 1-30).
pcall(dofile, "C:/Projects/Gamedev/sins of mana/build/probe_statinfo_cfg.lua")
local function vw(word, v)
  emu.write(word * 2, v & 0xFF, emu.memType.snesVideoRam)
  emu.write(word * 2 + 1, (v >> 8) & 0xFF, emu.memType.snesVideoRam)
end
emu.addEventCallback(function()
  if not PROBE_ON then return end
  for _, g in ipairs(GLYPHS_G) do
    for i, b in ipairs(g[2]) do emu.write(g[1] * 16 + i - 1, b, emu.memType.snesVideoRam) end
  end
  for _, r in ipairs(PANEL_G) do
    vw(0x5800 + r[1] * 32, 0x00FF)
    for c, v in ipairs(r[2]) do vw(0x5800 + r[1] * 32 + c, v) end
    vw(0x5800 + r[1] * 32 + 31, 0x00FF)
  end
  -- hide sprites inside the panel's lines (the top HUD portraits)
  for i = 0, 127 do
    local y = emu.read(i * 4 + 1, emu.memType.snesSpriteRam)
    if y >= 8 and y < 48 then emu.write(i * 4 + 1, 0xF0, emu.memType.snesSpriteRam) end
  end
end, emu.eventType.startFrame)
