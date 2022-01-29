local m = mqtt.Client(wifi.sta.getmac(), 120, MQTT_USERNAME, MQTT_PASSWORD)

m:lwt("homie/"..NODE_NAME.."/$state", "lost", 1, 1)

local connected = false
local connectionAttempts = 0

m:on("connect", function(client)
  print("connected to MQTT")
  connected = true
  connectionAttempts = 0

  client:publish("homie/"..NODE_NAME.."/$state", "init", 1, 1)
  client:publish("homie/"..NODE_NAME.."/$homie", "4.0.0", 1, 1)
  client:publish("homie/"..NODE_NAME.."/$fwversion", tostring(VERSION), 1, 1)
  client:publish("homie/"..NODE_NAME.."/$name", "Gate Controller", 1, 1)
  local nodes = "keypad"
  
  if HAS_KEYPAD then
    client:publish("homie/"..NODE_NAME.."/keypad/$name", "Keypad", 1, 1)
    client:publish("homie/"..NODE_NAME.."/keypad/$type", "Weigand", 1, 1)
    client:publish("homie/"..NODE_NAME.."/keypad/$properties", "code,bell,success", 1, 1)

    client:publish("homie/"..NODE_NAME.."/keypad/code/$name", "Received Code", 1, 1)
    client:publish("homie/"..NODE_NAME.."/keypad/code/$datatype", "string", 1, 1)
    client:publish("homie/"..NODE_NAME.."/keypad/code/$retained", "false", 1, 1)

    client:publish("homie/"..NODE_NAME.."/keypad/bell/$name", "Bell Pressed", 1, 1)
    client:publish("homie/"..NODE_NAME.."/keypad/bell/$datatype", "boolean", 1, 1)
    client:publish("homie/"..NODE_NAME.."/keypad/bell/$retained", "false", 1, 1)

    client:publish("homie/"..NODE_NAME.."/keypad/success/$name", "Signal Success", 1, 1)
    client:publish("homie/"..NODE_NAME.."/keypad/success/$datatype", "boolean", 1, 1)
    client:publish("homie/"..NODE_NAME.."/keypad/success/$retained", "false", 1, 1)
    client:publish("homie/"..NODE_NAME.."/keypad/success/$settable", "true", 1, 1)
  end

  if HAS_LATCH then
    nodes = nodes .. ",latch"
    client:publish("homie/"..NODE_NAME.."/latch/$name", "Latch", 1, 1)
    client:publish("homie/"..NODE_NAME.."/latch/$type", "Gate Crafters", 1, 1)
    local properties = "locked,latched,restricted"
    if HAS_CONTACT then properties = properties .. ",closed" end
    if HAS_PUSH_TO_EXIT then properties = properties .. ",push-to-exit" end
    client:publish("homie/"..NODE_NAME.."/latch/$properties", properties, 1, 1)

    client:publish("homie/"..NODE_NAME.."/latch/locked/$name", "Lock Status", 1, 1)
    client:publish("homie/"..NODE_NAME.."/latch/locked/$datatype", "boolean", 1, 1)
    client:publish("homie/"..NODE_NAME.."/latch/locked/$settable", "true", 1, 1)

    client:publish("homie/"..NODE_NAME.."/latch/latched/$name", "Latch Status", 1, 1)
    client:publish("homie/"..NODE_NAME.."/latch/latched/$datatype", "boolean", 1, 1)
    client:publish("homie/"..NODE_NAME.."/latch/latched/$settable", "true", 1, 1)

    client:publish("homie/"..NODE_NAME.."/latch/restricted/$name", "Restricted (no push-to-exit) Status", 1, 1)
    client:publish("homie/"..NODE_NAME.."/latch/restricted/$datatype", "boolean", 1, 1)
    client:publish("homie/"..NODE_NAME.."/latch/restricted/$settable", "true", 1, 1)
    client:publish("homie/"..NODE_NAME.."/latch/restricted", tostring(restricted), 1, 1)

    if HAS_CONTACT then
      client:publish("homie/"..NODE_NAME.."/latch/closed/$name", "Closed Status", 1, 1)
      client:publish("homie/"..NODE_NAME.."/latch/closed/$datatype", "boolean", 1, 1)
      closedChanged()
    end

    if HAS_PUSH_TO_EXIT then
      client:publish("homie/"..NODE_NAME.."/latch/push-to-exit/$name", "Push-to-Exit Pressed", 1, 1)
      client:publish("homie/"..NODE_NAME.."/latch/push-to-exit/$datatype", "boolean", 1, 1)
      client:publish("homie/"..NODE_NAME.."/latch/push-to-exit/$retained", "false", 1, 1)
    end

    lockedChanged()
    latchedChanged()  
  end

  if HAS_COVER then
    nodes = nodes .. ",cover"
    lastRange = nil
    lastTarget = nil
    client:publish("homie/"..NODE_NAME.."/cover/$name", "Pool Cover", 1, 1)
    client:publish("homie/"..NODE_NAME.."/cover/$type", "Pool Cover", 1, 1)
    client:publish("homie/"..NODE_NAME.."/cover/$properties", "locked,position,position-percent,target,target-percent,range,state", 1, 1)

    client:publish("homie/"..NODE_NAME.."/cover/locked/$name", "Lock status (local control enabled)", 1, 1)
    client:publish("homie/"..NODE_NAME.."/cover/locked/$datatype", "boolean", 1, 1)
    client:publish("homie/"..NODE_NAME.."/cover/locked/$settable", "true", 1, 1)

    client:publish("homie/"..NODE_NAME.."/cover/position/$name", "Position (absolute)", 1, 1)
    client:publish("homie/"..NODE_NAME.."/cover/position/$datatype", "integer", 1, 1)
    client:publish("homie/"..NODE_NAME.."/cover/position/$settable", "true", 1, 1)

    client:publish("homie/"..NODE_NAME.."/cover/position-percent/$name", "Position (percent)", 1, 1)
    client:publish("homie/"..NODE_NAME.."/cover/position-percent/$datatype", "float", 1, 1)
    client:publish("homie/"..NODE_NAME.."/cover/position-percent/$unit", "%", 1, 1)
    client:publish("homie/"..NODE_NAME.."/cover/position-percent/$format", "0:100", 1, 1)
    client:publish("homie/"..NODE_NAME.."/cover/position-percent/$settable", "true", 1, 1)
  
    client:publish("homie/"..NODE_NAME.."/cover/target/$name", "Target Position (absolute)", 1, 1)
    client:publish("homie/"..NODE_NAME.."/cover/target/$datatype", "integer", 1, 1)
    client:publish("homie/"..NODE_NAME.."/cover/target/$settable", "true", 1, 1)
  
    client:publish("homie/"..NODE_NAME.."/cover/target-percent/$name", "Target Position (percent)", 1, 1)
    client:publish("homie/"..NODE_NAME.."/cover/target-percent/$datatype", "float", 1, 1)
    client:publish("homie/"..NODE_NAME.."/cover/target-percent/$unit", "%", 1, 1)
    client:publish("homie/"..NODE_NAME.."/cover/target-percent/$format", "0:100", 1, 1)
    client:publish("homie/"..NODE_NAME.."/cover/target-percent/$settable", "true", 1, 1)

    client:publish("homie/"..NODE_NAME.."/cover/range/$name", "Range (absolute)", 1, 1)
    client:publish("homie/"..NODE_NAME.."/cover/range/$datatype", "integer", 1, 1)
    client:publish("homie/"..NODE_NAME.."/cover/range/$settable", "true", 1, 1)
  
    client:publish("homie/"..NODE_NAME.."/cover/state/$name", "State", 1, 1)
    client:publish("homie/"..NODE_NAME.."/cover/state/$datatype", "enum", 1, 1)
    client:publish("homie/"..NODE_NAME.."/cover/state/$format", "stopped,opening,closing", 1, 1)
  
    positionChanged()
    stateChanged()
    lockedChanged()
  end

  if HAS_DIMMER then
    nodes = "dimmer"
    client:publish("homie/"..NODE_NAME.."/dimmer/$name", "Dimmer", 1, 1)
    client:publish("homie/"..NODE_NAME.."/dimmer/$type", "PWM", 1, 1)
    client:publish("homie/"..NODE_NAME.."/dimmer/$properties", "target,min-dim,max-dim,dim-steps,dim-period", 1, 1)

    client:publish("homie/"..NODE_NAME.."/dimmer/target/$name", "Target Brightness (within the allowable range)", 1, 1)
    client:publish("homie/"..NODE_NAME.."/dimmer/target/$datatype", "float", 1, 1)
    client:publish("homie/"..NODE_NAME.."/dimmer/target/$unit", "%", 1, 1)
    client:publish("homie/"..NODE_NAME.."/dimmer/target/$format", "0:100", 1, 1)
    client:publish("homie/"..NODE_NAME.."/dimmer/target/$settable", "true", 1, 1)
    client:publish("homie/"..NODE_NAME.."/dimmer/target", "0", 1, 1)

    client:publish("homie/"..NODE_NAME.."/dimmer/min-dim/$name", "Minimum Brightness", 1, 1)
    client:publish("homie/"..NODE_NAME.."/dimmer/min-dim/$datatype", "integer", 1, 1)
    client:publish("homie/"..NODE_NAME.."/dimmer/min-dim/$unit", "%", 1, 1)
    client:publish("homie/"..NODE_NAME.."/dimmer/min-dim/$format", "0:1023", 1, 1)
    client:publish("homie/"..NODE_NAME.."/dimmer/min-dim/$settable", "true", 1, 1)

    client:publish("homie/"..NODE_NAME.."/dimmer/max-dim/$name", "Maximum Brightness", 1, 1)
    client:publish("homie/"..NODE_NAME.."/dimmer/max-dim/$datatype", "integer", 1, 1)
    client:publish("homie/"..NODE_NAME.."/dimmer/max-dim/$unit", "%", 1, 1)
    client:publish("homie/"..NODE_NAME.."/dimmer/max-dim/$format", "0:100", 1, 1)
    client:publish("homie/"..NODE_NAME.."/dimmer/max-dim/$settable", "true", 1, 1)

    client:publish("homie/"..NODE_NAME.."/dimmer/dim-steps/$name", "How big each step is when dim-period is non-zero", 1, 1)
    client:publish("homie/"..NODE_NAME.."/dimmer/dim-steps/$datatype", "integer", 1, 1)
    client:publish("homie/"..NODE_NAME.."/dimmer/dim-steps/$format", "0:", 1, 1)
    client:publish("homie/"..NODE_NAME.."/dimmer/dim-steps/$settable", "true", 1, 1)

    client:publish("homie/"..NODE_NAME.."/dimmer/dim-period/$name", "How long to wait between each step to reach the target", 1, 1)
    client:publish("homie/"..NODE_NAME.."/dimmer/dim-period/$datatype", "integer", 1, 1)
    client:publish("homie/"..NODE_NAME.."/dimmer/dim-period/$format", "0:", 1, 1)
    client:publish("homie/"..NODE_NAME.."/dimmer/dim-period/$settable", "true", 1, 1)
  end

  if HAS_LUXMETER then
    nodes = "luxmeter"
    client:publish("homie/"..NODE_NAME.."/luxmeter/$name", "Dimmer", 1, 1)
    client:publish("homie/"..NODE_NAME.."/luxmeter/$type", "OPT3001", 1, 1)
    client:publish("homie/"..NODE_NAME.."/luxmeter/$properties", "lux,report-period", 1, 1)

    client:publish("homie/"..NODE_NAME.."/luxmeter/lux/$name", "Luminance Flux", 1, 1)
    client:publish("homie/"..NODE_NAME.."/luxmeter/lux/$datatype", "float", 1, 1)
    client:publish("homie/"..NODE_NAME.."/luxmeter/lux/$unit", "lux", 1, 1)
    client:publish("homie/"..NODE_NAME.."/luxmeter/lux/$format", "0:83865.60", 1, 1)
  end

  if HAS_TEMP_SENSORS then
    nodes = "device"
    client:publish("homie/"..NODE_NAME.."/device/$name", "Device", 1, 1)
    client:publish("homie/"..NODE_NAME.."/device/$type", "Device", 1, 1)
    client:publish("homie/"..NODE_NAME.."/device/$properties", "report-period", 1, 1)

    if ds18b20.sens then
      for i, s in ipairs(ds18b20.sens) do
        addr = ('%02x-%02x-%02x-%02x-%02x-%02x-%02x-%02x'):format(s:byte(1,8))
        nodes = nodes .. "," .. addr

        client:publish("homie/"..NODE_NAME.."/"..addr.."/$name", "Temperature Sensor", 1, 1)
        client:publish("homie/"..NODE_NAME.."/"..addr.."/$type", "DS18B20", 1, 1)
        client:publish("homie/"..NODE_NAME.."/"..addr.."/$properties", "current-temperature", 1, 1)

        client:publish("homie/"..NODE_NAME.."/"..addr.."/current-temperature/$name", "Current Temperature", 1, 1)
        client:publish("homie/"..NODE_NAME.."/"..addr.."/current-temperature/$datatype", "float", 1, 1)
        client:publish("homie/"..NODE_NAME.."/"..addr.."/current-temperature/$unit", "°C", 1, 1)
      end
    end
  end

  if HAS_LUXMETER or HAS_TEMP_SENSORS then
    local node_name = "luxmeter"
    if HAS_TEMP_SENSORS then node_name = "device" end
    client:publish("homie/"..NODE_NAME.."/"..node_name.."/report-period/$name", "Report Period", 1, 1)
    client:publish("homie/"..NODE_NAME.."/"..node_name.."/report-period/$datatype", "integer", 1, 1)
    client:publish("homie/"..NODE_NAME.."/"..node_name.."/report-period/$format", "1:", 1, 1)
    client:publish("homie/"..NODE_NAME.."/"..node_name.."/report-period/$settable", "true", 1, 1)
    client:publish("homie/"..NODE_NAME.."/"..node_name.."/report-period/$unit", "ms", 1, 1)
  end

  client:publish("homie/"..NODE_NAME.."/$nodes", nodes, 1, 1)

  client:publish("homie/"..NODE_NAME.."/$rssi", tostring(wifi.sta.getrssi()), 1, 1)
  tmr.create():alarm(60000, tmr.ALARM_AUTO, function()
    if connected then
      client:publish("homie/"..NODE_NAME.."/$rssi", tostring(wifi.sta.getrssi()), 1, 1)
    end
  end)

  client:subscribe("homie/"..NODE_NAME.."/keypad/success/set", 0)
  if HAS_LATCH then
    client:subscribe("homie/"..NODE_NAME.."/latch/locked/set", 0)
    client:subscribe("homie/"..NODE_NAME.."/latch/latched/set", 0)
    client:subscribe("homie/"..NODE_NAME.."/latch/restricted/set", 0)
  end

  if HAS_COVER then
    -- use MQTT itself as our state store
    if position == nil then
      client:subscribe("homie/"..NODE_NAME.."/cover/position", 0)
    end
    if range == nil then
      client:subscribe("homie/"..NODE_NAME.."/cover/range", 0)
    end

    client:subscribe("homie/"..NODE_NAME.."/cover/locked/set", 0)
    client:subscribe("homie/"..NODE_NAME.."/cover/position/set", 0)
    client:subscribe("homie/"..NODE_NAME.."/cover/position-percent/set", 0)
    client:subscribe("homie/"..NODE_NAME.."/cover/range/set", 0)
    client:subscribe("homie/"..NODE_NAME.."/cover/target/set", 0)
    client:subscribe("homie/"..NODE_NAME.."/cover/target-percent/set", 0)
  end

  if HAS_DIMMER then
    client:subscribe("homie/"..NODE_NAME.."/dimmer/min-dim", 0)
    client:subscribe("homie/"..NODE_NAME.."/dimmer/max-dim", 0)
    client:subscribe("homie/"..NODE_NAME.."/dimmer/dim-steps", 0)
    client:subscribe("homie/"..NODE_NAME.."/dimmer/dim-period", 0)

    client:subscribe("homie/"..NODE_NAME.."/dimmer/min-dim/set", 0)
    client:subscribe("homie/"..NODE_NAME.."/dimmer/max-dim/set", 0)
    client:subscribe("homie/"..NODE_NAME.."/dimmer/dim-steps/set", 0)
    client:subscribe("homie/"..NODE_NAME.."/dimmer/dim-period/set", 0)
    client:subscribe("homie/"..NODE_NAME.."/dimmer/target/set", 0)
  end

  if HAS_LUXMETER then
    client:subscribe("homie/"..NODE_NAME.."/luxmeter/report-period", 0)

    client:subscribe("homie/"..NODE_NAME.."/luxmeter/report-period/set", 0)
  end

  if HAS_TEMP_SENSORS then
    client:subscribe("homie/"..NODE_NAME.."/device/report-period", 0)
    client:subscribe("homie/"..NODE_NAME.."/device/report-period/set", 0)
  end

  client:subscribe("homie/"..NODE_NAME.."/$ota_update", 0)
  client:subscribe("homie/"..NODE_NAME.."/$config", 0)
  client:subscribe("homie/"..NODE_NAME.."/$debug", 0)
  client:subscribe("homie/"..NODE_NAME.."/$restart", 0)
  client:subscribe("homie/"..NODE_NAME.."/$lua", 0)

  client:publish("homie/"..NODE_NAME.."/$state", "ready", 1, 1)
end)

