-- Probe: execution trace of a code range in one frame -> build/trace.txt.
-- Config (build/probe_trace_cfg.lua): TRACE_FRAME (one frame) or TRACE_F0..TRACE_F1, TRACE_FROM, TRACE_TO
-- (CPU addresses), TRACE_MAX lines.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "trace.txt", "w")
pcall(dofile, ROOTB .. "probe_trace_cfg.lua")
local frame, n = 0, 0
emu.addMemoryCallback(function(addr)
  if not PROBE_ON or n >= (TRACE_MAX or 4000) then return end
  if TRACE_FRAME and frame ~= TRACE_FRAME then return end
  if TRACE_F0 and (frame < TRACE_F0 or frame > TRACE_F1) then return end
  n = n + 1
  local s = emu.getState()
  out:write(string.format("f%d %06X A=%04X X=%04X Y=%04X P=%02X DB=%02X D=%04X S=%04X", frame, addr, s["cpu.a"], s["cpu.x"],
    s["cpu.y"], s["cpu.ps"], s["cpu.dbr"], s["cpu.d"], s["cpu.sp"]) .. string.char(10))
end, emu.callbackType.exec, TRACE_FROM, TRACE_TO)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  out:flush()
end, emu.eventType.endFrame)
