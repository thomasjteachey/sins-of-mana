-- Probe: who teaches a spell at level-up -> build/learn.txt.
-- Logs writes to a record's spell list (+$145..+$150) with the PC and frame, then, for LEARN_SPAN
-- frames before the first such write (from a re-run with LEARN_FRAME set), the ROM addresses read
-- as data, grouped into runs.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "learn.txt", "w")
pcall(dofile, ROOTB .. "probe_learn_cfg.lua")
local REC = LEARN_REC or 0xF060
local frame = 0
local function nl(s) out:write(s .. string.char(10)); out:flush() end
emu.addMemoryCallback(function(addr, value)
  if not PROBE_ON then return end
  local s = emu.getState()
  nl(string.format("frame %d write %06X = %02X at %02X:%04X", frame, addr, value or -1, s["cpu.k"], s["cpu.pc"]))
end, emu.callbackType.write, 0x7F0000 + REC + 0x145, 0x7F0000 + REC + 0x150)
local reads = {}
local function onread(addr)
  if not PROBE_ON or not LEARN_FRAME then return end
  if frame < LEARN_FRAME - (LEARN_SPAN or 1) or frame > LEARN_FRAME then return end
  reads[addr] = (reads[addr] or 0) + 1
end
emu.addMemoryCallback(onread, emu.callbackType.read, 0xC00000, 0xFFFFFF)
emu.addMemoryCallback(onread, emu.callbackType.read, 0x400000, 0x7DFFFF)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if LEARN_FRAME and frame == LEARN_FRAME + 1 then
    local a = {}
    for k in pairs(reads) do a[#a + 1] = k end
    table.sort(a)
    local i = 1
    while i <= #a do
      local j = i
      while j < #a and a[j + 1] - a[j] <= 4 do j = j + 1 end
      local bytes = {}
      for k = a[i], math.min(a[j], a[i] + 47) do bytes[#bytes + 1] = string.format("%02X", emu.read(k, emu.memType.snesMemory)) end
      nl(string.format("run %06X-%06X (%d addrs, %d reads) %s", a[i], a[j], j - i + 1, reads[a[i]], table.concat(bytes, " ")))
      i = j + 1
    end
  end
end, emu.eventType.endFrame)
