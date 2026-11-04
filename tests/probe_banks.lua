-- Probe: instructions executed per bank group over the run (no getState: cheap), plus lag
-- frames (sprite builder not run). Summary when $7E:1FFF = AA.
local cnt = {}
local per, lag, frames, done = 0, 0, 0, false
emu.addMemoryCallback(function(addr)
  local b = addr >> 16
  cnt[b] = (cnt[b] or 0) + 1
end, emu.callbackType.exec, 0x000000, 0xFFFFFF)
emu.addMemoryCallback(function() per = per + 1 end, emu.callbackType.exec, 0xFD6E24, 0xFD6E24)
emu.addEventCallback(function()
  if not PROBE_ON then cnt = {}; per = 0; return end
  frames = frames + 1
  if per == 0 then lag = lag + 1 end
  per = 0
  if not done and emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA then
    done = true
    local fast, slow, wram, total = 0, 0, 0, 0
    local list = {}
    for b, n in pairs(cnt) do
      total = total + n
      if b >= 0xC0 or (b >= 0x80 and b < 0xC0) then fast = fast + n
      elseif b >= 0x40 and b < 0x7E then slow = slow + n
      else wram = wram + n end
      list[#list + 1] = {b, n}
    end
    table.sort(list, function(x, y) return x[2] > y[2] end)
    local top = {}
    for i = 1, math.min(10, #list) do top[#top + 1] = string.format("%02X:%d%%", list[i][1], list[i][2] * 100 // total) end
    note(string.format("BANKS frames=%d lag=%d instr/frame=%d fast=%d%% slow(mod $40-$7D)=%d%% other=%d%% top: %s",
      frames, lag, total // frames, fast * 100 // total, slow * 100 // total, wram * 100 // total, table.concat(top, " ")))
  end
end, emu.eventType.endFrame)
