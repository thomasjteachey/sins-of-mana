local R = {
  {"Bars", 0xCBE400, 0xCBE5A8},
  {"Position", 0xCBE5A9, 0xCBE5CE},
  {"BuffMarker", 0xCBE5CF, 0xCBE627},
  {"AddBar", 0xCBE628, 0xCBE6C3},
  {"Setup", 0xCBE6C4, 0xCBE743},
  {"DrawSlot", 0xCBE744, 0xCBE7D0},
  {"ClearSlot", 0xCBE7D1, 0xCBE7F9},
  {"FirstCell", 0xCBE7FA, 0xCBE816},
  {"ScanRows", 0xCBE817, 0xCBE85E},
  {"BuildTable", 0xCBE85F, 0xCBE991},
  {"EmitNormal", 0xCBE992, 0xCBE9B7},
  {"BandBusy", 0xCBE9B8, 0xCBE9DD},
  {"FillSteps", 0xCBE9DE, 0xCBEA0D},
  {"RevengeColour", 0xCBEA0E, 0xCBEA39},
  {"HudTags", 0xCBEA3A, 0xCBEA84},
  {"BlockShown", 0xCBEA85, 0xCBEAAF},
  {"CollectTags", 0xCBEAB0, 0xCBEAFC},
  {"RenderTags", 0xCBEAFD, 0xCBEBAB},
  {"PutTag", 0xCBEBAC, 0xCBEBD1},
  {"PutCell", 0xCBEBD2, 0xCBEC10},
  {"QueueHudRows", 0xCBEC11, 0xCBEC3D},
  {"QueueRows", 0xCBEC3E, 0xCBEC91},
  {"QueueOldRows", 0xCBEC92, 0xCBECB5},
  {"QueueTiles", 0xCBECB6, 0xCBECD9},
  {"NmiHdma", 0xCBECDA, 0xCBED3A},
}
local cnt, frames, done = {}, 0, false
for _, r in ipairs(R) do
  local name = r[1]
  emu.addMemoryCallback(function() cnt[name] = (cnt[name] or 0) + 1 end, emu.callbackType.exec, r[2], r[3])
end
emu.addEventCallback(function()
  if not PROBE_ON then cnt = {}; return end
  frames = frames + 1
  if not done and emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA then
    done = true
    local l, total = {}, 0
    for k, v in pairs(cnt) do l[#l + 1] = {k, v}; total = total + v end
    table.sort(l, function(a, b) return a[2] > b[2] end)
    local t = {}
    for i = 1, #l do t[#t + 1] = string.format("%s=%d", l[i][1], l[i][2] // frames) end
    note(string.format("ICOUNT per frame total=%d: %s", total // frames, table.concat(t, " ")))
  end
end, emu.eventType.endFrame)
