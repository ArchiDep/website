# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :archidep,
  namespace: ArchiDep,
  ecto_repos: [ArchiDep.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true],
  auth: [
    root_users: [switch_edu_id: []]
  ],
  monitoring: [
    # Refresh monitoring metrics every minute
    metrics_poll_rate: 60 * 1000
  ],
  # Where the course material site the dashboard links into is published, and
  # which edition of it this deployment holds. There is no ArchiDep.CourseSite
  # module to key this on: the subsystem is pure and has no configuration of its
  # own, and this is what the application makes of it — when it emits a URL, and
  # when it builds the site itself.
  #
  # Every build is an edition's, so `version` is set here rather than left
  # empty: the deployment holds the edition `years` names, and the two say the
  # same thing in the two forms the site needs — the URL carries the starting
  # year alone, the chrome writes both.
  #
  # `watch` and `serve` are off here and switched on only by dev.exs. They are
  # asked explicitly rather than inferred from `course_dir` and `build_dir`
  # being set, because production will eventually set both: it rebuilds the site
  # too, but on an edit in the admin console rather than on a file changing, and
  # a separate static server puts the result in front of users. Inferring either
  # from a directory would turn both on exactly where neither is wanted.
  course_site: [
    mode: :live,
    base_path: "",
    version: "2025",
    years: "2025-2026",
    years_short: "25-26",
    # Which build of the site this deployment is serving. It names the search
    # index, so the application and whatever built the site have to agree on it
    # or the dashboard's own search dialog asks for a file nobody wrote — which
    # is why it is configuration rather than something either of them works out.
    # A literal is the default because a checkout that cannot say what its
    # revision is would otherwise take every page of the dashboard down with it.
    build_id: "build",
    # Where the generated PDFs of a build are published, as a base of
    # ArchiDep.CourseSite.Urls.PdfManifest. Nothing publishes them yet, and a
    # build that cannot say where they are offers no download link.
    pdf_base: nil,
    watch: false,
    serve: false
  ],
  servers: [
    connection_timeout: 30_000,
    ssh_private_key_file: Path.expand("../priv/ssh/id_ed25519", __DIR__),
    track_on_boot: true
  ]

# Context configuration
config :archidep, ArchiDep.Accounts, ArchiDep.Accounts.Context
config :archidep, ArchiDep.Course, ArchiDep.Course.Context
config :archidep, ArchiDep.Events, ArchiDep.Events.Context
config :archidep, ArchiDep.Servers, ArchiDep.Servers.Context

config :archidep, ArchiDep.Clock, ArchiDep.Clock.SystemClock
config :archidep, ArchiDep.Cmd, ExCmd
config :archidep, ArchiDep.Http, Req
config :archidep, ArchiDep.PubSub.Scope, ArchiDep.PubSub.Scope.GlobalScope
config :archidep, ArchiDep.Servers.Ansible, ArchiDep.Servers.Ansible.Context
config :archidep, ArchiDep.Servers.Ansible.RunnerClient, ArchiDep.Servers.Ansible.Runner
config :archidep, ArchiDep.Servers.SSH.Client, ArchiDep.Servers.SSH.Client.SystemClient

config :archidep,
       ArchiDep.Servers.ServerTracking.ServerManagerClient,
       ArchiDep.Servers.ServerTracking.ServerManager

config :archidep,
       ArchiDep.Servers.ServerTracking.ServersOrchestratorClient,
       ArchiDep.Servers.ServerTracking.ServersOrchestrator

config :archidep,
       ArchiDep.Servers.ServerTracking.ServerTrackerClient,
       ArchiDep.Servers.ServerTracking.ServerTracker

config :archidep,
       ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueueClient,
       ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueue

config :archidep, ArchiDep.TrackerClient, ArchiDep.Tracker

config :archidep, ArchiDep.Repo, pool_size: 10, socket_options: []

# Endpoint configuration
config :archidep, ArchiDepWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  # Bind to the loopback IPv4 address to prevent access from other machines by
  # default.
  http: [ip: {127, 0, 0, 1}, port: 42000],
  render_errors: [
    formats: [html: ArchiDepWeb.Errors.ErrorHTML],
    layout: false
  ],
  pubsub_server: ArchiDep.PubSub,
  serve_static: false,
  server: true,
  uploads_directory: Path.expand("../priv/uploads", __DIR__),
  url: [host: "localhost", port: 42000]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :archidep, ArchiDep.Mailer, adapter: Swoosh.Adapters.Local

config :archidep, ArchiDep.PromEx,
  disabled: true,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  grafana: :disabled,
  metrics_server: :disabled

config :flashy,
  disconnected_module: ArchiDepWeb.Components.Notifications.Disconnected

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :logger, level: :info

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :sentry,
  enable_logs: true,
  before_send: {ArchiDep.Sentry, :before_send},
  environment_name: Mix.env(),
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()],
  telemetry_processor_categories: [:log, :error, :check_in, :transaction]

config :ueberauth, Ueberauth,
  providers: [
    switch_edu_id: {
      Ueberauth.Strategy.Oidcc,
      issuer: :switch_edu_id,
      scopes: ["openid", "profile", "email", "https://login.eduid.ch/authz/User.Read"],
      userinfo: true,
      request_path: "/auth/switch-edu-id",
      callback_path: "/auth/switch-edu-id/callback"
    }
  ]

config :ueberauth_oidcc, :issuers, [
  %{name: :switch_edu_id, issuer: "https://login.test.eduid.ch/"}
]

config :ueberauth_oidcc, :providers, switch_edu_id: []

config_dir = Path.dirname(__ENV__.file)

# Import environment specific config (`dev/prod/test.exs`). This must remain at
# the bottom of this file so it overrides the configuration defined above.
environment_specific_config_file = Path.join(config_dir, "#{Mix.env()}.exs")
import_config environment_specific_config_file

# Import configuration specific to the local development environment (if
# available).
local_config_file = Path.join(config_dir, "local.exs")
if File.exists?(local_config_file), do: import_config(local_config_file)
