defmodule ArchiDep.CourseSite.Build do
  @moduledoc """
  The one part of the course material site that reads and writes files.

  Everything else in `ArchiDep.CourseSite` is a function of its inputs — that
  is what lets the same code produce the live site, a backup copy, a frozen
  archive and the build printed to PDF. The rules of a build are pure and live
  beside this module; what is left here is fetching bytes and putting them
  somewhere, so that a stray `File` call anywhere else in the subsystem reads
  as obviously wrong.

  Reading and writing are kept apart within it too: the files a build publishes
  are all read and all validated before any of them is written, so a content
  directory that is going to be rejected never leaves half a build behind.
  """

  alias ArchiDep.CourseSite.Build.AssetDigest
  alias ArchiDep.CourseSite.Build.ContentTree
  alias ArchiDep.CourseSite.Build.PageAssetDigest
  alias ArchiDep.CourseSite.Urls.AssetManifest
  alias ArchiDep.CourseSite.Urls.PageAssetManifest

  @cache_manifest "cache_manifest.json"
  @assets_dir "assets"

  @type error ::
          ContentTree.error()
          | PageAssetDigest.error()
          | AssetDigest.error()
          | {:missing_manifest, Path.t()}
          | {:unreadable_manifest, Path.t(), File.posix()}
          | {:undecodable_manifest, Path.t()}
          | {:unreadable_source, String.t(), Path.t(), File.posix()}
          | {:unwritable_output, String.t(), Path.t(), File.posix()}

  @doc """
  What each file of a content directory is and where it is published.

  The directory is the one holding the course's collections, and only the
  collections `ArchiDep.CourseSite.Build.ContentTree.roots/0` names are read
  from it.
  """
  @spec content_tree(Path.t()) :: {:ok, ContentTree.t()} | {:error, nonempty_list(error())}
  def content_tree(content_dir) do
    ContentTree.roots()
    |> Enum.flat_map(&relative_files(Path.join(content_dir, &1), content_dir))
    |> Enum.sort()
    |> ContentTree.plan()
  end

  @doc """
  The names the files sitting next to the pages of a content directory are
  published under, from the content of each.

  This reads and writes nothing back: a caller that only needs to know what a
  file is called — to resolve a reference, or to check that every one of them
  can be — never has to name a directory to write into.
  """
  @spec page_asset_manifest(ContentTree.t(), Path.t()) ::
          {:ok, PageAssetManifest.t()} | {:error, nonempty_list(error())}
  def page_asset_manifest(%ContentTree{page_assets: sources}, content_dir) do
    with {:ok, digests} <- digests(sources, content_dir),
         do: PageAssetDigest.manifest(digests)
  end

  @doc """
  Copy the files sitting next to the pages of a content directory into a build,
  under the names `page_asset_manifest/2` says they are published as.

  Every file is read and the whole manifest settled before any of them is
  written, so a content directory that is going to be rejected never leaves
  half a build behind.
  """
  @spec publish_page_assets(PageAssetManifest.t(), ContentTree.t(), Path.t(), Path.t()) ::
          :ok | {:error, nonempty_list(error())}
  def publish_page_assets(
        %PageAssetManifest{page_assets: published},
        %ContentTree{page_assets: sources},
        content_dir,
        output_dir
      ) do
    errors =
      Enum.flat_map(published, fn {output_path, file_name} ->
        source = Path.join(content_dir, Map.fetch!(sources, output_path))
        target = Path.join(output_dir, PageAssetDigest.published_path(output_path, file_name))

        with :ok <- File.mkdir_p(Path.dirname(target)),
             :ok <- File.cp(source, target) do
          []
        else
          {:error, reason} -> [{:unwritable_output, output_path, target, reason}]
        end
      end)

    case Enum.sort(errors) do
      [] -> :ok
      [_first | _rest] = errors -> {:error, errors}
    end
  end

  @doc """
  The names the global assets of a build are published under, read from the
  manifest the digester wrote at the root of its static directory.
  """
  @spec asset_manifest(Path.t()) :: {:ok, AssetManifest.t()} | {:error, nonempty_list(error())}
  def asset_manifest(static_dir) do
    manifest_file = Path.join(static_dir, @cache_manifest)

    with {:ok, contents} <- read_manifest(manifest_file),
         {:ok, decoded} <- decode_manifest(manifest_file, contents) do
      case AssetDigest.from_cache_manifest(decoded) do
        {:ok, manifest} -> {:ok, manifest}
        {:error, error} -> {:error, [error]}
      end
    end
  end

  @doc """
  The names the global assets of a build are published under when the build
  never digested them, which is how the site is served in development.
  """
  @spec undigested_asset_manifest(Path.t()) :: AssetManifest.t()
  def undigested_asset_manifest(static_dir) do
    assets_dir = Path.join(static_dir, @assets_dir)

    assets_dir
    |> relative_files(static_dir)
    |> Enum.sort()
    |> Enum.map(&("/" <> &1))
    |> AssetDigest.undigested()
  end

  @doc """
  Every path a build wrote, as an output path, ready to check its links
  against.
  """
  @spec output_files(Path.t()) :: MapSet.t(String.t())
  def output_files(output_dir),
    do: output_dir |> relative_files(output_dir) |> MapSet.new(&("/" <> &1))

  @doc """
  Describe what went wrong, whichever part of a build it came from.
  """
  @spec format_error(error()) :: String.t()
  def format_error({:missing_manifest, path}),
    do: "Asset manifest #{inspect(path)} does not exist; run the digest step before building"

  def format_error({:unreadable_manifest, path, reason}),
    do: "Asset manifest #{inspect(path)} could not be read: #{:file.format_error(reason)}"

  def format_error({:undecodable_manifest, path}),
    do: "Asset manifest #{inspect(path)} is not JSON"

  def format_error({:unreadable_source, output_path, source_path, reason}),
    do:
      "File #{inspect(source_path)}, published at #{inspect(output_path)}, could not be read: #{:file.format_error(reason)}"

  def format_error({:unwritable_output, output_path, target, reason}),
    do:
      "File published at #{inspect(output_path)} could not be written to #{inspect(target)}: #{:file.format_error(reason)}"

  def format_error({:unknown_source, _path} = error), do: ContentTree.format_error(error)
  def format_error({:unsafe_name, _path, _segment} = error), do: ContentTree.format_error(error)

  def format_error({:duplicate_output_path, _path, _sources} = error),
    do: ContentTree.format_error(error)

  def format_error({:digested_name_collision, _path, _owners} = error),
    do: PageAssetDigest.format_error(error)

  def format_error({:unsupported_manifest_version, _version} = error),
    do: AssetDigest.format_error(error)

  def format_error({:malformed_manifest, _why} = error), do: AssetDigest.format_error(error)

  # Dotfiles are listed rather than skipped here, so that what a build ignores
  # is a decision `ContentTree` records instead of a default of the walk.
  defp relative_files(dir, root) do
    dir
    |> Path.join("**/*")
    |> Path.wildcard(match_dot: true)
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(&(&1 |> Path.relative_to(root) |> Path.split() |> Enum.join("/")))
  end

  defp digests(sources, content_dir) do
    {digests, errors} =
      Enum.reduce(sources, {%{}, []}, fn {output_path, source_path}, {digests, errors} ->
        file = Path.join(content_dir, source_path)

        case md5(file) do
          {:ok, md5} ->
            {Map.put(digests, output_path, md5), errors}

          {:error, reason} ->
            {digests, [{:unreadable_source, output_path, source_path, reason} | errors]}
        end
      end)

    case Enum.reverse(errors) do
      [] -> {:ok, digests}
      [_first | _rest] = errors -> {:error, errors}
    end
  end

  defp md5(file) do
    file
    |> File.stream!(2048)
    |> Enum.reduce(:crypto.hash_init(:md5), &:crypto.hash_update(&2, &1))
    |> :crypto.hash_final()
    |> then(&{:ok, &1})
  rescue
    error in File.Error -> {:error, error.reason}
  end

  defp read_manifest(manifest_file) do
    case File.read(manifest_file) do
      {:ok, contents} -> {:ok, contents}
      {:error, :enoent} -> {:error, [{:missing_manifest, manifest_file}]}
      {:error, reason} -> {:error, [{:unreadable_manifest, manifest_file, reason}]}
    end
  end

  defp decode_manifest(manifest_file, contents) do
    case JSON.decode(contents) do
      {:ok, decoded} when is_map(decoded) -> {:ok, decoded}
      _other -> {:error, [{:undecodable_manifest, manifest_file}]}
    end
  end
end
