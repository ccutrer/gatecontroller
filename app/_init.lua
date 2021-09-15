--
-- File: _init.lua
--[[

  This is a template for the LFS equivalent of the SPIFFS init.lua.

  It is a good idea to such an _init.lua module to your LFS and do most of the LFS
  module related initialisaion in this. This example uses standard Lua features to
  simplify the LFS API.

  The first section adds a 'LFS' table to _G and uses the __index metamethod to
  resolve functions in the LFS, so you can execute the main function of module
  'fred' by executing LFS.fred(params), etc. It also implements some standard
  readonly properties:

  LFS._time    The Unix Timestamp when the luac.cross was executed.  This can be
               used as a version identifier.

  LFS._config  This returns a table of useful configuration parameters, hence
                 print (("0x%6x"):format(LFS._config.lfs_base))
               gives you the parameter to use in the luac.cross -a option.

  LFS._list    This returns a table of the LFS modules, hence
                 print(table.concat(LFS._list,'\n'))
               gives you a single column listing of all modules in the LFS.

---------------------------------------------------------------------------------]]

local index = node.flashindex

local lfs_t = {
  __index = function(_, name)
      local fn_ut, ba, ma, size, modules = index(name)
      if not ba then
        return fn_ut
      elseif name == '_time' then
        return fn_ut
      elseif name == '_config' then
        local fs_ma, fs_size = file.fscfg()
        return {lfs_base = ba, lfs_mapped = ma, lfs_size = size,
                fs_mapped = fs_ma, fs_size = fs_size}
      elseif name == '_list' then
        return modules
      else
        return nil
      end
    end,

  __newindex = function(_, name, value) -- luacheck: no unused
      error("LFS is readonly. Invalid write to LFS." .. name, 2)
    end,

  }

local G=getfenv()
G.LFS = setmetatable(lfs_t,lfs_t)

--[[-------------------------------------------------------------------------------
  The second section adds the LFS to the require searchlist, so that you can
  require a Lua module 'jean' in the LFS by simply doing require "jean". However
  note that this is at the search entry following the FS searcher, so if you also
  have jean.lc or jean.lua in SPIFFS, then this SPIFFS version will get loaded into
  RAM instead of using. (Useful, for development).

  See docs/en/lfs.md and the 'loaders' array in app/lua/loadlib.c for more details.

---------------------------------------------------------------------------------]]

package.loaders[3] = function(module) -- loader_flash
  local fn, ba = index(module)
  return ba and "Module not in LFS" or fn
end

--[[-------------------------------------------------------------------------------
  You can add any other initialisation here, for example a couple of the globals
  are never used, so setting them to nil saves a couple of global entries
---------------------------------------------------------------------------------]]

G.module       = nil    -- disable Lua 5.0 style modules to save RAM
package.seeall = nil

--[[-------------------------------------------------------------------------------
  These replaces the builtins loadfile & dofile with ones which preferentially
  loads the corresponding module from LFS if present.  Flipping the search order
  is an exercise left to the reader.-
---------------------------------------------------------------------------------]]

local lf, df = loadfile, dofile
G.loadfile = function(n)
  local mod, ext = n:match("(.*)%.(l[uc]a?)");
  local fn, ba   = index(mod)
  if ba or (ext ~= 'lc' and ext ~= 'lua') then return lf(n) else return fn end
end

G.dofile = function(n)
  local mod, ext = n:match("(.*)%.(l[uc]a?)");
  local fn, ba   = index(mod)
  if ba or (ext ~= 'lc' and ext ~= 'lua') then return df(n) else return fn() end
end


wifi.sta.sethostname(NODE_NAME)

VERSION = "1.6.2"

if not NO_INIT then
  if HAS_LATCH and HAS_COVER then
    print("can't have both cover and latch!\n")
    node.restart()
  end

  if HAS_LATCH then
    gpio.mode(0, gpio.OUTPUT)
    gpio.write(0, gpio.HIGH)
  end
  if HAS_KEYPAD then
    -- 1 and 2 are for Weigand
    -- bell
    gpio.mode(4, gpio.INT, gpio.PULLUP)
    -- door relay (to confirm success to keypad)
    gpio.mode(5, gpio.OUTPUT)
    gpio.write(5, gpio.HIGH)
  end
  if HAS_PUSH_TO_EXIT then
    gpio.mode(6, gpio.INT, gpio.PULLUP)
  end
  if HAS_CONTACT then
    gpio.mode(7, gpio.INT, gpio.PULLUP)
  end

  if HAS_COVER then
    -- make sure A0 is initialized properly
    if adc.force_init_mode(adc.INIT_ADC) then
      node.restart()
    end
    -- open and close relays
    gpio.mode(0, gpio.OUTPUT)
    gpio.write(0, gpio.HIGH)
    gpio.mode(3, gpio.OUTPUT)
    gpio.write(3, gpio.HIGH)
    -- open/close buttons
    gpio.mode(6, gpio.INT, gpio.PULLUP)
    gpio.mode(7, gpio.INT, gpio.PULLUP)
    -- relay to light up open/close buttons
    gpio.mode(8, gpio.OUTPUT)
    gpio.write(8, gpio.HIGH)

    if HAS_COUNTER then
      -- counter contact
      gpio.mode(9, gpio.INT, gpio.PULLUP)
    end
  end

  wifi.sta.autoconnect(0)

  dofile("repl.lua")
  if HAS_COVER then
    dofile("ammeter.lua")
    dofile("cover.lua")
  end
  if HAS_KEYPAD then
    dofile("keypad.lua")
  end
  if HAS_DIMMER then
    dofile("dimmer.lua")
  end
  if HAS_LUXMETER then
    dofile("luxmeter.lua")
  end
  if HAS_TEMP_SENSORS then
    dofile("temp_sensor.lua")
  end
  if MQTT_HOST then
    local connectWifi = function()
      wifi.sta.connect()
      -- just restart if we never got a connection within 10 minutes
      tmr.create():alarm(10 * 60 * 1000, tmr.ALARM_SINGLE, function()
        print("status: "..tostring(wifi.sta.status()).."\n")
        if wifi.sta.status() ~= wifi.STA_GOTIP then
          node.restart()
        end
      end)
    end

    wifi.eventmon.register(wifi.eventmon.STA_CONNECTED, function()
      print("connected to wifi")
    end)
    wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function()
      print("got IP")
      dofile("mqtt.lua")
      wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function()
        print("got IP again")
      end)
    end)
    wifi.eventmon.register(wifi.eventmon.STA_DISCONNECTED, function(t)
      print("got disconnect: "..tostring(t.reason))
      connectWifi()
    end)

    connectWifi()
  end
  dofile("ota_update.lua")
end
