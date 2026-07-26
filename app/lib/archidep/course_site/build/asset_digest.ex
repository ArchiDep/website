defmodule ArchiDep.CourseSite.Build.AssetDigest do
  @moduledoc """
  The names the global assets of the site are published under, read from the
  manifest `mix phx.digest` writes.

  The digester names a file after its own content and records the mapping in
  `cache_manifest.json`, keyed by paths relative to the directory it digested —
  `assets/theme/theme.css`, with no leading slash.
  `ArchiDep.CourseSite.Urls.AssetManifest` is keyed from the root of the site,
  so every path gains one here. That is the whole of the translation: digesting
  renames a file within its own directory, so a logical path and the path it
  resolves to differ in their last segment alone.

  Only the manifest's `latest` map is read. Its `digests` map is the digester's
  own bookkeeping, and it deliberately keeps entries for files a later run has
  already deleted so that URLs of a previous deployment go on resolving —
  building a site from it would publish pages naming files the next digest run
  removes.
  """

  alias ArchiDep.CourseSite.Urls.AssetManifest

  # The version `Phoenix.Digester` stamps into the manifest it writes. A build
  # that finds another one stops rather than guessing: the shape of `latest` is
  # what a version bump is free to change.
  @manifest_version 1

  @type error ::
          {:unsupported_manifest_version, term()}
          | {:malformed_manifest, String.t()}

  @doc """
  The asset manifest named by a decoded `cache_manifest.json`.

      iex> AssetDigest.from_cache_manifest(%{
      ...>   "version" => 1,
      ...>   "latest" => %{"assets/theme/theme.css" => "assets/theme/theme-1a2b3c.css"},
      ...>   "digests" => %{}
      ...> })
      {:ok, %AssetManifest{assets: %{"/assets/theme/theme.css" => "/assets/theme/theme-1a2b3c.css"}}}

      iex> AssetDigest.from_cache_manifest(%{"version" => 2, "latest" => %{}})
      {:error, {:unsupported_manifest_version, 2}}

      iex> AssetDigest.from_cache_manifest(%{"version" => 1})
      {:error, {:malformed_manifest, "no \\"latest\\" map"}}
  """
  @spec from_cache_manifest(map()) :: {:ok, AssetManifest.t()} | {:error, error()}
  def from_cache_manifest(%{"version" => @manifest_version} = manifest) do
    case Map.fetch(manifest, "latest") do
      {:ok, latest} when is_map(latest) -> rooted(latest)
      {:ok, _other} -> {:error, {:malformed_manifest, ~s{"latest" is not a map}}}
      :error -> {:error, {:malformed_manifest, ~s{no "latest" map}}}
    end
  end

  def from_cache_manifest(%{"version" => version}),
    do: {:error, {:unsupported_manifest_version, version}}

  def from_cache_manifest(manifest) when is_map(manifest),
    do: {:error, {:malformed_manifest, ~s{no "version"}}}

  @doc """
  The asset manifest of a build whose assets were never digested, mapping every
  path of a static directory to itself.

  Development never runs the digester, and a developer should not have to. This
  is a mode of its own rather than a fallback inside `from_cache_manifest/1`,
  because an asset the build has no file for stays an error in both modes: a
  manifest that answered for any path at all would let a mistyped stylesheet
  pass in development and fail in production.

      iex> AssetDigest.undigested(["/assets/app/app.js"])
      %AssetManifest{assets: %{"/assets/app/app.js" => "/assets/app/app.js"}}
  """
  @spec undigested([String.t()]) :: AssetManifest.t()
  def undigested(paths) when is_list(paths),
    do: paths |> Map.new(&{&1, &1}) |> AssetManifest.new()

  @doc """
  Describe what is wrong with a manifest, for a build that has to report it.
  """
  @spec format_error(error()) :: String.t()
  def format_error({:unsupported_manifest_version, version}),
    do:
      "Asset manifest version #{inspect(version)} is not version #{@manifest_version}, the one this build reads"

  def format_error({:malformed_manifest, why}), do: "Asset manifest is malformed: #{why}"

  defp rooted(latest) do
    case Enum.reduce_while(latest, %{}, &root_entry/2) do
      {:error, _reason} = error -> error
      assets -> {:ok, AssetManifest.new(assets)}
    end
  end

  defp root_entry({path, digested}, assets) when is_binary(path) and is_binary(digested),
    do: {:cont, Map.put(assets, "/" <> path, "/" <> digested)}

  defp root_entry({path, digested}, _assets),
    do:
      {:halt,
       {:error, {:malformed_manifest, "#{inspect(path)} is published as #{inspect(digested)}"}}}
end
