defmodule ArchiDep.CourseSite.Build.PageAssetDigest do
  @moduledoc """
  The names the files sitting next to a page are published under.

  A file next to a page is digested exactly as a global asset is, and by the
  same rule: `mix phx.digest` names a file after the MD5 of its content,
  inserted before its extension. The site has one naming convention rather than
  two, and `ArchiDep.CourseSite.Urls.UrlPath.insert_suffix/2` — which already
  names the search assets after the build that produced them — computes it.

  Digesting **renames a file within its own directory**, which is why
  `ArchiDep.CourseSite.Urls.PageAssetManifest` holds a file name rather than a
  path, and why a reference keeps the shape its author wrote: only its last
  segment changes.
  """

  alias ArchiDep.CourseSite.Urls.PageAssetManifest
  alias ArchiDep.CourseSite.Urls.UrlPath

  @type error :: {:digested_name_collision, String.t(), [String.t()]}

  @doc """
  The name a file is published under, given the MD5 of its content.

      iex> PageAssetDigest.digested_name("cli.jpg", Base.decode16!("6DC17DF95A0D2A0CE4B5A55A1B2C3D4E"))
      "cli-6dc17df95a0d2a0ce4b5a55a1b2c3d4e.jpg"

      iex> PageAssetDigest.digested_name("archive.tar.gz", Base.decode16!("00112233445566778899AABBCCDDEEFF"))
      "archive.tar-00112233445566778899aabbccddeeff.gz"

      iex> PageAssetDigest.digested_name("LICENSE", Base.decode16!("FFEEDDCCBBAA99887766554433221100"))
      "LICENSE-ffeeddccbbaa99887766554433221100"
  """
  @spec digested_name(String.t(), binary()) :: String.t()
  def digested_name(file_name, md5) when is_binary(file_name) and byte_size(md5) == 16,
    do: UrlPath.insert_suffix(file_name, Base.encode16(md5, case: :lower))

  @doc """
  The path a file is copied to within a build, given the name it is published
  under.

      iex> PageAssetDigest.published_path("/course/507-dns/images/zone.png", "zone-6f7a8b.png")
      "/course/507-dns/images/zone-6f7a8b.png"
  """
  @spec published_path(String.t(), String.t()) :: String.t()
  def published_path(output_path, file_name)
      when is_binary(output_path) and is_binary(file_name),
      do: UrlPath.dirname(output_path) <> file_name

  @doc """
  The manifest of files published from the digests of their content, keyed by
  the output path each is written under.

  `ArchiDep.CourseSite.Urls.PageAssetManifest` knows an asset by the name it is
  written under *and* by the name it is published under, which is what makes
  resolving one idempotent. Those two names share one lookup, so a file already
  named the way a digested file is named would answer for the file that
  publishes under that name, and a reference resolved once would then resolve
  to somebody else. It is rejected here — where there is still a list to look
  at — rather than inside `PageAssetManifest.new/1`, whose return value is the
  renderer's contract.
  """
  @spec manifest(%{String.t() => binary()}) ::
          {:ok, PageAssetManifest.t()} | {:error, nonempty_list(error())}
  def manifest(digests) when is_map(digests) do
    page_assets =
      Map.new(digests, fn {output_path, md5} ->
        {output_path, output_path |> Path.basename() |> digested_name(md5)}
      end)

    case collisions(page_assets) do
      [] -> {:ok, PageAssetManifest.new(page_assets)}
      [_first | _rest] = errors -> {:error, errors}
    end
  end

  @doc """
  Describe a name two files would be published under, for a build that has to
  report it.
  """
  @spec format_error(error()) :: String.t()
  def format_error({:digested_name_collision, published_path, output_paths}),
    do:
      "Published path #{inspect(published_path)} would be written by #{Enum.map_join(output_paths, " and ", &inspect/1)}"

  # Every path the manifest can be asked for, and which asset would answer for
  # it: the path an asset is written under answers for itself, and the path it
  # is published under answers for it too. A path two assets both answer for is
  # a lookup that has stopped meaning one thing.
  defp collisions(page_assets) do
    claimed_by_own_name =
      Enum.map(page_assets, fn {output_path, _name} -> {output_path, output_path} end)

    claimed_by_digest =
      Enum.map(page_assets, fn {output_path, file_name} ->
        {published_path(output_path, file_name), output_path}
      end)

    (claimed_by_own_name ++ claimed_by_digest)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.map(fn {path, owners} -> {path, owners |> Enum.uniq() |> Enum.sort()} end)
    |> Enum.filter(fn {_path, owners} -> length(owners) > 1 end)
    |> Enum.sort()
    |> Enum.map(fn {path, owners} -> {:digested_name_collision, path, owners} end)
  end
end
