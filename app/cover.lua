--[[
~12.5A-13.5A starting amps (for ~1.5s)
~5-6A continuous amps
~9.5-10.5A halt amps (for ~1s)
--]]


-- 0 - stopped
-- 1 - waiting for startup surge
-- 2 - waiting for startup surge to subside
-- 3 - moving
state = 0

-- also corresponds to the GPIO pin controlling the relay for that direction
-- 0 - open
-- 3 - close
direction = nil
local target = nil

-- 0 open
position = nil
range = nil

function stopMovement()
  if direction ~= nil then
    gpio.write(direction, gpio.HIGH)
    state = 0
    direction = nil
    target = nil
    if (stateChanged) then
      stateChanged()
    end
  end
end

function startMovement(dir, newTarget)
  stopMovement()
  direction = dir
  -- default to targetting 0 position for open, or limit on close
  target = newTarget or (dir == 0 and 0 or nil)
  gpio.write(direction, gpio.LOW)
  state = 1
  if (stateChanged) then
    stateChanged()
  end
  -- skip startup surge detection if debug
  if (DEBUG) then
    state = 2
    DEBUG = 5
  end
  tmr.create():alarm(250, tmr.ALARM_SINGLE, function()
    if state == 1 then
      stopMovement()
      log("aborting because motor never started")
    end
  end)
end

function moveTo(newTarget)
  -- allow opening even if we don't know range yet
  if newTarget == 0 then
    startMovement(0)
    return
  end

  -- can't do anything if we don't know where we are yet
  -- (or if we're already at the requested position)
  if range == nil or position == nil or newTarget == position then
    return
  end

  -- full close
  if newTarget == range then
    startMovement(3)
  elseif newTarget < position then
    startMovement(0, newTarget)
  else
    startMovement(3, newTarget)
  end
end

function ampsUpdated()
  if DEBUG then
    currentAmps = DEBUG
  end

  -- failsafe
  if currentAmps > 15 then
    stopMovement()
    log("overload abort")
  end

  if state == 1 then
    if currentAmps > 10 then
      state = 2
      log("saw startup surge")
      tmr.create():alarm(200, tmr.ALARM_SINGLE, function()
        if state == 2 then
          stopMovement()
          log("aborting because startup surge took too long")
        end
      end)    
    end
  elseif state == 2 then
    if currentAmps < 2 then
      stopMovement()
      log("power cut after startup surge??")
    elseif currentAmps < 7 then
      state = 3
      if (stateChanged) then
        stateChanged()
      end
      log("startup surge complete")
    end
  elseif state == 3 then
    if currentAmps > 7 then
      if direction == 1 then
        -- automatically set range if we hit the end
        -- AND we actually know where we are
        if position ~= nil then
          range = position
        end
        position = range
      else
        if range ~= nil and position ~= nil then
          range = range - position
        end
        position = 0
      end
      if positionChanged then
        positionChanged()
      end
      stopMovement()
      log("limit reached")
    elseif currentAmps < 2 then
      stopMovement()
      log("power cut during normal movement??")
    end
  end
end

function counterHit()
  if direction == nil then
    log("cover moved while motor not moving??")
    return
  end

  if position ~= nil then
    position = position + (direction == 1 and 1 or -1)
    if positionChanged then
      positionChanged()
    end
    if target ~= nil and position == target then
      log("target reached")
      stopMovement()
    end
  end
end
