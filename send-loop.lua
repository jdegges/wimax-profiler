-- send udp packets of size 'pktsz' bytes to 'host:port' at 'bitrate' kBps
--
-- note: a generic packet is generated from reading /dev/urandom and then
-- prefixed by a timestamp (accurate to the millisecond?) which is then
-- incremented by 1 for every packet sent.
--
-- no statistics are generated here...
function send_loop (host, port, pktsz, bitrate)
  require 'posix'
  require 'socket'

  -- seq num is 20 bytes... the socket lib cant send more than 8192 bytes.
  if pktsz < 20 or 8192 < pktsz then
    print ("invalid pktsz")
    return nil
  end

  -- generate random packet
  local fh = io.open ("/dev/urandom", "rb")
  local rawpkt = fh:read (pktsz - 20)
  fh:close ()

  -- create socket and initialize seqnum
  local sock = socket.udp ()
  local seqnum = socket.gettime () * 1e4

  while true do
    local seqfmt = string.format ("%020d", seqnum)

    -- generate packet to be sent
    local pkt = seqfmt .. rawpkt

    rv, msg = sock:sendto (pkt, host, port)
    if nil == rv then
      print ("error sending packet: " .. msg)
      return nil
    end

    -- wait some time thats proportional to the bitrate you'd like to send at
    local sleep = pktsz / (bitrate * 0.001024) - 50
    if 1 < sleep then
      posix.usleep (sleep)
    end

    seqnum = seqnum + 1
  end
end
