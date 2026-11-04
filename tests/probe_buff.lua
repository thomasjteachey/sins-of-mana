-- Test for the no-popup patches: catch the game's own call to the buff routine
-- (JSR $CE53 at $D0:C33D) and hand it "stat field 0 up" instead of no change.
-- POPUP_MODE env: "none" (Sin of Mana as is), "old" (original no_popup patch),
-- "fixed" (build/no_popup_messages_fixed.ips). Patch bytes are written into ROM live.
local mode = os.getenv("POPUP_MODE") or "none"
local OLD = { [0x10CE53] = {0x60}, [0x10D01A] = {0x60} }
local FIXED = {}
do -- read build/no_popup_messages_fixed.ips
  local f = io.open("C:/Projects/Gamedev/sins of mana/build/no_popup_messages_fixed.ips", "rb")
  local d = f:read("a"); f:close()
  local i = 6
  while d:sub(i, i + 2) ~= "EOF" do
    local off = d:byte(i) * 65536 + d:byte(i + 1) * 256 + d:byte(i + 2)
    local n = d:byte(i + 3) * 256 + d:byte(i + 4)
    local bytes = {}
    for k = 0, n - 1 do bytes[#bytes + 1] = d:byte(i + 5 + k) end
    FIXED[off] = bytes
    i = i + 5 + n
  end
end

local patched, injected, after = false, false, false
local recAddr = nil
local function rec()
  local t = {}
  for k = 0x35, 0x37 do t[#t + 1] = string.format("%02X", emu.read(recAddr + k, emu.memType.snesMemory)) end
  return table.concat(t, " ")
end

emu.addEventCallback(function()
  if not PROBE_ON or patched then return end
  patched = true
  local p = (mode == "old") and OLD or (mode == "fixed") and FIXED or {}
  local n = 0
  for off, bytes in pairs(p) do
    for k, b in ipairs(bytes) do emu.write(off + k - 1, b, emu.memType.snesPrgRom); n = n + 1 end
  end
  note("mode " .. mode .. ": wrote " .. n .. " patch bytes")
end, emu.eventType.startFrame)

emu.addMemoryCallback(function()
  if not PROBE_ON or injected then return end
  local s = emu.getState()
  local d = s["cpu.d"]
  recAddr = (s["cpu.dbr"] << 16) + emu.read16(d + 0x34, emu.memType.snesMemory)
  note(string.format("buff call: record %06X, buff bits before %s (A=%04X X=%04X)", recAddr, rec(), s["cpu.a"], s["cpu.x"]))
  s["cpu.a"] = tonumber(os.getenv("BUFF_A") or "64")
  s["cpu.x"] = tonumber(os.getenv("BUFF_X") or "0")
  emu.setState(s)
  injected = true
end, emu.callbackType.exec, 0xD0C33D, 0xD0C33D)

emu.addMemoryCallback(function()
  if not injected or after then return end
  after = true
  note("after buff routine: buff bits " .. rec())
end, emu.callbackType.exec, 0xD0C340, 0xD0C340)
