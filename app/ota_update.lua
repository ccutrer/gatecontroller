--
-- If you have the LFS _init loaded then you invoke the provision by
-- executing LFS.HTTP_OTA('your server','directory','image name').  Note
-- that is unencrypted and unsigned. But the loader does validate that
-- the image file is a valid and complete LFS image before loading.
--

local fullPath, host, port
local image = "LFS.img"
local doRequest, firstRec, subsRec, finalise
local n, total, size = 0, 0, 0

doRequest = function(socket, hostIP) -- luacheck: no unused
  if hostIP then
    local con = net.createConnection()
    -- Note that the current dev version can only accept uncompressed LFS images
    con:on("connection",function(sck)
      local request = table.concat( {
        "GET "..fullPath.." HTTP/1.1",
        "User-Agent: ESP8266 app (linux-gnu)",
        "Accept: application/octet-stream",
        "Accept-Encoding: identity",
        "Host: "..host,
        "Connection: close",
        "", "", }, "\r\n")
        print(request)
        sck:on("receive",firstRec)
        sck:send(request)
      end)
    con:on("disconnection",function()
      log("could not connect to "..host)
      node.restart()
    end)
    con:connect(port,hostIP)
  else
    log("could not get hostIP for "..host)
  end
end

firstRec = function (sck,rec)
  -- Process the headers; only interested in content length
  local i      = rec:find('\r\n\r\n',1,true) or 1
  local header = rec:sub(1,i+1):lower()
  size         = tonumber(header:match('\ncontent%-length: *(%d+)\r') or 0)
  print(rec:sub(1, i+1))
  if size > 0 then
    sck:on("receive",subsRec)
    file.open(image, 'w')
    subsRec(sck, rec:sub(i+4))
  else
    sck:on("receive", nil)
    sck:close()
    print("GET failed")
    node.restart()
  end
end

subsRec = function(sck,rec)
  total, n = total + #rec, n + 1
  if n % 4 == 1 then
    sck:hold()
    node.task.post(0, function() sck:unhold() end)
  end
  uart.write(0,('%u of %u, '):format(total, size))
  file.write(rec)
  if total == size then finalise(sck) end
end

finalise = function(sck)
  file.close()
  sck:on("receive", nil)
  sck:close()
  local s = file.stat(image)
  if (s and size == s.size) then
    wifi.eventmon.register(wifi.eventmon.STA_DISCONNECTED, nil)
    wifi.setmode(wifi.NULLMODE, false)
    collectgarbage();collectgarbage()
      -- run as separate task to maximise RAM available
    node.task.post(function()
      node.flashreload(image)
      node.restart()
    end)
  else
    print"Invalid save of image file"
    node.restart()
  end
end

function otaUpdate(this_host, this_port, path)
  fullPath = path
  host = this_host
  port = this_port
  net.dns.resolve(host, doRequest)
end
