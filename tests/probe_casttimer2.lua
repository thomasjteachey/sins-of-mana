-- Probe: follow the cast's wait timer and the caster's state frame by frame -> build/casttimer2.txt.
-- The cast timer is the timer in the active list with duration = cast value + 1 a frame after CastStart.
-- Per frame (on change): caster state (CT_REC +$00), clock, whether the timer is linked, its wake/+$08, and
-- the list of timers with duration >= 100 (other long waits).
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "casttimer2.txt", "w")
pcall(dofile, ROOTB .. "probe_casttimer2_cfg.lua")
local REC = CT_REC or 0xF060
local frame, value, t0, timer, last = 0, nil, nil, nil, ""
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
local function nl(s) out:write(s .. string.char(10)); out:flush() end
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  value = emu.getState()["cpu.x"]; t0 = r16(0x7F00C6); timer = nil
  nl(string.format("f%d CastStart clock %04X value %d", frame, t0, value))
end, emu.callbackType.exec, 0x56A000, 0x56A000)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if not value then return end
  local clock = r16(0x7F00C6)
  local node, n, linked, longs = r16(0x7F00C4), 0, false, {}
  while node ~= 0 and n < 60 do
    local dur = r16(0x7F0000 + node + 6)
    if not timer and dur == value + 1 then timer = node end
    if node == timer then linked = true end
    if dur >= 100 then longs[#longs + 1] = string.format("%04X:%d/%d", node, (r16(0x7F0000 + node + 4) - clock) & 0xFFFF, dur) end
    node = r16(0x7F0000 + node); n = n + 1
  end
  local ts = timer and string.format("timer %04X %s wake-clock %d save %d", timer, linked and "linked" or "OFF",
    ((r16(0x7F0000 + timer + 4) - clock + 0x8000) & 0xFFFF) - 0x8000, r16(0x7F0000 + timer + 8)) or "timer ?"
  local s = string.format("st %02X win %s %s | long: %s", r8(0x7F0000 + REC), r8(0x7F0032) ~= 0 and "up" or "--", ts,
    table.concat(longs, " "))
  if s ~= last then
    nl(string.format("f%d clock+%d %s", frame, (clock - t0) & 0xFFFF, s))
    last = s
  end
end, emu.eventType.endFrame)
