defmodule ArchiDep.Application do
  @moduledoc false

  use Application

  alias ArchiDep.CourseSite.Archives
  alias ArchiDep.CourseSite.Archives.Completeness

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

    # Rendering the course material site comes after the repository and PubSub,
    # which a build reads how far the course has got through, and before the
    # endpoint, which must not answer a request until this deployment has
    # rendered the site it exists to serve. The watcher only reports to the
    # rebuilder, so it comes after it.
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
        ArchiDep.Servers.Supervisor
      ] ++
        course_site_rebuilder() ++
        course_site_watcher() ++
        [
          # Start to serve requests, typically the last entry
          ArchiDepWeb.Endpoint
        ]

    # See https://hexdocs.pm/elixir/Supervisor.html for other strategies and
    # supported options.
    Supervisor.start_link(children, name: ArchiDep.Supervisor, strategy: :one_for_one)
  end

  # Rendering the course material site is asked for explicitly, by the `build`
  # and `watch` keys of the `course_site` configuration, and two environments
  # ask: production renders it at boot and again whenever how far the course has
  # got changes, development renders it as the material is edited. Every other
  # environment does not render it at all. A deployment that is missing the two
  # directories it takes while asking for it is misconfigured rather than opting
  # out, so this fetches them and lets the application refuse to boot.
  defp course_site_rebuilder do
    config = Application.get_env(:archidep, :course_site, [])
    build = Keyword.get(config, :build, false)
    watch = Keyword.get(config, :watch, false)

    if build or watch do
      build_dir = Keyword.fetch!(config, :build_dir)

      # A deployment that serves the site refuses to boot without it; one that
      # is being edited reports instead, so that a broken document is not a
      # broken development server. Only a deployment that watches has a browser
      # to tell, and its assets alone are rewritten under it by the asset
      # watchers while the site is being served — so its builds neither digest
      # those names nor take a copy of them: the application serves them where
      # they are.
      opts = [
        course_dir: Keyword.fetch!(config, :course_dir),
        build_dir: build_dir,
        boot: if(build, do: :required, else: :deferred),
        reload_marker: if(watch, do: build_dir <> ".reload"),
        digested: not watch,
        carry_assets: not watch
      ]

      [{ArchiDep.CourseSiteRebuilder, opts}]
    else
      []
    end
  end

  # Watching the course material is asked for by the `watch` key of the
  # `course_site` configuration, and only development asks.
  defp course_site_watcher do
    config = Application.get_env(:archidep, :course_site, [])

    if Keyword.get(config, :watch, false) do
      [{ArchiDep.CourseSiteWatcher, course_dir: Keyword.fetch!(config, :course_dir)}]
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
