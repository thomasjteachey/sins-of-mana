-- generated: per-routine master clocks inside the bar code
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
  {"NmiHdma", 0xCBECDA, 0xCBED3B},
  {"BarGfx", 0xCBED3C, 0xCBEE7B},
  {"BarGfxEnd", 0xCBEE7C, 0xCBEE7B},
  {"SlotBit", 0xCBEE7C, 0xCBEE8B},
  {"RowBit", 0xCBEE8C, 0xCBEE9B},
  {"SlotTile", 0xCBEE9C, 0xCBEEAB},
  {"SlotBase", 0xCBEEAC, 0xCBEEBB},
  {"SlotBgX", 0xCBEEBC, 0xCBEECB},
  {"SlotBgY", 0xCBEECC, 0xCBEEDB},
  {"BlockFirst", 0xCBEEDC, 0xCBEEE1},
  {"BlockCap", 0xCBEEE2, 0xCBEEE7},
  {"BlockAnchor", 0xCBEEE8, 0xCBEEED},
  {"TagSlotOff", 0xCBEEEE, 0xCBEEFD},
  {"TagRowBit", 0xCBEEFE, 0xCBEF0D},
  {"TagDefs", 0xCBEF0E, 0xCBEF8E},
}
local tot, last, lastR, frames, done = {}, nil, nil, 0, false
local function clk() return emu.getState()["masterClock"] end
for _, r in ipairs(R) do
  emu.addMemoryCallback(function()
    local c = clk()
    if last and lastR and c - last < 2000 then tot[lastR] = (tot[lastR] or 0) + (c - last) end
    last, lastR = c, r[1]
  end, emu.callbackType.exec, r[2], r[3])
end
emu.addEventCallback(function()
  last, lastR = nil, nil
  if not PROBE_ON then tot = {}; return end
  frames = frames + 1
  if not done and emu.read(0x1FFF, emu.memType.snesWorkRam) == 0xAA then
    done = true
    local l = {}
    for k, v in pairs(tot) do l[#l + 1] = {k, v // frames} end
    table.sort(l, function(a, b) return a[2] > b[2] end)
    local t = {}
    for i = 1, #l do t[#t + 1] = l[i][1] .. "=" .. l[i][2] end
    note("PROF " .. table.concat(t, " "))
  end
end, emu.eventType.endFrame)
