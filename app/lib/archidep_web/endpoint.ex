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

  # Where the course material site is published, for a deployment that asked
  # this application to serve it. Only development does: production publishes a
  # build to a directory of the same kind but puts a separate static server in
  # front of it, the reverse proxy routing the course URLs there and the
  # dashboard's here. So this is keyed on `serve` being asked for rather than on
  # a build directory being configured, which production will do as well.
  @course_site :archidep
               |> Application.compile_env(:course_site, [])
               |> Keyword.take([:serve, :build_dir, :version])

  @course_site_dir if Keyword.get(@course_site, :serve, false),
                     do: Keyword.fetch!(@course_site, :build_dir)

  # The edition a served build holds, as a path. A build that carries its own
  # global assets answers for them itself; the one served here does not, being
  # rewritten by the asset watchers as it is served, so its edition prefix is
  # where "priv/static" has to answer as well.
  @course_site_edition if @course_site_dir && Keyword.get(@course_site, :version),
                         do: "/" <> Keyword.fetch!(@course_site, :version)

  # Phoenix LiveView
  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [:peer_data, :user_agent, session: @session_options]],
    longpoll: [connect_info: [:peer_data, :user_agent, session: @session_options]]

  # Phoenix Channels
  socket "/socket", ArchiDepWeb.Channels.UserSocket,
    websocket: [connect_info: [:peer_data, :user_agent, session: @session_options]],
    longpoll: [connect_info: [:peer_data, :user_agent, session: @session_options]],
    error_handler: {ArchiDepWeb.Channels.UserSocket, :handle_error, []}

  # The live reloader comes before anything that answers a request, because it
  # injects its script from a callback it has to register before the response is
  # sent. It is also why ArchiDepWeb.CourseSitePages exists at all.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
  end

  if @serve_static do
    # A request for a directory is a request for the page in it, for all three
    # of the plugs below.
    plug Plug.Static.IndexHtml
  end

  # Serve the course material site from the build. It comes first, so it wins
  # "/", "/course/…", "/cheatsheets/…", "/favicon.ico" and "/404.html", and it
  # has no whitelist: a build owns its output directory, so everything in there
  # is something it published. The assets alone: everything else an edition
  # answers for is the build's own, and serving "priv/static" whole here would
  # put a stale copy of it in front.
  if @course_site_edition do
    plug Plug.Static, at: @course_site_edition, from: :archidep, gzip: false, only: ~w(assets)
  end

  if @course_site_dir do
    plug ArchiDepWeb.CourseSitePages, from: @course_site_dir
    plug Plug.Static, at: "/", from: @course_site_dir, gzip: false
  end

  if @serve_static do
    # Serve at "/" the static files from "priv/static" directory, which is what
    # answers "/assets/**" and the search index behind the build.
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
  # :code_reloader configuration of your endpoint. It stays after the static
  # plugs, so that serving a file never recompiles the application.
  if code_reloading? do
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
