-- Probe: text ops dispatched by the text interpreter ($C4:719D JSR ($702E,X)) with frame, op index (X/2) and
-- handler address -> build/textops.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "textops.txt", "w")
local frame = 0
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local s = emu.getState()
  local x = s["cpu.x"]
  local h = emu.read(0xC4702E + x, emu.memType.snesMemory) | (emu.read(0xC4702F + x, emu.memType.snesMemory) << 8)
  out:write(string.format("f%d op %02X handler C4:%04X D=%04X", frame, x // 2, h, s["cpu.d"]) .. string.char(10))
  out:flush()
end, emu.callbackType.exec, 0xC4719D, 0xC4719D)
emu.addEventCallback(function() if PROBE_ON then frame = frame + 1 end end, emu.eventType.endFrame)
