if HAS_LATCH then
  locked = true
  latched = true
  if HAS_CONTACT then
    closed = gpio.read(7) == 0
  end

  local latchTimer
  local openTimer
end  

if HAS_PUSH_TO_EXIT then
  restricted = false
end

local lastInput = 0
local successTimer

function signalSuccess()
  -- have to delay success sending until we didn't recently get input
  delta = tmr.now() - lastInput
  if delta < 0 then delta = delta + 2147483647 end;
  if delta < 500000 then
    tmr.create():alarm(500, tmr.ALARM_SINGLE, function()
      signalSuccess()
    end)
    return
  end

  if successTimer then
    log("extending success signal")
    successTimer:stop()
    successTimer:start()
  else
    log("signaling success")
    gpio.write(5, gpio.LOW)
    successTimer = tmr.create()
    successTimer:alarm(2000, tmr.ALARM_SINGLE, function()
      gpio.write(5, gpio.HIGH)
      log("success done")
      successTimer = nil
    end)
  end
end

if HAS_LATCH then
  function unlatch()
    if HAS_CONTACT and not closed then
      log("not unlatching because the gate is open")
      return
    end

    if not latched then
      latchTimer:stop()
      latchTimer:start()
      return
    end

    log("unlatching")

    gpio.write(0, gpio.LOW)
    latched = false
    latchedChanged()
    latchTimer = tmr.create()
    latchTimer:alarm(5000, tmr.ALARM_SINGLE, function()
      log("re-latching")
      gpio.write(0, gpio.HIGH)
      latched = true
      latchedChanged()
      latchTimer = nil
    end)
  end

  if HAS_CONTACT then
    -- closed contact
    gpio.trig(7, "both", function()
      local newClosed = gpio.read(7) == 0
      if newClosed ~= closed then
        closed = newClosed
        closedChanged()
      end
      log("contact changed "..tostring(newClosed))
      -- latch is closed, but it wasn't open long enough to be useful;
      -- abort the quick-re-latch
      if closed and openTimer then
        openTimer:stop()
        openTimer:unregister()
        openTimer = nil
        return
      end

      if not latched and not closed then
        if openTimer then
          openTimer:stop()
          openTimer:start()
          return
        end

        openTimer = tmr.create()
        openTimer:alarm(500, tmr.ALARM_SINGLE, function()
          log("re-latched because door opened")
          gpio.write(0, gpio.HIGH)
          latched = true
          latchedChanged()
          if latchTimer then
            latchTimer:stop()
            latchTimer:unregister()
            latchTimer = nil
            log("latch timer canceled")
          end
          openTimer = nil
        end)
      end
    end)
  end
end

-- bell
gpio.trig(4, "down", function()
  triggered = gpio.read(4) == 0
  log("bell pressed: " .. tostring(triggered))
  if triggered then triggerBell() end
end)

-- push-to-exit
if HAS_PUSH_TO_EXIT then
  gpio.trig(6, "both", function()
    triggered = gpio.read(6) == 0
    log("exit requested: " .. tostring(triggered))
    if triggered then triggerPushToExit() end
    if triggered and not restricted then unlatch() end
  end)
end

local totalCode = ""
local keypadTimeout
local lastEsc = false
local lastEnter = false

wiegand.create(1, 2, function(code, type)
  log("got code "..code)
  lastInput = tmr.now()
  if keypadTimeout then
    keypadTimeout:stop()
    keypadTimeout:unregister()
    keypadTimeout = nil
  end
  if type == 4 then
    if code == 10 then -- *
      -- two esc in a row means to unlatch
      if totalCode == "" then
        if lastEsc then
          lastEsc = false
          if HAS_LATCH then
            if not locked then
              signalSuccess()
              unlatch()
            end
          else
            -- we don't have a local latch; let the hub handle it
            receivedCode("**")
          end
        else
          lastEsc = true
          keypadTimeout = tmr.create()
          keypadTimeout:alarm(4000, tmr.ALARM_SINGLE, function()
            lastEsc = false
          end)
        end
      end
      lastEnter = false
      totalCode = ""
    elseif code == 11 then -- #
      if totalCode ~= "" then
        receivedCode(totalCode)
        totalCode = ""
        lastEnter = false
      elseif lastEnter then
        -- two enter in a row means to lock
        lastEnter = false
        if HAS_LATCH then
          locked = true
          lockedChanged()
          signalSuccess()
        else
          -- we don't have a local latch; let the hub handle it
          receivedCode("##")
        end
      else
        lastEnter = true
        keypadTimeout = tmr.create()
        keypadTimeout:alarm(4000, tmr.ALARM_SINGLE, function()
          lastEnter = false
        end)
      end
      lastEsc = false
    else
      lastEsc = false
      lastEnter = false
      totalCode = totalCode .. tostring(code)
      keypadTimeout = tmr.create()
      keypadTimeout:alarm(4000, tmr.ALARM_SINGLE, function()
        totalCode = ""
      end)
    end
  else
    -- prepend a * so it knows it came from an RFID read
    -- also include any pending typed PIN in case you want
    -- to require both
    receivedCode(totalCode.."*"..code)
    totalCode = ""
    lastEsc = false
    lastEnter = false
  end
end)
