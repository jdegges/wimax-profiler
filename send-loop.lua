function send_loop (host, port, pktsz, bitrate)
  require 'posix'
  require 'socket'

  if pktsz < 20 or 8192 < pktsz then
    print ("invalid pktsz")
    return nil
  end

  local fh = io.open ("/dev/urandom", "rb")
  local rawpkt = fh:read (pktsz - 20)
  fh:close ()

  local sock = socket.udp ()
  local seqnum = socket.gettime () * 1e4

  while true do
    local seqfmt = string.format ("%020d", seqnum)
    local pkt = seqfmt .. rawpkt

    rv, msg = sock:sendto (pkt, host, port)
    if nil == rv then
      print ("error sending packet: " .. msg)
      return nil
    end

    local sleep = pktsz / (bitrate * 0.001024) - 50
    if 1 < sleep then
      posix.usleep (sleep)
    end

    seqnum = seqnum + 1
  end
end
