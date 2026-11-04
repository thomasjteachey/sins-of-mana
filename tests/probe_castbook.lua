-- Probe: controller-2 schedule (P2_SCHEDULE in build/probe_p2_cfg.lua) + per frame (on change) the caster's
-- state, the cast book entry of its slot (CB_SLOT, default 0), the timer it points at (+$04 - clock, +$08)
-- and the window flag -> build/castbook.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "castbook.txt", "w")
pcall(dofile, ROOTB .. "probe_p2_cfg.lua")
local SLOT, REC = CB_SLOT or 0, CB_REC or 0xF060
local function slotOf(rec) for i = 0, 15 do if emu.read16(0x7E2040 + i * 2, emu.memType.snesMemory) == rec then return i end end end
local sched = P2_SCHEDULE or {}
local frame, last = 0, ""
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
local function nl(s) out:write(s .. string.char(10)); out:flush() end
emu.addEventCallback(function()
  local inp = {}
  for _, s in ipairs(sched) do
    if frame >= s.frame and frame < s.frame + (s.hold or 3) then
      for k in string.gmatch(s.keys, "[^+]+") do inp[k] = true end
    end
  end
  emu.setInput(inp, 1)
end, emu.eventType.inputPolled)
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local d = emu.getState()["cpu.d"]
  local rec = (r16(0x7E0000 + d + 0x34) - 0x90) & 0xFFFF
  local sl = slotOf(rec)
  if sl then SLOT, REC = sl, rec end
  nl(string.format("f%d CastStart rec %04X slot %s value %d", frame, rec, tostring(sl), emu.getState()["cpu.x"]))
end, emu.callbackType.exec, 0x56A000, 0x56A000)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  local clock = r16(0x7F00C6)
  local t, len = r16(0x7E2800 + SLOT * 4), r16(0x7E2802 + SLOT * 4)
  local ts = ""
  if t ~= 0 and t ~= 0xFFFF then
    ts = string.format(" timer %04X left %d save %d", t, ((r16(0x7F0000 + t + 4) - clock + 0x8000) & 0xFFFF) - 0x8000,
      r16(0x7F0000 + t + 8))
  end
  local node, ntim = r16(0x7F00C4), 0
  while node ~= 0 and ntim < 80 do node = r16(0x7F0000 + node); ntim = ntim + 1 end
  local s = string.format("st %02X win %s timers %d book %04X/%d%s", r8(0x7F0000 + REC), r8(0x7F0032) ~= 0 and "up" or "--",
    ntim, t, len, ts)
  local key = s:gsub("left %-?%d+", "left")
  if key ~= last then nl(string.format("f%d clock %04X %s", frame, clock, s)); last = key end
end, emu.eventType.endFrame)
