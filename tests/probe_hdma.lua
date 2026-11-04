-- Probe: values written to $420B (DMA enable) and $420C (HDMA enable), writes to BG3 scroll
-- ($2111/$2112) with PC, and the HDMA shadow $7F:0032. Summary when $7E:1FFF = AA.
local dma, hdma, scroll, done = {}, {}, {}, false
local function add(t, k) t[k] = (t[k] or 0) + 1 end
local function pc() local s = emu.getState(); return string.format("%02X:%04X", s["cpu.k"], s["cpu.pc"]) end
for _, base in ipairs({0x000000, 0x800000}) do
  emu.addMemoryCallback(function(a, v) add(dma, string.format("%02X", v)) end, emu.callbackType.write, base + 0x420B, base + 0x420B)
  emu.addMemoryCallback(function(a, v) add(hdma, string.format("%02X@%s", v, pc())) end, emu.callbackType.write, base + 0x420C, base + 0x420C)
  emu.addMemoryCallback(function(a, v) add(scroll, string.format("%04X=%02X@%s", a & 0xFFFF, v, pc())) end, emu.callbackType.write, base + 0x2111, base + 0x2112)
end
emu.addEventCallback(function()
  if not done and PROBE_ON and emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA then
    done = true
    local function dump(name, t) local l = {}; for k, v in pairs(t) do l[#l + 1] = k .. "x" .. v end; table.sort(l); note(name .. " " .. table.concat(l, " ")) end
    dump("DMA420B", dma); dump("HDMA420C", hdma); dump("BG3SCROLL", scroll)
    note(string.format("shadow 7F:0032=%02X", emu.read(0x7F0032, emu.memType.snesMemory)))
  end
end, emu.eventType.endFrame)
