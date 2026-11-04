-- Probe: per frame, did Bars run ($CB:E40B) and is the ring window on the BG3 map
-- (any cell of rows 2-6 with palette 5-7)? -> build/barsrun.txt (changes only)
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "barsrun.txt", "w")
local frame, ran, last = 0, 0, nil
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
emu.addMemoryCallback(function() if PROBE_ON then ran = ran + 1 end end, emu.callbackType.exec, 0xCBE40B, 0xCBE40B)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  local win, rows = 0, {}
  for row = 0, 27 do
    for col = 0, 31 do
      local v = r16(0x7E4000 + (row * 32 + col) * 2)
      local pal = (v >> 10) & 7
      if (v & 0x3FF) ~= 0xFF and pal >= 5 then win = win + 1; rows[row] = true end
    end
  end
  local rl = {}
  for r = 0, 27 do if rows[r] then rl[#rl + 1] = r end end
  local line = string.format("bars_ran=%d window_cells=%d rows=%s", ran, win, table.concat(rl, ","))
  if line ~= last then out:write(string.format("F%d %s\n", frame, line)); out:flush(); last = line end
  ran = 0
end, emu.eventType.endFrame)
