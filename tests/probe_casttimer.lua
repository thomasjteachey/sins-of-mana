-- Probe: find the caster's timer record -> build/casttimer.txt.
-- At CastStart: the current task word $7F:008C and the clock. A few frames later: every timer in the active
-- list ($7F:00C4 head; +$00 next, +$04 wake, +$06 duration, +$08 remaining when suspended).
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "casttimer.txt", "w")
local frame, at = 0, nil
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
local function nl(s) out:write(s .. string.char(10)); out:flush() end
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local s = emu.getState()
  nl(string.format("f%d CastStart clock %04X value %04X task $7F:008C=%04X $7F:008A=%04X $7F:008E=%04X D=%04X", frame,
    r16(0x7F00C6), s["cpu.x"], r16(0x7F008C), r16(0x7F008A), r16(0x7F008E), s["cpu.d"]))
  at = frame + 3
end, emu.callbackType.exec, 0x56A000, 0x56A000)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if frame == at then
    local clock, node, n, t = r16(0x7F00C6), r16(0x7F00C4), 0, {}
    while node ~= 0 and n < 40 do
      t[#t + 1] = string.format("%04X:wake+%d dur %d", node, (r16(0x7F0000 + node + 4) - clock) & 0xFFFF, r16(0x7F0000 + node + 6))
      node = r16(0x7F0000 + node); n = n + 1
    end
    nl(string.format("f%d clock %04X timers: %s", frame, clock, table.concat(t, "  ")))
  end
end, emu.eventType.endFrame)
