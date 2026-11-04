-- Probe: hot spots (16-byte granularity, every 4th instruction sampled) outside the task
-- scheduler, between button presses -> build/menu_hot.txt. Also logs every call of the
-- graphics decompressor ($E8:C484 / $E8:C480 entries) with its caller and parameters.
-- Flush the last segment by poking $7E:1FFF = AA.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
HOT_FROM, HOT_TO = 0, 1e9
pcall(dofile, ROOTB .. "probe_hot_cfg.lua")
local out = io.open(ROOTB .. "menu_hot.txt", "w")
local cnt = 0
local seg, segFrames = {}, 0
local frame, segStart, prevPad, done = 0, 1, 0, false
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
local function idle(a)
  return (a >= 0xC04A00 and a <= 0xC04FFF) or (a >= 0xC05E00 and a <= 0xC05FFF)
end
local function flush(label)
  local l = {}
  for k, v in pairs(seg) do l[#l + 1] = {k, v} end
  table.sort(l, function(a, b) return a[2] > b[2] end)
  local t = {}
  for i = 1, math.min(24, #l) do t[#t + 1] = string.format("%06X=%d", l[i][1] << 4, l[i][2] * 4) end
  out:write(string.format("%s frames=%d | %s\n", label, segFrames, table.concat(t, " ")))
  out:flush()
  seg, segFrames = {}, 0
end
emu.addMemoryCallback(function(address)
  if not PROBE_ON then return end
  cnt = cnt + 1
  if cnt & 3 == 0 and frame >= HOT_FROM and frame <= HOT_TO and not idle(address) then
    local p = address >> 4
    seg[p] = (seg[p] or 0) + 1
  end
end, emu.callbackType.exec, 0x000000, 0xFFFFFF)
local function decomp(name)
  return function()
    if not PROBE_ON then return end
    local s = emu.getState()
    local sp, d = s["cpu.sp"], s["cpu.d"]
    local ret = r8(sp + 1) | (r8(sp + 2) << 8) | (r8(sp + 3) << 16)
    local p = {}
    for i = 0x10, 0x2D do p[#p + 1] = string.format("%02X", r8(d + i)) end
    out:write(string.format("F%d %s from %06X D=%04X DB=%02X dp10..2D=%s\n", frame, name, ret, d,
      s["cpu.db"] or 0, table.concat(p, " ")))
  end
end
emu.addMemoryCallback(decomp("C480"), emu.callbackType.exec, 0xE8C480, 0xE8C480)
emu.addMemoryCallback(decomp("C484"), emu.callbackType.exec, 0xE8C484, 0xE8C484)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  segFrames = segFrames + 1
  local pad = r8(0x4218) | (r8(0x4219) << 8)
  if pad ~= 0 and prevPad == 0 then
    flush(string.format("SEG %d-%d", segStart, frame - 1))
    segStart = frame
    out:write(string.format("PRESS %04X at %d\n", pad, frame))
  end
  prevPad = pad
  if not done and emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA then
    done = true
    flush(string.format("SEG %d-%d", segStart, frame))
  end
end, emu.eventType.endFrame)
