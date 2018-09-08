require './lib/ssdp.rb'
require './lib/http_header.rb'

header = HttpHeader.new "HTTP/1.1 200 OK"
header['Content-Length'] = '0'
header['LOCATION'] = 'http://example.com'

puts header.keys
puts header.org_keys
puts "#{header}"

# header
header = HttpHeader.read "GET / HTTP/1.1\r\na: b\r\nlocation: http://example.com\r\n"
puts header

# ssdp listener
listener = SSDP::SsdpListener.new
listener.handler = SSDP::SsdpHandler.new lambda {
  |ssdp_header|
  # puts "header: #{ssdp_header}"
  puts "notify? #{ssdp_header.notify?}"
  puts "location: #{ssdp_header.location}"
}
listener.start

sleep(1)

# send msearch
puts "send msearch..."
lst = SSDP.send_msearch 'ssdp:all', 3
lst.each do |header|
  # puts "#{header}"
end

gets

puts 'stop listener'
listener.stop
puts "[done]"
