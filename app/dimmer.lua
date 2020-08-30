minDim = 0
maxDim = 1000
dimSteps = 10
local dimPeriod = 10

local current = 0
local target = 0

pwm2.setup_pin_hz(1, 240, 100, 0)
pwm2.start()

local dimTimer = tmr.create()

local function doStep()
  if dimPeriod == 0 then
    current = target
  else
    if target > current then
      current = current + dimSteps
      if current > target then current = target end
    else
      current = current - dimSteps
      if current < target then current = target end
    end
  end

  log("setting duty "..tostring(current + minDim))
  pwm2.set_duty(1, current + minDim)

  if current ~= target then
    dimTimer:start()
  end
end

dimTimer:register(dimPeriod, tmr.ALARM_SEMI, doStep)

function dimTo(newTarget)
  target = math.floor((maxDim - minDim) * newTarget / 100)
  log("new target: " .. tostring(target))
  if current ~= target then
    doStep()
  end
  return 100 * target / (maxDim - minDim)
end

function changeDimPeriod(newPeriod)
  dimPeriod = newPeriod
  if newPeriod ~= 0 then
    dimTimer:unregister()
    dimTimer:register(dimPeriod, tmr.ALARM_SEMI, doStep)
  end
end
