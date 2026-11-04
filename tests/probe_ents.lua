-- Probe: every ENT_STEP frames, entity slots 0-9: record, side, type (+$90 & $1FF), HP (+$92) -> build/ents.txt
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "ents.txt", "w")
local frame = 0
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if frame % (ENT_STEP or 40) ~= 0 then return end
  local t = {}
  for i = 0, 9 do
    local rec = r16(0x7E2040 + i * 2)
    if rec ~= 0 then
      t[#t + 1] = string.format("%d:%04X s%d t%02X hp%d", i, rec, emu.read(0x7F0001 + rec, emu.memType.snesMemory),
        r16(0x7F0090 + rec) & 0x1FF, r16(0x7F0092 + rec))
    end
  end
  out:write(string.format("f%d %s", frame, table.concat(t, "  ")) .. string.char(10)); out:flush()
end, emu.eventType.endFrame)
