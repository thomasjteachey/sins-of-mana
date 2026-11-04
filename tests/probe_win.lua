local done = false
emu.addEventCallback(function()
  if not PROBE_ON or done or emu.read(0x1FFF, emu.memType.snesWorkRam) ~= 0xAA then return end
  done = true
  local s = emu.getState()
  local keys = {}
  for k, v in pairs(s) do
    if (string.find(k, "window") or string.find(k, "Window") or string.find(k, "mask") or string.find(k, "Mask") or string.find(k, "Layers") or string.find(k, "colorMath")) and type(v) ~= "table" then
      keys[#keys + 1] = k .. "=" .. tostring(v)
    end
  end
  table.sort(keys)
  note("WIN " .. table.concat(keys, " "))
end, emu.eventType.endFrame)
