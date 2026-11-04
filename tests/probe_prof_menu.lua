-- Probe: sampling profile of every executed instruction (every 8th one, by 256-byte code
-- page), split into segments at each new button press -> build/menu_prof.txt.
-- Also per frame: instructions outside the task scheduler / idle task (C0:4A00-4FFF,
-- C0:5E00-5FFF) = real work.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "menu_prof.txt", "w")
local cnt, work = 0, 0
local seg, segWork, segFrames = {}, 0, 0
local frame, segStart, prevPad = 0, 1, 0
local function idle(a)
  return (a >= 0xC04A00 and a <= 0xC04FFF) or (a >= 0xC05E00 and a <= 0xC05FFF)
end
local function flush(label)
  local l = {}
  for k, v in pairs(seg) do l[#l + 1] = {k, v} end
  table.sort(l, function(a, b) return a[2] > b[2] end)
  local t = {}
  for i = 1, math.min(16, #l) do t[#t + 1] = string.format("%04X=%d", l[i][1], l[i][2]) end
  out:write(string.format("%s frames=%d work/frame=%d | %s\n", label, segFrames,
    segFrames > 0 and segWork // segFrames or 0, table.concat(t, " ")))
  out:flush()
  seg, segWork, segFrames = {}, 0, 0
end
emu.addMemoryCallback(function(address)
  if not PROBE_ON then return end
  cnt = cnt + 1
  if not idle(address) then work = work + 1 end
  if cnt & 7 == 0 then
    local p = address >> 8
    seg[p] = (seg[p] or 0) + 1
  end
end, emu.callbackType.exec, 0x000000, 0xFFFFFF)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  local pad = emu.read(0x4218, emu.memType.snesMemory) | (emu.read(0x4219, emu.memType.snesMemory) << 8)
  if pad ~= 0 and prevPad == 0 then
    flush(string.format("SEG %d-%d", segStart, frame - 1))
    segStart = frame
    out:write(string.format("PRESS %04X at %d\n", pad, frame))
  end
  prevPad = pad
  out:write(string.format("F%d all=%d work=%d\n", frame, cnt, work))
  segWork = segWork + work; segFrames = segFrames + 1
  cnt, work = 0, 0
end, emu.eventType.endFrame)
