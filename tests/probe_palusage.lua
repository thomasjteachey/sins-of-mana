-- Probe: palette use of every tilemap cell of BG1/BG2 (4bpp in mode 1: palette p = CGRAM
-- p*16..p*16+15) and BG3 (2bpp: CGRAM p*4..p*4+3), from the game's register copies at
-- $7F:0800+reg, sampled every 20 frames for FRAMES_G frames -> build/palusage.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
FRAMES_G = 200
pcall(dofile, ROOTB .. "probe_pal_cfg.lua")
local out = io.open(ROOTB .. "palusage.txt", "w")
local frame = 0
local use = {}
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
local function vram16(w) return emu.read(w * 2, emu.memType.snesVideoRam) | (emu.read(w * 2 + 1, emu.memType.snesVideoRam) << 8) end
local function scan(bg, sc)
  local base = (sc >> 2) * 0x400          -- word address
  local size = sc & 3
  local maps = (size == 0) and 1 or ((size == 3) and 4 or 2)
  for m = 0, maps - 1 do
    for i = 0, 1023 do
      local v = vram16(base + m * 1024 + i)
      local pal = (v >> 10) & 7
      local k = string.format("BG%d pal%d", bg, pal)
      use[k] = (use[k] or 0) + 1
    end
  end
end
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if frame % 20 ~= 0 or frame > FRAMES_G then return end
  local mode = r8(0x7F0805)
  scan(1, r8(0x7F0807)); scan(2, r8(0x7F0808)); scan(3, r8(0x7F0809))
  if frame + 20 > FRAMES_G then
    local l = {}
    for k, v in pairs(use) do l[#l + 1] = string.format("%s: %d", k, v) end
    table.sort(l)
    out:write(string.format("BGMODE copy %02X  BG1SC %02X BG2SC %02X BG3SC %02X\n%s\n", mode, r8(0x7F0807), r8(0x7F0808), r8(0x7F0809), table.concat(l, "\n")))
    out:flush()
  end
end, emu.eventType.endFrame)
