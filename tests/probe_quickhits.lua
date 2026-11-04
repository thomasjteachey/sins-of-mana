-- Probe for sinofmana_quick_hits.ips: how late hits land, and what it costs.
-- Run with tools/run.py --probe tests/probe_quickhits.lua from a battle state (e.g. icecave), any ROM.
-- Summary when the run reaches QH_FRAMES frames (default 1800):
--   impact -> process-hit: the blow lands (message type $40, param 3, from the hit detection) until the
--                          target's battle script applies it (op $D0:C151)
--   impact -> number:      until the damage-number task (id $0A) gets a turn after the target reported
--   no sprite build:       frames in which the sprite builder ($FD:6E24) did not run
--   boost overdue:         most frames a task kept one of the patch's priorities past the point where it
--                          should have dropped it (hit / number hurries: past their time limit from task
--                          +$14 plus 32 frames for the sweep; cast hurries: its fighter not casting)
-- QH_KEEPALIVE = true keeps the party's HP/MP full so fights last.
QH_FRAMES = QH_FRAMES or 1800
if QH_KEEPALIVE == nil then QH_KEEPALIVE = true end
local f = 0
local function b(a) return emu.read(a, emu.memType.snesMemory) end
local function w(a) return emu.read16(a, emu.memType.snesMemory) end
local OURS = {[0x4E] = true, [0x4F] = true, [0x50] = true, [0x65] = true, [0x66] = true}

local impact, impactNum, toHit, toNum, waitNum = {}, {}, {}, {}, {}
local builder, skips, hits = 0, 0, 0
local since, longest = {}, 0
local LIMIT = {[0x4E] = 20, [0x4F] = 60, [0x65] = 60}

local function fighterOf(id)
  for i = 0, 15 do
    local r = w(0x7E2040 + i * 2)
    if r ~= 0 and b(0x7F0002 + r) == id then return r end
  end
end

emu.addMemoryCallback(function()                         -- $C0:5EAC: send message (A = class/task, X = message)
  if not PROBE_ON or f > QH_FRAMES then return end
  local s = emu.getState(); local x, a = s["cpu.x"], s["cpu.a"]
  local typ, p = b(0x7F0003 + x), b(0x7F0004 + x)
  if typ == 0x40 then
    if p == 0x0C then hits = hits + 1 end
    if p == 0x03 and not impact[a & 0xFF] then impact[a & 0xFF] = f end
    if p == 0x03 and not impactNum[a & 0xFF] then impactNum[a & 0xFF] = f end
  elseif (a & 0xFF) == 0x0A and typ == 0x80 and p == 0x01 then
    local from = b(0x7F0004 + w(0x7F0064))
    if impactNum[from] then waitNum[#waitNum + 1] = impactNum[from]; impactNum[from] = nil end
  end
end, emu.callbackType.exec, 0xC05EAC, 0xC05EAC)

emu.addMemoryCallback(function()                         -- $D0:C151: process hit (in the target's task)
  if not PROBE_ON or f > QH_FRAMES then return end
  local id = b(0x7F0004 + w(0x7F0064))
  if impact[id] then toHit[#toHit + 1] = f - impact[id]; impact[id] = nil end
end, emu.callbackType.exec, 0xD0C151, 0xD0C151)

emu.addMemoryCallback(function()                         -- $C0:4AED: the scheduler resumes task X
  if not PROBE_ON or f > QH_FRAMES then return end
  if b(0x7F0004 + emu.getState()["cpu.x"]) == 0x0A and #waitNum > 0 then
    for _, t in ipairs(waitNum) do toNum[#toNum + 1] = f - t end
    waitNum = {}
  end
end, emu.callbackType.exec, 0xC04AED, 0xC04AED)

emu.addMemoryCallback(function() builder = builder + 1 end, emu.callbackType.exec, 0xFD6E24, 0xFD6E24)

local function stats(t)
  if #t == 0 then return "n=0" end
  local c = {} for i, v in ipairs(t) do c[i] = v end
  table.sort(c)
  local sum = 0 for _, v in ipairs(c) do sum = sum + v end
  return string.format("n=%d avg=%.1f median=%d p90=%d max=%d", #c, sum / #c, c[(#c + 1) // 2],
    c[math.max(1, math.floor(#c * 0.9 + 0.5))], c[#c])
end

emu.addEventCallback(function()
  if not PROBE_ON then builder = 0; return end
  f = f + 1
  if QH_KEEPALIVE then
    for i = 0, 2 do
      local r = w(0x7E2040 + i * 2)
      if r ~= 0 then
        if w(0x7F0092 + r) > 0 then emu.write16(0x7F0092 + r, w(0x7F00A2 + r), emu.memType.snesMemory) end
        emu.write(0x7F0094 + r, b(0x7F00A4 + r), emu.memType.snesMemory)
      end
    end
  end
  if f <= QH_FRAMES then
    if builder == 0 then skips = skips + 1 end
    for tk = 0x0C00, 0x0F60, 0x20 do
      local pr = b(0x7F0003 + tk)
      if b(0x7F0002 + tk) ~= 0 and OURS[pr] and b(0x7F0013 + tk) ~= 0 then
        if LIMIT[pr] then
          local over = ((b(0x7F00C6) - b(0x7F0014 + tk)) & 0xFF) - LIMIT[pr] - 32
          if over > longest then longest = over end
        else
          local r = fighterOf(b(0x7F0004 + tk))
          if r and b(0x7F0000 + r) == 0x0A then since[tk] = nil
          else since[tk] = since[tk] or f; if f - since[tk] > longest then longest = f - since[tk] end end
        end
      else since[tk] = nil end
    end
  end
  builder = 0
  if f == QH_FRAMES then
    note("QH impact -> process-hit: " .. stats(toHit))
    note("QH impact -> number:      " .. stats(toNum))
    note(string.format("QH hits %d, no sprite build %d of %d frames, boost overdue %d frames",
      hits, skips, QH_FRAMES, longest))
  end
end, emu.eventType.endFrame)
