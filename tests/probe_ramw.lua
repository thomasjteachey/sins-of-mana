-- Probe: count writes into candidate free RAM regions during the run, with the first few PCs.
local R = { {0x7EBAA7, 0x7EC012}, {0x7E2800, 0x7E2BE0}, {0x7E3979, 0x7E3C00}, {0x7E315A, 0x7E3300} }
local counts, pcs, done = {}, {}, false
for i, r in ipairs(R) do
  counts[i] = 0; pcs[i] = {}
  emu.addMemoryCallback(function(addr)
    if not PROBE_ON then return end
    counts[i] = counts[i] + 1
    if counts[i] <= 3 then
      local s = emu.getState()
      pcs[i][#pcs[i] + 1] = string.format("%06X@%02X:%04X", addr, s["cpu.k"], s["cpu.pc"])
    end
  end, emu.callbackType.write, r[1], r[2])
end
emu.addEventCallback(function()
  if not done and PROBE_ON and emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA then
    done = true
    for i, r in ipairs(R) do note(string.format("RAMW %06X-%06X writes=%d %s", r[1], r[2], counts[i], table.concat(pcs[i], " "))) end
  end
end, emu.eventType.endFrame)
