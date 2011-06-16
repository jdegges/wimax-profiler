function sample_wimax (linda, connect_script, sample_delay, reconnect_delay)
  require 'lanes'
  require 'posix'
  require 'wimax'

  linda:set ("wimax.freq", 0)
  linda:set ("wimax.rssi", 0)
  linda:set ("wimax.cinr", 0)
  linda:set ("wimax.txpwr", 0)

  linda:send ("wimax.ready", true)

  local w = wimax.open (wimax.PRIVILEGE_READ_ONLY)
  local dl = w:get_device_list ()
  local i = 0
  for k, v in pairs (dl) do
    i = k
  end
  w:device_open (i)

  if nil == w then
    os.execute (connect_script)
    w = wimax.open (wimax.PRIVILEGE_READ_ONLY)
    local dl = w:get_device_list ()
    local i = 0
    for k, v in pairs (dl) do
      i = k
    end
    w:device_open (i)
  end

  while true do while true do
    local ls = w:get_link_status ()
    if nil == ls then
      print ("error getting link status... restarting in 20")
      linda:set ("wimax.freq", 0)
      linda:set ("wimax.rssi", 0)
      linda:set ("wimax.cinr", 0)
      linda:set ("wimax.txpwr", 0)

      w:device_close ()
      w:close ()

      posix.sleep (reconnect_delay)
      os.execute (connect_script)

      w = wimax.open (wimax.PRIVILEGE_READ_ONLY)
      local dl = w:get_device_list ()
      local i = 0
      for k, v in pairs (dl) do
        i = k
      end
      w:device_open (i)

      break
    end

    linda:set ("wimax.freq", ls.freq)
    linda:set ("wimax.rssi", ls.rssi)
    linda:set ("wimax.cinr", ls.cinr)
    linda:set ("wimax.txpwr", ls.txpwr)

    posix.sleep (sample_delay)
  end end
end
