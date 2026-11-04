-- Probe: the level-up info panel's state at frame PANEL_F (default 6) -> build/panel.txt:
-- !PanelOn / !PanelSig, the matched record, OAM entries 1-2, the HDMA table, and the panel's
-- BG3-copy rows (28-31 and 5) decoded back to text.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "panel.txt", "w")
local frame = 0
pcall(dofile, ROOTB .. "probe_panel_cfg.lua")
local FR = PANEL_FRAMES or {PANEL_F or 6}
local want = {}
for _, f in ipairs(FR) do want[f] = true end
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
local function ch(t)
  if t >= 0x04A and t <= 0x063 then return string.char(65 + t - 0x04A) end
  if t >= 0x064 and t <= 0x07D then return string.char(97 + t - 0x064) end
  if t >= 0x080 and t <= 0x089 then return string.char(48 + t - 0x080) end
  local m = {[0x03D] = "+", [0x03E] = "-", [0x0DD] = ":", [0x0DE] = ",", [0x0DF] = ".", [0x0E0] = "/",
             [0x0E1] = "%", [0x0E2] = "(", [0x0E3] = ")", [0x0E4] = "&", [0x0E5] = "=", [0x0E6] = "*", [0x0E7] = "#", [0x0E8] = "^", [0x07E] = "!", [0x0FF] = " "}
  return m[t] or "#"
end
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if not want[frame] then return end
  out:write(string.format("== frame %d", frame) .. string.char(10))
  local sig = r16(0x7E28E2)
  out:write(string.format("PanelOn %d  Sig %04X (stat %d char %d line %d red %d)  Active %d Ready %04X\n",
    r16(0x7E28E0), sig, sig & 7, (sig >> 3) & 7, (sig >> 6) & 3, (sig >> 8) & 1, r16(0x7E2846), r16(0x7E2844)))
  for s = 0, 2 do
    local rec = r16(0x7E2040 + s * 2)
    local b = 0x7F0000 + rec
    out:write(string.format("slot %d rec %04X char %d tier %d lvl %d C8 %02X stats %d %d %d %d %d %d\n", s, rec,
      r8(b + 0xB3), r8(b + 0xB4), r8(b + 0xB1), r8(b + 0xC8), r8(b + 0x96), r8(b + 0x97), r8(b + 0x98),
      r8(b + 0x99), r8(b + 0x9A), r8(b + 0x9B)))
  end
  out:write(string.format("OAM entry 1 y %d, entry 2 y %d, SprHid %02X\n", r8(0x7F0105), r8(0x7F0109), r8(0x7E28E8)))
  local t = r16(0x7E2844)
  local tb = {}
  for i = 0, 31 do tb[#tb + 1] = string.format("%02X", r8(0x7E0000 + t + i)) end
  out:write("table " .. table.concat(tb, " ") .. "\n")
  for _, row in ipairs({28, 29, 30, 31, 5}) do
    local s, p = {}, {}
    for c = 0, 31 do
      local v = r16(0x7E4000 + (row * 32 + c) * 2)
      s[#s + 1] = ch(v & 0x3FF)
      p[#p + 1] = ((v & 0x3FF) == 0xFF) and " " or tostring((v >> 10) & 7)
    end
    out:write(string.format("row %2d |%s|\n       |%s|\n", row, table.concat(s), table.concat(p)))
  end
  out:flush()
end, emu.eventType.endFrame)
