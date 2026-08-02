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
  alias ArchiDep.CourseSite.Build.Site
  alias ArchiDep.CourseSite.Headings
  alias ArchiDep.CourseSite.PageRef
  alias ArchiDep.CourseSite.Progress
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

  # The files anchored at the build's mount point rather than under its edition,
  # which is what `{:root_file, _}` means. They are named one by one rather than
  # walked, for the same reason the includes are: the directory they come from
  # holds marks nothing draws, and what a build publishes is a decision rather
  # than whatever happens to be sitting there.
  @root_files [
    "favicon.ico",
    "favicons/heig.png",
    "favicons/archidep-512-flat.png",
    "favicons/archidep-coffee.png",
    "favicons/archidep-rocket-16.png",
    "favicons/archidep-rocket-32.png",
    "favicons/archidep-rocket-48.png",
    "favicons/archidep-rocket-96.png",
    "favicons/archidep-rocket-180.png",
    "favicons/archidep-rocket-192.png"
  ]

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
          | {:output_not_empty, Path.t(), [String.t()]}
          | {:unremovable_output, Path.t(), File.posix()}
          | {:invalid_course, Structure.error()}
          | Site.error()

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
  The home page, which is not in the content directory.

  The home page introduces the course rather than being part of it: it has no
  number, no section and no chapter directory, so there is nowhere in the
  content tree to put it and it is read from where it is written instead. Its
  source path is its file name, which is what the course's own repository shows
  it under.
  """
  @spec home_source(Path.t()) :: {:ok, Source.t()} | {:error, nonempty_list(error())}
  def home_source(file) do
    case source(Path.dirname(file), Path.basename(file)) do
      {:ok, source} -> {:ok, source}
      {:error, error} -> {:error, [error]}
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
  Every path a build wrote, as an output path, ready to check its links against.

  Hand it the directory of the **edition** rather than the whole output: a
  relative link is written from one page of an edition to another, so those are
  the coordinates `ArchiDep.CourseSite.Build.LinkCheck` resolves in, and the
  files anchored above an edition are not addressable from a page in the first
  place.
  """
  @spec output_files(Path.t()) :: MapSet.t(String.t())
  def output_files(output_dir),
    do: output_dir |> relative_files(output_dir) |> MapSet.new(&("/" <> &1))

  @doc """
  Everything a build reads before it decides anything.

  The content tree is read first and its failure is reported **alone**: what
  each file of the directory is, is what every other read is expressed in terms
  of, so nothing else about the course can be trusted once that is wrong. This
  is the same exception the declarations already get in `course!/2`.

  Everything after it is read whether or not the others succeeded, and every
  failure is reported together — a build directory takes one run to fix rather
  than one run per mistake.

  Options:

  - `:content_dir` (required) — the course collections.
  - `:home_file` (required) — the page introducing the course, which is not one
    of them.
  - `:includes_dir` (required) — the partials a document may include.
  - `:root_files_dir` (required) — where the files anchored at the build's mount
    point are read from.
  - `:declarations_file` (required) — what the course declares about itself.
  - `:progress` (required) — how far the course has got, as the sessions that
    taught it. It is handed over already read, where every other input is a path
    to read from: which chapters have been covered is the one thing about a
    build that is **not** a fact about the course material, and where it is kept
    is the caller's business. `progress/1` is the reader for a caller whose
    source is a file.
  - `:static_dir` (required) — where the global assets were published.
  - `:digested` — whether those assets carry a digest, which is a **mode**
    rather than a fallback: a build whose manifest is missing fails rather than
    quietly emitting names that only resolve in development. Defaults to `true`.
  """
  @spec site_inputs(keyword()) :: {:ok, Site.Inputs.t()} | {:error, nonempty_list(error())}
  def site_inputs(opts) when is_list(opts) do
    content_dir = Keyword.fetch!(opts, :content_dir)

    with {:ok, tree} <- content_tree(content_dir),
         do: read_site_inputs(tree, content_dir, opts)
  end

  @doc """
  Make ready the directory a build writes into.

  A build **owns** its output directory rather than merging into it. That is not
  tidiness: the link check is measured against what the directory holds
  (`output_files/1`), so a page left behind by an earlier build would make a
  link that leads nowhere look like a link that resolves. An output that is a
  function of the inputs has to start from nothing.

  `:empty` accepts a directory that is absent or empty and refuses one that is
  not, naming what is in it; `:clean` empties it first.
  """
  @spec prepare_output(Path.t(), :empty | :clean) :: :ok | {:error, nonempty_list(error())}
  def prepare_output(output_dir, mode) when mode in [:empty, :clean] do
    with :ok <- clear_output(output_dir, mode),
         :ok <- check_output_empty(output_dir),
         do: make_output(output_dir)
  end

  @doc """
  Put a build rendered into a staging directory in the place of the one being
  served, and remove what it replaced.

  A build that renders into the directory it is served from is broken for as
  long as it takes to write, and a build that fails half way through leaves it
  broken for good. So a rebuild of a site somebody is reading renders into
  `<output>.staging` and finishes here, where the only thing that can go wrong
  is a rename.

  Two renames rather than one, because this needs no symlink to indirect
  through: the output is moved aside to `<output>.old`, the staging directory is
  renamed into place and the old one is removed. That leaves a window of less
  than a millisecond in which the output directory does not exist — which is
  what the `current`-symlink variant would close, and which is worth closing
  where a rebuild happens under production traffic rather than under one
  developer's browser.
  """
  @spec swap_output(Path.t(), Path.t()) :: :ok | {:error, nonempty_list(error())}
  def swap_output(output_dir, staging_dir) do
    old_dir = output_dir <> ".old"

    with :ok <- check_staging(staging_dir),
         :ok <- remove_output(old_dir),
         :ok <- move_output_aside(output_dir, old_dir),
         :ok <- move_output(staging_dir, output_dir),
         do: remove_output(old_dir)
  end

  @doc """
  Write the files of a planned build.

  Everything was read, rendered and laid out before this is called, so what is
  left is putting bytes where they go — each of them at the path the plan
  already worked out, mount point and edition included.
  """
  @spec publish_site(Site.t(), Path.t()) :: :ok | {:error, nonempty_list(error())}
  def publish_site(%Site{files: files}, output_dir) do
    errors =
      Enum.flat_map(files, fn {output_path, contents} ->
        target = Path.join(output_dir, output_path)

        with :ok <- File.mkdir_p(Path.dirname(target)),
             :ok <- File.write(target, contents) do
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
  Copy the global assets of a build into it, under the names they were published
  as.

  A build carries its own copy of them so that it is self-contained: it is what
  lets an edition be frozen without a later year's asset build reaching back
  into it, and what lets a build be served from anywhere at all. The whole
  directory is copied rather than the manifest's own entries, because a bundle
  loads the chunks beside it by names no manifest is asked about.

  The one build that does not carry them is the development one, whose assets
  are written by the watchers while it is being served — see the `:carry_assets`
  option of `ArchiDep.CourseSite.Builder.build/1`.
  """
  @spec publish_assets(Path.t(), Path.t()) :: :ok | {:error, nonempty_list(error())}
  def publish_assets(static_dir, output_dir) do
    assets_dir = Path.join(static_dir, @assets_dir)

    errors =
      assets_dir
      |> relative_files(static_dir)
      |> Enum.sort()
      |> Enum.flat_map(fn path ->
        target = Path.join(output_dir, path)

        with :ok <- File.mkdir_p(Path.dirname(target)),
             :ok <- File.cp(Path.join(static_dir, path), target) do
          []
        else
          {:error, reason} -> [{:unwritable_output, "/" <> path, target, reason}]
        end
      end)

    case errors do
      [] -> :ok
      [_first | _rest] = errors -> {:error, errors}
    end
  end

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

  def format_error({:output_not_empty, path, entries}),
    do:
      "Output directory #{inspect(path)} is not empty; a build owns its output and must start from nothing, but it holds: #{Enum.join(entries, ", ")}"

  def format_error({:unremovable_output, path, reason}),
    do: "Output #{inspect(path)} could not be removed: #{:file.format_error(reason)}"

  # What the course is, is one problem with one wording wherever it surfaces, so
  # this delegates rather than restating eleven of `Structure`'s failures.
  def format_error({:invalid_course, error}), do: Structure.format_error(error)

  def format_error({:unlayoutable_page, _page, _error} = error), do: Site.format_error(error)

  defp or_raise(result, what, format \\ &__MODULE__.format_error/1)
  defp or_raise({:ok, value}, _what, _format), do: value
  defp or_raise({:error, errors}, what, format), do: raise_errors(what, errors, format)

  defp raise_errors(what, errors, format),
    do: raise("#{what}:\n" <> Enum.map_join(errors, "\n", &("  " <> format.(&1))))

  defp read_site_inputs(tree, content_dir, opts) do
    home_file = Keyword.fetch!(opts, :home_file)

    sources = sources(tree, content_dir)
    home = home_source(home_file)
    declarations = declarations(Keyword.fetch!(opts, :declarations_file))
    includes = includes(Keyword.fetch!(opts, :includes_dir))
    root_files = root_files(Keyword.fetch!(opts, :root_files_dir))
    page_assets = page_asset_manifest(tree, content_dir)
    assets = assets(Keyword.fetch!(opts, :static_dir), Keyword.get(opts, :digested, true))
    structure = structure(tree, sources, declarations)

    reads = [sources, home, declarations, includes, root_files, page_assets, assets, structure]

    case Enum.sort(errors_of(reads)) do
      [] ->
        {:ok,
         %Site.Inputs{
           tree: tree,
           sources: Map.put(value_of(sources), :home, value_of(home)),
           home_source_path: Path.basename(home_file),
           structure: value_of(structure),
           progress: Progress.new(Keyword.fetch!(opts, :progress)),
           includes: value_of(includes),
           root_files: value_of(root_files),
           assets: value_of(assets),
           page_assets: value_of(page_assets)
         }}

      [_first | _rest] = errors ->
        {:error, errors}
    end
  end

  # What the course says it is is a different kind of failure from a file that
  # could not be read, so it is wrapped and worded by `Structure` itself. The
  # sources and the declarations report their own failures, so a structure that
  # could not even be attempted reports nothing rather than repeating them.
  defp structure(tree, {:ok, sources}, {:ok, declarations}) do
    case Structure.plan(tree, front_matter(sources), declarations) do
      {:ok, structure} -> {:ok, structure}
      {:error, errors} -> {:error, Enum.map(errors, &{:invalid_course, &1})}
    end
  end

  defp structure(_tree, _sources, _declarations), do: {:error, []}

  # The bytes travel through the plan rather than being copied straight across.
  # There is a fixed handful of these and none of them is large, unlike the
  # files sitting next to a page, which are copied because the whole of them is
  # far too big to hold in memory.
  defp root_files(root_files_dir) do
    {contents, errors} =
      Enum.reduce(@root_files, {%{}, []}, fn path, {contents, errors} ->
        file = Path.join(root_files_dir, path)

        case File.read(file) do
          {:ok, bytes} ->
            {Map.put(contents, "/" <> path, bytes), errors}

          {:error, reason} ->
            {contents, [{:unreadable_source, "/" <> path, file, reason} | errors]}
        end
      end)

    case Enum.reverse(errors) do
      [] -> {:ok, contents}
      [_first | _rest] = errors -> {:error, errors}
    end
  end

  defp assets(static_dir, true), do: asset_manifest(static_dir)
  defp assets(static_dir, false), do: {:ok, undigested_asset_manifest(static_dir)}

  defp errors_of(results),
    do:
      Enum.flat_map(results, fn
        {:ok, _value} -> []
        {:error, errors} -> errors
      end)

  defp value_of({:ok, value}), do: value

  defp clear_output(_output_dir, :empty), do: :ok

  defp clear_output(output_dir, :clean) do
    case File.rm_rf(output_dir) do
      {:ok, _removed} -> :ok
      {:error, reason, path} -> {:error, [{:unremovable_output, path, reason}]}
    end
  end

  defp check_output_empty(output_dir) do
    case File.ls(output_dir) do
      {:ok, []} -> :ok
      {:ok, entries} -> {:error, [{:output_not_empty, output_dir, Enum.sort(entries)}]}
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, [{:unwritable_output, "/", output_dir, reason}]}
    end
  end

  defp make_output(output_dir) do
    case File.mkdir_p(output_dir) do
      :ok -> :ok
      {:error, reason} -> {:error, [{:unwritable_output, "/", output_dir, reason}]}
    end
  end

  # Asked before anything is moved, so that a swap of a build that was never
  # rendered leaves the one being served where it is rather than in the
  # directory it was moved aside to.
  defp check_staging(staging_dir) do
    if File.dir?(staging_dir),
      do: :ok,
      else: {:error, [{:unwritable_output, "/", staging_dir, :enoent}]}
  end

  defp remove_output(dir) do
    case File.rm_rf(dir) do
      {:ok, _removed} -> :ok
      {:error, reason, path} -> {:error, [{:unremovable_output, path, reason}]}
    end
  end

  # A build that has never been published has nothing to move aside, which is
  # the first swap of a development server rather than a failure.
  defp move_output_aside(dir, target) do
    case File.rename(dir, target) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, [{:unwritable_output, "/", target, reason}]}
    end
  end

  defp move_output(dir, target) do
    case File.rename(dir, target) do
      :ok -> :ok
      {:error, reason} -> {:error, [{:unwritable_output, "/", target, reason}]}
    end
  end

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
