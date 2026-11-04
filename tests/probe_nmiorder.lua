-- Probe: order inside the NMI of the game's CGRAM DMA (C0:25EC) and the HDMA re-enable hook
-- (C0:22BC), with the scanline -> build/nmiorder.txt (first 40 events).
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "nmiorder.txt", "w")
local n, frame = 0, 0
local function log(what)
  if not PROBE_ON or n > 60 then return end
  n = n + 1
  local s = emu.getState()
  out:write(string.format("F%d line %d %s\n", frame, s["ppu.scanline"] or -1, what)); out:flush()
end
emu.addMemoryCallback(function() log("CGRAM/VRAM DMA C0:25EC") end, emu.callbackType.exec, 0xC025EC, 0xC025EC)
emu.addMemoryCallback(function() log("hook C0:22BC") end, emu.callbackType.exec, 0xC022BC, 0xC022BC)
emu.addEventCallback(function() if PROBE_ON then frame = frame + 1 end end, emu.eventType.endFrame)
