require 'test/unit'
require "webrick"
require_relative '../lib/upnp_server.rb'
require_relative '../lib/upnp_soap.rb'

class TestServer < Test::Unit::TestCase

  def test_device_description
    server = UPnPServer.new
    device = UPnPDevice.read(open('../res/device.xml').read)
    server.register_device device, {}

    path = "/#{server.get_hash(device.udn)}/device.xml"
    xml = server.get_device_description path
    puts xml
  end

  def test_scpd
    server = UPnPServer.new
    device = UPnPDevice.read(open('../res/device.xml').read)
    scpd_table = {'urn:schemas-upnp-org:service:SwitchPower:1' =>
                  UPnPScpd.read(open('../res/scpd.xml'))}
    server.register_device device, scpd_table

    path = "/#{server.get_hash('urn:schemas-upnp-org:service:SwitchPower:1')}/scpd.xml"
    xml = server.get_scpd path
    puts xml
  end
  
  def test_action
    server = UPnPServer.new
    server.register_device UPnPDevice.read(open('../res/device.xml').read), {}
    server.action_handler = lambda { |service, soap_req|
      puts soap_req
      res = UPnPSoapResponse.new
    }

    service_hash = server.get_hash 'urn:schemas-upnp-org:service:SwitchPower:1'
    path = "/#{service_hash}/control.xml"
    soap_req = UPnPSoapRequest.new
    soap_req['a'] = 'b'
    server.on_action_request path, soap_req
  end

  class EventServlet < WEBrick::HTTPServlet::AbstractServlet
    def do_NOTIFY(req, res)
      puts '-- notify --'
      puts "sid: #{req['SID']}"
      puts req.body
      res.status = 200
    end
  end

  def test_event_sub

    http_server = WEBrick::HTTPServer.new :BindAddress => '0.0.0.0', :Port => 0
    http_server.mount '/', EventServlet
    port = http_server.config[:Port]
    thread = Thread.new { http_server.start }
    
    server = UPnPServer.new
    device = UPnPDevice.read(open('../res/device.xml').read)
    server.register_device device, {}
    callback_urls = ["http://localhost:#{port}/event-handler"]
    path = "/#{server.get_hash('urn:schemas-upnp-org:service:SwitchPower:1')}/event.xml"
    sid = server.on_subscribe path, 1800, callback_urls
    puts sid

    service = device.get_service 'urn:schemas-upnp-org:service:SwitchPower:1'
    props = UPnPEventProperty.new
    props['LoadLevelStatus'] = 21
    server.set_property device, service, props
    sleep 1

    http_server.shutdown
    thread.join
  end
end
