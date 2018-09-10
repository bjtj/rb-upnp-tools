require 'webrick'


class UPnPServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(req, res)
    server = @options[0]
    server.on_request(req, res)
  end

  def do_POST(req, res)
    server = @options[0]
    server.on_request(req, res)
  end
  
  def do_NOTIFY(req, res)
    server = @options[0]
    server.on_request(req, res)
  end

  def do_SUBSCRIBE(req, res)
    server = @options[0]
    server.on_request(req, res)
  end

  def do_UNSUBSCRIBE(req, res)
    server = @options[0]
    server.on_request(req, res)
  end
end


class HttpServer

  def initialize(host = '0.0.0.0', port = 0)
    @http_server = WEBrick::HTTPServer.new :BindAddress => host, :Port => port
    @http_server.mount '/', UPnPServlet, self
  end

  attr_accessor :handler

  def get_port
    @http_server.config[:Port]
  end

  def on_request(req, res)
    if @handler != nil
      @handler.call(req, res)
    end
  end

  def start
    @http_server.start
  end

  def stop
    @http_server.shutdown
  end
end
