defmodule Gg2048Web.Endpoint do
  use Phoenix.Endpoint, otp_app: :gg2048_web

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_gg2048_web_key",
    signing_salt: "K0RWhLvR"
  ]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  def sess_user_id(conn, _opts) do
    conn = Plug.Conn.fetch_session(conn)
    conn =
      case Plug.Conn.get_session(conn, :user_id) do
        nil ->
          user_id = Ecto.UUID.generate()
          Plug.Conn.put_session(conn, :user_id, user_id)
        _ ->
          conn
      end

#    IO.puts """
#      conn: #{inspect(conn.cookies)}
#      Verb: #{inspect(conn.method)}
#      Host: #{inspect(conn.host)}
#      Headers: #{inspect(conn.req_headers)}
#      Opts: #{opts}
#    """

    conn
  end

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :gg2048_web,
    gzip: false,
    only: ~w(assets fonts images favicon.ico robots.txt)

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug :sess_user_id
  plug Gg2048Web.Router
end
