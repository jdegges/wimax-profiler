-- listen for udp packets on host:port and aggregate
-- bandwidth/%dropped/#pkts recvd statistics over 'sample_window' seconds.
--
-- statistics are written to the linda at:
-- 'recv.bandwidth' -- bandwidth measured in Mbps
-- 'recv.pdropped'  -- percent of recvd packets that were dropped
--                    # dropped = max_seq_num - min_seq_num + 1 (of course,
--                      this might be inaccurate if drops occurred near the
--                      beginning or end of the sample window)
--                    % dropped = 100 * #dropped / (#dropped + #recvd)
-- 'recv.pkts'      -- the number of packets received in the sample window
function recv_loop (linda, host, port, sample_window)
  require 'lanes'
  require 'posix'
  require 'socket'

  -- initialize output values to 0
  linda:set ("recv.bandwidth", 0)
  linda:set ("recv.pdropped", 0)
  linda:set ("recv.pkts", 0)

  -- initialize the socket and start listening
  local sock = socket.udp ()
  sock:setsockname (host, port)
  sock:settimeout (1)

  -- every iteration of this while loop generates a set of statistics across
  -- the sample window
  while true do
    local recvd_bytes = 0   -- # of bytes received in this sample window
    local recvd_pkts = 0    -- # of packets received in this sample window
    local min_seq = 2e60    -- minimum sequence number received 
    local max_seq = 0       -- maximum sequence number received

    local final_time = socket.gettime () + sample_window

    -- every iteration of this loop receives an additional packet, it breaks
    -- when the end of the sample window is reached
    while true do
      local current_time = socket.gettime ()

      -- compute statistics if the sample window has ended
      if final_time < current_time then
        local bw = recvd_bytes / 131072 / sample_window
        local dropped = max_seq - min_seq + 1 - recvd_pkts
        linda:set ("recv.bandwidth", bw)
        linda:set ("recv.pdropped", 100 * dropped / (dropped + recvd_pkts))
        linda:set ("recv.pkts", recvd_pkts)
        break
      end

      -- receive another packet, extract sequence number, and update
      -- recvd_bytes, recvd_pkts, min_seq, and max_seq
      local rawpkt = sock:receive ()
      if nil ~= rawpkt then
        local seqnum = tonumber (rawpkt:sub (0, 20))
        if seqnum < min_seq then
          min_seq = seqnum
        end
        if max_seq < seqnum then
          max_seq = seqnum
        end

        recvd_bytes = recvd_bytes + rawpkt:len ()
        recvd_pkts = recvd_pkts + 1
      end
    end
  end
end
