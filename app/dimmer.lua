minDim = 0
maxDim = 1023
dimSteps = 10
local dimPeriod = 10

local current = 0
local target = 0

pwm.setup(1, 100, 0)

local dimTimer = tmr.create()

local function doStep()
  if current == 0 then
    log("turning on")
    pwm.start(1)
  end

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

  if current == 0 then
    log("turning off")
    pwm.stop(1)
  else
    log("setting duty "..tostring(current + minDim))
    pwm.setduty(1, current + minDim)
  end

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
