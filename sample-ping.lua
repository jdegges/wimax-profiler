function sample_ping (linda, host, sample_delay)
  require 'lanes'
  require 'oping'
  require 'posix'

  linda:set ("ping.seqnum", 0)
  linda:set ("ping.dropped", 0)
  linda:set ("ping.latency", 0)

  local op = oping.new ()
  op:host_add (host)

  while true do
    op:send ()
    local iter = op:iterator_get ()
    linda:set ("ping.seqnum", iter:get_info (oping.INFO_SEQUENCE))
    linda:set ("ping.dropped", iter:get_info (oping.INFO_DROPPED))
    linda:set ("ping.latency", iter:get_info (oping.INFO_LATENCY))
    posix.sleep (sample_delay)
  end
end
