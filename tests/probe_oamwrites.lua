-- Probe: per frame, how many times the OAM buffer's Y bytes of entries 0-2 ($7F:0101, 0105,
-- 0109) are written, and by which code -> build/oamwrites.txt (first 40 frames).
local ROOTB = "C:/Projects/Gamedev/sins of mana/build/"
local out = io.open(ROOTB .. "oamwrites.txt", "w")
local frame, cnt, who = 0, {}, {}
for _, a in ipairs({0x7F0101, 0x7F0105, 0x7F0109}) do
  emu.addMemoryCallback(function(addr, value)
    if not PROBE_ON then return end
    cnt[addr] = (cnt[addr] or 0) + 1
    local s = emu.getState()
    who[string.format("%02X:%04X", s["cpu.k"], s["cpu.pc"])] = true
  end, emu.callbackType.write, a, a)
end
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frame = frame + 1
  if frame <= 40 then
    local w = {}
    for k in pairs(who) do w[#w + 1] = k end
    out:write(string.format("F%d e0 %d e1 %d e2 %d  by %s\n", frame, cnt[0x7F0101] or 0, cnt[0x7F0105] or 0,
      cnt[0x7F0109] or 0, table.concat(w, " ")))
    out:flush()
  end
  cnt, who = {}, {}
end, emu.eventType.endFrame)
