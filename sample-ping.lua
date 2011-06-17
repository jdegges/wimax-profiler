-- send ping requests to 'host' every 'sample_delay' seconds
--
-- statistics are written to the linda at:
-- 'ping.seqnum'    -- icmp_seqnum
-- 'ping.dropped'   -- total number of ping packets dropped so far
-- 'ping.latency'   -- the round trip time as measured by the ping
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
    -- send out a ping packet to 'host;
    op:send ()

    -- since we are only pinging one host the iterator only iterates over one
    -- response
    local iter = op:iterator_get ()

    -- grab seq/dropped/latency measurements and write to the linda
    linda:set ("ping.seqnum", iter:get_info (oping.INFO_SEQUENCE))
    linda:set ("ping.dropped", iter:get_info (oping.INFO_DROPPED))
    linda:set ("ping.latency", iter:get_info (oping.INFO_LATENCY))

    posix.sleep (sample_delay)
  end
end
