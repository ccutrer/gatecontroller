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

-- 0 open
position = nil
range = nil
target = nil

local lockTimer = nil
local movementTimer = nil

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
  if lockTimer ~= nil then
    lockTimer:start()
  end
  if movementTimer ~= nil then
    movementTimer:stop()
    movementTimer:unregister()
    movementTimer = nil
  end
end

function startMovement(dir, newTarget)
  stopMovement()
  if lockTimer ~= nil then
    lockTimer:stop()
  end
  direction = dir
  -- default to targetting 0 position for open, or limit on close
  target = newTarget or (dir == 0 and 0 or nil)
  log("starting movement towards "..tostring(direction).." target "..tostring(target))
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
  tmr.create():alarm(2500, tmr.ALARM_SINGLE, function()
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

  if newTarget == range then
    -- full close
    startMovement(3)
  elseif newTarget == 0 then
    -- full open
    startMovement(0)
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
  if currentAmps > 18 then
    stopMovement()
    log("overload abort")
  end

  if state == 1 then
    if currentAmps > 8 then
      state = 2
      log("saw startup surge")
      tmr.create():alarm(500, tmr.ALARM_SINGLE, function()
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
    elseif currentAmps < 9 then
      state = 3
      if (stateChanged) then
        stateChanged()
      end
      log("startup surge complete")
      if position == 0 and direction == 3 and not HAS_COUNTER then
        position = 1
        if (positionChanged) then
          positionChanged()
        end
      elseif position == range and direction == 0 and not HAS_COUNTER then
        if range ~= nil then
          position = range - 1
        end
        if (positionChanged) then
          positionChanged()
        end
      end
    end
  elseif state == 3 then
    if currentAmps > 12 then
      if direction == 3 then
        -- automatically set range if we hit the end
        -- AND we actually know where we are
        if position ~= nil and position > 2 and HAS_COUNTER then
          range = position
        end
        position = range
      else
        if range ~= nil and position ~= nil and range ~= position and HAS_COUNTER then
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
  log("counter hit")

  if position ~= nil then
    position = position + (direction == 3 and 1 or -1)
    if positionChanged then
      positionChanged()
    end
    if target ~= nil and target ~= 0 and position == target then
      log("target reached")
      stopMovement()
    end
  end

  if movementTimer == nil then
    log("starting movement timer")
    movementTimer = tmr.create()
    movementTimer:alarm(2000, tmr.ALARM_SINGLE, function()
      if state ~= 0 then
        log("aborting because no movement detected")
        stopMovement()
      else
        log("movement timer hit when not running?")
        movementTimer = nil
      end
    end)
  else
    log("restarting movement timer")
    movementTimer:stop()
    movementTimer:start()
  end
end

locked = true
local remoteUnlock = false

function unlock(remote)
  if locked then
    log("unlocking")
    locked = false
    remoteUnlock = true
    gpio.write(8, gpio.LOW)
    lockTimer = tmr.create()
    lockTimer:alarm(10000, tmr.ALARM_SINGLE, function()
      log("timed out")
      lockTimer = nil
      lock()
    end)
    lockedChanged()
  end
end

function lock()
  if not locked then
    log("locking")
    locked = true
    gpio.write(8, gpio.HIGH)
    if lockTimer ~= nil then
      lockTimer:stop()
      lockTimer:unregister()
      lockTimer = nil
    end
    lockedChanged()
  end
end

local open = 1
local close = 1

local function buttonPressed(pin)
  if pin == 6 then
    open = gpio.read(6)
  end
  if pin == 7 then
    close = gpio.read(7)
  end

  log("button press open: "..tostring(open).." close "..tostring(close))

  -- ignore "no button press" when remotely triggered
  if open == 1 and close == 1 and remoteUnlock then return end

  remoteUnlock = false
  -- both buttons pressed; you're always allowed to stop
  -- even if locked (remote control)
  if open == 0 and close == 0 then
    stopMovement()
  end

  if locked == true then return end

  if open == 0 and close == 1 then
    startMovement(0)
  elseif open == 1 and close == 0 then
    startMovement(3)
  else
    stopMovement()
  end
end

gpio.trig(6, "both", function(level) buttonPressed(6, level) end)
gpio.trig(7, "both", function(level) buttonPressed(7, level) end)

local last = 0
local delay = 100000 -- 100ms * 1000 as tmr.now() has μs resolution

local function debounceCounter()
  local now = tmr.now()
  local delta = now - last
  if delta < 0 then delta = delta + 2147483647 end
  if delta < delay then
    log("discarding counter hit of "..tostring(delta))
    return
  end

  last = now

  counterHit()
end

if HAS_COUNTER then
  gpio.trig(9, "down", debounceCounter)
end
