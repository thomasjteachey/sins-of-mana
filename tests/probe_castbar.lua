-- Probe: the cast bar of every cast, frame by frame -> build/castbar.txt.
-- At CastStart ($56:A000): frame, caster slot, cast value. Then per frame while that slot casts (and a few
-- frames after): Bars ran (count), caster state, cast book entry (timer record, bar length T and steps shown,
-- or "ran out"), the timer's time left (wake - clock) and +$08 (time left while suspended), and the code of
-- the slot's cast bar on screen (low 4 bits = steps, $1000 = gold). At the end of each cast, a summary line:
-- steps that went backwards (must be 0), when the timer ran out and when the bar turned gold.
-- Options in build/probe_castbar_cfg.lua (all optional):
--   CB_FAKE_ENEMY = true   entity slot 3's level byte (+$B1) = 5 at the first frame, so the mod counts an
--                          enemy as present and casts get their real cast time (at the save statue)
--   CB_FORCE = { {"push", from, to}, {"susp", at}, {"resume", at} }   (frames after CastStart, caster slot 0)
--       push:   hold party slot 1's +$8A = 4 from..to-1, then 0: the mod's $40:2400 (every 16 ticks) then
--               pushes the party's cast waits 16 ticks later, as it does right after a ring menu
--       susp:   take the caster's cast timer (record +$57) off the list, time left -> +$08 (as $C0:CA53)
--       resume: wake = clock + +$08, back into the list in wake order, +$08 = 0 (as $C0:CA98)
--       (don't overlap push and susp: the mod's push puts a suspended timer back into the list)
--   CB_KEEP_HP = true      party HP back to max every frame (long casts in a fight)
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "castbar.txt", "w")
pcall(dofile, ROOTB .. "probe_castbar_cfg.lua")
local frame, casts, faked = 0, {}, false
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
local function w16(a, v) emu.write16(a, v & 0xFFFF, emu.memType.snesMemory) end
local function nl(s) out:write(s .. string.char(10)); out:flush() end
local bars = 0
emu.addMemoryCallback(function() bars = bars + 1 end, emu.callbackType.exec, 0xCBE40B, 0xCBE40B)
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local s = emu.getState()
  local rec = (r16(0x7E0000 + s["cpu.d"] + 0x34) - 0x90) & 0xFFFF
  for sl = 0, 15 do
    if r16(0x7E2040 + sl * 2) == rec then
      casts[sl] = { start = frame, last = nil, back = 0, out = nil, gold = nil, after = 0 }
      nl(string.format("f%d CastStart slot %d value %d clock %04X", frame, sl, s["cpu.x"], r16(0x7F00C6)))
    end
  end
end, emu.callbackType.exec, 0x56A000, 0x56A000)

local function force(t)
  local rec = r16(0x7F0000 + r16(0x7E2040) + 0x57)
  for _, e in ipairs(CB_FORCE or {}) do
    if e[1] == "push" and t >= e[2] and t < e[3] then
      emu.write(0x7F0000 + r16(0x7E2042) + 0x8A, 4, emu.memType.snesMemory)
    elseif e[1] == "push" and t == e[3] then
      emu.write(0x7F0000 + r16(0x7E2042) + 0x8A, 0, emu.memType.snesMemory)
    elseif e[1] == "susp" and t == e[2] and rec ~= 0 then
      local p = 0xC4
      while r16(0x7F0000 + p) ~= 0 and r16(0x7F0000 + p) ~= rec do p = r16(0x7F0000 + p) end
      if r16(0x7F0000 + p) == rec then
        w16(0x7F0000 + p, r16(0x7F0000 + rec)); w16(0x7F0000 + rec, 0)
        w16(0x7F0000 + rec + 8, r16(0x7F0000 + rec + 4) - r16(0x7F00C6))
        nl(string.format("  (suspended timer %04X)", rec))
      end
    elseif e[1] == "resume" and t == e[2] and rec ~= 0 and r16(0x7F0000 + rec + 8) ~= 0 then
      local clock, left = r16(0x7F00C6), r16(0x7F0000 + rec + 8)
      w16(0x7F0000 + rec + 4, clock + left)
      local p = 0xC4
      while r16(0x7F0000 + p) ~= 0 and ((r16(0x7F0000 + r16(0x7F0000 + p) + 4) - clock) & 0xFFFF) < left do
        p = r16(0x7F0000 + p)
      end
      w16(0x7F0000 + rec, r16(0x7F0000 + p)); w16(0x7F0000 + p, rec); w16(0x7F0000 + rec + 8, 0)
      nl(string.format("  (resumed timer %04X, %d left)", rec, left))
    end
  end
end

emu.addEventCallback(function()
  if not PROBE_ON then bars = 0; return end
  frame = frame + 1
  if CB_FAKE_ENEMY and not faked and r16(0x7E2046) ~= 0 then
    faked = true
    emu.write(0x7F0000 + r16(0x7E2046) + 0xB1, 5, emu.memType.snesMemory)
  end
  if CB_KEEP_HP then
    for sl = 0, 2 do
      local rec = r16(0x7E2040 + sl * 2)
      if rec ~= 0 then w16(0x7F0092 + rec, r16(0x7F00A2 + rec)) end
    end
  end
  if casts[0] then force(frame - casts[0].start) end
  local clock = r16(0x7F00C6)
  for sl, c in pairs(casts) do
    local rec = r16(0x7E2040 + sl * 2)
    local st = rec ~= 0 and r8(0x7F0000 + rec) or 0
    local w0, w1 = r16(0x7E2800 + sl * 4), r16(0x7E2802 + sl * 4)
    local book
    if w0 == 0xFFFF then book = string.format("ran out at %04X", w1)
    else book = string.format("timer %04X T %d steps %d", w0, w1 & 0xFFF, w1 >> 12) end
    local ts = ""
    if w0 ~= 0 and w0 ~= 0xFFFF then
      ts = string.format(" left %d save %d", ((r16(0x7F0000 + w0 + 4) - clock + 0x8000) & 0xFFFF) - 0x8000,
        r16(0x7F0000 + w0 + 8))
    end
    local code = nil
    for k = 0, 7 do if r16(0x7E2848 + k * 2) == 0x8000 + sl * 2 + 1 then code = r16(0x7E2858 + k * 2) end end
    if code then
      local steps = code & 0x0F
      if c.last and steps < c.last then c.back = c.back + 1 end
      c.last = steps
      if code & 0x1000 ~= 0 and not c.gold then c.gold = frame - c.start end
    end
    if w0 == 0xFFFF and not c.out then c.out = frame - c.start end
    nl(string.format("f%d s%d +%d bars%d st%02X clock %04X %s%s | code %s", frame, sl, frame - c.start, bars, st, clock,
      book, ts, code and string.format("%04X", code) or "-"))
    if st ~= 0x0A then c.after = c.after + 1 end
    if c.after >= 4 then
      nl(string.format("f%d s%d cast over: backward steps %d, timer ran out at +%s, gold at +%s", frame, sl, c.back,
        tostring(c.out), tostring(c.gold)))
      casts[sl] = nil
    end
  end
  bars = 0
end, emu.eventType.endFrame)
