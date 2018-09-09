require_relative 'upnp_model.rb'
require_relative 'ssdp.rb'
require_relative 'upnp_event.rb'
require "webrick"
require 'securerandom'
require 'time'
require 'digest'

class UPnPServerServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(req, res)
    server = @options[0]
    if req.path.end_with? "device.xml"
      device_description = server.get_device_description req.path
      res.status = 200
      res['Content-Type'] = 'text/xml; charset="utf-8"'
      res.body = device_description
    elsif req.path.end_with? "scpd.xml"
      scpd = server.get_scpd req.path
      res.status = 200
      res['Content-Type'] = 'text/xml; charset="utf-8"'
      res.body = scpd
    end
  end
  
  def do_POST(req, res)
    server = @options[0]
    soap_req = UPnPSoapRequest.read req.body
    soap_res = server.on_action_request req.path soap_req
    res.status = 200
    res['Content-Type'] = 'text/xml; charset="utf-8"'
    res.body = soap_res.to_s
  end
  
  def do_SUBSCRIBE(req, res)
    server = @options[0]
    path = req.path
    if req['SID']
      server.on_renew_subscription req['SID']
      res.status = 200
    else
      callback_urls = req['CALLBACK'].split(' ').map { |elem| elem[2..-1] }
      timeout = Integer(req['TIMEOUT'].split('-')[-1])
      server.on_subscribe req.path timeout, callback_urls
      res.status = 200
    end
  end
  
  def do_UNSUBSCRIBE(req, res)
    server = @options[0]
    server.on_unsubscribe req['SID']
    res.status = 200
  end
end


