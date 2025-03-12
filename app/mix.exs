defmodule ArchiDep.MixProject do
  use Mix.Project

  def project do
    [
      app: :archidep,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: compilation_paths_for(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: project_dependencies(),
      preferred_cli_env: [
        "test.watch": :test
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {ArchiDep.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp compilation_paths_for(:test), do: ["lib", "test/support"]
  defp compilation_paths_for(_), do: ["lib"]

  defp project_dependencies do
    [
      {:bandit, "~> 1.5"},
      {:dns_cluster, "~> 0.1.1"},
      {:ecto_sql, "~> 3.10"},
      {:finch, "~> 0.13"},
      {:heroicons, "~> 0.5.6"},
      {:jason, "~> 1.2"},
      {:phoenix, "~> 1.7.19"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "~> 1.0.0"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:plug_static_index_html, "~> 1.0"},
      {:postgrex, ">= 0.0.0"},
      {:swoosh, "~> 1.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:ueberauth, "~> 0.10.8"},
      {:ueberauth_oidcc, "~> 0.4.1"},
      # Development
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      # Test
      {:floki, ">= 0.30.0", only: :test},
      {:mix_test_watch, "~> 1.0", only: :test, runtime: false}
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
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["esbuild.install --if-missing"],
      "assets.build": ["esbuild archidep"],
      "assets.deploy": [
        "esbuild archidep --minify",
        "phx.digest"
      ]
    ]
  end
end