local connectionFailed

local function reconnect(client)
  local delay = 0
  if connectionAttempts == 6 then
    print("Too many reconnect attempts; restarting")
    node.restart()
    return
  else
    delay = 3 ^ connectionAttempts * 1000 - 1000 + 1
  end

  connectionAttempts = connectionAttempts + 1
  print("connection attempt "..tostring(connectionAttempts).." waiting "..tostring(delay / 1000).."s")
  tmr.create():alarm(delay, tmr.ALARM_SINGLE, function()
    if (wifi.sta.status() == wifi.STA_GOTIP) then
      print("reconnecting to MQTT")
      client:connect(MQTT_HOST, MQTT_PORT, MQTT_SECURE, nil, connectionFailed)
    else
      print("network not connected at retry time; trying again later")
      reconnect(client)
    end
  end)
end

local function connectionFailed(client, reason)
  connected = false
  print("connection failed: "..tostring(reason))
  client:close()
  reconnect(client)
end

m:on("offline", function(client)
  connected = false
  print("lost connection")
  client:close()
  reconnect(client)
end)

if HAS_LATCH then
  function lockedChanged()
    if connected == false then
      return
    end

    m:publish("homie/"..NODE_NAME.."/latch/locked", tostring(locked), 1, 1)
  end

  function latchedChanged()
    if connected == false then
      return
    end

    m:publish("homie/"..NODE_NAME.."/latch/latched", tostring(latched), 1, 1)
  end

  if HAS_CONTACT then
    function closedChanged()
      if connected == false then
        return
      end

      m:publish("homie/"..NODE_NAME.."/latch/closed", tostring(closed), 1, 1)
    end
  end
