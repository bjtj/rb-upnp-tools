require 'nokogiri'

class UPnPEventProperty < Hash
  
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
  def initialize(sid, timeout, url)
    @sid = sid
    @timeout = timeout
    @reg_date = Process.clock_gettime(Process::CLOCK_MONOTONIC, :second)
    @url = url
  end

  attr_accessor :sid, :timeout, :url

  def renew_timeout
    @reg_date = Process.clock_gettime(Process::CLOCK_MONOTONIC, :second)
  end

  def expired?
    now = Process.clock_gettime(Process::CLOCK_MONOTONIC, :second)
    return (now - @reg_date) >= @tiemout
  end
end
