-- Probe: at the "new line" text op ($C4:6C58), the text task's pointer ($0400+$2E) and its bank guess ($0430),
-- plus 40 bytes there (bank $7E and the $0430 bank) -> build/bartext.txt.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "bartext.txt", "w")
local frame = 0
local function rd(a) return emu.read(a, emu.memType.snesMemory) end
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local s = emu.getState()
  local d = s["cpu.d"]
  local p = rd(d + 0x2E) | (rd(d + 0x2F) << 8)
  local line = string.format("f%d D=%04X ptr=%04X 30=%02X%02X 32=%02X%02X :", frame, d, p, rd(d + 0x31), rd(d + 0x30), rd(d + 0x33), rd(d + 0x32))
  for _, bank in ipairs({0x7E, 0x7F, 0xFB}) do
    local b = {}
    for i = 0, 23 do b[#b + 1] = string.format("%02X", rd(bank * 0x10000 + p + i)) end
    line = line .. string.format(" [%02X] %s", bank, table.concat(b, " "))
  end
  out:write(line .. string.char(10)); out:flush()
end, emu.callbackType.exec, 0xC46C58, 0xC46C58)
emu.addEventCallback(function() if PROBE_ON then frame = frame + 1 end end, emu.eventType.endFrame)
