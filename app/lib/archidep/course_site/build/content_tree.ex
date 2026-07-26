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

  @roots ["_course", "_cheatsheets"]

  @chapter_regex ~r{\A_course/([1-9]\d\d-[^/]+)/(.+)\z}
  @cheatsheet_regex ~r{\A_cheatsheets/([^/]+)/(.+)\z}
  @cheatsheet_document_regex ~r{\A_cheatsheets/([^/]+)/cheatsheet\.md\z}

  # Why a published path must not need percent-encoding:
  # `ArchiDep.CourseSite.Urls.PageAssetManifest`.
  @url_safe_regex ~r{\A[A-Za-z0-9._-]+\z}

  @doc """
  The directories of the content tree a build reads, relative to the content
  directory.

      iex> ContentTree.roots()
      ["_course", "_cheatsheets"]
  """
  @spec roots() :: [String.t()]
  def roots, do: @roots

  @doc """
  Sort the source paths of the content directory into what a build makes of
  them.

  Paths are relative to the content directory and separated by slashes, the
  same way `ArchiDep.CourseSite.DocumentRef.parse_source_path/1` reads them.
  Every offending path is reported rather than the first, since a build that
  stops at one makes a content directory take as many runs to fix as it has
  mistakes.
  """
  @spec plan([String.t()]) :: {:ok, t()} | {:error, nonempty_list(error())}
  def plan(source_paths) when is_list(source_paths) do
    classified = Enum.map(source_paths, &{&1, classify(&1)})

    errors =
      Enum.flat_map(classified, fn
        {_source_path, {:error, error}} -> [error]
        {_source_path, {:ok, _entry}} -> []
      end) ++ collisions(classified)

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
end
