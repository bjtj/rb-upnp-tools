require_relative 'upnp.rb'
require_relative 'ssdp.rb'


class UPnPServerServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(req, res)
    server = @options[0]
    if 
    device_description = server.get_device_description req.path
    res.status = 200
  end
  def do_POST(req, res)
    server = @options[0]
    res.status = 200
  end
  def do_SUBSCRIBE(req, res)
    server = @options[0]
    res.status = 200
  end
  def do_UNSUBSCRIBE(req, res)
    server = @options[0]
    res.status = 200
  end
end


class UPnPServer
  
  def initialize(host='0.0.0.0', port=0)
    @finishing = false
    @devices = {}
    @ssdp_listner = SsdpListener()
    @ssdp_listener.handler = self
    @http_server = WEBrick::HTTPServer.new :BindAddress => host, :Port => port
    @http_server.mount '/', UPnPServerServlet, self
  end

  
  def register_device(device)
    @devices[device.udn] = device
  end


  def unregister_device(device)
    @devices.remove device.udn
  end

  
  def notify_alive_all
    @devices.each do |device|
      devices = device.all_devices
      services = device.all_services
    end
  end


  def get_device_description(path)
    
  end


  def get_scpd(path)
    
  end


  def on_action_request(req)
    
  end


  def on_subscribe(req)
    
  end


  def on_unsubscribe(req)
    
  end


  def on_msearch(st)
    
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
