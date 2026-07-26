defmodule Digest.MixProject do
  use Mix.Project

  def project do
    [
      app: :archidep_digest,
      version: "0.0.0",
      elixir: "~> 1.19",
      start_permanent: false,
      deps: deps(),
      aliases: aliases()
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.2"},
      {:phoenix, "~> 1.8"}
    ]
  end

  defp aliases do
    [
      # The manifest is keyed by paths relative to the directory that was
      # digested, and `ArchiDep.CourseSite.Build.AssetDigest` reads those keys
      # as paths from the root of the site. So the static directory is
      # digested, not the assets directory inside it.
      "assets.deploy": [
        "phx.digest priv/static -o priv/static"
      ]
    ]
  end
end
