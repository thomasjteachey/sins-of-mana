-- Headless smoke test: boot the ROM, run some frames, save screenshots, quit.
-- Run: third_party/mesen2/Mesen.exe --testRunner build/som_desc.sfc tests/boot.lua
local OUT = "C:/Projects/Gamedev/sins of mana/build/"
local frames = 0

local function note(msg)
  local f = io.open(OUT .. "lua_log.txt", "a")
  if f then f:write(msg .. "\n"); f:close() end
  print(msg)
end

local function shot(name)
  local ok, png = pcall(emu.takeScreenshot)
  if not ok then note("screenshot error: " .. tostring(png)); return end
  local f, err = io.open(OUT .. name .. ".png", "wb")
  if f then f:write(png); f:close(); note("saved " .. name .. " (" .. #png .. " bytes)")
  else note("io failed: " .. tostring(err)) end
end

note("script start, io=" .. tostring(io ~= nil))
emu.addEventCallback(function()
  frames = frames + 1
  if frames == 300 or frames == 900 then shot("boot_" .. frames) end
  if frames >= 900 then note("done"); emu.stop(0) end
end, emu.eventType.endFrame)
