import Config

# Enable dev routes for dashboard and mailbox
config :archidep,
  dev_routes: true,
  monitoring: [
    # Refresh monitoring metrics every 10 minutes to avoid polluting the logs
    metrics_poll_rate: 10 * 60 * 1000
  ],
  servers: [
    api_base_url: "http://localhost:42000/api",
    connection_timeout: 5_000
  ]

# Configure your database
config :archidep, ArchiDep.Repo,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we can use it
# to bundle .js and .css sources.
# Binding to loopback ipv4 address prevents access from other machines.
config :archidep, ArchiDepWeb.Endpoint,
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  serve_static: true

# Watch static and templates for browser reloading.
config :archidep, ArchiDepWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/gettext/.*(po)$",
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/archidep_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable Prometheus metrics server
config :archidep, ArchiDep.PromEx, disabled: false, metrics_server: [port: 42003]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"
config :logger, level: :debug

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Include HEEx debug annotations as HTML comments in rendered markup
  debug_heex_annotations: true,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false
