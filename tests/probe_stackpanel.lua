-- Probe: stack use of Bars and the level-up panel -> build/stackpanel.txt.
-- S at Bars entry ($CB:E40B) and the lowest S reached while executing mod code in bank $58 / $CB /
-- the NMI, per frame (on change), plus the overall minimum.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "stackpanel.txt", "w")
local frame, entryS, minS, minPC, gmin, gpc, last = 0, -1, 0x10000, "", 0x10000, "", ""
local function nl(s) out:write(s .. string.char(10)); out:flush() end
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  entryS = emu.getState()["cpu.sp"]
end, emu.callbackType.exec, 0xCBE40B, 0xCBE40B)
local function track()
  if not PROBE_ON then return end
  local s = emu.getState()
  local sp = s["cpu.sp"]
  if sp < minS then minS = sp; minPC = string.format("%02X:%04X", s["cpu.k"], s["cpu.pc"]) end
  if sp < gmin then gmin = sp; gpc = string.format("%02X:%04X f%d (Bars entry S %04X)", s["cpu.k"], s["cpu.pc"], frame, entryS) end
end
emu.addMemoryCallback(track, emu.callbackType.exec, 0x580000, 0x58FFFF)
emu.addMemoryCallback(track, emu.callbackType.exec, 0xCBE400, 0xCBF4FF)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if minS < 0x10000 then
    local s = string.format("entry S %04X  lowest %04X at %s  depth %d", entryS, minS, minPC, entryS - minS)
    if s ~= last then nl(string.format("f%d %s", frame, s)); last = s end
  end
  minS = 0x10000
end, emu.eventType.endFrame)
emu.addEventCallback(function()
  nl("overall lowest S " .. string.format("%04X", gmin) .. " at " .. gpc)
end, emu.eventType.scriptEnded)
