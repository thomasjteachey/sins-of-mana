-- Probe: what an EQUIP screen action does frame by frame -> build/equipsteps.txt.
-- Per frame (after the first button press): glyphs drawn ($C0:ECF6/$ECFE), icon requests
-- ($C4:4DA2 JSL $C103DA -> returns at $C4:4DA6), the extra frame wait ($C4:4DB0), strings
-- started ($C0:EAC8 / $C0:EADA), and any other wait-service call with its caller.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "equipsteps.txt", "w")
local frame, armed = 0, false
local ev = {}
local function add(s) ev[#ev + 1] = s end
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
local glyphs, strings = 0, 0
emu.addMemoryCallback(function() if armed then glyphs = glyphs + 1 end end, emu.callbackType.exec, 0xC0ECF6, 0xC0ECF6)
emu.addMemoryCallback(function() if armed then glyphs = glyphs + 1 end end, emu.callbackType.exec, 0xC0ECFE, 0xC0ECFE)
emu.addMemoryCallback(function() if armed then strings = strings + 1 end end, emu.callbackType.exec, 0xC0EAC8, 0xC0EAC8)
emu.addMemoryCallback(function() if armed then strings = strings + 1 end end, emu.callbackType.exec, 0xC0EADA, 0xC0EADA)
emu.addMemoryCallback(function() if armed then add("iconreq") end end, emu.callbackType.exec, 0xC44DA2, 0xC44DA2)
emu.addMemoryCallback(function() if armed then add("iconback") end end, emu.callbackType.exec, 0xC44DA6, 0xC44DA6)
emu.addMemoryCallback(function() if armed then add("iconwaited") end end, emu.callbackType.exec, 0xC44DB0, 0xC44DB0)
emu.addMemoryCallback(function()
  if not armed then return end
  local s = emu.getState()
  local sp = s["cpu.sp"]
  local ret = r8(sp + 1) | (r8(sp + 2) << 8)
  if ret >= 0x0400 and ret < 0x0800 then
    local l = r8(sp + 3) | (r8(sp + 4) << 8) | (r8(sp + 5) << 16)
    local who = (l + 1) & 0xFFFFFF
    if who ~= 0xC44DB0 and who ~= 0xC04A1F then
      add(string.format("wait(A=%02X,X=%d)@%06X", s["cpu.a"] & 0xFF, s["cpu.x"], who))
    end
  end
end, emu.callbackType.exec, 0xC04E02, 0xC04E02)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  local pad = r8(0x4218) | (r8(0x4219) << 8)
  if pad ~= 0 and not armed then armed = true; out:write(string.format("press %04X at %d\n", pad, frame)) end
  if armed and (glyphs > 0 or strings > 0 or #ev > 0) then
    out:write(string.format("F%d glyphs=%d strings=%d %s\n", frame, glyphs, strings, table.concat(ev, " ")))
    out:flush()
  end
  glyphs, strings, ev = 0, 0, {}
end, emu.eventType.endFrame)
