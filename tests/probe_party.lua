-- Probe: when $7E:1FFF = AA, log party slots 0-2: record, HP (+$92), words that equal common
-- max-HP values, and search WRAM $7E:0000-$7E:3FFF for 3-word arrays that are a permutation
-- of the party record pointers.
local done = false
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
emu.addEventCallback(function()
  if not PROBE_ON or done or emu.read(0x1FFF, emu.memType.snesWorkRam) ~= 0xAA then return end
  done = true
  local recs = {}
  for s = 0, 2 do
    local rec = r16(0x7E2040 + s * 2)
    recs[#recs + 1] = rec
    local hp = r16(0x7F0000 + rec + 0x92)
    local found = {}
    for o = 0x90, 0x140, 2 do
      local v = r16(0x7F0000 + rec + o)
      if v == 549 or v == 520 or v == 516 then found[#found + 1] = string.format("+%X=%d", o, v) end
    end
    note(string.format("slot%d rec=%04X hp=%d maxhp-candidates %s", s, rec, hp, table.concat(found, " ")))
  end
  local set = {[recs[1]] = 1, [recs[2]] = 1, [recs[3]] = 1}
  local hits = {}
  for bank = 0x7E, 0x7F do
    for a = 0, 0xFFFC, 2 do
      local x, y, z = r16(bank * 0x10000 + a), r16(bank * 0x10000 + a + 2), r16(bank * 0x10000 + a + 4)
      if set[x] and set[y] and set[z] and x ~= y and y ~= z and x ~= z then
        hits[#hits + 1] = string.format("%02X:%04X=[%04X %04X %04X]", bank, a, x, y, z)
      end
    end
  end
  note("PERM " .. table.concat(hits, " "))
end, emu.eventType.endFrame)
