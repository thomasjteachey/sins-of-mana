-- Probe: each string the text engine starts ($C0:EAC8 / $C0:EADA: A = bank, Y = address),
-- with its decoded text, per frame after the first press -> build/lines.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "lines.txt", "w")
local frame, armed = 0, false
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
local cur = nil
local function start()
  if not armed then return end
  local s = emu.getState()
  cur = { f = frame, bank = s["cpu.a"] & 0xFF, addr = s["cpu.y"], text = {} }
  out:write(string.format("F%d string %02X:%04X\n", frame, cur.bank, cur.addr))
end
emu.addMemoryCallback(start, emu.callbackType.exec, 0xC0EAC8, 0xC0EAC8)
emu.addMemoryCallback(start, emu.callbackType.exec, 0xC0EADA, 0xC0EADA)
-- glyph render entry: A = character code (+ flags)
local function glyph()
  if not armed then return end
  local a = emu.getState()["cpu.a"] & 0x7F
  out:write(string.format("%s", (a >= 0x20 and a < 0x7F) and string.char(a) or string.format("<%02X>", a)))
end
emu.addMemoryCallback(glyph, emu.callbackType.exec, 0xC0ECF6, 0xC0ECF6)
emu.addMemoryCallback(glyph, emu.callbackType.exec, 0xC0ECFE, 0xC0ECFE)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  local pad = r8(0x4218) | (r8(0x4219) << 8)
  if pad ~= 0 and not armed then armed = true; out:write(string.format("\npress %04X at %d\n", pad, frame)) end
  out:flush()
end, emu.eventType.endFrame)
