require 'socket'

class SSDP
  @@mcast_host = '239.255.255.250'
  @@mcast_port = 1900

  def self.mcast_host
    @@mcast_host
  end

  def self.mcast_port
    @@mcast_port
  end
end


class SsdpListner
  def initialize(port=0)
    @port = port
  end
  
  def run
    puts 'run'
  end
end

def send_msearch(st, mx)
  socket = UDPSocket.new
  socket.setsockopt(:IPPROTO_IP, :IP_MULTICAST_TTL, 1)
  payload = "M-SEARCH * HTTP/1.1\r\n" \
            "HOST: #{SSDP.mcast_host}:#{SSDP.mcast_port}\r\n" \
            "MAN: \"ssdp:discover\"\r\n" \
            "MX: 3\r\n" \
            "ST: ssdp:all\r\n" \
            "\r\n"

  socket.send(payload, 0, SSDP.mcast_host, SSDP.mcast_port)

  start = Process.clock_gettime(Process::CLOCK_MONOTONIC, :second)

  fds = [socket]

  while true
    cur = Process.clock_gettime(Process::CLOCK_MONOTONIC, :second)
    if (cur - start) >= mx 
      break
    end
    if ios = select(fds, [], [], 1)
      pack = socket.recvfrom(4096)
      puts pack
    end
  end

  socket.close
end
