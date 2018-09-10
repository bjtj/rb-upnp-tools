require 'active_support/core_ext/hash/conversions'
require 'net/http'
require 'uri'
require 'logger'
require_relative "ssdp.rb"
require_relative "http_server.rb"
require_relative "upnp_model.rb"
require_relative "usn.rb"
require_relative "upnp_soap.rb"
require_relative "upnp_event.rb"


$logger = Logger.new STDOUT


class UPnPDeviceListener
  def initialize(on_device_added = nil, on_device_removed = nil)
    @on_device_added = on_device_added
    @on_device_removed = on_device_removed
  end
  
  def on_device_added(device)
    if @on_device_added
      @on_device_added.call(device)
    end
  end

  def on_device_removed(device)
    if @on_device_removed
      @on_device_removed.call(device)
    end
  end
end


class UPnPControlPoint

  def initialize(host = '0.0.0.0', port = 0)
    @finishing = false
    @ssdp_listener = SSDP::SsdpListener.new
    @ssdp_listener.handler = self
    @http_server = HttpServer.new host, port
    @http_server.handler = lambda { |req, res| on_http_request req, res }
    @devices = {}
    @subscriptions = {}
    @interval_timer = 10
  end

  attr_accessor :device_listener, :event_listener, :subscriptions


  def on_http_request(req, res)
    if req.path == '/event'
      on_event_notify req['SID'], req.body
    end
    res.status = 200
  end


  def on_event_notify(sid, body)
    props = UPnPEventProperty.read(body)
    if @event_listener
      @event_listener.on_event_notify sid, props
    end
  end


  def on_ssdp_header(ssdp_header)
    if ssdp_header.notify_alive? or ssdp_header.http_response?
      usn = Usn.read(ssdp_header.usn)
      if not @devices.key? usn.udn
        xml = self.build_device ssdp_header
        if xml.to_s.empty?
          return
        end
        device = UPnPDevice.read xml
        device.base_url = ssdp_header.location
        @devices[usn.udn] = device
        if @device_listener
          @device_listener.on_device_added device
        end
      end
    elsif ssdp_header.notify_byebye?
      usn = Usn.read(ssdp_header['usn'])
      device = @devices[usn.udn]
      if device
        if @device_listener
          @device_listener.on_device_removed device
        end
        @devices.delete usn.udn
      end
    end
  end


  def send_msearch(st, mx = 3)
    $logger.debug("send msearch / #{st}")
    SSDP.send_msearch st, mx, lambda {
      |ssdp_header| on_ssdp_header ssdp_header}
  end


  def build_device(ssdp_header)
    uri = URI(ssdp_header.location)
    xml = Net::HTTP.get(uri)
  end


  def get_ip_address
    Socket::getaddrinfo(Socket.gethostname, 'echo', Socket::AF_INET)[0][3]
  end


  def subscribe(device, service)
    host = self.get_ip_address
    port = @http_server.get_port
    headers = {
      'NT' => 'upnp:event',
      'CALLBACK' => "<http://#{host}:#{port}/event>",
      'TIMEOUT' => 'Second-1800'
    }
    url = URI::join(device.base_url, service['eventSubURL'])
    Net::HTTP.start(url.host, url.port) { |http|
      req = SubscribeRequest.new url, initheader = headers
      res = http.request req
      sid = res['sid']
      timeout = res['timeout'].split('-')[-1]
      subscription = UPnPEventSubscription.new device, service, sid, timeout
      @subscriptions[sid] = subscription
      return subscription
    }
  end


  def unsubscribe(subscription)
    headers = {
      'SID' => subscription.sid,
    }
    url = URI::join(subscription.device.base_url, subscription.service.scpdurl)
    Net::HTTP.start(url.host, url.port) { |http|
      req = UnsubscribeRequest.new url, initheader = headers
      res = http.request req
      $logger.debug("response : #{res.code}'")
    }
    @subscriptions.delete(subscription.sid)
  end


  def invoke_action(device, service, action_name, params)
    url = URI::join(device.base_url, service['controlURL'])
    soap_req = UPnPSoapRequest.new service.service_type, action_name
    soap_req.merge! params
    header = {
      'SOAPACTION' => "#{service.service_type}##{action_name}",
      'Content-Type' => 'text/xml; charset="utf-8'
    }
    http = Net::HTTP.new(url.host, url.port)
    req = Net::HTTP::Post.new(url.request_uri, header)
    req.body = soap_req.to_xml
    res = http.request(req)
    UPnPSoapResponse.read res.body
  end

  
  def on_timer
    @devices.reject! {|key, value| value.expired? }
  end

  def timer_loop
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC, :second)
    while not @finishing
      dur = Process.clock_gettime(Process::CLOCK_MONOTONIC, :second) - start
      if dur >= @interval_timer
        on_timer
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC, :second)
      end
    end
  end
  
  def start
    @finishing = false
    @ssdp_listener_thread = Thread.new { @ssdp_listener.run }
    @http_server_thread = Thread.new { @http_server.start }
    @timer_thread = Thread.new { timer_loop }
  end


  def stop
    @finishing = true
    @http_server.stop
    @http_server_thread.join
    @timer_thread.join
  end
end
