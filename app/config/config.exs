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
  servers: [
    connection_timeout: 30_000,
    ssh_private_key_file: Path.expand("../priv/ssh/id_ed25519", __DIR__),
    track_on_boot: true
  ]

# Configure contexts.
config :archidep, ArchiDep.Accounts, ArchiDep.Accounts.Context
config :archidep, ArchiDep.Course, ArchiDep.Course.Context
config :archidep, ArchiDep.Events, ArchiDep.Events.Context
config :archidep, ArchiDep.Servers, ArchiDep.Servers.Context

config :archidep, ArchiDep.Repo, pool_size: 10, socket_options: []

# Configures the endpoint
config :archidep, ArchiDepWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  # Bind to the loopback IPv4 address to prevent access from other machines by
  # default.
  http: [ip: {127, 0, 0, 1}, port: 42000],
  render_errors: [
    formats: [html: ArchiDepWeb.Controllers.ErrorHTML],
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

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  archidep: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets/app --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :flashy,
  disconnected_module: ArchiDepWeb.Components.Notifications.Disconnected

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :logger, level: :info

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :ueberauth, Ueberauth,
  providers: [
    switch_edu_id: {
      Ueberauth.Strategy.Oidcc,
      issuer: :switch_edu_id,
      scopes: ["openid", "profile", "email", "https://login.eduid.ch/authz/User.Read"],
      userinfo: true,
      request_path: "/auth/switch-edu-id",
      callback_path: "/auth/switch-edu-id/callback"
      # uid_field: "email"
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
