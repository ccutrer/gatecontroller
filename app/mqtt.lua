local m = mqtt.Client(wifi.sta.getmac(), 120, MQTT_USERNAME, MQTT_PASSWORD)

m:lwt("homie/"..NODE_NAME.."/$state", "lost", 0, 1)

local connected = false
local connectionAttempts = 0

m:on("connect", function(client)
  print("connected to MQTT")
  connected = true
  connectionAttempts = 0

  client:publish("homie/"..NODE_NAME.."/$homie", "4.0.0", 0, 1)
  client:publish("homie/"..NODE_NAME.."/$fwversion", tostring(VERSION), 0, 1)
  client:publish("homie/"..NODE_NAME.."/$name", "Gate Controller", 0, 1)
  local nodes = "keypad"
  if HAS_LATCH then
    nodes = nodes .. ",latch"
  end
  if HAS_COVER then
    nodes = nodes .. ",cover"
  end
  client:publish("homie/"..NODE_NAME.."/$nodes", nodes, 0, 1)

  client:publish("homie/"..NODE_NAME.."/keypad/$name", "Keypad", 0, 1)
  client:publish("homie/"..NODE_NAME.."/keypad/$type", "Weigand", 0, 1)
  client:publish("homie/"..NODE_NAME.."/keypad/$properties", "code,bell", 0, 1)

  client:publish("homie/"..NODE_NAME.."/keypad/code/$name", "Received Code", 0, 1)
  client:publish("homie/"..NODE_NAME.."/keypad/code/$datatype", "string", 0, 1)
  client:publish("homie/"..NODE_NAME.."/keypad/code/$retained", "false", 0, 1)
  client:publish("homie/"..NODE_NAME.."/keypad/code", "", 0, 1)

  client:publish("homie/"..NODE_NAME.."/keypad/bell/$name", "Bell Pressed", 0, 1)
  client:publish("homie/"..NODE_NAME.."/keypad/bell/$datatype", "boolean", 0, 1)
  client:publish("homie/"..NODE_NAME.."/keypad/bell/$retained", "false", 0, 1)
  client:publish("homie/"..NODE_NAME.."/keypad/bell", "false", 0, 1)

  if HAS_LATCH then
    client:publish("homie/"..NODE_NAME.."/latch/$name", "Latch", 0, 1)
    client:publish("homie/"..NODE_NAME.."/latch/$type", "Gate Crafters", 0, 1)
    local properties = "locked,latched,restricted"
    if HAS_CONTACT then properties = properties .. ",closed" end
    client:publish("homie/"..NODE_NAME.."/latch/$properties", properties, 0, 1)

    client:publish("homie/"..NODE_NAME.."/latch/locked/$name", "Lock Status", 0, 1)
    client:publish("homie/"..NODE_NAME.."/latch/locked/$datatype", "boolean", 0, 1)
    client:publish("homie/"..NODE_NAME.."/latch/locked/$settable", "true", 0, 1)

    client:publish("homie/"..NODE_NAME.."/latch/latched/$name", "Latch Status", 0, 1)
    client:publish("homie/"..NODE_NAME.."/latch/latched/$datatype", "boolean", 0, 1)
    client:publish("homie/"..NODE_NAME.."/latch/latched/$settable", "true", 0, 1)

    client:publish("homie/"..NODE_NAME.."/latch/restricted/$name", "Restricted (no push-to-exit) Status", 0, 1)
    client:publish("homie/"..NODE_NAME.."/latch/restricted/$datatype", "boolean", 0, 1)
    client:publish("homie/"..NODE_NAME.."/latch/restricted/$settable", "true", 0, 1)
    client:publish("homie/"..NODE_NAME.."/latch/restricted", tostring(restricted), 0, 1)

    if HAS_CONTACT then
      client:publish("homie/"..NODE_NAME.."/latch/closed/$name", "Closed Status", 0, 1)
      client:publish("homie/"..NODE_NAME.."/latch/closed/$datatype", "boolean", 0, 1)
      closedChanged()
    end

    lockedChanged()
    latchedChanged()  
  end

  if HAS_COVER then
    lastRange = nil
    client:publish("homie/"..NODE_NAME.."/cover/$name", "Pool Cover", 0, 1)
    client:publish("homie/"..NODE_NAME.."/cover/$type", "Pool Cover", 0, 1)
    client:publish("homie/"..NODE_NAME.."/cover/$properties", "position,position-percent,range,state", 0, 1)
  
    client:publish("homie/"..NODE_NAME.."/cover/position/$name", "Position (absolute)", 0, 1)
    client:publish("homie/"..NODE_NAME.."/cover/position/$datatype", "integer", 0, 1)
    client:publish("homie/"..NODE_NAME.."/cover/position/$settable", "true", 0, 1)
  
    client:publish("homie/"..NODE_NAME.."/cover/position-percent/$name", "Position (percent)", 0, 1)
    client:publish("homie/"..NODE_NAME.."/cover/position-percent/$datatype", "float", 0, 1)
    client:publish("homie/"..NODE_NAME.."/cover/position-percent/$unit", "%", 0, 1)
    client:publish("homie/"..NODE_NAME.."/cover/position-percent/$format", "0:100", 0, 1)
    client:publish("homie/"..NODE_NAME.."/cover/position-percent/$settable", "true", 0, 1)
  
    client:publish("homie/"..NODE_NAME.."/cover/range/$name", "Range (absolute)", 0, 1)
    client:publish("homie/"..NODE_NAME.."/cover/range/$datatype", "integer", 0, 1)
    client:publish("homie/"..NODE_NAME.."/cover/range/$settable", "true", 0, 1)
  
    client:publish("homie/"..NODE_NAME.."/cover/state/$name", "State", 0, 1)
    client:publish("homie/"..NODE_NAME.."/cover/state/$datatype", "enum", 0, 1)
    client:publish("homie/"..NODE_NAME.."/cover/state/$format", "stopped,opening,closing", 0, 1)
  
    positionChanged()
    stateChanged()
  end

  client:publish("homie/"..NODE_NAME.."/$rssi", tostring(wifi.sta.getrssi()), 0, 1)
  tmr.create():alarm(60000, tmr.ALARM_AUTO, function()
    if connected then
      client:publish("homie/"..NODE_NAME.."/$rssi", tostring(wifi.sta.getrssi()), 0, 1)
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

    client:subscribe("homie/"..NODE_NAME.."/cover/position/set", 0)
    client:subscribe("homie/"..NODE_NAME.."/cover/position-percent/set", 0)
    client:subscribe("homie/"..NODE_NAME.."/cover/range/set", 0)
  end

  client:subscribe("homie/"..NODE_NAME.."/$ota_update", 0)
  client:subscribe("homie/"..NODE_NAME.."/$config", 0)
  client:subscribe("homie/"..NODE_NAME.."/$debug", 0)

  client:publish("homie/"..NODE_NAME.."/$state", "ready", 0, 1)
end)

local connectionFailed

local function reconnect(client)
  local delay = 0
  if connectionAttempts == 7 then
    node.restart()
  else
    delay = 3 ^ connectionAttempts * 1000 - 1000 + 1
  end

  connectionAttempts = connectionAttempts + 1
  tmr.create():alarm(delay, tmr.ALARM_SINGLE, function()
    client:connect(MQTT_HOST, MQTT_PORT, MQTT_SECURE, nil, connectionFailed)
  end)
end

local function connectionFailed(client, reason)
  connected = false
  print("connection failed", reason)
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

    m:publish("homie/"..NODE_NAME.."/latch/locked", tostring(locked), 0, 1)
  end

  function latchedChanged()
    if connected == false then
      return
    end

    m:publish("homie/"..NODE_NAME.."/latch/latched", tostring(latched), 0, 1)
  end

  if HAS_CONTACT then
    function closedChanged()
      if connected == false then
        return
      end

      m:publish("homie/"..NODE_NAME.."/latch/closed", tostring(closed), 0, 1)
    end
  end
end

if HAS_COVER then
  function positionChanged()
    if connected == false then
      return
    end

    if position ~= nil then
      m:publish("homie/"..NODE_NAME.."/cover/position", position, 0, 1)
      if range ~= nil then
        m:publish("homie/"..NODE_NAME.."/cover/position-percent", position * 100 / range, 0, 1)
      end
    end
    if range ~= lastRange then
      if range ~= nil then
        m:publish("homie/"..NODE_NAME.."/cover/range", range, 0, 1)
        m:publish("homie/"..NODE_NAME.."/cover/position/$format", "0:"..tostring(range), 0, 1)
      end
      lastRange = range
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
    m:publish("homie/"..NODE_NAME.."/cover/state", stateString, 0, 1)
  end
end

function triggerBell()
  if connected == false then
    return
  end

  m:publish("homie/"..NODE_NAME.."/keypad/bell", "true", 0, 0)
  m:publish("homie/"..NODE_NAME.."/keypad/bell", "false", 0, 1)
end

function receivedCode(code)
  if connected == false then
    return
  end

  m:publish("homie/"..NODE_NAME.."/keypad/code", code, 0, 0)
  m:publish("homie/"..NODE_NAME.."/keypad/code", "", 0, 1)
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
      client:publish("homie/"..NODE_NAME.."/latch/restricte", tostring(restricted))
    end
  end
    
  if HAS_COVER then
    if topic == "homie/"..NODE_NAME.."/cover/position-percent/set" then
      if message == "UP" then
        startMovement(0)
      elseif message == "DOWN" then
        startMovement(1)
      elseif message == "STOP" then
        stopMovement()
      else
        local targetPosition = tonumber(message)
        if targetPosition == nil or range == nil then
          return
        end
        -- round to the closest integer stop
        moveTo(math.floor(targetPosition * range / 100 + 0.5))
      end
    elseif topic == "homie/"..NODE_NAME.."/cover/position/set" then
      if message == "" then
        position = nil
        return
      end
      local value = tonumber(message)
      if value == nil then
        return
      end
      if position == nil then
        position = value
      else
        moveTo(value)
      end
    elseif topic == "homie/"..NODE_NAME.."/cover/range/set" then
      range = tonumber(message)
    elseif topic == "homie/"..NODE_NAME.."/cover/range" then
      if range == nil then
        range = tonumber(message)
        client:unsubscribe("homie/"..NODE_NAME.."/cover/range")
      end
    elseif topic == "homie/"..NODE_NAME.."/cover/position" then
      if position == nil then
        position = tonumber(message)
        client:unsubscribe("homie/"..NODE_NAME.."/cover/position")
      end
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
  end
end)

debug = false
function log(message)
  if connected and debug then
    m:publish("homie/"..NODE_NAME.."/$log", message, 0, 0)
  end
  print(message)
end

-- all set up, kick it off
m:connect(MQTT_HOST, MQTT_PORT, MQTT_SECURE, nil, connectionFailed)
