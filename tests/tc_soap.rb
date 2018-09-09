require_relative "../lib/upnp_soap.rb"
require "test/unit"

class TestSoap < Test::Unit::TestCase
  def test_soap_req
    xml = open('../res/action_request2.xml').read
    req = UPnPSoapRequest.read xml
    puts req.to_xml
  end
end
