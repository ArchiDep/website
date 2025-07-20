import Config

config :archidep,
  public_key:
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHbV+M6SR+flT3XhFhQv2DsyBs1+ORZU4qv9SLTqIFEs archidep",
  root_users: [switch_edu_id: ["root@archidep.ch"]],
  servers: [
    connection_timeout: 5_000,
    track_on_boot: false
  ]

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :archidep, ArchiDep.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Do not run a server when testing.
config :archidep, ArchiDepWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 42003],
  server: false

# Do not send emails when testing.
config :archidep, ArchiDep.Mailer, adapter: Swoosh.Adapters.Test

# Mock application contexts.
config :archidep, ArchiDep.Accounts, ArchiDep.Accounts.ContextMock
config :archidep, ArchiDep.Course, ArchiDep.Course.ContextMock
config :archidep, ArchiDep.Events, ArchiDep.Events.ContextMock
config :archidep, ArchiDep.Servers, ArchiDep.Servers.ContextMock

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Configure fake OpenID Connect provider for testing.
config :ueberauth_oidcc, :providers,
  switch_edu_id: [
    client_id: "id",
    client_secret: "secret"
  ]
