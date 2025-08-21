defmodule ArchiDepWeb.Endpoint do
  use Sentry.PlugCapture
  use Phoenix.Endpoint, otp_app: :archidep

  # The session will be stored in the cookie and signed, this means its contents
  # can be read but not tampered with. Set :encryption_salt if you would also
  # like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_archidep_key",
    signing_salt: {__MODULE__, :session_signing_salt, []}
  ]

  @serve_static :archidep |> Application.compile_env!(__MODULE__) |> Keyword.fetch!(:serve_static)

  # Phoenix LiveView
  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [:peer_data, :user_agent, session: @session_options]],
    longpoll: [connect_info: [:peer_data, :user_agent, session: @session_options]]

  # Phoenix Channels
  socket "/socket", ArchiDepWeb.Channels.UserSocket,
    websocket: [connect_info: [:peer_data, :user_agent, session: @session_options]],
    longpoll: [connect_info: [:peer_data, :user_agent, session: @session_options]],
    error_handler: {ArchiDepWeb.Channels.UserSocket, :handle_error, []}

  if @serve_static do
    # Serve course material in the "priv/static" directory.
    plug Plug.Static.IndexHtml

    # Serve at "/" the static files from "priv/static" directory.
    #
    # You should set gzip to true if you are running phx.digest
    # when deploying your static files in production.
    plug Plug.Static,
      at: "/",
      from: :archidep,
      gzip: false,
      only: ArchiDepWeb.static_paths()
  end

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :archidep
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint], log: {__MODULE__, :log_level, []}

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Sentry.PlugContext
  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug ArchiDepWeb.Router

  @doc """
  Returns the configured salt used to sign session cookies.
  """
  @spec session_signing_salt() :: String.t()
  def session_signing_salt,
    do: :archidep |> Application.fetch_env!(__MODULE__) |> Keyword.fetch!(:session_signing_salt)

  # Disable logging for health check route
  @spec log_level(Plug.Conn.t()) :: false | :info
  def log_level(%{path_info: ["api", "health"]}), do: false
  def log_level(_req), do: :info
end
