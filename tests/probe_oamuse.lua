-- Probe: which sprite tiles in $180-$1FF are referenced by the shadow OAM ($7F:0100) during the
-- run, counted per 16x16 base tile. Summary when $7E:1FFF = AA.
local used, done = {}, false
emu.addEventCallback(function()
  if not PROBE_ON then return end
  for i = 0, 127 do
    local b = 0x7F0100 + i * 4
    local y = emu.read(b + 1, emu.memType.snesMemory)
    if y < 224 or y > 240 then
      local t = emu.read(b + 2, emu.memType.snesMemory) | ((emu.read(b + 3, emu.memType.snesMemory) & 1) << 8)
      if t >= 0x180 then used[t] = (used[t] or 0) + 1 end
    end
  end
  if not done and emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA then
    done = true
    local l = {}
    for t, n in pairs(used) do l[#l + 1] = string.format("%03X:%d", t, n) end
    table.sort(l)
    note("OAMUSE " .. table.concat(l, " "))
  end
end, emu.eventType.endFrame)
