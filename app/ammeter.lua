
currentAmps = 0

local mVperAmp = 100

local buffer_idx = 1
local ammeterReadings = {} 

local function getVPP()
  local min, max = 1024, 0
  for _, val in ipairs(ammeterReadings) do
    if val < min then
      min = val
    end
    if val > max then
      max = val
    end
  end
  -- I don't know why this is 5, not 3.3, but the results seem sane cross-checked against a clamp meter
  return ((max - min) * 5) / 1024.0
end

local function getAmps()
voltage = getVPP()
vRMS = (voltage/2.0)*0.707
return vRMS * 1000/mVperAmp
end

local ammeterTimer = tmr.create()
-- 15ms, 10 samples kept = 0.15s total buffered
ammeterTimer:alarm(15, tmr.ALARM_AUTO, function()
  ammeterReadings[buffer_idx] = adc.read(0)
  buffer_idx = buffer_idx + 1
  if #ammeterReadings == 10 and buffer_idx % 10 == 0 then
    currentAmps = getAmps()
    if (ampsUpdated) then
      ampsUpdated()
    end
  end
  if buffer_idx == 11 then
    buffer_idx = 1
  end
end)
