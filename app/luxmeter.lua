local bus = 0
local addr = 0x44
local sda = 1
local scl = 2

i2c.setup(bus, sda, scl, i2c.FAST)

local function read_only(bus, dev_addr)
  i2c.start(bus)
  i2c.address(bus, dev_addr, i2c.RECEIVER)
  local c = i2c.read(bus, 2)
  i2c.stop(bus)
  return c
end


local function setup_read(bus, dev_addr, reg_addr)
  i2c.start(bus)
  i2c.address(bus, dev_addr, i2c.TRANSMITTER)
  i2c.write(bus, reg_addr)
  i2c.stop(bus)
end

local function read_reg(bus, dev_addr, reg_addr)
  setup_read(bus, dev_addr, reg_addr)
  return read_only(bus, dev_addr)
end

local function write_reg(bus, dev_addr, reg_addr, data)
  i2c.start(bus)
  i2c.address(bus, dev_addr, i2c.TRANSMITTER)
  i2c.write(bus, reg_addr)
  local c = i2c.write(bus, data)
  i2c.stop(bus)
  return c
end


local function read_result()
  local c = read_reg(0, addr, 0x00)
  local e = bit.rshift(string.byte(c), 4)
  local b = bit.lshift(bit.band(string.byte(c), 0xf), 8) + string.byte(c:sub(2,2))
  return 0.01 * 2^e * b
end

local function read()
  write_reg(0, addr, 0x01, "\202\0")
  -- wait the correct amount of time for the reading to come through
  tmr.create():alarm(800, tmr.ALARM_SINGLE, function()
    -- ensure the single shot flag is clear, indicating it's done
    setup_read(0, addr, 0x01)
    while (bit.band(string.byte(read_only(0, addr)), 0x02) == 0x02)
    do
    end
    luxChanged(read_result())
  end)
end

local timer = tmr.create()

timer:alarm(15000, tmr.ALARM_AUTO, read)

function changeReportPeriod(newPeriod)
  timer:stop()
  timer:unregister()
  -- do an immediate read
  read()
  timer:alarm(newPeriod, tmr.ALARM_AUTO, read)
end