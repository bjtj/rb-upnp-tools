require "test/unit"

class TestEtc < Test::Unit::TestCase
  def test_callback_url
    callback = '<url1> <url2>'
    puts callback.split(' ').map {|elem| elem[1..-2]}

    callback = '<url1>'
    puts callback.split(' ').map {|elem| elem[1..-2]}
  end
end
