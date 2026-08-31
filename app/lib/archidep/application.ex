defmodule ArchiDep.Application do
  @moduledoc false

  use Application

  alias ArchiDep.CourseSite.Archives
  alias ArchiDep.CourseSite.Archives.Completeness
  alias ArchiDep.CourseSitePublisher

  @impl Application
  def start(_type, _args) do
    :logger.add_handler(:archidep_sentry_handler, Sentry.LoggerHandler, %{
      config: %{metadata: [:file, :line]}
    })

    ArchiDep.Git.start()
    ArchiDep.Config.start!()
    ArchiDepWeb.Config.start!()

    # Unlike the two above, this reports rather than raises. The application
    # serves none of the archived editions and refusing to boot over one would
    # trade the dashboard, the admin console and the servers pipeline for a dead
    # link.
    Completeness.log(Archives.completeness())

    # And unlike the line above, this refuses to boot. The build is what a
    # separate static server is pointed at, and it is already holding the
    # previous one: an application that carried on would leave the site it
    # serves and the application beside it disagreeing about which edition this
    # deployment is.
    build_course_site()

    children =
      [
        ArchiDepWeb.Telemetry,
        # PromEx should be started before most other stuff as PromEx will capture
        # init events from libraries like Ecto and Phoenix. If it is started after
        # those other supervision trees those events and metrics will be missed.
        ArchiDep.PromEx,
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
      ] ++ course_site_watcher()

    # See https://hexdocs.pm/elixir/Supervisor.html for other strategies and
    # supported options.
    Supervisor.start_link(children, name: ArchiDep.Supervisor, strategy: :one_for_one)
  end

  # Rendering the course material site is asked for explicitly, by the `build`
  # key of the `course_site` configuration, and only production asks:
  # development has the watcher below render it instead, and every other
  # environment does not render it.
  defp build_course_site do
    config = Application.get_env(:archidep, :course_site, [])

    if Keyword.get(config, :build, false) do
      CourseSitePublisher.publish_configured!()
    else
      :ok
    end
  end

  # Watching the course material and rebuilding the site as it changes is asked
  # for explicitly, by the `watch` key of the `course_site` configuration, and
  # only development asks. A deployment that is missing the two directories it
  # takes while asking for it is misconfigured rather than opting out, so this
  # fetches them and lets the application refuse to boot.
  defp course_site_watcher do
    config = Application.get_env(:archidep, :course_site, [])

    if Keyword.get(config, :watch, false) do
      [
        {ArchiDep.CourseSiteWatcher,
         course_dir: Keyword.fetch!(config, :course_dir),
         build_dir: Keyword.fetch!(config, :build_dir)}
      ]
    else
      []
    end
  end

  # Tell Phoenix to update the endpoint configuration whenever the application
  # is updated.
  @impl Application
  def config_change(changed, _new, removed) do
    ArchiDepWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  @impl Application
  def start_phase(:seed_prom_ex_telemetry, :normal, _phase_args) do
    ArchiDep.PromEx.seed_event_metrics()
    :ok
  end

  @spec version() :: String.t()
  def version, do: Application.spec(:archidep, :vsn)
end
