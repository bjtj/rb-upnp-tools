require 'active_support/core_ext/hash/conversions'
require "webrick"
require 'net/http'
require 'uri'
require 'logger'
require_relative "upnp.rb"
require_relative "ssdp.rb"
require_relative "usn.rb"
require_relative "upnp_soap.rb"
require_relative "upnp_event.rb"


$logger = Logger.new STDOUT


class SubscribeRequest < Net::HTTPRequest
  METHOD = 'SUBSCRIBE'
  REQUEST_HAS_BODY = false
  RESPONSE_HAS_BODY = false
end

class UnsubscribeRequest < Net::HTTPRequest
  METHOD = 'UNSUBSCRIBE'
  REQUEST_HAS_BODY = false
  RESPONSE_HAS_BODY = false
end


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


class EventNotifyServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_NOTIFY(req, res)
    cp = @options[0]
    if req.path == '/event'
      cp.on_event_notify req['SID'], req.body
    end
    res.status = 200
  end
end


class UPnPControlPoint

  def initialize(host = '0.0.0.0', port = 0)
    @ssdp_listener = SSDP::SsdpListener.new
    @ssdp_listener.handler = self
    @http_server = WEBrick::HTTPServer.new :BindAddress => host, :Port => port
    @http_server.mount '/', EventNotifyServlet, self
    @devices = {}
    @subscriptions = {}
  end

  attr_accessor :device_listener, :event_listener, :subscriptions


  def on_time_task
    
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
    port = @http_server.config[:Port]
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
      subscription = UPnPEventSubscription.new sid, timeout, url
      @subscriptions[sid] = subscription
      return subscription
    }
  end


  def unsubscribe(subscription)
    headers = {
      'SID' => subscription.sid,
    }
    url = subscription.url
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


  def start
    @ssdp_listener_thread = Thread.new { @ssdp_listener.run }
    @http_server_thread = Thread.new { @http_server.start }
  end


  def stop
    @http_server.shutdown
    @http_server_thread.join
  end
end
