defmodule ArchiDep.PromEx do
  @moduledoc """
  Prometheus monitoring and metrics for the application.
  """

  use PromEx, otp_app: :archidep

  alias PromEx.Plugins

  @impl PromEx
  def plugins do
    [
      Plugins.Application,
      Plugins.Beam,
      Plugins.Ecto,
      {Plugins.Phoenix, router: ArchiDepWeb.Router, endpoint: ArchiDepWeb.Endpoint},
      Plugins.PhoenixLiveView

      # Add your own PromEx metrics plugins
      # Archidep.Users.PromExPlugin
    ]
  end
end
