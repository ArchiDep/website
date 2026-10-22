defmodule ArchiDep.MixProject do
  use Mix.Project

  def project do
    [
      app: :archidep,
      version: "0.1.0",
      elixir: "~> 1.20",
      elixirc_paths: compilation_paths_for(Mix.env()),
      start_permanent: Mix.env() == :prod,
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      aliases: aliases(),
      deps: project_dependencies(),
      dialyzer: [
        # Suppress :no_opaque warnings from manipulating opaque structs
        # (Ecto.Changeset, DateTime) under OTP 28. Still required on Elixir
        # 1.20.4 / OTP 28: dropping this flag yields 50 call_without_opaque
        # and contract_with_opaque warnings. Keep the matching
        # ".vscode/settings.json" setting
        # ("elixirLS.dialyzerWarnOpts") in sync.
        flags: [:no_opaque],
        plt_add_apps: [:ex_unit, :mix]
      ],
      listeners: [Phoenix.CodeReloader],
      releases: [
        archidep: [
          include_executables_for: [:unix],
          applications: [runtime_tools: :permanent],
          validate_compile_env: false
        ]
      ],
      test_coverage: [tool: ExCoveralls, export: "cov"]
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

  def cli do
    [
      preferred_envs: [
        check: :test,
        coveralls: :test,
        "coveralls.html": :test,
        dialyzer: :test,
        test: :test,
        "test.watch": :test
      ]
    ]
  end

  defp compilation_paths_for(:test), do: ["lib", "test/support"]
  defp compilation_paths_for(_), do: ["lib"]

  defp project_dependencies do
    [
      {:bandit, "~> 1.5"},
      {:csv, "~> 3.2"},
      {:dns_cluster, "~> 0.3.1"},
      {:ecto_network, "~> 1.6"},
      {:ecto_sql, "~> 3.10"},
      {:ex_cldr_messages, "~> 2.0"},
      {:ex_cmd, "~> 0.18.0"},
      # Named here rather than inherited: several dependencies already pull it
      # in, but every one of them is itself limited to :dev or :test, so
      # ArchiDep.CourseSiteWatcher referring to it from lib/ would warn while
      # compiling and be missing in :prod.
      {:file_system, "~> 1.0"},
      {:finch, "~> 0.13"},
      {:flashy, "~> 0.4.3"},
      {:gen_stage, "~> 1.2"},
      {:gettext, "~> 1.0"},
      {:heroicons, "~> 0.5.6"},
      {:jason, "~> 1.2"},
      {:lazy_html, ">= 0.0.0"},
      {:lumis, "~> 0.10.3"},
      # The languages the course material's code blocks are written in, and
      # those they can embed. Lumis highlights a language no package supplies as
      # plain text, without a warning.
      {:lumis_wasm_bash, "~> 0.26.5"},
      {:lumis_wasm_c, "~> 0.26.2"},
      {:lumis_wasm_comment, "~> 0.26.2"},
      {:lumis_wasm_css, "~> 0.26.3"},
      {:lumis_wasm_dockerfile, "~> 0.26.2"},
      {:lumis_wasm_html, "~> 0.26.3"},
      {:lumis_wasm_javascript, "~> 0.26.3"},
      {:lumis_wasm_markdown, "~> 0.26.3"},
      {:lumis_wasm_markdown_inline, "~> 0.26.2"},
      {:lumis_wasm_nginx, "~> 0.26.1"},
      {:lumis_wasm_php, "~> 0.26.7"},
      {:lumis_wasm_powershell, "~> 0.26.3"},
      {:lumis_wasm_sql, "~> 0.26.5"},
      {:lumis_wasm_yaml, "~> 0.26.2"},
      {:mdex, "~> 0.14.2"},
      {:phoenix, "~> 1.8.0"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "~> 1.1"},
      {:phoenix_live_dashboard, "~> 0.9.1"},
      {:phoenix_pubsub, "~> 2.1"},
      {:plug_cowboy, "~> 2.8"},
      {:plug_static_index_html, "~> 1.0"},
      {:postgrex, ">= 0.0.0"},
      {:prom_ex, "~> 1.12.0"},
      {:req, "~> 0.7.5"},
      {:sentry, "~> 14.0"},
      {:solid, "~> 1.3"},
      {:sshex, "~> 2.2"},
      {:swoosh, "~> 1.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:ua_inspector, "~> 3.11"},
      {:ueberauth, "~> 0.11.0"},
      {:ueberauth_oidcc, "~> 0.4.1"},
      {:yaml_elixir, "~> 2.11"},
      # Development & test dependencies
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:credo_contrib, "~> 0.2.0", only: [:dev, :test], runtime: false},
      {:credo_naming, "~> 2.1", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_machina, "~> 2.8.0", only: :test},
      {:excoveralls, "~> 0.18.1", only: :test},
      {:faker, "~> 0.19.0", only: :test},
      {:hammox, "~> 1.0.0", only: :test},
      {:mix_test_watch, "~> 1.0", only: :test, runtime: false},
      {:nicene, "~> 0.7.0", only: [:dev, :test], runtime: false},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:sobelow, "~> 0.8", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 1.2", only: [:dev, :test]},
      {:testcontainers, "~> 2.3", only: :test}
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
        "credo --strict",
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
        "archidep.ua_inspector.download",
        "assets.setup",
        "assets.build"
      ],
      start: ["phx.server"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
