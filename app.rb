require './lib/ssdp.rb'
require './lib/http_header.rb'

listener = SsdpListner.new

listener.run


header = HttpHeader.new "HTTP/1.1 200 OK"

header['Content-Length'] = '0'
header['LOCATION'] = 'http://example.com'


puts header.keys
puts header.org_keys

puts "#{header}"

header = HttpHeader.read "GET / HTTP/1.1\r\na: b\r\nlocation: http://example.com\r\n"
puts header

send_msearch 'ssdp:all', 3
