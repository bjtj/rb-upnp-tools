require_relative 'lib/upnp_server.rb'

server = UPnPServer.new

device = UPnPDevice.read open('res/device.xml').read
scpd_table = {}
device.services.each do |service|
  scpd_table[service.service_type] = UPnPScpd.read(open('res/scpd.xml').read)
end

server.register_device device, scpd_table

server.start

gets

server.stop
