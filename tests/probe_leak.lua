-- Probe: resource pools across map changes (leak hunt) -> build/leak.txt (appended).
-- The run is cycles of LEAK_LEN frames (walk in, wait, walk out, wait). At the end of each cycle
-- (outside the room) it logs: cycle, heap pages in use ($7E:2100-21FF owner table), free DMA jobs (list $7F:0028, next
-- at +0), sprite objects (list $7E:035B, next at +$A7, in bank $7E and $7F), game timers (list
-- $7F:00C4, next at +0), entities in use ($7E:2040, 16 slots), distinct heap owners.
-- Config (build/probe_leak_cfg.lua): LEAK_CYCLE (first cycle number), LEAK_START (frame the first
-- cycle starts), LEAK_LEN (frames per cycle), KILL_AT (frames after the enemies first appear in a
-- cycle to set their HP to 1, so the next hit kills; nil = never), KILL_STEP (added to KILL_AT each cycle, wraps at 90).
-- Keeps the party's HP at 400 so long runs don't end in a game over.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
pcall(dofile, ROOTB .. "probe_leak_cfg.lua")
local out = io.open(ROOTB .. "leak.txt", "a")
local cycle = LEAK_CYCLE or 1
local killAt = KILL_AT
local since, lastSlot3 = nil, 0
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
local function r16(a) return r8(a) | (r8(a + 1) << 8) end
local function w16(a, v) emu.write(a, v & 0xFF, emu.memType.snesMemory); emu.write(a + 1, v >> 8, emu.memType.snesMemory) end
local function walk(head, bank, nextOfs)
  local n, p, seen = 0, head, {}
  while p ~= 0 and n < 400 and not seen[p] do
    seen[p] = true; n = n + 1; p = r16(bank * 0x10000 + p + nextOfs)
  end
  return n
end
local function pools()
  local heap, owners = 0, {}
  for a = 0x7E2100, 0x7E21FF do local o = r8(a); if o ~= 0 then heap = heap + 1; owners[o] = true end end
  local nown = 0; for _ in pairs(owners) do nown = nown + 1 end
  local ents = 0
  for i = 0, 15 do if r16(0x7E2040 + i * 2) ~= 0 then ents = ents + 1 end end
  return string.format("heap %d owners %d dmafree %d obj7E %d obj7F %d timers %d ents %d",
    heap, nown, walk(r16(0x7F0028), 0x7F, 0), walk(r16(0x7E035B), 0x7E, 0xA7), walk(r16(0x7E035B), 0x7F, 0xA7),
    walk(r16(0x7F00C4), 0x7F, 0), ents)
end
local frame, spawned, deaths, prevEnemy = 0, false, 0, {}
local start, len = LEAK_START or 5, LEAK_LEN or 590
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  for i = 0, 2 do                        -- party HP
    local rec = r16(0x7E2040 + i * 2)
    if rec ~= 0 and r16(0x7F0000 + rec + 0x92) ~= 0 then w16(0x7F0000 + rec + 0x92, 400) end
  end
  local ofs = frame >= start and (frame - start) % len or -1
  if ofs == len - 1 then                  -- end of a cycle: outside
    out:write(string.format("cycle %d %s%s", cycle, pools(),
      KILL_AT and string.format(" killAt %d died %d", killAt, deaths) or "") .. string.char(10))
    out:flush()
    cycle = cycle + 1
    spawned, since, deaths = false, nil, 0
    if killAt then killAt = killAt + (KILL_STEP or 7); if killAt > 90 then killAt = killAt - 80 end end
  end
  local s3 = r16(0x7E2046)
  if s3 ~= 0 and lastSlot3 == 0 and not spawned and ofs >= 0 then spawned, since = true, 0 end
  lastSlot3 = s3
  if since then since = since + 1 end
  for i = 3, 15 do                        -- enemies: hold HP at 1 from KILL_AT on (the next hit
    local rec = r16(0x7E2040 + i * 2)     -- kills); count the ones that go away before the walk out
    if killAt and since and since >= killAt and rec ~= 0 and r16(0x7F0000 + rec + 0x92) > 1 then
      w16(0x7F0000 + rec + 0x92, 1)
    end
    if prevEnemy[i] and prevEnemy[i] ~= 0 and rec == 0 and ofs >= 0 and ofs < 280 then deaths = deaths + 1 end
    prevEnemy[i] = rec
  end
end, emu.eventType.endFrame)
