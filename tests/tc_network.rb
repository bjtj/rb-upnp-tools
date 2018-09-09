require "test/unit"
require_relative '../lib/upnp_server.rb'

class TestNetwork < Test::Unit::TestCase
  def test_ip_addr
    server = UPnPServer.new
    puts server.get_ip_address
  end
end
