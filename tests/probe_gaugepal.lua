-- Probe: palettes used by the game's own BG3 HUD cells (not our icon tiles $0C0-$0DC), sampled
-- every 30 frames -> build/gaugepal.txt (counts per palette, and the rows they're on).
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "gaugepal.txt", "w")
local frame, tot = 0, {}
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if frame % 30 ~= 0 then return end
  local c = {}
  for row = 0, 27 do
    if row <= 4 or row >= 22 then
      for col = 0, 31 do
        local v = r16(0x7E4000 + (row * 32 + col) * 2)
        local tile, pal = v & 0x3FF, (v >> 10) & 7
        if tile ~= 0xFF and (tile < 0xC0 or tile > 0xDC) then
          local k = string.format("p%d", pal)
          c[k] = (c[k] or 0) + 1
          tot[k .. "@row" .. row] = true
        end
      end
    end
  end
  local l = {}
  for k, v in pairs(c) do l[#l + 1] = k .. "=" .. v end
  table.sort(l)
  out:write(string.format("F%d %s\n", frame, table.concat(l, " "))); out:flush()
end, emu.eventType.endFrame)
