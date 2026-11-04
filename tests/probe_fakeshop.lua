-- Test: stand in for an equipment shop in Deen's class-item shop. After each item name the
-- shop bar prints ($FB:3006-$32FF), point the shop note (!ShopDesc $7E:28F0, stamp $7E:28F2)
-- at a real description (FAKE_DESC_G, alternating per item), as ShopNote would for equipment.
pcall(dofile, "C:/Projects/Gamedev/sins of mana/build/probe_fakeshop_cfg.lua")
local n, pending = 0, nil
emu.addMemoryCallback(function()
  if not PROBE_ON then return end
  local s = emu.getState()
  if (s["cpu.a"] & 0xFF) == 0xFB and s["cpu.y"] >= 0x3006 and s["cpu.y"] < 0x3300 then
    n = n + 1
    pending = FAKE_DESC_G[(n % #FAKE_DESC_G) + 1]
  end
end, emu.callbackType.exec, 0xC0EADA, 0xC0EADA)
emu.addEventCallback(function()
  if not PROBE_ON or not pending then return end
  local function w16(a, v) emu.write(a, v & 0xFF, emu.memType.snesWorkRam); emu.write(a + 1, v >> 8, emu.memType.snesWorkRam) end
  w16(0x28F0, pending)
  w16(0x28F2, emu.read16(0x7F00C6, emu.memType.snesMemory))
  pending = nil
end, emu.eventType.endFrame)
