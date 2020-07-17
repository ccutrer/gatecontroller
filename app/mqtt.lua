local m = mqtt.Client(wifi.sta.getmac(), 120, MQTT_USERNAME, MQTT_PASSWORD)

m:lwt("homie/"..NODE_NAME.."/$state", "lost", 0, 1)

local connected = false

m:on("connect", function(client)
  print("connected to MQTT")
  connected = true

  client:publish("homie/"..NODE_NAME.."/$homie", "4.0.0", 0, 1)
  client:publish("homie/"..NODE_NAME.."/$name", "Gate Controller", 0, 1)
  client:publish("homie/"..NODE_NAME.."/$nodes", "keypad,latch", 0, 1)

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

  client:subscribe("homie/"..NODE_NAME.."/keypad/success/set", 0)
  client:subscribe("homie/"..NODE_NAME.."/latch/locked/set", 0)
  client:subscribe("homie/"..NODE_NAME.."/latch/latched/set", 0)
  client:subscribe("homie/"..NODE_NAME.."/latch/restricted/set", 0)

  client:publish("homie/"..NODE_NAME.."/$state", "ready", 0, 1)
end)

local connectionFailed

local function reconnect(client)
  -- try again in 10 seconds
  tmr.create():alarm(10000, tmr.ALARM_SINGLE, function()
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

function closedChanged()
  if connected == false then
    return
  end

  m:publish("homie/"..NODE_NAME.."/latch/closed", tostring(closed), 0, 1)
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


m:on("message", function(client, topic, message)
  print("got message "..tostring(message).." at "..topic)

  if topic == "homie/"..NODE_NAME.."/latch/locked/set" then
    locked = message == "true" and true or false
    lockedChanged()
  elseif topic == "homie/"..NODE_NAME.."/latch/latched/set" then
    if message == "false" then unlatch() end
  elseif topic == "homie/"..NODE_NAME.."/latch/restricted/set" then
    restricted = message == "true" and true or false
    client:pubmlish("homie/"..NODE_NAME.."/latch/restricte", tostring(restricted))
  end
end)

function log(message)
  if connected then
    m:publish("homie/"..NODE_NAME.."/$log", message, 0, 0)
  end
  print(message)
end

-- all set up, kick it off
m:connect(MQTT_HOST, MQTT_PORT, MQTT_SECURE, nil, connectionFailed)
