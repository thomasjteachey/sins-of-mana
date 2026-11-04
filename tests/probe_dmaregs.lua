-- Probe: every write to the DMA registers ($4300-$437F), the WRAM port address ($2181-$2183) and
-- $420B / $420C, with frame, scanline and PC -> build/dmaregs.txt (one line per write).
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "dmaregs.txt", "w")
pcall(dofile, ROOTB .. "probe_dmaregs_cfg.lua")
local F0, F1 = DMAREGS_F0 or 1, DMAREGS_F1 or 100000
local frame = 0
local function cb(a, v)
  if not PROBE_ON or frame < F0 or frame > F1 then return end
  local s = emu.getState()
  out:write(string.format("f%d l%d %04X=%02X %02X:%04X", frame, s["ppu.scanline"] or -1, a & 0xFFFF, v or -1, s["cpu.k"],
    s["cpu.pc"]) .. string.char(10))
end
emu.addMemoryCallback(cb, emu.callbackType.write, 0x004300, 0x00437F)
emu.addMemoryCallback(cb, emu.callbackType.write, 0x002181, 0x002183)
emu.addMemoryCallback(cb, emu.callbackType.write, 0x00420B, 0x00420C)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if frame % 30 == 0 then out:flush() end
end, emu.eventType.endFrame)
