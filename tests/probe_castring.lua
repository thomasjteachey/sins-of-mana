-- Probe: does a cast keep counting while the ring menu is open? -> build/castring.txt.
-- Logs CastStart (frame, clock, the bar's expected length) and, per frame when anything changes, the
-- caster's state (record +$00 of CASTRING_REC, default Duran $F060), the window flag ($7F:0032) and the clock
-- ($7F:00C6); then the frame and clock when the caster leaves the casting state ($0A).
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "castring.txt", "w")
pcall(dofile, ROOTB .. "probe_castring_cfg.lua")
local REC = CASTRING_REC or 0xF060
local frame, last, startTick, startFrame = 0, "", nil, nil
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
local function r16(a) return emu.read16(a, emu.memType.snesMemory) end
local function nl(s) out:write(s .. string.char(10)); out:flush() end
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  startTick = r16(0x7F00C6); startFrame = frame
  nl(string.format("f%d CastStart clock %04X value %04X", frame, startTick, emu.getState()["cpu.x"]))
end, emu.callbackType.exec, 0x56A000, 0x56A000)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  local st = r8(0x7F0000 + REC)
  local win = r8(0x7F0032) ~= 0
  local s = string.format("state %02X window %s", st, win and "up" or "--")
  if s ~= last then
    local extra = ""
    if startTick then extra = string.format("  (clock since cast start %d, frames %d)", (r16(0x7F00C6) - startTick) & 0xFFFF, frame - startFrame) end
    nl(string.format("f%d clock %04X %s%s", frame, r16(0x7F00C6), s, extra))
    last = s
  end
end, emu.eventType.endFrame)
