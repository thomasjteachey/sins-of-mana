-- Probe: heap blocks taken by the new text upload (X after the JSL $C00500 at $CB:FC3B) and
-- the heap's real free ($C0:5C4D, X = block) -> build/heap.txt: per frame the blocks
-- still outstanding, and at the end (when $7E:1FFF = AA) totals and any never freed.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "heap.txt", "w")
local frame, live, taken, freed, fails, maxlive, done = 0, {}, 0, 0, 0, 0, false
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local x = emu.getState()["cpu.x"]
  if x == 0 then fails = fails + 1; return end
  live[x] = frame; taken = taken + 1
  local n = count(live); if n > maxlive then maxlive = n end
end, emu.callbackType.exec, 0xCBFC5C, 0xCBFC5C)
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local x = emu.getState()["cpu.x"]
  if live[x] then live[x] = nil; freed = freed + 1 end
end, emu.callbackType.exec, 0xC05C4D, 0xC05C4D)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if not done and emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA then
    done = true
    local old = {}
    for b, f in pairs(live) do if frame - f > 10 then old[#old + 1] = string.format("%04X@%d", b, f) end end
    out:write(string.format("text blocks taken=%d freed=%d alloc_fails=%d max_outstanding=%d still_held=%d older_than_10_frames=[%s]\n",
      taken, freed, fails, maxlive, count(live), table.concat(old, " ")))
    out:flush()
  end
end, emu.eventType.endFrame)
-- any write to TextCount ($7E:2BD0-2BD1) from outside the text upload code
local others = 0
emu.addMemoryCallback(function(addr, value)
  if not PROBE_ON then return end
  local pc = emu.getState()["cpu.k"] * 65536 + emu.getState()["cpu.pc"]
  if pc < 0xCBF500 or pc > 0xCBFCFF then
    others = others + 1
    out:write(string.format("foreign write to %06X = %02X from %06X\n", addr, value, pc)); out:flush()
  end
end, emu.callbackType.write, 0x7E2BD0, 0x7E2BD1)
