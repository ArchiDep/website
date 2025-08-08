defmodule ArchiDep.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    ArchiDep.Git.start()
    ArchiDep.Config.start!()
    ArchiDepWeb.Config.start!()

    children = [
      # PromEx should be started before anything else as PromEx will caputre
      # init events from libraries like Ecto and Phoenix. If it is started after
      # those other supervision trees those events and metrics will be missed.
      ArchiDep.PromEx,
      ArchiDepWeb.Telemetry,
      ArchiDep.Repo,
      {DNSCluster, query: Application.get_env(:archidep, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ArchiDep.PubSub},
      {ArchiDep.Tracker, pubsub_server: ArchiDep.PubSub},
      # Start the Finch HTTP client for sending emails.
      {Finch, name: ArchiDep.Finch},
      # Start supervisors for the application's contexts.
      ArchiDep.Servers.Supervisor,
      # Start to serve requests, typically the last entry
      ArchiDepWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html for other strategies and
    # supported options.
    Supervisor.start_link(children, name: ArchiDep.Supervisor, strategy: :one_for_one)
  end

  # Tell Phoenix to update the endpoint configuration whenever the application
  # is updated.
  @impl Application
  def config_change(changed, _new, removed) do
    ArchiDepWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  @spec version() :: String.t()
  def version, do: Application.spec(:archidep, :vsn)
end
