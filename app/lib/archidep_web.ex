defmodule ArchiDepWeb do
  @moduledoc """
  Phoenix live view web interface for the ArchiDep application.
  """

  @spec static_paths :: list(String.t())
  def static_paths,
    do:
      ~w(assets cheatsheets course favicon.ico favicons feed.xml fonts images index.html lunr.json robots.txt search.json)

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

      alias Phoenix.LiveView.Rendered

      unquote(html_helpers())
    end
  end

  @spec controller :: Macro.t()
  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html],
        layouts: [html: ArchiDepWeb.Components.Layouts]

      use Gettext, backend: ArchiDepWeb.Gettext

      import Plug.Conn

      # Flash helpers
      import Flashy

      alias ArchiDepWeb.Components.Notifications.Message
      alias Plug.Conn

      unquote(verified_routes())
    end
  end

  @spec live_view :: Macro.t()
  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {ArchiDepWeb.Components.Layouts, :app}

      import ArchiDep.Helpers.PipeHelpers
      import ArchiDepWeb.Helpers.AuthHelpers
      alias ArchiDep.Authentication
      alias ArchiDepWeb.Components.Notifications.Message
      alias Ecto.Changeset
      alias Phoenix.LiveView
      alias Phoenix.LiveView.JS
      alias Phoenix.LiveView.Socket

      on_mount(ArchiDepWeb.LiveAuth)

      unquote(html_helpers())
    end
  end

  @spec live_component :: Macro.t()
  def live_component do
    quote do
      use Phoenix.LiveComponent

      import ArchiDep.Helpers.PipeHelpers
      alias ArchiDepWeb.Components.Notifications.Message
      alias Ecto.Changeset
      alias Phoenix.LiveComponent
      alias Phoenix.LiveView.JS
      alias Phoenix.LiveView.Rendered
      alias Phoenix.LiveView.Socket

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

      alias Phoenix.LiveView.Rendered

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      use Gettext, backend: ArchiDepWeb.Gettext

      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components
      import ArchiDepWeb.Components.CoreComponents
      import ArchiDepWeb.Helpers.AuthHelpers
      import ArchiDepWeb.Helpers.DateFormatHelpers
      # Flash helpers
      import Flashy

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  @spec verified_routes :: Macro.t()
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
  @spec __using__(atom) :: Macro.t()
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