class UPnPServer
  
  def initialize(host='0.0.0.0', port=0)
    @finishing = false
    @devices = {}
    @ssdp_listener = SSDP::SsdpListener.new
    @ssdp_listener.handler = self
    @http_server = WEBrick::HTTPServer.new :BindAddress => host, :Port => port
    @http_server.mount '/', UPnPServerServlet, self
    @action_handler = nil
    @subscriptions = {}
    @interval_timer = 10
  end

  attr_accessor :action_handler, :devices
  
  def register_device(device, scpd_table)
    device.all_services.each do |service|
      hash = get_hash service.service_type
      service.scpdurl = "/#{hash}/scpd.xml"
      service.control_url = "/#{hash}/control.xml"
      service.event_sub_url = "/#{hash}/event.xml"
      service.scpd = scpd_table[service.service_type]
    end
    @devices[device.udn] = device
  end


  def unregister_device(device)
    @devices.remove device.udn
  end

  
  def notify_alive_all
  end


  def get_device_description(path)
    hash = path.split('/').reject(&:empty?).first
    @devices.each do |udn, device|
      if get_hash(udn) == hash
        return UPnPDevice.to_xml_doc device
      end
    end
  end


  def get_scpd(path)
    hash = path.split('/').reject(&:empty?).first
    @devices.values.each do |device|
      device.all_services.each do |service|
        if get_hash(service.service_type) == hash
          return UPnPScpd.to_xml_doc service.scpd
        end
      end
    end
  end


  def on_action_request(path, soap_req)
    hash = path.split('/').reject(&:empty?).first
    @devices.values.each do |device|
      device.all_services.each do |service|
        if get_hash(service.service_type) == hash
          if @action_handler
            return @action_handler.call service, soap_req
          end
        end
      end
    end
    
  end

  def set_property(device, service, props)
    @subscriptions.values.each do |subscription|
      if subscription.device.udn == device.udn and
        subscription.service.service_type == service.service_type
        subscription.callback_urls.each do |url|
          url = URI.parse(url)
          header = {
            'SID' => subscription.sid
          }
          Net::HTTP.start(url.host, url.port) do |http|
            req = NotifyRequest.new url, initheader = header
            req.body = UPnPEventProperty.to_xml_doc props
            res = http.request req
          end
        end
      end
    end
  end

  def on_subscribe(path, timeout, callback_urls)
    hash = path.split('/').reject(&:empty?).first
    @devices.values.each do |device|
      device.all_services.each do |service|
        if get_hash(service.service_type) == hash
          sid = 'uuid:' + SecureRandom.uuid
          subscription = UPnPEventSubscription.new device, service, sid, timeout, callback_urls
          @subscriptions[sid] = subscription
          return sid
        end
      end
    end
    nil
  end


  def on_renew_subscription(sid)
    subscription = @subscriptions[sid]
    subscription.renew_timeout
  end


  def on_unsubscribe(sid)
    @subscriptions.remove sid
  end


  def on_ssdp_header(ssdp_header)
    if ssdp_header.msearch?
      ret = on_msearch ssdp_header['st']
    end
  end


  def on_msearch(st)

    # ST can be one of
    #  - ssdp:all
    #  - upnp:rootdevice
    #  - udn
    #  - device type
    #  - service type

    # HTTP/1.1 200 OK
    # Cache-Control: max-age=1800
    # HOST: 239.255.255.250:1900
    # Location: http://172.17.0.2:9001/device.xml?udn=e399855c-7ecb-1fff-8000-000000000000
    # ST: e399855c-7ecb-1fff-8000-000000000000
    # Server: Cross-Platform/0.0 UPnP/1.0 App/0.0
    # USN: e399855c-7ecb-1fff-8000-000000000000
    # Ext: 
    # Date: Sat, 08 Sep 2018 13:47:14 GMT

    response_list = []

    if st == 'ssdp:all'
      devices = @devices.values
      devices.each do |root_device|

        location = get_device_location root_device

        response_list << msearch_response('upnp:rootdevice',
                                          root_device.udn + '::upnp:rootdevice',
                                          location)

        root_device.all_devices.each do |device|
          response_list << msearch_response(device.device_type,
                                            device.usn,
                                            location)
        end

        root_device.all_services.each do |service|
          response_list << msearch_response(service.service_type,
                                            root_device.udn + '::' + service.service_type,
                                            location)
        end
      end
    elsif st == 'upnp:rootdevice'
      devices = @devices.values
      devices.each do |root_device|

        location = get_device_location root_device

        response_list << msearch_response('upnp:rootdevice',
                                          root_device.udn + '::upnp:rootdevice',
                                          location)
      end
    else
      @devices.values.each do |root_device|
        location = get_device_location root_device
        root_device.all_devices.each do |device|
          if device.device_type == st
            response_list << msearch_response(st, device.usn, location)
          end
        end
        root_device.all_services.each do |service|
          if service.service_type == st
            response_list << msearch_response(st,
                                              root_device.udn + '::' + service.service_type,
                                              location)
          end
        end
      end
    end

    return response_list
  end

  def get_device_location(device)
    host = get_ip_address
    port = @http_server.config[:Port]
    return "http://#{host}:#{port}/#{get_hash(device.udn)}/device.xml"
  end

  def msearch_response(st, usn, location, ext_header = nil)
    header = HttpHeader.new FirstLine.new ['HTTP/1.1', '200', 'OK']
    fields = {
      'Cache-Control' => 'max-age=1800',
      'Location' => location,
      'ST' => st,
      'USN' => usn,
      'Ext' => '',
      'Date' => Time.now.httpdate,
    }
    header.update! fields
    if ext_header != nil
      header.update! ext_header
    end
    return header
  end

  def get_hash(udn)
    Digest::MD5.hexdigest udn
  end

  def get_ip_address
    Socket::getaddrinfo(Socket.gethostname, 'echo', Socket::AF_INET)[0][3]
  end

  def on_timer
    @subscriptions.reject! {|key, value| value.expired?}
    notify_alive_all
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
    @http_server.shutdown
    @http_server_thread.join
    @timer_thread.join
  end
end
