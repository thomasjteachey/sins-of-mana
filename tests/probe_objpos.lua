-- Probe: every 6 frames, per entity slot with an object: obj +83 (x), +87 (y), +8B (height?),
-- screen position, and the shadow-OAM entries (tile $1E6/$1E8 ovals) from $7F:0100.
local f = 0
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
emu.addEventCallback(function()
  if not PROBE_ON then return end
  f = f + 1
  if f % 6 ~= 0 or f > 360 then return end
  local camX, camY = r16(0x7F032A), r16(0x7F032C)
  local parts = {}
  for slot = 0, 7 do
    local rec = r16(0x7E2040 + slot * 2)
    if rec ~= 0 then
      local obj = r16(0x7F0000 + rec + 4)
      if obj ~= 0 then
        local o = 0x7F0000 + obj
        local x, y, h = r16(o + 0x83), r16(o + 0x87), r16(o + 0x8B)
        parts[#parts + 1] = string.format("s%d x%d y%d h%d sx%d sy%d", slot, x, y, h, (x - camX) & 0xFFFF, (y - camY) & 0xFFFF)
      end
    end
  end
  local sh = {}
  for i = 0, 127 do
    local b = 0x7F0100 + i * 4
    local t = emu.read(b + 2, emu.memType.snesMemory) | ((emu.read(b + 3, emu.memType.snesMemory) & 1) << 8)
    if t == 0x1E6 or t == 0x1E8 then
      sh[#sh + 1] = string.format("(%d,%d)", emu.read(b, emu.memType.snesMemory), emu.read(b + 1, emu.memType.snesMemory))
    end
  end
  note(string.format("f%d cam %d,%d | %s | shadows %s", f, camX, camY, table.concat(parts, " | "), table.concat(sh, " ")))
end, emu.eventType.endFrame)
