-- Probe: once armed (poke $7E:1FFF=AA), log ROM data reads made by code
-- running in banks $D0/$D1 (the stat calculation) for 40 frames, with the
-- reading instruction's address.
local armed, frames, seen = false, 0, {}
emu.addEventCallback(function()
  if not PROBE_ON then return end
  if not armed and emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA then
    armed = true; frames = 0; note("probe armed")
  end
  if armed then
    frames = frames + 1
    if frames > 40 then
      armed = false
      local keys = {}
      for k, _ in pairs(seen) do keys[#keys + 1] = k end
      table.sort(keys)
      for _, a in ipairs(keys) do note(string.format("read %06X by %s", a, seen[a])) end
      seen = {}
    end
  end
end, emu.eventType.endFrame)

emu.addMemoryCallback(function(addr)
  if not armed then return end
  local s = emu.getState()
  local k = s["cpu.k"]
  if k ~= 0xD0 and k ~= 0xD1 then return end
  if not seen[addr] then seen[addr] = string.format("%02X:%04X", k, s["cpu.pc"]) end
end, emu.callbackType.read, 0x000000, 0x5FFFFF, emu.cpuType.snes, emu.memType.snesPrgRom)
