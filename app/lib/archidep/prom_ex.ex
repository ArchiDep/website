defmodule ArchiDep.PromEx do
  @moduledoc """
  Prometheus monitoring and metrics for the application.
  """

  use PromEx, otp_app: :archidep

  alias ArchiDep.Monitoring.Metrics
  alias PromEx.Plugins

  @impl PromEx
  def plugins do
    [
      Metrics,
      Plugins.Application,
      Plugins.Beam,
      Plugins.Ecto,
      {Plugins.Phoenix, router: ArchiDepWeb.Router, endpoint: ArchiDepWeb.Endpoint},
      Plugins.PhoenixLiveView
    ]
  end

  @spec seed_event_metrics() :: :ok
  def seed_event_metrics, do: Metrics.seed_event_metrics()
end
