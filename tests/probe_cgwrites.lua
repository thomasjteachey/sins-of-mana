-- Probe: who writes CGRAM: CPU writes to $2121 (address) with PC and value, and DMA setups
-- whose B-bus target is $22 (CGDATA), for 10 frames -> build/cgwrites.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "cgwrites.txt", "w")
local frame, seen = 0, {}
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
emu.addMemoryCallback(function(addr, value)
  if not PROBE_ON or frame > 240 then return end
  local s = emu.getState()
  local pc = string.format("%02X:%04X", s["cpu.k"], s["cpu.pc"])
  local k = pc .. " cgadd=" .. value
  if not seen[k] then seen[k] = 0 end
  seen[k] = seen[k] + 1
end, emu.callbackType.write, 0x2121, 0x2121)
emu.addMemoryCallback(function(addr, value)
  if not PROBE_ON or frame > 240 then return end
  -- DMA start: list channels aimed at $2122
  for c = 0, 7 do
    if (value >> c) & 1 == 1 and r8(0x4301 + c * 16) == 0x22 then
      local src = r8(0x4304 + c * 16) * 65536 + r8(0x4303 + c * 16) * 256 + r8(0x4302 + c * 16)
      local n = r8(0x4305 + c * 16) + r8(0x4306 + c * 16) * 256
      local s = emu.getState()
      local k = string.format("DMA ch%d from %06X len %d (pc %02X:%04X)", c, src, n, s["cpu.k"], s["cpu.pc"])
      seen[k] = (seen[k] or 0) + 1
    end
  end
end, emu.callbackType.write, 0x420B, 0x420B)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if frame == 240 then
    local l = {}
    for k, v in pairs(seen) do l[#l + 1] = string.format("%5d  %s", v, k) end
    table.sort(l)
    out:write(table.concat(l, "\n") .. "\n"); out:flush()
  end
end, emu.eventType.endFrame)
