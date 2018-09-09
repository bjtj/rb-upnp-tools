require 'nokogiri'
require 'net/http'
require_relative 'upnp_xml.rb'

class NotifyRequest < Net::HTTPRequest
  METHOD = 'NOTIFY'
  REQUEST_HAS_BODY = true
  RESPONSE_HAS_BODY = false
end

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

class UPnPEventProperty < Hash
  def to_xml
    propertyset = XmlTag.new 'e:propertyset'
    propertyset.attributes = {
      'xmlns:e' => "urn:schemas-upnp-org:event-1-0"
    }
    self.each do |k,v|
      prop = propertyset.append XmlTag.new 'e:property'
      prop.append(XmlTag.new(k)).append(XmlText.new(v))
    end
    return propertyset.to_s
  end
end

def UPnPEventProperty.to_xml_doc(property)
  return '<?xml version="1.0" encoding="UTF-8"?>' + "\n#{property.to_xml}"
end

def UPnPEventProperty.read(xml)
  props = UPnPEventProperty.new
  doc = Nokogiri::XML(xml)
  doc.root.elements.each do |elem|
    if elem.name == 'property'
      name = elem.elements.first.name
      value = elem.elements.first.text
      props[name] = value
    end
  end
  props
end

class UPnPEventListener
  def initialize(on_event_notify = nil)
    @on_event_notify = on_event_notify
  end

  def on_event_notify(sid, props)
    if @on_event_notify
      @on_event_notify.call sid, props
    end
  end
end

class UPnPEventSubscription
  def initialize(device, service, sid, timeout, callback_urls = nil)
    @device = device
    @service = service
    @sid = sid
    @timeout = timeout
    @reg_date = Process.clock_gettime(Process::CLOCK_MONOTONIC, :second)
    @callback_urls = callback_urls
  end

  attr_accessor :device, :service, :sid, :timeout, :callback_urls

  def renew_timeout
    @reg_date = Process.clock_gettime(Process::CLOCK_MONOTONIC, :second)
  end

  def expired?
    now = Process.clock_gettime(Process::CLOCK_MONOTONIC, :second)
    return (now - @reg_date) >= @tiemout
  end
end