end

if HAS_COVER then
  function positionChanged()
    if connected == false then
      return
    end

    if position ~= nil then
      m:publish("homie/"..NODE_NAME.."/cover/position", position, 1, 1)
      if range ~= nil then
        m:publish("homie/"..NODE_NAME.."/cover/position-percent", position * 100 / range, 1, 1)
      end
    end
    if range ~= lastRange then
      if range ~= nil then
        m:publish("homie/"..NODE_NAME.."/cover/range", range, 1, 1)
        m:publish("homie/"..NODE_NAME.."/cover/position/$format", "0:"..tostring(range), 1, 1)
      end
      lastRange = range
    end
    local newTarget = target or range
    if newTarget ~= lastTarget then
      if newTarget ~= nil then
        m:publish("homie/"..NODE_NAME.."/cover/target", newTarget, 1, 1)
        if range ~= nil then
          m:publish("homie/"..NODE_NAME.."/cover/target-percent", newTarget * 100 / range, 1, 1)
        end
      end
      lastTarget = newTarget
    end
  end

  function stateChanged()
    if connected == false then
      return
    end

    local stateString
    if state == 0 then
      stateString = "stopped"
    elseif direction == 0 then
      stateString = "opening"
    else
      stateString = "closing"
    end
    m:publish("homie/"..NODE_NAME.."/cover/state", stateString, 1, 1)
  end

  function lockedChanged()
    if connected == false then
      return
    end

    m:publish("homie/"..NODE_NAME.."/cover/locked", tostring(locked), 1, 1)
  end
