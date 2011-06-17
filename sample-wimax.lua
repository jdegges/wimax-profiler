-- measure wimax link status every 'sample_delay' seconds. if we get
-- disconnected then wait 'reconnect_delay' seconds before trying to reconnect.
-- the script 'connect_script' will be executed to try to reconnect.
--
-- statistics are written to the linda at:
-- 'wimax.freq'     -- frequency...
-- 'wimax.rssi'     -- signal strength...
-- 'wimax.cinr'     -- channel quality...
-- 'wimax.txpwr'    -- transmit power...
function sample_wimax (linda, connect_script, sample_delay, reconnect_delay)
  require 'lanes'
  require 'posix'
  require 'wimax'

  -- zero out values in the linda
  linda:set ("wimax.freq", 0)
  linda:set ("wimax.rssi", 0)
  linda:set ("wimax.cinr", 0)
  linda:set ("wimax.txpwr", 0)

  -- open and connect to wimax device
  local w = wimax.open (wimax.PRIVILEGE_READ_ONLY)
  local dl = w:get_device_list ()
  local i = 0

  -- iterate over all the wimax devices found and connect to the 'last one'
  -- TODO: if multiple devices are connected the caller should specify which
  -- device to use
  for k, v in pairs (dl) do
    i = k
  end
  w:device_open (i)

  -- execute 'connect_script' if w == nil?
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

    -- if error getting link status then try to reconnect (its kind of obvious
    -- that the reconnect code should be out in another function, but because
    -- of the multithreading environment its not possible to define and execute
    -- other functions from within this file, they would have to be in separate
    -- lua files.)
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

    -- write measurements to the linda...
    linda:set ("wimax.freq", ls.freq)
    linda:set ("wimax.rssi", ls.rssi)
    linda:set ("wimax.cinr", ls.cinr)
    linda:set ("wimax.txpwr", ls.txpwr)

    posix.sleep (sample_delay)
  end end
end
