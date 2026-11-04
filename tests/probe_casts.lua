-- Probe: frames where any entity is casting (record +$00 = $0A), with side and slot,
-- plus the cast book entry -> build/casts.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "casts.txt", "w")
local frame = 0
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  local t = {}
  for s = 0, 15 do
    local rec = r16(0x7E2040 + s * 2)
    if rec ~= 0 then
      local st = r8(0x7F0000 + rec)
      if st == 0x0A then
        t[#t + 1] = string.format("slot%d side%d len=%d start=%d now=%d", s, r8(0x7F0001 + rec),
          r16(0x7E2802 + s * 4), r16(0x7E2800 + s * 4), r16(0x7F00C6))
      end
    end
  end
  if #t > 0 then out:write(string.format("F%d %s\n", frame, table.concat(t, " | "))); out:flush() end
end, emu.eventType.endFrame)
