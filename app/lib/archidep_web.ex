defmodule ArchiDepWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use ArchiDepWeb, :controller
      use ArchiDepWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths, do: ~w(assets favicon.ico course fonts images index.html robots.txt)

  @spec router :: Macro.t()
  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  @spec channel :: Macro.t()
  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  @spec component :: Macro.t()
  def component do
    quote do
      use Phoenix.Component

      unquote(html_helpers())
    end
  end

  @spec controller :: Macro.t()
  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html],
        layouts: [html: ArchiDepWeb.Layouts]

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  @spec live_view :: Macro.t()
  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {ArchiDepWeb.Layouts, :app}

      import ArchiDep.Helpers.PipeHelpers
      alias Ecto.Changeset
      alias Phoenix.LiveView

      on_mount(ArchiDepWeb.LiveAuth)

      unquote(html_helpers())
    end
  end

  @spec live_component :: Macro.t()
  def live_component do
    quote do
      use Phoenix.LiveComponent

      import ArchiDep.Helpers.PipeHelpers
      alias Phoenix.LiveComponent
      alias Phoenix.LiveView.JS

      @type js :: %JS{}

      unquote(html_helpers())
    end
  end

  @spec html :: Macro.t()
  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components
      import ArchiDepWeb.CoreComponents
      import ArchiDepWeb.Helpers.AuthHelpers
      import ArchiDepWeb.Helpers.DateFormatHelpers

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: ArchiDepWeb.Endpoint,
        router: ArchiDepWeb.Router,
        statics: ArchiDepWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
