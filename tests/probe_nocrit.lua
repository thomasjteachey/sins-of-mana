-- Probe: ice cave battle with one party member at critical HP and one at low HP, party and
-- enemy stat changes (red icons / arrows, one enemy with both arrows). Logs, per phase
-- (A: frames 60-119, no window; B: frames 200-259, after the steps open the ring menu),
-- how many values CGRAM 1-31 took, the red icon cells' palettes, and Bars' state
-- -> build/nocrit.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "nocrit.txt", "w")
local frame = 0
local function w8(a, v) emu.write(a - 0x7E0000, v, emu.memType.snesWorkRam) end
local function w16(a, v) w8(a, v & 0xFF); w8(a + 1, (v >> 8) & 0xFF) end
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
local function cg(i) return emu.read(i * 2, emu.memType.snesCgRam) | (emu.read(i * 2 + 1, emu.memType.snesCgRam) << 8) end
local phases = { {"A", 60, 119}, {"B", 200, 259} }
local seen = {}
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if frame >= 5 and frame <= 300 then
    if frame <= 12 then
      -- (no HP change)

    end
    w8(0x7FF125, 0x58); w8(0x7FF126, 0x94); w8(0x7FF127, 0x54)
    w8(0x7FF425, 0x48)
    w8(0x7FF725, 0x04); w8(0x7FF726, 0x08)
    w8(0x7FE225, 0x40); w8(0x7FE226, 0x08)   -- $E160: raised and lowered -> both arrows
    w8(0x7FDF26, 0x08)                       -- $DE60: lowered -> red arrow
  end
  for _, p in ipairs(phases) do
    local name, f0, f1 = p[1], p[2], p[3]
    if frame >= f0 and frame <= f1 then
      seen[name] = seen[name] or {}
      for i = 1, 31 do
        local v = cg(i)
        seen[name][i] = seen[name][i] or {}
        seen[name][i][v] = (seen[name][i][v] or 0) + 1
      end
      if frame == f1 then
        out:write(string.format("phase %s (F%d-%d) mask %02X RedPal %04X Borrow %04X Borrowed %04X Warn %04X\n", name, f0, f1,
          r8(0x7F0032), r16(0x7E28AC), r16(0x7E28A6), r16(0x7E28A8), r16(0x7E28AA)))
        for i = 1, 31 do
          local l = {}
          for v, n in pairs(seen[name][i]) do l[#l + 1] = string.format("%04X(%d)", v, n) end
          table.sort(l)
          if #l > 1 or i >= 20 and i <= 23 then out:write(string.format("  cgram %2d: %s\n", i, table.concat(l, " "))) end
        end
        -- icon cells beside the HUD: rows 1-2 cols 11-21, rows 23-24 cols 22-30
        local cells = {}
        for _, rc in ipairs({{1, 11, 21}, {2, 11, 21}, {23, 22, 30}, {24, 22, 30}}) do
          for c = rc[2], rc[3] do
            local v = r16(0x7E4000 + (rc[1] * 32 + c) * 2)
            local t = v & 0x3FF
            if t >= 0x0D4 and t <= 0x0DC then cells[#cells + 1] = string.format("r%dc%d:t%03X/p%d", rc[1], c, t, (v >> 10) & 7) end
          end
        end
        out:write("  icons " .. table.concat(cells, " ") .. "\n")
        local caps = {}
        for slot = 0, 7 do
          local base = 0x7E4700 + slot * 0x20
          local l, r = r16(base), r16(base + 8)
          if (l & 0x3FF) ~= 0xFF then caps[#caps + 1] = string.format("slot%d L=%04X R=%04X", slot, l, r) end
        end
        out:write("  bar caps " .. table.concat(caps, ", ") .. "\n")
        out:flush()
      end
    end
  end
end, emu.eventType.endFrame)
