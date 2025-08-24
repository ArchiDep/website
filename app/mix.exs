defmodule ArchiDep.MixProject do
  use Mix.Project

  def project do
    [
      app: :archidep,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: compilation_paths_for(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: project_dependencies(),
      dialyzer: [
        # Remove :no_opaque warnings to avoid issues with Dialyzer in OTP 28.
        # This should no longer be necessary once Elixir 1.19 is released. (Make
        # sure to also remove it from ".vscode/settings.json).
        flags: [:no_opaque],
        plt_add_apps: [:ex_unit, :mix]
      ],
      preferred_cli_env: [
        check: :test,
        coveralls: :test,
        "coveralls.html": :test,
        dialyzer: :test,
        test: :test,
        "test.watch": :test
      ],
      releases: [
        archidep: [
          include_executables_for: [:unix],
          applications: [runtime_tools: :permanent],
          validate_compile_env: false
        ]
      ],
      test_coverage: [tool: ExCoveralls]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {ArchiDep.Application, []},
      extra_applications: [:logger, :observer, :runtime_tools, :ssh, :wx],
      start_phases: [seed_prom_ex_telemetry: []]
    ]
  end

  defp compilation_paths_for(:test), do: ["lib", "test/support"]
  defp compilation_paths_for(_), do: ["lib"]

  defp project_dependencies do
    [
      {:bandit, "~> 1.5"},
      {:csv, "~> 3.2"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:dns_cluster, "~> 0.2.0"},
      {:ecto_network, "~> 1.5.0"},
      {:ecto_sql, "~> 3.10"},
      {:ex_cldr_messages, "~> 1.0"},
      {:ex_cmd, "~> 0.15.0"},
      {:finch, "~> 0.13"},
      {:flashy, "~> 0.3.1"},
      {:gen_stage, "~> 1.2"},
      {:gettext, "~> 0.26.2"},
      {:hackney, "~> 1.25.0"},
      {:heroicons, "~> 0.5.6"},
      {:jason, "~> 1.2"},
      {:phoenix, "~> 1.7.19"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "~> 1.0.0"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:phoenix_pubsub, "~> 2.1"},
      {:plug_cowboy, "2.7.4"},
      {:plug_static_index_html, "~> 1.0"},
      {:postgrex, ">= 0.0.0"},
      {:prom_ex, "~> 1.11.0"},
      {:req, "~> 0.5.15"},
      {:sentry, "~> 11.0.3"},
      {:sshex, "~> 2.2"},
      {:swoosh, "~> 1.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      # Use the latest version of ua_inspector from the master branch because of
      # a compilation issue with OTP 28 that has not yet been released. Switch
      # back to the published version once 3.11 is out. See
      # https://github.com/elixir-inspector/ua_inspector/blob/master/CHANGELOG.md.
      # {:ua_inspector, "~> 3.0"},
      {:ua_inspector,
       git: "https://github.com/elixir-inspector/ua_inspector.git", branch: "master"},
      {:ueberauth, "~> 0.10.8"},
      {:ueberauth_oidcc, "~> 0.4.1"},
      # Development & test dependencies
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:credo_contrib, "~> 0.2.0", only: [:dev, :test], runtime: false},
      {:credo_naming, "~> 2.1", only: [:dev, :test], runtime: false},
      {:ex_machina, "~> 2.8.0", only: :test},
      {:excoveralls, "~> 0.18.1", only: :test},
      {:faker, "~> 0.18.0", only: :test},
      {:floki, "~> 0.38.0", only: :test},
      {:hammox, "~> 0.7.1", only: :test},
      {:mix_test_watch, "~> 1.0", only: :test, runtime: false},
      {:nicene, "~> 0.7.0", only: [:dev, :test], runtime: false},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:sobelow, "~> 0.8", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "assets.deploy": ["phx.digest"],
      check: [
        "coveralls.html --raise",
        "format --check-formatted",
        "dialyzer",
        "deps.unlock --check-unused"
      ],
      "check.security": [
        "sobelow --exit --ignore-files config/local.exs,config/local.sample.exs --skip"
      ],
      "docker.dev": ["ecto.migrate", "phx.server"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      setup: [
        "deps.get",
        "ecto.setup",
        "ua_inspector.download --force",
        "assets.setup",
        "assets.build"
      ],
      start: ["phx.server"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
