defmodule Digest.MixProject do
  use Mix.Project

  def project do
    [
      app: :archidep_digest,
      version: "0.0.0",
      elixir: "~> 1.18",
      start_permanent: false,
      deps: deps(),
      aliases: aliases()
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.2"},
      {:phoenix, "~> 1.7.19"}
    ]
  end

  defp aliases do
    [
      "assets.deploy": [
        "phx.digest priv/static/assets -o priv/static/assets"
      ]
    ]
  end
end
