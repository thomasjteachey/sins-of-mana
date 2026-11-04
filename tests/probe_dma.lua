-- Probe: log DMA jobs submitted via $C0:0568 (X = job in bank $7F) whose VRAM
-- destination is in the BG3 tilemap ($5800-$5BFF), with the caller chain.
local count = 0
emu.addMemoryCallback(function()
  if not PROBE_ON or count > 40 then return end
  local s = emu.getState()
  local job = 0x7F0000 + s["cpu.x"]
  local function r16(o) return emu.read16(job + o, emu.memType.snesMemory) end
  local dest = r16(0x0B)
  local all = os.getenv("DMA_ALL")
  if not all and (dest < 0x5800 or dest >= 0x5C00) then return end
  count = count + 1
  local sp = s["cpu.sp"]
  local st = {}
  for i = 1, 18 do st[#st + 1] = string.format("%02X", emu.read(sp + i, emu.memType.snesMemory)) end
  note(string.format("job %04X type %02X src %02X:%04X size %04X dest %04X  stack %s",
    s["cpu.x"], emu.read(job + 0x0F, emu.memType.snesMemory), emu.read(job + 6, emu.memType.snesMemory),
    r16(4), r16(7), dest, table.concat(st, " ")))
end, emu.callbackType.exec, 0xC00568, 0xC00568)
