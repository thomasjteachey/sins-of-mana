-- Probe: writes to a record's six stat bytes (+$96..+$9B) with frame, scanline and PC -> build/statw.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "statw.txt", "w")
pcall(dofile, ROOTB .. "probe_statw_cfg.lua")
local REC = STATW_REC or 0xF060
local MAXN = STATW_MAX or 400
local frame, n = 0, 0
emu.addMemoryCallback(function(addr, value)
  if not PROBE_ON or n >= MAXN then return end
  n = n + 1
  local s = emu.getState()
  out:write(string.format("frame %d line %d write %06X (+%02X) = %02X at %02X:%04X", frame, s["ppu.scanline"] or -1, addr,
    addr - 0x7F0000 - REC, value or -1, s["cpu.k"], s["cpu.pc"]) .. string.char(10))
  out:flush()
end, emu.callbackType.write, 0x7F0000 + REC + 0x96, 0x7F0000 + REC + 0x9B)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
end, emu.eventType.endFrame)
