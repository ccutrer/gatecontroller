-- wait 5 seconds in case I screwed up
tmr.create():alarm(5000, tmr.ALARM_SINGLE, function()
  dofile("config.lua")
  pcall(node.flashindex("_init"))
end)
