-- Probe: log every string the translation's print routine is asked to draw.
-- Hooks the mod's redirect check at $40:7960 (entered via JSL from $C0:EAF4).
-- At entry: Y = string address, stack S+4..S+5 = string bank (pushed A),
-- S+6 = saved B, S+7 = saved P, S+8..S+10 = return address of the caller's JSL.
local dumped = false
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local s = emu.getState()
  if not dumped then
    local keys = {}
    for k, _ in pairs(s) do if string.sub(k, 1, 4) == "cpu." then keys[#keys + 1] = k end end
    table.sort(keys); note("state keys: " .. table.concat(keys, " ")); dumped = true
  end
  local sp = s["cpu.sp"]
  local function rd(a) return emu.read(a, emu.memType.snesMemory) end
  local bank = rd(sp + 4)
  local ret = rd(sp + 8) | (rd(sp + 9) << 8) | (rd(sp + 10) << 16)
  local stack = {}
  for i = 1, 40 do stack[#stack + 1] = string.format("%02X", rd(sp + i)) end
  note(string.format("print %02X:%04X  X=%04X  caller ret=%06X  S=%04X  stack: %s",
    bank, s["cpu.y"], s["cpu.x"], ret, sp, table.concat(stack, " ")))
end, emu.callbackType.exec, 0x407960, 0x407960)
