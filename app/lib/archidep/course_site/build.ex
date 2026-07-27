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
  alias ArchiDep.CourseSite.PageRef
  alias ArchiDep.CourseSite.Renderer.Source
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Urls.AssetManifest
  alias ArchiDep.CourseSite.Urls.PageAssetManifest

  @cache_manifest "cache_manifest.json"
  @assets_dir "assets"
  @progress_dir "_progress"

  @type error ::
          ContentTree.error()
          | PageAssetDigest.error()
          | AssetDigest.error()
          | {:missing_manifest, Path.t()}
          | {:unreadable_manifest, Path.t(), File.posix()}
          | {:undecodable_manifest, Path.t()}
          | {:unreadable_source, String.t(), Path.t(), File.posix()}
          | {:unwritable_output, String.t(), Path.t(), File.posix()}
          | {:missing_declarations, Path.t()}
          | {:unreadable_declarations, Path.t(), File.posix()}
          | {:undecodable_declarations, Path.t(), String.t()}
          | {:unreadable_document, String.t(), Path.t(), File.posix()}
          | {:unparsable_document, String.t(), Source.error()}

  @doc """
  Every file a build reads from a content directory, relative to it, sorted.

  Only the collections `ArchiDep.CourseSite.Build.ContentTree.roots/0` names are
  walked, and nothing is left out of the listing — what a build ignores is a
  decision `ArchiDep.CourseSite.Build.ContentTree` records rather than a default
  of the walk.
  """
  @spec content_files(Path.t()) :: [String.t()]
  def content_files(content_dir),
    do:
      ContentTree.roots()
      |> Enum.flat_map(&relative_files(Path.join(content_dir, &1), content_dir))
      |> Enum.sort()

  @doc """
  What a content directory holds, as one hash of the names of its files.

  This answers whether a build reading the directory again would be handed the
  same files, which is a different question from whether any of them has
  changed. Every file counts rather than the documents alone, because
  `ArchiDep.CourseSite.Build.ContentTree.plan/1` decides what a build makes of
  the files beside a page too.
  """
  @spec content_digest(Path.t()) :: binary()
  def content_digest(content_dir),
    do: :crypto.hash(:sha256, content_dir |> content_files() |> Enum.join("\n"))

  @doc """
  What each file of a content directory is and where it is published.

  The directory is the one holding the course's collections, and only the
  collections `ArchiDep.CourseSite.Build.ContentTree.roots/0` names are read
  from it.
  """
  @spec content_tree(Path.t()) :: {:ok, ContentTree.t()} | {:error, nonempty_list(error())}
  def content_tree(content_dir), do: content_dir |> content_files() |> ContentTree.plan()

  @doc """
  What the course declares about itself: the sections it is divided into and the
  order of its cheatsheets, neither of which any one document states.

  The file is read and decoded here and validated by
  `ArchiDep.CourseSite.Structure.plan/3`, which is where the rest of what a
  build makes of the course is decided.
  """
  @spec declarations(Path.t()) :: {:ok, term()} | {:error, nonempty_list(error())}
  def declarations(file) do
    with {:ok, contents} <- read_declarations(file), do: decode_declarations(file, contents)
  end

  @doc """
  Every page of a content directory, taken apart.

  A build reads each source once: what a page *is* comes from its front matter
  and what it shows comes from its body, and both are in here. Every document is
  read and every one of them parsed before the first failure is reported, so a
  content directory takes one run to fix rather than one run per mistake.
  """
  @spec sources(ContentTree.t(), Path.t()) ::
          {:ok, %{PageRef.t() => Source.t()}} | {:error, nonempty_list(error())}
  def sources(%ContentTree{documents: documents, cheatsheets: cheatsheets}, content_dir) do
    pages =
      Enum.map(documents, fn {ref, source_path} -> {{:document, ref}, source_path} end) ++
        Enum.map(cheatsheets, fn {slug, source_path} -> {{:cheatsheet, slug}, source_path} end)

    {sources, errors} =
      Enum.reduce(pages, {%{}, []}, fn {page, source_path}, {sources, errors} ->
        case source(content_dir, source_path) do
          {:ok, source} -> {Map.put(sources, page, source), errors}
          {:error, error} -> {sources, [error | errors]}
        end
      end)

    case Enum.sort(errors) do
      [] -> {:ok, sources}
      [_first | _rest] = errors -> {:error, errors}
    end
  end

  @doc """
  The front matter of every page of a content directory, which is what
  `ArchiDep.CourseSite.Structure.plan/3` reads a page's name and kind from.
  """
  @spec front_matter(%{PageRef.t() => Source.t()}) ::
          %{PageRef.t() => Structure.front_matter()}
  def front_matter(sources) when is_map(sources),
    do:
      Map.new(sources, fn {page, %Source{front_matter: front_matter}} -> {page, front_matter} end)

  @doc """
  Work out what the course is from a content directory and a declarations file,
  raising when it is not a course.

  This is the whole of the reading `ArchiDep.CourseSite.Structure` needs, in one
  call, for a caller that has nothing to do with what went wrong: every problem
  of every stage is in the message it raises, so a content directory takes one
  run to fix rather than one run per mistake.
  """
  @spec course!(Path.t(), Path.t()) :: Structure.t()
  def course!(content_dir, declarations_file) do
    tree =
      content_dir |> content_tree() |> or_raise("The content directory could not be read")

    sources =
      tree
      |> sources(content_dir)
      |> or_raise("The pages of the content directory could not be read")

    declarations =
      declarations_file
      |> declarations()
      |> or_raise("The course declarations could not be read")

    tree
    |> Structure.plan(front_matter(sources), declarations)
    |> or_raise("What the course says it is could not be worked out", &Structure.format_error/1)
  end

  @doc """
  Every file recording a session of the course, relative to the content
  directory, in filename order.

  These sit beside the collections a build renders rather than in them: they are
  a record of when the course was taught rather than something it publishes, so
  `ArchiDep.CourseSite.Build.ContentTree.roots/0` does not name them and this is
  a read of its own.
  """
  @spec progress_files(Path.t()) :: [String.t()]
  def progress_files(content_dir),
    do:
      content_dir
      |> Path.join(@progress_dir)
      |> Path.join("*.md")
      |> Path.wildcard()
      |> Enum.map(&Path.relative_to(&1, content_dir))
      |> Enum.sort()

  @doc """
  What each session of the course has said about the progress through it, in
  filename order, raising when one of those cannot be read.
  """
  @spec progress_entries!(Path.t()) :: [Structure.front_matter()]
  def progress_entries!(content_dir) do
    {entries, errors} =
      content_dir
      |> progress_files()
      |> Enum.reduce({[], []}, fn source_path, {entries, errors} ->
        case source(content_dir, source_path) do
          {:ok, %Source{front_matter: front_matter}} -> {[front_matter | entries], errors}
          {:error, error} -> {entries, [error | errors]}
        end
      end)

    case Enum.reverse(errors) do
      [] ->
        Enum.reverse(entries)

      [_first | _rest] = errors ->
        raise_errors("The progress through the course could not be read", errors, &format_error/1)
    end
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

  def format_error({:missing_declarations, path}),
    do: "Course declarations #{inspect(path)} do not exist"

  def format_error({:unreadable_declarations, path, reason}),
    do: "Course declarations #{inspect(path)} could not be read: #{:file.format_error(reason)}"

  def format_error({:undecodable_declarations, path, why}),
    do: "Course declarations #{inspect(path)} are not YAML: #{why}"

  def format_error({:unreadable_document, source_path, file, reason}),
    do:
      "Document #{inspect(source_path)} could not be read from #{inspect(file)}: #{:file.format_error(reason)}"

  def format_error({:unparsable_document, source_path, :unterminated_front_matter}),
    do: "Document #{inspect(source_path)} opens front matter it never closes"

  def format_error({:unparsable_document, source_path, {:invalid_front_matter, why}}),
    do: "Document #{inspect(source_path)} has invalid front matter: #{why}"

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

  defp or_raise(result, what, format \\ &__MODULE__.format_error/1)
  defp or_raise({:ok, value}, _what, _format), do: value
  defp or_raise({:error, errors}, what, format), do: raise_errors(what, errors, format)

  defp raise_errors(what, errors, format),
    do: raise("#{what}:\n" <> Enum.map_join(errors, "\n", &("  " <> format.(&1))))

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

  defp read_declarations(file) do
    case File.read(file) do
      {:ok, contents} -> {:ok, contents}
      {:error, :enoent} -> {:error, [{:missing_declarations, file}]}
      {:error, reason} -> {:error, [{:unreadable_declarations, file, reason}]}
    end
  end

  defp decode_declarations(file, contents) do
    case YamlElixir.read_from_string(contents) do
      {:ok, declarations} ->
        {:ok, declarations}

      {:error, error} ->
        {:error, [{:undecodable_declarations, file, Exception.message(error)}]}
    end
  end

  defp source(content_dir, source_path) do
    file = Path.join(content_dir, source_path)

    with {:ok, contents} <- read_document(source_path, file),
         do: parse_document(source_path, contents)
  end

  defp read_document(source_path, file) do
    case File.read(file) do
      {:ok, contents} -> {:ok, contents}
      {:error, reason} -> {:error, {:unreadable_document, source_path, file, reason}}
    end
  end

  defp parse_document(source_path, contents) do
    case Source.parse(contents) do
      {:ok, source} -> {:ok, source}
      {:error, error} -> {:error, {:unparsable_document, source_path, error}}
    end
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
