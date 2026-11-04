-- Scripted input driver for headless Mesen runs.
-- Reads build/steps.lua, which must define:
--   STEPS = { {keys="start", hold=2, wait=30}, {shot="name"}, {save="name"}, ... }
--   START_STATE = "name" or nil   (loads build/states/<name>.mss first)
--   DEBUG_PAD = true/false        (log joypad registers while a button is held)
-- Written by tools/run.py; see that file for usage.
local ROOT = "C:/Projects/Gamedev/sins of mana/build/"
dofile(ROOT .. "steps.lua")

function note(msg)
  local f = io.open(ROOT .. "lua_log.txt", "a")
  if f then f:write(msg .. "\n"); f:close() end
end

local function readfile(p)
  local f = io.open(p, "rb"); if not f then return nil end
  local d = f:read("a"); f:close(); return d
end

local function writefile(p, d)
  local f = io.open(p, "wb"); if f then f:write(d); f:close(); return true end
  return false
end

-- Optional probe script (extra memory/exec callbacks), set by tools/run.py --probe.
-- Probes should check PROBE_ON so they stay quiet while a start state is loading.
PROBE_ON = false
if PROBE_FILE then dofile(PROBE_FILE) end

local stopped = false
local step, holdLeft, waitLeft, held = 1, 0, 0, {}
local frame = 0
local pendingLoad = START_STATE   -- savestates are done in startFrame (Mesen requires it)
local pendingSave = nil
local busy = (START_STATE ~= nil) -- don't run steps until the start state is loaded

emu.addEventCallback(function()
  local inp = {}
  if holdLeft > 0 then for k, _ in pairs(held) do inp[k] = true end end
  emu.setInput(inp, 0)
end, emu.eventType.inputPolled)

local execRef = nil
local function doPending()
  if stopped then return end
  if pendingLoad then
    local d = readfile(ROOT .. "states/" .. pendingLoad .. ".mss")
    if not d then note("missing state " .. pendingLoad); stopped = true; emu.stop(2); return end
    local ok, err = pcall(emu.loadSavestate, d)
    note(ok and ("loaded state " .. pendingLoad) or ("load failed: " .. tostring(err)))
    if not ok then stopped = true; emu.stop(3); return end
    pendingLoad = nil; busy = false; PROBE_ON = true
  end
  if pendingSave then
    local ok, d = pcall(emu.createSavestate)
    if ok then writefile(ROOT .. "states/" .. pendingSave .. ".mss", d); note("saved state " .. pendingSave)
    else note("save failed: " .. tostring(d)) end
    pendingSave = nil; busy = false
  end
  if execRef and not pendingLoad and not pendingSave then
    emu.removeMemoryCallback(execRef, emu.callbackType.exec, 0x000000, 0xFFFFFF)
    execRef = nil
  end
end

-- Savestates may only be made/loaded inside a CPU exec callback, so hook
-- execution only while one is pending.
local function armExec()
  if not execRef then
    execRef = emu.addMemoryCallback(doPending, emu.callbackType.exec, 0x000000, 0xFFFFFF)
  end
end
if pendingLoad then armExec() else PROBE_ON = true end

emu.addEventCallback(function()
  if stopped or busy then return end
  frame = frame + 1
  if holdLeft > 0 then
    if DEBUG_PAD then
      local lo = emu.read(0x4218, emu.memType.snesMemory)
      local hi = emu.read(0x4219, emu.memType.snesMemory)
      note(string.format("frame %d pad $4218=%02X $4219=%02X", frame, lo, hi))
    end
    holdLeft = holdLeft - 1; return
  end
  if waitLeft > 0 then waitLeft = waitLeft - 1; return end
  while true do
    local s = STEPS[step]
    if s == nil then note("done at frame " .. frame); stopped = true; emu.stop(0); return end
    step = step + 1
    if s.shot then
      writefile(ROOT .. "shots/" .. s.shot .. ".png", emu.takeScreenshot())
      note("shot " .. s.shot)
    elseif s.save then
      pendingSave = s.save; busy = true; armExec()
      return
    elseif s.poke then
      -- "7FEE61=02,03": write bytes starting at a 24-bit WRAM address ($7E/$7F)
      local addr, bytes = string.match(s.poke, "(%x+)=([%x,]+)")
      local a = tonumber(addr, 16) - 0x7E0000
      for b in string.gmatch(bytes, "%x+") do
        emu.write(a, tonumber(b, 16), emu.memType.snesWorkRam); a = a + 1
      end
      note("poked " .. s.poke)
    elseif s.dump then
      -- dump all 128 KB of work RAM ($7E:0000-$7F:FFFF)
      local parts = {}
      for base = 0, 0x1FFFF, 0x1000 do
        local chunk = {}
        for i = 0, 0xFFF do chunk[i + 1] = emu.read(base + i, emu.memType.snesWorkRam) end
        parts[#parts + 1] = string.char(table.unpack(chunk))
      end
      writefile(ROOT .. "ram/" .. s.dump .. ".bin", table.concat(parts))
      note("dumped ram " .. s.dump)
    elseif s.keys or s.wait then
      held = {}
      if s.keys then for k in string.gmatch(s.keys, "[^+]+") do held[k] = true end end
      holdLeft = s.keys and (s.hold or 2) or 0
      waitLeft = s.wait or 0
      return
    end
  end
end, emu.eventType.endFrame)
