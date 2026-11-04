-- Probe: log a few addresses every N frames (TRACK env: "1E506,1CC60", WRAM offsets; EVERY env)
local addrs = {}
for a in string.gmatch(os.getenv("TRACK") or "1E506", "%x+") do addrs[#addrs + 1] = tonumber(a, 16) end
local every = tonumber(os.getenv("EVERY") or "20")
local frames = 0
emu.addEventCallback(function()
  if not PROBE_ON then return end
  frames = frames + 1
  if frames % every ~= 0 then return end
  local t = {}
  for _, a in ipairs(addrs) do t[#t + 1] = string.format("%05X=%3d", a, emu.read(a, emu.memType.snesWorkRam)) end
  note(string.format("f%04d state %02X  %s", frames, emu.read(0x1ED60, emu.memType.snesWorkRam), table.concat(t, " ")))
end, emu.eventType.endFrame)