end

if HAS_LUXMETER then
  function luxChanged(lux)
    if connected == false then
      return
    end

    m:publish("homie/"..NODE_NAME.."/luxmeter/lux", tostring(lux), 1, 1)
  end
end

if HAS_TEMP_SENSORS then
  function tempChanged(addr, temp)
    if connected == false then
      return
    end

    m:publish("homie/"..NODE_NAME.."/"..addr.."/current-temperature", tostring(temp), 1, 1)
  end
end

function triggerBell()
  if connected == false then
    return
  end

  m:publish("homie/"..NODE_NAME.."/keypad/bell", "true", 1, 0)
end

function triggerPushToExit()
  if connected == false then
    return
  end

  m:publish("homie/"..NODE_NAME.."/latch/push-to-exit", "true", 1, 0)
end

function receivedCode(code)
  if connected == false then
    return
  end

  m:publish("homie/"..NODE_NAME.."/keypad/code", code, 1, 0)
end

local function split(string, sep)
  local sep, fields = sep or ":", {}
  local pattern = string.format("([^%s]+)", sep)
  string:gsub(pattern, function(c) fields[#fields+1] = c end)
  return fields
end

m:on("message", function(client, topic, message)
  log("got message "..tostring(message).." at "..topic)

  if HAS_LATCH then
    if topic == "homie/"..NODE_NAME.."/latch/locked/set" then
      locked = message == "true" and true or false
      lockedChanged()
    elseif topic == "homie/"..NODE_NAME.."/latch/latched/set" then
      if message == "false" then unlatch() end
    elseif topic == "homie/"..NODE_NAME.."/latch/restricted/set" then
      restricted = message == "true" and true or false
      client:publish("homie/"..NODE_NAME.."/latch/restricted", tostring(restricted), 1, 1)
    end
  end

  if HAS_COVER then
    if topic == "homie/"..NODE_NAME.."/cover/locked/set" then
      if message == "false" then
        unlock(false)
      else
        lock()
      end
    elseif topic == "homie/"..NODE_NAME.."/cover/target-percent/set" or
      topic == "homie/"..NODE_NAME.."/cover/position-percent/set" then
      if message == "UP" then
        unlock(true)
        startMovement(0)
      elseif message == "DOWN" then
        unlock(true)
        startMovement(3)
      elseif message == "STOP" then
        unlock(true)
        stopMovement()
      else
        local targetPosition = tonumber(message)
        if targetPosition == nil then
          return
        end

        unlock(true)
        if range == nil then
          if position == nil then
            if targetPosition == 0 then
              startMovement(0)
            else
              startMovement(3)
            end
          elseif targetPosition < position then
            startMovement(0)
          else
            startMovement(3)
          end
        else
          -- round to the closest integer stop
          moveTo(math.floor(targetPosition * range / 100 + 0.5))
        end
      end
    elseif topic == "homie/"..NODE_NAME.."/cover/target/set" then
      if message == nil then
        position = nil
        return
      end
      local value = tonumber(message)
      if value == nil then
        return
      end
      if value < 0 then
        value = 0
      elseif range ~= nil and value > range then
        value = range
      end
      unlock(true)
      moveTo(value)
    elseif topic == "homie/"..NODE_NAME.."/cover/position/set" then
      if message == nil then
        position = nil
        return
      end
      local value = tonumber(message)
      if value == nil then
        return
      end

      position = value
      if position > range then
        range = position
      end
      positionChanged()
    elseif topic == "homie/"..NODE_NAME.."/cover/range/set" then
      if message == nil then
        range = nil
      else
        range = tonumber(message)
        if position > range then
          position = range
        end
      end
      positionChanged()
    elseif topic == "homie/"..NODE_NAME.."/cover/range" then
      if range == nil and message ~= nil then
        range = tonumber(message)
        client:unsubscribe("homie/"..NODE_NAME.."/cover/range")
      end
    elseif topic == "homie/"..NODE_NAME.."/cover/position" then
      if position == nil and message ~= nil then
        position = tonumber(message)
        client:unsubscribe("homie/"..NODE_NAME.."/cover/position")
      end
    end
  end

  if HAS_KEYPAD then
    if topic == "homie/"..NODE_NAME.."/keypad/success/set" then
      if message == "true" then signalSuccess() end
    end
  end

  if HAS_DIMMER then
    if topic == "homie/"..NODE_NAME.."/dimmer/target/set" then
      local result = dimTo(tonumber(message))
      client:publish("homie/"..NODE_NAME.."/dimmer/target", tostring(result), 1, 1)
    elseif topic == "homie/"..NODE_NAME.."/dimmer/min-dim" then
      minDim = tonumber(message)
      client:unsubscribe("homie/"..NODE_NAME.."/dimmer/min-dim")
    elseif topic == "homie/"..NODE_NAME.."/dimmer/min-dim/set" then
      minDim = tonumber(message)
      if minDim < 0 then minDim = 0 end
      if minDim > 100 then minDim = 100 end
      if minDim > maxDim then maxDim = minDim end
      client:publish("homie/"..NODE_NAME.."/dimmer/min-dim", tostring(minDim), 1, 1)
      client:publish("homie/"..NODE_NAME.."/dimmer/max-dim", tostring(maxDim), 1, 1)
    elseif topic == "homie/"..NODE_NAME.."/dimmer/max-dim" then
      maxDim = tonumber(message)
      client:unsubscribe("homie/"..NODE_NAME.."/dimmer/max-dim")
    elseif topic == "homie/"..NODE_NAME.."/dimmer/max-dim/set" then
      maxDim = tonumber(message)
      if maxDim < 0 then maxDim = 0 end
      if maxDim > 100 then maxDim = 100 end
      if minDim > maxDim then minDim = maxDim end
      client:publish("homie/"..NODE_NAME.."/dimmer/min-dim", tostring(minDim), 1, 1)
      client:publish("homie/"..NODE_NAME.."/dimmer/max-dim", tostring(maxDim), 1, 1)
    elseif topic == "homie/"..NODE_NAME.."/dimmer/dim-steps" then
      dimSteps = tonumber(message)
      client:unsubscribe("homie/"..NODE_NAME.."/dimmer/dim-steps")
    elseif topic == "homie/"..NODE_NAME.."/dimmer/dim-steps/set" then
      dimSteps = tonumber(message)
      if dimSteps < 0 then dimSteps = 0 end
      client:publish("homie/"..NODE_NAME.."/dimmer/dim-steps", tostring(dimSteps), 1, 1)
    elseif topic == "homie/"..NODE_NAME.."/dimmer/dim-period" then
      dimPeriod = tonumber(message)
      client:unsubscribe("homie/"..NODE_NAME.."/dimmer/dim-period")
    elseif topic == "homie/"..NODE_NAME.."/dimmer/dim-period/set" then
      local dimPeriod = tonumber(message)
      if dimPeriod < 0 then dimPeriod = 0 end
      changeDimPeriod(dimPeriod)
      client:publish("homie/"..NODE_NAME.."/dimmer/dim-period", tostring(dimPeriod), 1, 1)
    end
  end

  if HAS_LUXMETER or HAS_TEMP_SENSORS then
    local node_name = "luxmeter"
    if HAS_TEMP_SENSORS then node_name = "device" end

    if topic == "homie/"..NODE_NAME.."/"..node_name.."/report-period/set" then
      local period = tonumber(message)
      changeReportPeriod(period)
      client:publish("homie/"..NODE_NAME.."/"..node_name.."/report-period", tostring(period), 1, 1)
    elseif topic == "homie/"..NODE_NAME.."/"..node_name.."/report-period" then
      local period = tonumber(message)
      changeReportPeriod(period)
      client:unsubscribe("homie/"..NODE_NAME.."/"..node_name.."/report-period")
    end
  end

  if HAS_TEMP_SENSORS then
    if topic == "homie/"..NODE_NAME.."/device/report-period/set" then
      local period = tonumber(message)
      changeReportPeriod(period)
      client:publish("homie/"..NODE_NAME.."/device/report-period", tostring(period), 1, 1)
    elseif topic == "homie/"..NODE_NAME.."/device/report-period" then
      local period = tonumber(message)
      changeReportPeriod(period)
      client:unsubscribe("homie/"..NODE_NAME.."/device/report-period")
    end
  end

  if topic == "homie/"..NODE_NAME.."/$ota_update" then
    local fields = split(tostring(message), "\n")
    local host, port, path = fields[1], fields[2], fields[3]
    otaUpdate(host, port, path)
  elseif topic == "homie/"..NODE_NAME.."/$config" and message ~= nil and message ~= "" then
    file.open("config.lua", 'w')
    file.write(message)
    file.close()
    node.restart()
  elseif topic == "homie/"..NODE_NAME.."/$debug" then
    debug = message == "true"
    log("debug set to "..tostring(debug))
  elseif topic == "homie/"..NODE_NAME.."/$lua" then
    output = evaluate(message)
    if output == nil then
      output = 'nil'
    end
    m:publish("homie/"..NODE_NAME.."/$lua/output", tostring(output), 1, 0)
  elseif topic == "homie/"..NODE_NAME.."/$restart" and message == "true" then
    log("forcing restart")
    node.restart()
  end
end)

debug = false
function log(message)
  if connected and debug then
    m:publish("homie/"..NODE_NAME.."/$log", message, 1, 0)
  end
  print(message)
end

-- all set up, kick it off
m:connect(MQTT_HOST, MQTT_PORT, MQTT_SECURE, nil, connectionFailed)
