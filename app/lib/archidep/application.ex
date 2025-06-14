defmodule ArchiDep.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @spec public_key() :: String.t()
  def public_key, do: Application.fetch_env!(:archidep, :public_key)

  @impl true
  def start(_type, _args) do
    children = [
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
  @impl true
  def config_change(changed, _new, removed) do
    ArchiDepWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
