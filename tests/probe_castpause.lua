-- Probe: what pauses while the ring menu is open during a cast -> build/castpause.txt.
-- At CastStart ($56:A000) remember D (the caster's script thread page) and log the cast value; then per
-- frame: caster state (record +$00), !Ticks ($7F:00C6), the bar's elapsed/length from the cast book,
-- $7F:0032 (game HDMA channels: windows), and the thread page D..D+$3F as hex (to spot a countdown).
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "castpause.txt", "w")
local frame, D, rec, slot = 0, nil, nil, nil
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
local function nl(s) out:write(s .. string.char(10)); out:flush() end
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local s = emu.getState()
  D = s["cpu.d"]
  rec = (r16(0x7E0000 + D + 0x34) - 0x90) & 0xFFFF
  for i = 0, 15 do if r16(0x7E2040 + i * 2) == rec then slot = i end end
  nl(string.format("f%d CastStart D=%04X value X=%04X caster rec %04X slot %s", frame, D, s["cpu.x"], rec, tostring(slot)))
end, emu.callbackType.exec, 0x56A000, 0x56A000)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if not D then return end
  local t = {}
  for i = 0, 0x3F do t[#t + 1] = string.format("%02X", r8(0x7E0000 + D + i)) end
  local st = r8(0x7F0000 + rec)
  local start, len = r16(0x7E2800 + slot * 4), r16(0x7E2802 + slot * 4)
  local ticks = r16(0x7F00C6)
  nl(string.format("f%d st %02X ticks %04X elapsed %d/%d hdma %02X | %s", frame, st, ticks, (ticks - start) & 0xFFFF, len,
    r8(0x7F0032), table.concat(t, " ")))
end, emu.eventType.endFrame)
