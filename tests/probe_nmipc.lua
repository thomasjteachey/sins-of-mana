-- Probe: where the main code was when each NMI hit (histogram of interrupted PB:PC).
-- Frames interrupted outside the idle/wait loops = the CPU was still busy at vblank.
local hist, frames, done = {}, 0, false
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local s = emu.getState()
  local sp = s["cpu.sp"]
  local p = 0x7E0000 + sp
  local pc = emu.read(p + 2, emu.memType.snesMemory) | (emu.read(p + 3, emu.memType.snesMemory) << 8)
  local pb = emu.read(p + 4, emu.memType.snesMemory)
  local k = string.format("%02X:%04X", pb, pc)
  hist[k] = (hist[k] or 0) + 1
  frames = frames + 1
end, emu.callbackType.exec, 0xC033A8, 0xC033A8)
emu.addEventCallback(function()
  if not done and PROBE_ON and emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA then
    done = true
    local l = {}
    for k, v in pairs(hist) do l[#l + 1] = {k, v} end
    table.sort(l, function(a, b) return a[2] > b[2] end)
    local t = {}
    for i = 1, math.min(12, #l) do t[#t + 1] = l[i][1] .. "=" .. l[i][2] end
    note("NMIPC nmis=" .. frames .. " " .. table.concat(t, " "))
  end
end, emu.eventType.endFrame)
