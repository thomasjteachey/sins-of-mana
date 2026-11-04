-- Probe: per frame for 260 frames after CastStart: the tracked timer's fields (+00 next, +02 owner, +04-clock,
-- +06 length, +08 saved) and every timer in the list -> build/castjump.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "castjump.txt", "w")
local frame, startF = 0, nil
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
local function nl(s) out:write(s .. string.char(10)); out:flush() end
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  startF = frame
  nl(string.format("f%d CastStart value %d clock %04X", frame, emu.getState()["cpu.x"], r16(0x7F00C6)))
end, emu.callbackType.exec, 0x56A000, 0x56A000)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if not startF or frame > startF + 260 then return end
  local clock = r16(0x7F00C6)
  local t = r16(0x7E2800)
  local ts = ""
  if t ~= 0 and t ~= 0xFFFF then
    local b = 0x7F0000 + t
    ts = string.format("book %04X: next %04X owner %04X left %d len %d save %d", t, r16(b), r16(b + 2),
      ((r16(b + 4) - clock + 0x8000) & 0xFFFF) - 0x8000, r16(b + 6), r16(b + 8))
  else ts = string.format("book %04X", t) end
  local node, n, l = r16(0x7F00C4), 0, {}
  while node ~= 0 and n < 60 do
    l[#l + 1] = string.format("%04X(%d/%d o%04X)", node, ((r16(0x7F0000 + node + 4) - clock + 0x8000) & 0xFFFF) - 0x8000,
      r16(0x7F0000 + node + 6), r16(0x7F0000 + node + 2))
    node = r16(0x7F0000 + node); n = n + 1
  end
  nl(string.format("f%d clock %04X %s | %s", frame, clock, ts, table.concat(l, " ")))
end, emu.eventType.endFrame)
