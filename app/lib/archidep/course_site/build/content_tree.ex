defmodule ArchiDep.CourseSite.Build.ContentTree do
  @moduledoc """
  What each file of the content directory is, and where it is published.

  A build is handed a list of source paths and has to sort them into the
  documents it renders and the files it copies. Both are settled here rather
  than in whatever walks the directory, so that the rule is a value a test can
  assert instead of a shape a filesystem happens to have.

  **A file is published where it is written; a document is not.** The source
  tree mirrors the output tree for everything but Markdown: a file under a
  chapter directory keeps its path relative to that chapter, verbatim, and a
  file under a cheatsheet directory keeps its path relative to that cheatsheet.
  Only a document moves, to the page path `ArchiDep.CourseSite.PageRef` gives
  it.

  That is what makes the mapping **per chapter directory rather than per
  document**, and it is why a deck written at the root of a chapter refers to
  the chapter's images with `../images/…`: the deck is published one segment
  deeper than it is written and its images are not. Both slides layouts fall out
  of the same rule, so nothing here has to know which one a chapter uses.

  Everything that is not a document is a file of the site, whatever its type —
  the course publishes PDFs next to its exercises as well as images. Only one
  thing is skipped, and it lands in `ignored` rather than being quietly dropped:
  a path with a dot-prefixed segment, which is the operating system's litter
  (`.DS_Store`, an AppleDouble file, a directory marker) rather than anybody's
  content. A Markdown file the content layout does not recognise is an error
  instead, since publishing it raw would serve Markdown as text.

  ## What a chapter may hold

  Two rules govern the documents of a chapter, and this is where they are
  enforced:

  1. **A chapter has a subject or an exercise, never both.**
  2. **An exercise never has slides.**

  They are checked here because a chapter is only visible to whatever lists its
  files: the renderer is handed one document at a time and never sees its
  siblings, so it is structurally incapable of noticing either violation.

  The first rule is load-bearing rather than tidy. A chapter's subject and its
  exercise are published at the *same* URL, which is coherent only because at
  most one of them exists; `ArchiDep.CourseSite.PageRef.identity/1` collapses
  them into one identity for the same reason. Were both present, two pages would
  be written to one directory and their files would resolve against a directory
  belonging to both. Neither failure is loud, which is why the input is refused
  instead of one of the two being picked.

  The second rule has no such consequence. It is enforced because it is true of
  the course, and because leaving it unenforced invites a slides page under a
  chapter that nothing listing the material expects to find one under.

  ## One number, one document of each type

  Two more ways a chapter directory can be ambiguous, neither of them a
  statement about what a chapter may hold:

  - **A document written twice.** A chapter writing its deck in both source
    layouts (`slides.md` and `slides/slides.md`) writes one document twice, and
    since the documents are keyed by their identity the second would replace the
    first — publishing one of the two files and silently ignoring the other.
  - **A number used twice.** Two chapter directories differing only after the
    number are two pages as far as their URLs are concerned, but one chapter to
    everything that lists the material: a chapter's progress is recorded against
    its number alone.

  Both are refused here for the same reason the rules above are: what makes them
  visible is having the whole content directory in hand, and what makes them
  worth refusing is that neither fails loudly.
  """

  alias ArchiDep.CourseSite.DocumentRef

  @enforce_keys [:documents, :cheatsheets, :page_assets, :ignored]
  defstruct [:documents, :cheatsheets, :page_assets, :ignored]

  @type t :: %__MODULE__{
          documents: %{DocumentRef.t() => String.t()},
          cheatsheets: %{String.t() => String.t()},
          page_assets: %{String.t() => String.t()},
          ignored: [String.t()]
        }

  @type error ::
          {:unknown_source, String.t()}
          | {:unsafe_name, String.t(), String.t()}
          | {:duplicate_output_path, String.t(), [String.t()]}
          | {:duplicate_document, String.t(), DocumentRef.doc_type(), [String.t()]}
          | {:duplicate_chapter_number, pos_integer(), [String.t()]}
          | {:subject_and_exercise, String.t(), [String.t()]}
          | {:exercise_with_slides, String.t(), [String.t()]}

  @roots ["chapters", "cheatsheets"]

  @chapter_regex ~r{\Achapters/([1-9]\d\d-[^/]+)/(.+)\z}
  @cheatsheet_regex ~r{\Acheatsheets/([^/]+)/(.+)\z}
  @cheatsheet_document_regex ~r{\Acheatsheets/([^/]+)/cheatsheet\.md\z}

  # Why a published path must not need percent-encoding:
  # `ArchiDep.CourseSite.Urls.PageAssetManifest`.
  @url_safe_regex ~r{\A[A-Za-z0-9._-]+\z}

  @doc """
  The directories of the content tree a build reads, relative to the content
  directory.

  They are named rather than derived from what the directory holds, which is
  what lets the content directory be the course directory itself: everything
  beside them — the asset sources, the archive manifests, the generated PDFs —
  is another pipeline's input or this one's output.

      iex> ContentTree.roots()
      ["chapters", "cheatsheets"]
  """
  @spec roots() :: [String.t()]
  def roots, do: @roots

  @doc """
  Sort the source paths of the content directory into what a build makes of
  them.

  Paths are relative to the content directory and separated by slashes, the same
  way `ArchiDep.CourseSite.DocumentRef.parse_source_path/1` reads them. Every
  offending path is reported rather than the first, since a build that stops at
  one makes a content directory take as many runs to fix as it has mistakes —
  and so is every ambiguous chapter, which is a fact about a directory rather
  than about any one path.
  """
  @spec plan([String.t()]) :: {:ok, t()} | {:error, nonempty_list(error())}
  def plan(source_paths) when is_list(source_paths) do
    classified = Enum.map(source_paths, &{&1, classify(&1)})

    errors =
      unplaceable(classified) ++
        collisions(classified) ++
        duplicate_documents(classified) ++
        duplicate_chapter_numbers(classified) ++ chapter_invariants(classified)

    case errors do
      [] -> {:ok, tree(classified)}
      [_first | _rest] -> {:error, errors}
    end
  end

  @doc """
  Describe what is wrong with a source path, for a build that has to report it.
  """
  @spec format_error(error()) :: String.t()
  def format_error({:unknown_source, source_path}),
    do: "Source file #{inspect(source_path)} is neither a document nor a file of a page"

  def format_error({:unsafe_name, source_path, segment}),
    do:
      "Source file #{inspect(source_path)} is published under a path whose segment #{inspect(segment)} is not made of letters, digits, dots, underscores and dashes"

  def format_error({:duplicate_output_path, output_path, source_paths}),
    do:
      "Output path #{inspect(output_path)} is written by #{Enum.map_join(source_paths, " and ", &inspect/1)}"

  def format_error({:duplicate_document, chapter, type, source_paths}),
    do:
      "Chapter #{inspect(chapter)} has more than one #{type} document, written by #{Enum.map_join(source_paths, " and ", &inspect/1)}"

  def format_error({:duplicate_chapter_number, num, chapters}),
    do: "Chapter number #{num} is used by #{Enum.map_join(chapters, " and ", &inspect/1)}"

  def format_error({:subject_and_exercise, chapter, source_paths}),
    do:
      "Chapter #{inspect(chapter)} has both a subject and an exercise, written by #{Enum.map_join(source_paths, " and ", &inspect/1)}"

  def format_error({:exercise_with_slides, chapter, source_paths}),
    do:
      "Chapter #{inspect(chapter)} is an exercise and has slides, written by #{Enum.map_join(source_paths, " and ", &inspect/1)}"

  defp tree(classified) do
    tree =
      Enum.reduce(
        classified,
        %__MODULE__{documents: %{}, cheatsheets: %{}, page_assets: %{}, ignored: []},
        fn {source_path, {:ok, entry}}, tree -> add(tree, entry, source_path) end
      )

    %{tree | ignored: Enum.sort(tree.ignored)}
  end

  defp add(tree, {:document, ref}, source_path),
    do: %{tree | documents: Map.put(tree.documents, ref, source_path)}

  defp add(tree, {:cheatsheet, slug}, source_path),
    do: %{tree | cheatsheets: Map.put(tree.cheatsheets, slug, source_path)}

  defp add(tree, {:page_asset, output_path}, source_path),
    do: %{tree | page_assets: Map.put(tree.page_assets, output_path, source_path)}

  defp add(tree, :ignored, source_path),
    do: %{tree | ignored: [source_path | tree.ignored]}

  defp classify(source_path) do
    cond do
      littered?(source_path) -> {:ok, :ignored}
      String.ends_with?(source_path, ".md") -> document(source_path)
      true -> page_asset(source_path)
    end
  end

  defp littered?(source_path),
    do: source_path |> String.split("/") |> Enum.any?(&String.starts_with?(&1, "."))

  defp document(source_path) do
    case DocumentRef.parse_source_path(source_path) do
      {:ok, ref} -> {:ok, {:document, ref}}
      {:error, {:invalid_source_path, _path}} -> cheatsheet(source_path)
    end
  end

  defp cheatsheet(source_path) do
    case Regex.run(@cheatsheet_document_regex, source_path) do
      [_whole, slug] -> {:ok, {:cheatsheet, slug}}
      nil -> {:error, {:unknown_source, source_path}}
    end
  end

  defp page_asset(source_path) do
    with {:ok, output_path} <- output_path(source_path),
         :ok <- validate_url_safe(source_path, output_path) do
      {:ok, {:page_asset, output_path}}
    end
  end

  defp output_path(source_path) do
    chapter = Regex.run(@chapter_regex, source_path)
    cheatsheet = Regex.run(@cheatsheet_regex, source_path)

    cond do
      chapter != nil ->
        [_whole, dir, rest] = chapter
        {:ok, "/course/#{dir}/#{rest}"}

      cheatsheet != nil ->
        [_whole, slug, rest] = cheatsheet
        {:ok, "/cheatsheets/#{slug}/#{rest}"}

      true ->
        {:error, {:unknown_source, source_path}}
    end
  end

  defp validate_url_safe(source_path, output_path) do
    unsafe =
      output_path
      |> String.split("/", trim: true)
      |> Enum.find(&(not Regex.match?(@url_safe_regex, &1)))

    case unsafe do
      nil -> :ok
      segment -> {:error, {:unsafe_name, source_path, segment}}
    end
  end

  defp unplaceable(classified) do
    Enum.flat_map(classified, fn
      {_source_path, {:error, error}} -> [error]
      {_source_path, {:ok, _entry}} -> []
    end)
  end

  # `page_assets` is a map, and building a map from a list is exactly where two
  # files writing one path stop being two files. Nothing in the content
  # directory does this today; noticing when something starts to costs a group.
  defp collisions(classified) do
    classified
    |> Enum.flat_map(fn
      {source_path, {:ok, {:page_asset, output_path}}} -> [{output_path, source_path}]
      {_source_path, _other} -> []
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.filter(fn {_output_path, sources} -> length(sources) > 1 end)
    |> Enum.sort()
    |> Enum.map(fn {output_path, sources} ->
      {:duplicate_output_path, output_path, Enum.sort(sources)}
    end)
  end

  # The same hazard as two files publishing one path, one level up: `documents`
  # is keyed by identity, and the two slides layouts are one identity.
  defp duplicate_documents(classified) do
    classified
    |> documents()
    |> Enum.group_by(fn {ref, _source_path} -> {DocumentRef.dir(ref), ref.type} end)
    |> Enum.filter(fn {_document, written} -> length(written) > 1 end)
    |> Enum.sort()
    |> Enum.map(fn {{chapter, type}, written} ->
      {:duplicate_document, chapter, type, written |> Enum.map(&elem(&1, 1)) |> Enum.sort()}
    end)
  end

  # A chapter directory is only visible through the documents it holds, which is
  # enough: a directory holding none of them publishes files nobody links to
  # rather than a chapter anything can be recorded against.
  defp duplicate_chapter_numbers(classified) do
    classified
    |> documents()
    |> Enum.group_by(fn {ref, _source_path} -> ref.num end, fn {ref, _source_path} ->
      DocumentRef.dir(ref)
    end)
    |> Enum.map(fn {num, chapters} -> {num, chapters |> Enum.uniq() |> Enum.sort()} end)
    |> Enum.filter(fn {_num, chapters} -> length(chapters) > 1 end)
    |> Enum.sort()
    |> Enum.map(fn {num, chapters} -> {:duplicate_chapter_number, num, chapters} end)
  end

  # The two rules are checked independently, so a chapter breaking both is told
  # about both: the second is not a consequence of the first, and an author
  # fixing one file at a time would otherwise be sent back for a second run.
  defp chapter_invariants(classified) do
    classified
    |> documents()
    |> Enum.group_by(fn {ref, _source_path} -> DocumentRef.dir(ref) end, fn {ref, source_path} ->
      {ref.type, source_path}
    end)
    |> Enum.sort()
    |> Enum.flat_map(fn {chapter, written} ->
      by_type = Map.new(written)

      subject_and_exercise(chapter, by_type) ++ exercise_with_slides(chapter, by_type)
    end)
  end

  defp documents(classified) do
    Enum.flat_map(classified, fn
      {source_path, {:ok, {:document, ref}}} -> [{ref, source_path}]
      {_source_path, _other} -> []
    end)
  end

  defp subject_and_exercise(chapter, %{subject: subject, exercise: exercise}),
    do: [{:subject_and_exercise, chapter, Enum.sort([subject, exercise])}]

  defp subject_and_exercise(_chapter, _documents), do: []

  defp exercise_with_slides(chapter, %{exercise: exercise, slides: slides}),
    do: [{:exercise_with_slides, chapter, Enum.sort([exercise, slides])}]

  defp exercise_with_slides(_chapter, _documents), do: []
end
