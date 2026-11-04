-- Probe: calls to the scheduler's wait/sleep services and palette/colour-math writes,
-- per frame, from the first button press until FRAMES_G frames later -> build/waits.txt.
-- Each line: frame, service, A, X, caller (JSR return or, via a $C0:04xx trampoline,
-- the JSL return).
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
pcall(dofile, ROOTB .. "probe_waits_cfg.lua")
local out = io.open(ROOTB .. "waits.txt", "w")
local LIMIT = LIMIT_G or 260
local frame, armed, startF = 0, false, 0
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
local seen = {}
local function svc(name)
  return function()
    if not PROBE_ON or not armed then return end
    local s = emu.getState()
    local sp = s["cpu.sp"]
    local a, x = s["cpu.a"], s["cpu.x"]
    local ret = r8(sp + 1) | (r8(sp + 2) << 8)
    local caller = string.format("C0:%04X", (ret + 1) & 0xFFFF)
    -- called through a "JSR svc : RTL" trampoline at $C0:04xx? then show the JSL return
    if ret >= 0x0400 and ret < 0x0800 then
      local l = r8(sp + 3) | (r8(sp + 4) << 8) | (r8(sp + 5) << 16)
      caller = string.format("%06X(JSL)", (l + 1) & 0xFFFFFF)
    end
    local k = string.format("%s A=%04X X=%04X from %s", name, a, x, caller)
    local e = seen[k]
    if not e then e = {first = frame, last = frame, n = 0}; seen[k] = e end
    e.last = frame; e.n = e.n + 1
  end
end
emu.addMemoryCallback(svc("wait4E02"), emu.callbackType.exec, 0xC04E02, 0xC04E02)
emu.addMemoryCallback(svc("svc4D91"), emu.callbackType.exec, 0xC04D91, 0xC04D91)
emu.addMemoryCallback(svc("svc4E99"), emu.callbackType.exec, 0xC04E99, 0xC04E99)
emu.addMemoryCallback(svc("svc4D70"), emu.callbackType.exec, 0xC04D70, 0xC04D70)
emu.addMemoryCallback(svc("svc4EFA"), emu.callbackType.exec, 0xC04EFA, 0xC04EFA)
emu.addMemoryCallback(svc("svc4BED"), emu.callbackType.exec, 0xC04BED, 0xC04BED)
local cg, col = 0, {}
emu.addMemoryCallback(function() if armed then cg = cg + 1 end end, emu.callbackType.write, 0x2122, 0x2122)
emu.addMemoryCallback(function(addr, v) if armed then col[#col + 1] = string.format("%02X", v) end end,
  emu.callbackType.write, 0x2132, 0x2132)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  local pad = r8(0x4218) | (r8(0x4219) << 8)
  if not armed and pad ~= 0 then armpress = (armpress or 0) + 1; if armpress >= (ARM_PRESS_G or 1) then armed = true; startF = frame end end
  if armed then
    if cg > 0 or #col > 0 then
      out:write(string.format("F%d cgdata_writes=%d coldata=%s\n", frame, cg, table.concat(col, ",")))
    end
    cg, col = 0, {}
    if frame - startF >= LIMIT then
      armed = false
      local l = {}
      for k, e in pairs(seen) do l[#l + 1] = {k, e} end
      table.sort(l, function(p, q) return p[2].first < q[2].first end)
      for _, p in ipairs(l) do
        out:write(string.format("%s  frames %d-%d calls %d\n", p[1], p[2].first, p[2].last, p[2].n))
      end
      out:flush()
    end
  end
end, emu.eventType.endFrame)
