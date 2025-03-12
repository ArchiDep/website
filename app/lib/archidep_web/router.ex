defmodule ArchiDepWeb.Router do
  use ArchiDepWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ArchiDepWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug Plug.SSL, rewrite_on: [:x_forwarded_proto]
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/app", ArchiDepWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/auth", ArchiDepWeb do
    pipe_through :browser

    get "/switch-edu-id", AuthController, :request
    get "/switch-edu-id/callback", AuthController, :callback
  end

  # Other scopes may use custom stacks.
  # scope "/api", ArchiDepWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:archidep, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ArchiDepWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
