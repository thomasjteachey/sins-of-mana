-- Probe: stack pointer and direct page when the text hook runs (NewRedirect $56:8000, ShopNote's PHX)
-- -> build/hookstack.txt: per distinct (S, D) at entry, the count and the lowest S seen inside the hook,
-- and the X pushed by ShopNote.
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "hookstack.txt", "w")
pcall(dofile, ROOTB .. "probe_hookstack_cfg.lua")
local SHOPNOTE_PHX = HOOK_PHX or 0x568060
local stats, frame = {}, 0
local function nl(s) out:write(s .. string.char(10)); out:flush() end
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local s = emu.getState()
  local key = string.format("S=%04X D=%04X", s["cpu.sp"], s["cpu.d"])
  stats[key] = (stats[key] or 0) + 1
end, emu.callbackType.exec, 0x568000, 0x568000)
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local s = emu.getState()
  local key = string.format("ShopNote PHX S=%04X (writes %04X-%04X) D=%04X X=%04X", s["cpu.sp"], s["cpu.sp"] - 1, s["cpu.sp"],
    s["cpu.d"], s["cpu.x"])
  stats[key] = (stats[key] or 0) + 1
end, emu.callbackType.exec, SHOPNOTE_PHX, SHOPNOTE_PHX)
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if frame % 60 == 0 then
    local f = io.open(ROOTB .. "hookstack.txt", "w")
    local keys = {}
    for k in pairs(stats) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do f:write(string.format("%6d  %s", stats[k], k) .. string.char(10)) end
    f:close()
  end
end, emu.eventType.endFrame)
