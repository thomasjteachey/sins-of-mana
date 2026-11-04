-- Probe: DMA transfers aimed at OAMDATA ($2104): source, size, PC -> build/oamdma.txt (40 frames).
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "oamdma.txt", "w")
local frame, seen = 0, {}
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
emu.addMemoryCallback(function(addr, value)
  if not PROBE_ON or frame > 40 then return end
  for c = 0, 7 do
    if (value >> c) & 1 == 1 and r8(0x4301 + c * 16) == 0x04 then
      local src = r8(0x4304 + c * 16) * 65536 + r8(0x4303 + c * 16) * 256 + r8(0x4302 + c * 16)
      local n = r8(0x4305 + c * 16) + r8(0x4306 + c * 16) * 256
      local s = emu.getState()
      local k = string.format("ch%d src %06X len %d pc %02X:%04X oamaddr? ", c, src, n, s["cpu.k"], s["cpu.pc"])
      seen[k] = (seen[k] or 0) + 1
    end
  end
end, emu.callbackType.write, 0x420B, 0x420B)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if frame == 40 then
    for k, v in pairs(seen) do out:write(string.format("%4d  %s\n", v, k)) end
    out:flush()
  end
end, emu.eventType.endFrame)
