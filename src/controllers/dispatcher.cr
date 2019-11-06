require "../models/session"

class Dispatcher < Application
  base "/api/server"
  before_action :authenticate

  ws "/tcp_dispatch" do |ws|
    port = params["port"].to_u32.to_i
    ip_addresses = params["accept"].split(",")

    logger.tag "new TCP server requested", server_protocol: "tcp", server_port: port, accepting: ip_addresses

    session = Session.new(true, port, ws, ip_addresses, logger)
    Servers.open_tcp_server(port, session.configure_websocket)
    ws.on_close { Servers.close_tcp_server(port, session) }
  end

  ws "/udp_dispatch" do |ws|
    port = params["port"].to_u32.to_i
    ip_addresses = params["accept"].split(",")

    logger.tag "new UDP server requested", server_protocol: "udp", server_port: port, accepting: ip_addresses

    session = Session.new(false, port, ws, ip_addresses, logger)
    Listeners.open_udp_server(port, session.configure_websocket)
    ws.on_close { Listeners.close_udp_server(port, session) }
  end

  # Returns details about open servers and number of engine drivers listening.
  # Also returns details about the number of TCP client connections to the servers
  def index
    udp_listeners = Listeners.stats
    tcp_listeners, tcp_clients = Servers.stats

    render json: {
      udp_listeners: udp_listeners,
      tcp_listeners: tcp_listeners,
      tcp_clients: tcp_clients
    }
  end

  AUTH_SECRET = ENV["SERVER_SECRET"]? || "testing"

  def authenticate
    head :unauthorized unless acquire_token == AUTH_SECRET
  end

  def acquire_token : String?
    if (token = request.headers["Authorization"]?)
      token.lchop("Bearer ").rstrip
    elsif (token = params["bearer_token"]?)
      token.strip
    end
  end
end