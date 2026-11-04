-- Probe: every 4 frames, log which bytes of an entity record changed.
-- REC env = record address in bank $7F (hex, default ED60 = Duran). Starts when
-- $7E:1FFF == $AA.
local rec = tonumber(os.getenv("REC") or "ED60", 16)
local prev, frames, armed = nil, 0, false
emu.addEventCallback(function()
  if not PROBE_ON then return end
  if not armed then
    if emu.read(0x1FFF, emu.memType.snesWorkRam) ~= 0xAA then return end
    armed = true
  end
  frames = frames + 1
  if frames % 4 ~= 0 or frames > 240 then return end
  local cur = {}
  for i = 0, 0x1FF do cur[i] = emu.read(0x10000 + rec + i, emu.memType.snesWorkRam) end
  if prev then
    local ch = {}
    for i = 0, 0x1FF do
      if cur[i] ~= prev[i] then ch[#ch + 1] = string.format("+%03X:%02X>%02X", i, prev[i], cur[i]) end
    end
    if #ch > 0 then note(string.format("f%03d %s", frames, table.concat(ch, " "))) end
  end
  prev = cur
end, emu.eventType.endFrame)
