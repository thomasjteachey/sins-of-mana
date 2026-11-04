-- Probe: every call of the graphics decoders ($E8:C484 tiles, $E8:C480 doubled pixels,
-- $C2:3B87 field graphics) with what it changed -> build/dec_<DEC_TAG>.txt.
-- Per call: inputs, every direct-page byte that differs from entry, registers and stack
-- pointer on return, a checksum of the output buffer and of 64 bytes around it.
-- Same scenario on the old and the new ROM: the logs must match line for line.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
DEC_TAG = "x"
pcall(dofile, ROOTB .. "probe_dec_cfg.lua")
local out = io.open(ROOTB .. "dec_" .. DEC_TAG .. ".txt", "w")
local frame = 0
local function r8(a) return emu.read(a, emu.memType.snesMemory) end
local function r16(a) return r8(a) | (r8(a + 1) << 8) end
local pend = nil           -- {kind, ret, sp, d, db, dp, outlo, outhi}
local keysLogged = false
local function st() return emu.getState() end

local function sum(bank, lo, len)
  local h = 0
  for i = 0, len - 1 do
    h = (h * 31 + r8(bank * 65536 + ((lo + i) & 0xFFFF))) % 4294967291
  end
  return h
end

local ENTRY = { [0xE8C484] = "tiles", [0xE8C480] = "stretch", [0xC23B87] = "field" }

emu.addMemoryCallback(function(address)
  if not PROBE_ON then return end
  local kind = ENTRY[address]
  if kind and not pend then
    local s = st()
    if not keysLogged then
      keysLogged = true
      local k = {}
      for key, _ in pairs(s) do if string.sub(key, 1, 4) == "cpu." then k[#k + 1] = key end end
      table.sort(k)
      out:write("KEYS " .. table.concat(k, " ") .. "\n")
    end
    local sp, d = s["cpu.sp"], s["cpu.d"]
    local db = s["cpu.dbr"] or s["cpu.db"] or 0
    local dp = {}
    for i = 0, 255 do dp[i] = r8(d + i) end
    local ret, rsz
    if kind == "field" then
      ret = (address & 0xFF0000) | ((r16(sp + 1) + 1) & 0xFFFF); rsz = 2
    else
      ret = ((r8(sp + 3) << 16) | r16(sp + 1)) + 1; rsz = 3
    end
    local lo, len
    if kind == "tiles" then lo = dp[0x13] | (dp[0x14] << 8); len = ((dp[0x28] | (dp[0x29] << 8)) * 32) & 0xFFFF
    elseif kind == "stretch" then lo = dp[0x10] | (dp[0x11] << 8); len = 0x980
    else
      local t = (dp[0x44] | (dp[0x45] << 8))
      lo = dp[0x76] | (dp[0x77] << 8); len = ((((t * 32) & 0xFFFF) + 7) >> 3) * 8
    end
    local src = "-"
    if kind == "tiles" then src = string.format("%02X%02X%02X", dp[0x12], dp[0x11], dp[0x10])
    elseif kind == "field" then src = string.format("%02X%02X%02X", dp[0x75], dp[0x74], dp[0x73]) end
    pend = { kind = kind, ret = ret, sp = sp, rsz = rsz, d = d, db = db, dp = dp, lo = lo, len = len,
             a = s["cpu.a"], x = s["cpu.x"], y = s["cpu.y"], p = s["cpu.ps"] or s["cpu.p"] or 0, src = src }
    return
  end
  if pend and address == pend.ret then
    local s = st()
    if s["cpu.sp"] ~= pend.sp + pend.rsz then return end   -- a deeper return to the same address
    local changed = {}
    for i = 0, 255 do
      local v = r8(pend.d + i)
      -- bytes at or below the entry stack pointer are free stack space: skip them
      if v ~= pend.dp[i] and pend.d + i > pend.sp then
        changed[#changed + 1] = string.format("%02X:%02X>%02X", i, pend.dp[i], v)
      end
    end
    local p = s["cpu.ps"] or s["cpu.p"] or 0
    out:write(string.format("%s src=%s out=%02X:%04X+%X D=%04X in(A=%04X X=%04X Y=%04X) out(A=%04X X=%04X Y=%04X MX=%02X) sum=%u around=%u/%u dp[%s]\n",
      pend.kind, pend.src, pend.db, pend.lo, pend.len, pend.d, pend.a, pend.x, pend.y,
      s["cpu.a"], s["cpu.x"], s["cpu.y"], p & 0x30,
      sum(pend.db, pend.lo, pend.len), sum(pend.db, pend.lo - 32, 32), sum(pend.db, pend.lo + pend.len, 32),
      table.concat(changed, " ")))
    out:flush()
    pend = nil
  end
end, emu.callbackType.exec, 0x000000, 0xFFFFFF)

emu.addEventCallback(function()
  if PROBE_ON then frame = frame + 1 end
end, emu.eventType.endFrame)
