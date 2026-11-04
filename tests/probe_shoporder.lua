-- Probe: frame of each $FB print (address) and of the "Owned" box appearing/disappearing in the
-- BG3 copy (corner (8,1) = tile $040 and "O" at (10,2)) -> build/shoporder.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "shoporder.txt", "w")
local frame, box = 0, false
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local s = emu.getState()
  if (s["cpu.a"] & 0xFF) == 0xFB then
    out:write(string.format("F%d print FB:%04X", frame, s["cpu.y"]) .. string.char(10)); out:flush()
  end
end, emu.callbackType.exec, 0xC0EADA, 0xC0EADA)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  local c = r16(0x7E4000 + (8 * 32 + 1) * 2) & 0x3FF
  local o = r16(0x7E4000 + (10 * 32 + 2) * 2) & 0x3FF
  local now = (c == 0x040 and o == 0x058)
  if now ~= box then out:write(string.format("F%d owned box %s", frame, now and "ON" or "off") .. string.char(10)); out:flush(); box = now end
end, emu.eventType.endFrame)
