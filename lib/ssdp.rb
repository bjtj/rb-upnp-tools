require 'socket'
require 'logger'
require_relative 'http_header.rb'

$logger = Logger.new(STDOUT)

module SSDP

  MCAST_HOST = '239.255.255.250'
  MCAST_PORT = 1900


  class SsdpHeader < HttpHeader
    def initialize(http_header)
      @http_header = http_header
    end

    def notify?
      @http_header.firstline[0] == 'NOTIFY'
    end

    def notify_alive?
      self.notify? and @http_header['nts'] == 'ssdp:alive'
    end

    def notify_byebye?
      self.notify? and @http_header['nts'] == 'ssdp:byebye'
    end

    def msearch?
      @http_header.firstline[0] == 'M-SEARCH'
    end

    def http_response?
      @http_header.firstline[0].start_with? 'HTTP'
    end

    def usn
      self['usn']
    end

    def location
      self['location']
    end

    def [](key)
      @http_header[key]
    end

    def []=(key, value)
      @http_header[key] = value
    end

    def to_s
      @http_header.to_s
    end

    def to_str
      @http_header.to_str
    end
  end


  class SsdpHandler
    def initialize(func = nil)
      @func = func
    end
    
    def on_ssdp_header(ssdp_header)
      if @func
        return @func.call(ssdp_header)
      end
    end
  end


  class SsdpListener
    def initialize(port = 1900)
      @host = '0.0.0.0'
      @port = port
      @handler = nil
      @finishing = false
    end

    attr_reader :port
    attr_accessor :handler

    def finish
      @finishing = true
    end
    
    def run
      @finishing = false
      socket = UDPSocket.new
      membership = IPAddr.new(MCAST_HOST).hton + IPAddr.new(@host).hton
      socket.setsockopt(:IPPROTO_IP, :IP_ADD_MEMBERSHIP, membership)
      socket.setsockopt(:SOL_SOCKET, :SO_REUSEADDR, 1)
      socket.setsockopt(:SOL_SOCKET, :SO_REUSEPORT, 1)
      socket.bind(@host, @port)
      fds = [socket]
      $logger.debug 'listen...'
      while @finishing == false do
        timeout = 1
        if ios = select(fds, [], [], timeout)
          data, addr = socket.recvfrom(4096)
          ssdp_header = SsdpHeader.new HttpHeader.read(data.chomp)
          if @handler
            responses = @handler.on_ssdp_header(ssdp_header)
            if responses != nil
              responses.each do |response|
                socket.send response.to_s, 0, addr[2], addr[1]
              end
            end
          end
        end
      end
      socket.close
    end

    def start
      @run_thread = Thread.new { self.run }
    end

    def stop
      @finishing = true
      @run_thread.join
    end
  end


  def self.send_msearch(st, mx, handler = nil)
    socket = UDPSocket.new
    socket.setsockopt(:IPPROTO_IP, :IP_MULTICAST_TTL, 1)
    payload = "M-SEARCH * HTTP/1.1\r\n" \
              "HOST: #{MCAST_HOST}:#{MCAST_PORT}\r\n" \
              "MAN: \"ssdp:discover\"\r\n" \
              "MX: 3\r\n" \
              "ST: ssdp:all\r\n" \
              "\r\n"

    socket.send(payload, 0, MCAST_HOST, MCAST_PORT)

    start = Process.clock_gettime(Process::CLOCK_MONOTONIC, :second)

    fds = [socket]

    lst = []

    while true
      cur = Process.clock_gettime(Process::CLOCK_MONOTONIC, :second)
      if (cur - start) >= mx 
        break
      end
      if ios = select(fds, [], [], 1)
        data, addr = socket.recvfrom(4096)
        ssdp_header = SsdpHeader.new HttpHeader.read(data.chomp)
        if handler
          handler.call(ssdp_header)
        end
        lst << ssdp_header
      end
    end
    socket.close
    return lst
  end


end
