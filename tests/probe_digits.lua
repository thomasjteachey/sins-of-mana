-- Probe: per frame (on change) the record's six stats and the window's six values (BG3 copy rows 10..20,
-- columns 14-15) -> build/digits.txt. Lines read "rec 21 23 .. | win 22 23 ..".
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "digits.txt", "w")
pcall(dofile, ROOTB .. "probe_digits_cfg.lua")
local REC = DIGITS_REC or 0xF060
local frame, last = 0, ""
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
local function dig(t)
  t = t & 0x3FF
  if t == 0xFF then return " " end
  if t >= 0x80 and t <= 0x89 then return tostring(t - 0x80) end
  return "?"
end
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  local rec, win, pal = {}, {}, {}
  for i = 0, 5 do
    rec[#rec + 1] = string.format("%2d", r8(0x7F0000 + REC + 0x96 + i))
    local row = 10 + 2 * i
    local a = 0x7E4000 + (row * 32 + 14) * 2
    win[#win + 1] = dig(r16(a)) .. dig(r16(a + 2))
    pal[#pal + 1] = tostring((r16(0x7E4000 + (row * 32 + 2) * 2) >> 10) & 7)
  end
  local s = "rec " .. table.concat(rec, " ") .. " | win " .. table.concat(win, " ") .. " | pal " .. table.concat(pal, "")
  if s ~= last then
    out:write(string.format("%4d %s", frame, s) .. string.char(10))
    out:flush()
    last = s
  end
end, emu.eventType.endFrame)
