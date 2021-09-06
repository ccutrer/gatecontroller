ds18b20 = require("ds18b20")

local function readout(temp)
  for addr, temp in pairs(temp) do
    if tempChanged ~= nil then
      tempChanged(('%02x-%02x-%02x-%02x-%02x-%02x-%02x-%02x'):format(addr:byte(1,8)), temp)
    end
  end
end

ds18b20:read_temp(readout, 3, ds18b20.C)

local function read()
  ds18b20:read_temp(readout, 3, ds18b20.C)
end

local timer = tmr.create()

timer:alarm(15000, tmr.ALARM_AUTO, read)

function changeReportPeriod(newPeriod)
  timer:stop()
  timer:unregister()
  -- do an immediate read
  read()
  timer:alarm(newPeriod, tmr.ALARM_AUTO, read)
end
