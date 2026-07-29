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
  alias ArchiDep.CourseSite.Build.ProgressFile
  alias ArchiDep.CourseSite.Headings
  alias ArchiDep.CourseSite.PageRef
  alias ArchiDep.CourseSite.Renderer
  alias ArchiDep.CourseSite.Renderer.RenderContext
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.CourseSite.Renderer.Source
  alias ArchiDep.CourseSite.Session
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Urls.AssetManifest
  alias ArchiDep.CourseSite.Urls.PageAssetManifest
  alias ArchiDep.CourseSite.Urls.UrlContext

  @cache_manifest "cache_manifest.json"
  @assets_dir "assets"

  # Only the partials a *document* includes, which today are the icons. The rest
  # of the includes directory is the Liquid layout the site is wrapped in, which
  # belongs to Jekyll and uses the tags of its plugins.
  @includes "icons/**/*.html"

  @type error ::
          ContentTree.error()
          | PageAssetDigest.error()
          | AssetDigest.error()
          | ProgressFile.error()
          | {:missing_manifest, Path.t()}
          | {:unreadable_manifest, Path.t(), File.posix()}
          | {:undecodable_manifest, Path.t()}
          | {:unreadable_source, String.t(), Path.t(), File.posix()}
          | {:unwritable_output, String.t(), Path.t(), File.posix()}
          | {:missing_declarations, Path.t()}
          | {:unreadable_declarations, Path.t(), File.posix()}
          | {:undecodable_declarations, Path.t(), String.t()}
          | {:missing_progress, Path.t()}
          | {:unreadable_progress, Path.t(), File.posix()}
          | {:undecodable_progress, Path.t()}
          | {:unreadable_document, String.t(), Path.t(), File.posix()}
          | {:unparsable_document, String.t(), Source.error()}
          | {:unknown_page, PageRef.t()}
          | {:unrenderable_document, String.t(), RenderError.t()}
          | {:unreadable_include, String.t(), Path.t(), File.posix()}
          | {:unparsable_include, RenderError.t()}

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
  Every partial a document of the course may include, relative to the includes
  directory, sorted.
  """
  @spec include_files(Path.t()) :: [String.t()]
  def include_files(includes_dir),
    do:
      includes_dir
      |> Path.join(@includes)
      |> Path.wildcard()
      |> Enum.map(&Path.relative_to(&1, includes_dir))
      |> Enum.sort()

  @doc """
  The partials a document of the course may include, parsed.

  A build parses them once and every document that includes one looks it up, so
  a partial drawn on forty pages is read and parsed once rather than forty
  times.
  """
  @spec includes(Path.t()) ::
          {:ok, %{String.t() => Solid.Template.t()}} | {:error, nonempty_list(error())}
  def includes(includes_dir) do
    with {:ok, sources} <- include_sources(includes_dir), do: compile_includes(sources)
  end

  @doc """
  The headings of a named pages of a content directory, raising when one of them
  cannot be read.

  A heading's identifier is settled by rendering the page it is on, so this
  renders each page it is asked about — and only those. What a caller wants is
  to check the handful of headings it links to; rendering the whole course to
  answer that would put a build inside every compilation of
  `ArchiDep.CourseSite.Material`.

  The partials are needed all the same, because it is the tags of the course
  rather than its documents that include them: a note draws its icon that way,
  and there is no page without a note. What the render does *not* need is either
  asset manifest, its passes being dropped — see
  `ArchiDep.CourseSite.Renderer.headings/1`.
  """
  @spec headings!(Path.t(), Path.t(), [PageRef.t()]) :: Headings.t()
  def headings!(content_dir, includes_dir, pages) when is_list(pages) do
    tree = content_dir |> content_tree() |> or_raise("The content directory could not be read")

    includes =
      includes_dir |> includes() |> or_raise("The partials of the course could not be read")

    {identifiers, errors} =
      Enum.reduce(pages, {%{}, []}, fn page, {identifiers, errors} ->
        case page_headings(tree, content_dir, includes, page) do
          {:ok, page_identifiers} -> {Map.put(identifiers, page, page_identifiers), errors}
          {:error, page_errors} -> {identifiers, errors ++ page_errors}
        end
      end)

    case errors do
      [] ->
        Headings.new(identifiers)

      [_first | _rest] = errors ->
        raise_errors(
          "The headings of the course material could not be read",
          errors,
          &format_error/1
        )
    end
  end

  @doc """
  What each session of the course recorded of the progress through it, in the
  order they were taught.

  This is read when a build runs rather than when the application compiles: how
  far the course has got changes every week of the year, while what the course
  *is* does not. So it is a file of its own, outside the collections a build
  renders — `ArchiDep.CourseSite.Build.ContentTree.roots/0` does not name it —
  and the caller says where it is, since only the caller knows whether it is
  reading a repository or a release.
  """
  @spec progress(Path.t()) :: {:ok, [Session.t()]} | {:error, nonempty_list(error())}
  def progress(file) do
    with {:ok, contents} <- read_progress(file),
         {:ok, decoded} <- decode_progress(file, contents) do
      case ProgressFile.sessions(decoded) do
        {:ok, sessions} -> {:ok, sessions}
        {:error, error} -> {:error, [error]}
      end
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

  def format_error({:missing_progress, path}),
    do: "The progress file #{path} does not exist"

  def format_error({:unreadable_progress, path, reason}),
    do: "The progress file #{path} could not be read: #{:file.format_error(reason)}"

  def format_error({:undecodable_progress, path}),
    do: "The progress file #{path} is not a JSON object"

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

  def format_error({:unreadable_include, path, file, reason}),
    do:
      "Partial #{inspect(path)} could not be read from #{inspect(file)}: #{:file.format_error(reason)}"

  def format_error({:unparsable_include, %RenderError{} = error}),
    do: "A partial could not be parsed: #{RenderError.message(error)}"

  def format_error({:unknown_page, page}),
    do: "The content directory holds no page at #{inspect(PageRef.output_path(page))}"

  def format_error({:unrenderable_document, source_path, %RenderError{} = error}),
    do: "Document #{inspect(source_path)} could not be rendered: #{RenderError.message(error)}"

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

  def format_error({:malformed_progress, _why} = error), do: ProgressFile.format_error(error)

  def format_error({:malformed_session, _index, _why} = error),
    do: ProgressFile.format_error(error)

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

  defp include_sources(includes_dir) do
    {sources, errors} =
      includes_dir
      |> include_files()
      |> Enum.reduce({%{}, []}, fn path, {sources, errors} ->
        file = Path.join(includes_dir, path)

        case File.read(file) do
          {:ok, contents} -> {Map.put(sources, path, contents), errors}
          {:error, reason} -> {sources, [{:unreadable_include, path, file, reason} | errors]}
        end
      end)

    case Enum.reverse(errors) do
      [] -> {:ok, sources}
      [_first | _rest] = errors -> {:error, errors}
    end
  end

  defp compile_includes(sources) do
    case Renderer.compile_includes(sources) do
      {:ok, includes} -> {:ok, includes}
      {:error, errors} -> {:error, Enum.map(errors, &{:unparsable_include, &1})}
    end
  end

  defp page_headings(tree, content_dir, includes, page) do
    with {:ok, source_path} <- page_source_path(tree, page),
         {:ok, source} <- page_source(content_dir, source_path),
         do: rendered_headings(page, source_path, source, includes)
  end

  defp page_source_path(%ContentTree{documents: documents}, {:document, ref}),
    do: documents |> Map.fetch(ref) |> or_unknown({:document, ref})

  defp page_source_path(%ContentTree{cheatsheets: cheatsheets}, {:cheatsheet, slug}),
    do: cheatsheets |> Map.fetch(slug) |> or_unknown({:cheatsheet, slug})

  defp page_source_path(%ContentTree{}, page), do: {:error, [{:unknown_page, page}]}

  defp or_unknown({:ok, source_path}, _page), do: {:ok, source_path}
  defp or_unknown(:error, page), do: {:error, [{:unknown_page, page}]}

  defp page_source(content_dir, source_path) do
    case source(content_dir, source_path) do
      {:ok, source} -> {:ok, source}
      {:error, error} -> {:error, [error]}
    end
  end

  defp rendered_headings(page, source_path, source, includes) do
    context =
      RenderContext.new(
        source: source,
        source_path: source_path,
        urls: headings_urls(),
        page: page,
        includes: includes
      )

    case Renderer.headings(context) do
      {:ok, identifiers} ->
        {:ok, identifiers}

      {:error, errors} ->
        {:error, Enum.map(errors, &{:unrenderable_document, source_path, &1})}
    end
  end

  # Every URL this render emits is discarded — only the identifiers of the
  # headings are kept — so what it says about the build it is for cannot reach
  # anything. It says the least a URL context may say.
  defp headings_urls, do: UrlContext.new(mode: :live, build_id: "headings")

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

  defp read_progress(file) do
    case File.read(file) do
      {:ok, contents} -> {:ok, contents}
      {:error, :enoent} -> {:error, [{:missing_progress, file}]}
      {:error, reason} -> {:error, [{:unreadable_progress, file, reason}]}
    end
  end

  defp decode_progress(file, contents) do
    case JSON.decode(contents) do
      {:ok, decoded} when is_map(decoded) -> {:ok, decoded}
      _other -> {:error, [{:undecodable_progress, file}]}
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
