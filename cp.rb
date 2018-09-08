require './lib/upnp_control_point.rb'


cp = UPnPControlPoint.new

cp.device_listener = UPnPDeviceListener.new lambda {|device|
  puts "added: #{device['friendlyName']}"

  res = cp.invoke_action device, device.services.first, 'GetTarget', {}
  puts res.to_xml
  puts res
  
  subscription = cp.subscribe device, device.services.first
  puts "subscription / sid: #{subscription.sid}"

  Thread.new {
    sleep 3
    cp.unsubscribe subscription
  }
  
}, lambda {|device|
  puts "removed: #{device['friendlyName']}"
}

cp.event_listener = UPnPEventListener.new lambda {|sid, props|
  puts sid
  puts props
}

cp.start

cp.send_msearch 'ssdp:all'

gets

cp.stop
