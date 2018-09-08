require 'nokogiri'
require_relative 'upnp_xml.rb'

class UPnPSoapRequest < Hash

  def initialize(service_type = nil, action_name = nil)
    @service_type = service_type
    @action_name = action_name
  end
  
  attr_accessor :service_type, :action_name
  def to_xml
    tag = XmlTag.new 's:Envelope'
    tag.attributes = {
      's:encodingStyle' => "http://schemas.xmlsoap.org/soap/encoding/",
	  'xmlns:s' => "http://schemas.xmlsoap.org/soap/envelope/"
    }
    body = tag.append XmlTag.new('s:Body')
    action = body.append XmlTag.new("u:#{@action_name}")
    action.attributes = {
      'xmlns:u' => @service_type
    }
    self.each do |k,v|
      prop = action.append XmlTag k
      prop.append XmlText.new v
    end

    return '<?xml version="1.0" encoding="utf-8"?>' + "\n#{tag}"
    
  end
end

def UPnPSoapRequest.read(xml)
  soap_req = UPnPSoapRequest.new
  doc = Nokogiri::XML(xml)
  action_elem = doc.root.first_element_child.first_element_child
  # puts action_elem.methods.grep(/.*/)
  # puts '------------------------'
  # puts action_elem.attributes
  # puts action_elem.namespace.href
  soap_req.service_type = action_elem.namespace.href
  soap_req.action_name = action_elem.name
  action_elem.elements.each do |node|
    name = node.name
    value = node.text
    soap_req[name] = value
  end
  soap_req
end


class UPnPSoapResponse < Hash

  def initialize(service_type = nil, action_name = nil)
    @service_type = service_type
    @action_name = action_name
  end
  
  attr_accessor :service_type, :action_name
  
  def to_xml
    tag = XmlTag.new 's:Envelope'
    tag.attributes = {
      's:encodingStyle' => "http://schemas.xmlsoap.org/soap/encoding/",
	  'xmlns:s' => "http://schemas.xmlsoap.org/soap/envelope/"
    }
    body = tag.append XmlTag.new('s:Body')
    action = body.append XmlTag.new("u:#{@action_name}Response")
    action.attributes = {
      'xmlns:u' => @service_type
    }
    self.each do |k,v|
      prop = action.append XmlTag.new(k)
      prop.append XmlText.new(v)
    end

    return '<?xml version="1.0" encoding="utf-8"?>' + "\n#{tag}"
  end
end


def UPnPSoapResponse.read(xml)
  soap_res = UPnPSoapResponse.new
  doc = Nokogiri::XML(xml)
  action_elem = doc.root.first_element_child.first_element_child
  soap_res.service_type = action_elem.namespace.href
  soap_res.action_name = action_elem.name[0..-'Response'.length]
  action_elem.elements.each do |node|
    name = node.name
    value = node.text
    soap_res[name] = value
  end
  soap_res
end
