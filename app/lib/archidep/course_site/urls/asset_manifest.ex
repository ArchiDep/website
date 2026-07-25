defmodule ArchiDep.CourseSite.Urls.AssetManifest do
  @moduledoc """
  The digested names of the site's global assets — stylesheets, scripts, fonts —
  mapping the logical path an author or a layout refers to onto the path the
  build actually wrote.

  The manifest is built by the build step, which is the only part that reads
  files; `ArchiDep.CourseSite.Urls` only looks entries up, so an asset missing
  from the manifest is an error rather than a silently broken URL.
  """

  @enforce_keys [:assets]
  defstruct [:assets]

  @type t :: %__MODULE__{assets: %{String.t() => String.t()}}

  @doc """
  Build an asset manifest from logical root-relative paths to digested
  root-relative paths.
  """
  @spec new(%{String.t() => String.t()}) :: t()
  def new(assets) when is_map(assets), do: %__MODULE__{assets: assets}

  @doc """
  Look up the digested path of a global asset.

      iex> manifest = AssetManifest.new(%{"/assets/theme/theme.css" => "/assets/theme/theme-1a2b3c.css"})
      iex> AssetManifest.fetch(manifest, "/assets/theme/theme.css")
      {:ok, "/assets/theme/theme-1a2b3c.css"}

      iex> AssetManifest.fetch(AssetManifest.new(%{}), "/assets/theme/theme.css")
      :error
  """
  @spec fetch(t(), String.t()) :: {:ok, String.t()} | :error
  def fetch(%__MODULE__{assets: assets}, path) when is_binary(path), do: Map.fetch(assets, path)
end
