-- With probe_stage.lua: per frame in the stage window, the enemy's state as Bars sees it,
-- its cast book entry, the tick, and the bar slot owners -> build/stagecheck.txt.
dofile("C:/Projects/Gamedev/sins of mana/tests/probe_stage.lua")
local out = io.open("C:/Projects/Gamedev/sins of mana/build/stagecheck.txt", "w")
local f2 = 0
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  if f2 < 230 or f2 > 320 or f2 % 10 ~= 0 then return end
  local own = {}
  for i = 0, 7 do own[#own + 1] = string.format("%04X", r16(0x7E2848 + i * 2)) end
  out:write(string.format("F%d at .back: DE60 state=%02X side=%02X book=%d/%d tick=%d ent4=%04X owners=%s\n", f2,
    r8(0x7FDE60), r8(0x7FDE61), r16(0x7E2810), r16(0x7E2812), r16(0x7F00C6), r16(0x7E2048), table.concat(own, " ")))
  out:flush()
end, emu.callbackType.exec, 0xCBE40B, 0xCBE40B)
emu.addEventCallback(function() if PROBE_ON then f2 = f2 + 1 end end, emu.eventType.endFrame)
