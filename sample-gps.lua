-- connect to the gpsd running at host:port and sample it for location data
-- every 'sample_delay' seconds. if an error occurrs or it gets disconnected
-- then it will wait 'reconnect_delay' seconds before attempting to reconnect.
--
-- statistics are written to the linda at:
-- 'gps.time'   -- the time according to the gps module
-- 'gps.lat'    -- latitude...
-- 'gps.lon'    -- longitude...
-- 'gps.alt'    -- altitude...
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

      -- if there is an error reading the gps module then reconnect
      if nil == d then
        print ("error reading gps... reconnecting")

        -- zero out the statistics in the linda (indicating error)
        linda:set ("gps.time", 0)
        linda:set ("gps.lat", 0)
        linda:set ("gps.lon", 0)
        linda:set ("gps.alt", 0)

        -- disconnect...
        g:close ()

        posix.sleep (reconnect_delay)

        -- reconnect...
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
