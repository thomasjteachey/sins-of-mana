-- Probe: scanline at which our NMI hook writes $420C, histogram over the run.
local hist, late, n, done = {}, 0, 0, false
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local l = emu.getState()["ppu.scanline"]
  n = n + 1
  local b = l < 225 and string.format("next%03d", l) or string.format("%03d", l)
  if l < 225 then late = late + 1 end
  hist[b] = (hist[b] or 0) + 1
end, emu.callbackType.exec, 0xCBED18, 0xCBED18)
emu.addEventCallback(function()
  if not done and PROBE_ON and emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA then
    done = true
    local l = {}
    for k, v in pairs(hist) do l[#l + 1] = k .. ":" .. v end
    table.sort(l)
    note(string.format("NMILINE writes=%d after_frame_start=%d  %s", n, late, table.concat(l, " ")))
  end
end, emu.eventType.endFrame)
