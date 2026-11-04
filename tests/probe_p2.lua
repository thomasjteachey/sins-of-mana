-- Probe: controller 2 presses on a schedule (P2_SCHEDULE = { {frame=, keys="start", hold=}, ... } in
-- build/probe_p2_cfg.lua), plus the cast/ring logging of probe_castring.lua -> build/castring.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
pcall(dofile, ROOTB .. "probe_p2_cfg.lua")
dofile("C:/Projects/Gamedev/sins of mana/tests/probe_castring.lua")
local sched = P2_SCHEDULE or {}
local f2 = 0
emu.addEventCallback(function()
  if PROBE_ON then f2 = f2 + 1 end
end, emu.eventType.endFrame)
emu.addEventCallback(function()
  local inp = {}
  for _, s in ipairs(sched) do
    if f2 >= s.frame and f2 < s.frame + (s.hold or 3) then
      for k in string.gmatch(s.keys, "[^+]+") do inp[k] = true end
    end
  end
  emu.setInput(inp, 1)
end, emu.eventType.inputPolled)
