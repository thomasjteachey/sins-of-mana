-- Probe: per frame (on change of the pattern) !Ticks ($7F:00C6), the game's HDMA channels ($7F:0032,
-- nonzero while a window / ring is drawn), $7E:0A04 (a half-rate counter), $7F:BD5A, and whether Bars ran
-- ($CB:E40B) -> build/ringticks.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "ringticks.txt", "w")
local frame, bars = 0, 0
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
local function nl(s) out:write(s .. string.char(10)); out:flush() end
emu.addMemoryCallback(function() bars = bars + 1 end, emu.callbackType.exec, 0xCBE40B, 0xCBE40B)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  nl(string.format("f%d ticks %04X hdma %02X a04 %04X bd5a %04X bars %d", frame, r16(0x7F00C6), r8(0x7F0032), r16(0x7E0A04),
    r16(0x7FBD5A), bars))
  bars = 0
end, emu.eventType.endFrame)
