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

local function signalSuccess()
  -- have to delay success sending until we didn't recently get input
  delta = tmr.now() - lastInput
  if delta < 0 then delta = delta + 2147483647 end;
  if delta < 500000 then
    tmr.create():alarm(500, tmr.ALARM_SINGLE, function()
      signalSuccess()
    end)
    return
  end

  gpio.write(5, gpio.LOW)
  tmr.create():alarm(500, tmr.ALARM_SINGLE, function()
    gpio.write(5, gpio.HIGH)
  end)
end

if HAS_LATCH then
  function unlatch()
    if HAS_CONTACT and closed == false then
      return
    end

    if latched == false then
      latchTimer:stop()
      latchTimer:start()
      return
    end

    print("unlatching")
    signalSuccess()

    gpio.write(0, gpio.LOW)
    latched = false
    latchedChanged()
    latchTimer = tmr.create()
    latchTimer:alarm(5000, tmr.ALARM_SINGLE, function()
      print("re-latching")
      gpio.write(0, gpio.HIGH)
      latched = true
      latchedChanged()
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
      print("contact changed "..tostring(newClosed))
      -- latch is closed, but it wasn't open long enough to be useful;
      -- abort the quick-re-latch
      if closed == true and openTimer then
        openTimer:stop()
        openTimer:unregister()
        return
      end

      if latched == false and closed == false then
        if openTimer then
          openTimer:stop()
          openTimer:start()
          return
        end

        openTimer = tmr.create()
        openTimer:alarm(500, tmr.ALARM_SINGLE, function()
          print("re-latched because door opened")
          gpio.write(0, gpio.HIGH)
          latched = true
          latchedChanged()
          if latchTimer then
            latchTimer:stop()
            latchTimer:unregister()
            latchTimer = nil
            print("latch timer canceled")
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
  print("bell pressed: " .. tostring(triggered))
  if triggered then 
    if HAS_LATCH and locked == false then
      unlatch()
    else
      triggerBell()
    end
  end
end)

-- push-to-exit
if HAS_PUSH_TO_EXIT then
  gpio.trig(6, "both", function()
    triggered = gpio.read(6) == 0
    print("exit requested: " .. tostring(triggered))
    if triggered and restricted == false then unlatch() end
  end)
end

local totalCode = ""
local keypadTimeout
local lastEsc = false

wiegand.create(1, 2, function(code, type)
  print("got code "..code)
  lastInput = tmr.now()
  if type == 4 then
    if keypadTimeout then
      keypadTimeout:stop()
      keypadTimeout:unregister()
      keypadTimeout = nil
    end
    if code == 10 then -- *
      -- two esc in a row means to lock
      if totalCode == "" then
        if lastEsc then
          lastEsc = false
          if HAS_LATCH then
            locked = true
            lockedChanged()
          else
            -- we don't have a local latch; let the hub handle it
            receivedCode("**")
          end
          signalSuccess()
        else
          lastEsc = true
          keypadTimeout = tmr.create()
          keypadTimeout:alarm(4000, tmr.ALARM_SINGLE, function()
            lastEsc = false
          end)
        end
      end
      totalCode = ""
    elseif code == 11 then -- #
      if totalCode ~= "" then
        receivedCode(totalCode)
        totalCode = ""
      end
      lastEsc = false
    else
      lastEsc = false
      totalCode = totalCode .. tostring(code)
      keypadTimeout = tmr.create()
      keypadTimeout:alarm(4000, tmr.ALARM_SINGLE, function()
        totalCode = ""
      end)
    end
  else
    -- prepend a * so it knows it came from an RFID read
    receivedCode("*"..code)
  end
end)
