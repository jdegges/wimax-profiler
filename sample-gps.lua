function sample_gps (linda, host, port, sample_delay, reconnect_delay)
  require 'lanes'
  require 'posix'
  require 'gps'

  linda:set ("gps.time", 0)
  linda:set ("gps.lat", 0)
  linda:set ("gps.lon", 0)
  linda:set ("gps.alt", 0)

  local g = gps.open (host, port)
  g:stream (gps.WATCH_ENABLE)

  while true do
    while true == g:waiting (sample_delay) do
      local d = g:read ()
      if nil == d then
        print ("error reading gps... reconnecting")

        linda:set ("gps.time", 0)
        linda:set ("gps.lat", 0)
        linda:set ("gps.lon", 0)
        linda:set ("gps.alt", 0)

        g:close ()

        posix.sleep (reconnect_delay)

        g = gps.open (host, port)
        g:stream (gps.WATCH_ENABLE)
        break
      end

      linda:set ("gps.time", d.fix.time)
      linda:set ("gps.lat", d.fix.latitude)
      linda:set ("gps.lon", d.fix.longitude)
      linda:set ("gps.alt", d.fix.altitude)
    end
  end
end
