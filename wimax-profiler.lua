require 'getopt'
require 'lanes'
require 'posix'
require 'sample-gps'
require 'sample-ping'
require 'sample-wimax'
require 'send-loop'
require 'recv-loop'


function usage ()
  print ("wimax-profiler [options]")
  print ("  --help                  Display these help options")
  print ("  --wimax                 Sample WiMax link status")
  print ("  --gps=host:port         host:port to connect to for GPS data")
  print ("  --ping=host             host to ping")
  print ("  --send=host:port        host:port to send UDP packets to")
  print ("    --bitrate=br          Bitrate to send at (kBps)")
  print ("    --pktsz=packet size   Size of packet to send (20-8182 bytes)")
  print ("  --recv=host:port        host:port to listen for UDP packets on")
  print ("    --timestep=seconds    Amount of time to compute statistics over")
  print ("  --output=file           file to write measurements into")
end

-- parse a string like "host:port" into "host" and "port"
function split_hostaddr (str)
  local i = string.find (str, ":")
  return string.sub (str, 1, i - 1), string.sub (str, i + 1, str:len ())
end

local opt = getopt (arg, "bl")
if nil ~= opt.help then
  usage ()
  return 0
end

-- parse arguments for logging measurements
if nil ~= opt.output then
  opt.output = io.open (opt.output, "a+")
else
  opt.output = io.stdout
end

-- create thread communication channel 'linda'
local linda = lanes.linda ()

-- output logfile header
opt.output:write ('#')

-- parse arguments for GPS measurements
if nil ~= opt.gps then
  local host, port = split_hostaddr (opt.gps)

  -- write log header
  opt.output:write (',time,lat,lon,alt')

  -- query gps position every 4 seconds, if disconnected/error happens then
  -- wait 20 seconds before reconnecting.
  gps_lane = lanes.gen ("*", sample_gps) (linda, host, port, 4, 20)
end

-- parse arguemnts for sending UDP packets
if nil ~= opt.send then
  if nil == opt.bitrate or nil == opt.pktsz then
    print ("You must specify bitrate and packet size with the --send option")
    usage ()
    return 1
  end

  local bitrate = tonumber (opt.bitrate)
  local pktsz = tonumber (opt.pktsz)

  if bitrate < 0 or pktsz < 20 or 8192 < pktsz then
    print ("Bitrate must be positive and packet size must be within bounds")
    usage ()
    return 1
  end

  local host, port = split_hostaddr (opt.send)

  -- start running the send thread
  send_lane = lanes.gen ("*", send_loop) (host, port, pktsz, bitrate)
end

-- parse arguments for receiving UDP packets
if nil ~= opt.recv then
  if nil == opt.timestep then
    print ("You must specify a timestep with the --recv option")
    usage ()
    return 1
  end

  local host, port = split_hostaddr (opt.recv)

  -- startup the recv thread
  opt.output:write (',bandwidth,%dropped,pkts_recvd')
  recv_lane = lanes.gen ("*", recv_loop) (linda, host, port, tonumber (opt.timestep))
end

-- startup the wimax link monitoring thread
if nil ~= opt.wimax then
  opt.output:write (',freq,rssi,cinr,txpwr')

  -- the script setup-wimax.sh will be invoked to reconnect to the BS if it
  -- gets disconnected. reconnect timeout is 20 seconds. when connected, will
  -- sample every 4 seconds.
  wimax_lane = lanes.gen ("*", sample_wimax) (linda, "./setup-wimax.sh", 4, 20)
  if true ~= linda:receive ("wimax.ready") then
    print ("wimax is not ready... big problem")
    return 1
  else
    print ("wimax is now ready.")
  end
end

-- startup the ping thread
if nil ~= opt.ping then
  opt.output:write (',seqnum,dropped,latency')

  -- send/recv pings every 4 seconds.
  ping_lane = lanes.gen ("*", sample_ping) (linda, opt.ping, 4)
end

opt.output:write ('\n')
opt.output:flush ()

posix.sleep (5)

-- collect samples from the running threads
local counter = 0
while true do
  local output_line = ""

  if nil ~= opt.gps then
    local time = linda:get ("gps.time")
    local lat = linda:get ("gps.lat")
    local lon = linda:get ("gps.lon")
    local alt = linda:get ("gps.alt")
    print (counter .. " | "
      .. "time:" .. time .. " | "
      .. "lat: " .. lat .. " | "
      .. "lon: " .. lon .. " | "
      .. "alt: " .. alt)
    output_line = string.format ("%s,%f,%f,%f,%f", output_line, time, lat, lon, alt)
  end

  if nil ~= opt.recv then
    local bandwidth = linda:get ("recv.bandwidth")
    local pdropped = linda:get ("recv.pdropped")
    local pkts = linda:get ("recv.pkts")
    print (counter .. " | "
      .. bandwidth .. "Mbps | "
      .. pdropped .. "% dropped | "
      .. pkts .. " pkts recvd")
    output_line = string.format ("%s,%f,%f,%d", output_line, bandwidth, pdropped, pkts)
  end

  if nil ~= opt.wimax then
    local freq = linda:get ("wimax.freq")
    local rssi = linda:get ("wimax.rssi")
    local cinr = linda:get ("wimax.cinr")
    local txpwr = linda:get("wimax.txpwr")
    print (counter .. " | "
      .. "Freq: " .. freq .. "KHz" .. " | "
      .. "RSSI: " .. rssi .. "dBm" .. " | "
      .. "CINR: " .. cinr .. "dB" .. " | "
      .. "TXPWR:" .. txpwr .. "dBm")
    output_line = string.format ("%s,%d,%d,%d,%d", output_line, freq, rssi, cinr, txpwr)
  end

  if nil ~= opt.ping then
    local seqnum = linda:get ("ping.seqnum")
    local dropped = linda:get ("ping.dropped")
    local latency = linda:get ("ping.latency")
    print (counter .. " | "
      .. "icmp_req=" .. seqnum .. " | "
      .. "dropped=" .. dropped .. " | "
      .. "time=" .. latency .. "ms")
    output_line = string.format ("%s,%d,%d,%d", output_line, seqnum, dropped, latency)
  end

  print ("")

  opt.output:write (output_line .. "\n")
  opt.output:flush ()

  counter = counter + 1

  -- wait for 8 seconds before sampling again (this is 1/2 the frequency that
  -- the threads are sampling at)
  posix.sleep (8)
end
