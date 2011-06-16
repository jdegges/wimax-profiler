function recv_loop (linda, host, port, sample_window)
  require 'lanes'
  require 'posix'
  require 'socket'

  linda:set ("recv.bandwidth", 0)
  linda:set ("recv.pdropped", 0)
  linda:set ("recv.pkts", 0)


  local sock = socket.udp ()
  sock:setsockname (host, port)
  sock:settimeout (1)

  while true do
    local recvd_bytes = 0
    local recvd_pkts = 0
    local min_seq = 2e60
    local max_seq = 0

    local final_time = socket.gettime () + sample_window

    while true do
      local current_time = socket.gettime ()
      if final_time < current_time then
        local bw = recvd_bytes / 131072 / sample_window
        local dropped = max_seq - min_seq + 1 - recvd_pkts
        linda:set ("recv.bandwidth", bw)
        linda:set ("recv.pdropped", 100 * dropped / (dropped + recvd_pkts))
        linda:set ("recv.pkts", recvd_pkts)
        break
      end

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
