require "test/unit"
require_relative '../lib/upnp_server.rb'

class TestSsdp < Test::Unit::TestCase
  def test_ssdp_msearch_response
    server = UPnPServer.new
    device  = UPnPDevice.read open('../res/device.xml').read
    device.udn = 'uuid:' + SecureRandom::uuid
    server.register_device device

    puts '----'

    responses = server.on_msearch 'ssdp:all'
    puts responses

    puts '----'

    responses = server.on_msearch 'upnp:rootdevice'
    puts responses

    puts '----'

    responses = server.on_msearch 'urn:schemas-upnp-org:device:DimmableLight:1'
    puts responses

    puts '----'

    responses = server.on_msearch 'urn:schemas-upnp-org:service:SwitchPower:1'
    puts responses
  end
end
