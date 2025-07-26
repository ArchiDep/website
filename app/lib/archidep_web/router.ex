defmodule ArchiDepWeb.Router do
  use ArchiDepWeb, :router

  import ArchiDepWeb.Auth
  alias Plug.Conn

  pipeline :api do
    plug :accepts, ["json"]

    plug Plug.SSL,
      exclude: ["localhost", "www.example.com"],
      rewrite_on: [:x_forwarded_proto]
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ArchiDepWeb.Components.Layouts, :root}
    plug :protect_from_forgery

    plug(:put_secure_browser_headers, %{
      "content-security-policy" =>
        "default-src 'self'; font-src 'self' fonts.gstatic.com; img-src 'self' data:; style-src-elem 'self' fonts.googleapis.com;"
    })

    plug Plug.SSL,
      exclude: ["localhost", "www.example.com"],
      rewrite_on: [:x_forwarded_proto]
  end

  pipeline :dev do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  scope "/", ArchiDepWeb do
    pipe_through :browser

    scope "/", Auth do
      pipe_through [:fetch_authentication, :set_current_path, :redirect_if_user_is_authenticated]
      get "/login", AuthController, :login
    end

    scope "/", Auth do
      pipe_through :fetch_authentication
      get "/auth/csrf", AuthController, :generate_csrf_token
      get "/auth/socket", AuthController, :generate_socket_token
      post "/auth/impersonate", AuthController, :impersonate
      post "/auth/stop-impersonating", AuthController, :stop_impersonating
      delete "/logout", AuthController, :logout
    end

    scope "/auth", Auth do
      pipe_through [:fetch_authentication, :redirect_if_user_is_authenticated]
      get "/switch-edu-id", AuthController, :request
      get "/switch-edu-id/configure", AuthController, :configure_switch_edu_id_login
      get "/switch-edu-id/callback", AuthController, :callback
    end

    live_session :default, on_mount: [Flashy.Hook, ArchiDepWeb.LiveHooks] do
      scope "/" do
        pipe_through :fetch_authentication
        live "/profile", Profile.ProfileLive
      end

      scope "/app" do
        pipe_through :fetch_authentication
        live "/", Dashboard.DashboardLive
      end

      scope "/admin" do
        pipe_through :fetch_authentication
        live "/", Admin.AdminLive
        live "/classes", Admin.Classes.ClassesLive
        live "/classes/:id", Admin.Classes.ClassLive
        live "/classes/:class_id/students/:id", Admin.Classes.StudentLive
        live "/events", Admin.Events.EventLogLive
      end

      scope "/servers" do
        pipe_through :fetch_authentication
        live "/", Servers.ServersLive
        live "/:id", Servers.ServerLive
      end
    end
  end

  scope "/api", ArchiDepWeb do
    pipe_through :api

    scope "/callbacks/servers", Servers do
      post "/:server_id/up", ServerCallbacksController, :server_up
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:archidep, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :dev

      live_dashboard "/dashboard", metrics: ArchiDepWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  @spec set_current_path(Conn.t(), keyword) :: Conn.t()
  def set_current_path(conn, _opts), do: assign(conn, :current_path, conn.request_path)
end
