-- Probe: what the menu text engine produced, per character -> build/text_<TEXT_TAG>.txt.
--   L line: after the character is copied into the shift buffer ($C0:ED78):
--           checksum of $7E:3090-$30BC, X, Y, A, carry.
--   B line: after each tile column ($C0:EFE1 / $C0:EFEA, right after JSR $F075):
--           the 16 bytes at $7E:3400+Y(entry), X, Y, A, carry.
-- The same actions on two ROMs must give the same lines.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
TEXT_TAG = "x"
pcall(dofile, ROOTB .. "probe_text_cfg.lua")
local out = io.open(ROOTB .. "text_" .. TEXT_TAG .. ".txt", "w")
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
local count = 0
local yEntry = nil
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  yEntry = emu.getState()["cpu.y"]
end, emu.callbackType.exec, 0xC0F075, 0xC0F075)
local function after()
  if not PROBE_ON or not yEntry then return end
  local s = emu.getState()
  local b = {}
  for i = 0, 15 do b[#b + 1] = string.format("%02X", r8(0x7E3400 + yEntry + i)) end
  out:write(string.format("B y=%04X %s X=%04X Y=%04X A=%04X C=%d\n", yEntry, table.concat(b), s["cpu.x"], s["cpu.y"],
    s["cpu.a"], s["cpu.ps"] & 1))
  yEntry = nil
  count = count + 1
end
emu.addMemoryCallback(after, emu.callbackType.exec, 0xC0EFE1, 0xC0EFE1)
emu.addMemoryCallback(after, emu.callbackType.exec, 0xC0EFEA, 0xC0EFEA)
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local s = emu.getState()
  local h = 0
  for i = 0, 0x2C do h = (h * 31 + r8(0x7E3090 + i)) % 4294967291 end
  out:write(string.format("L %u X=%04X Y=%04X A=%04X C=%d\n", h, s["cpu.x"], s["cpu.y"], s["cpu.a"], s["cpu.ps"] & 1))
end, emu.callbackType.exec, 0xC0ED78, 0xC0ED78)
emu.addEventCallback(function() out:flush() end, emu.eventType.endFrame)
