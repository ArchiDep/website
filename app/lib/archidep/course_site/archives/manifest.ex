defmodule ArchiDep.CourseSite.Archives.Manifest do
  @moduledoc """
  What one finished edition of the course held: its year, and every page it
  published, each with the path it was served at and the identity that edition
  gave it.

  Both halves are recorded because each answers a question the other cannot. The
  **path** is what a reader arrives with, and it is opaque: it is compared for
  equality and never taken apart, because the numbering, the slugging and the
  shape of a URL are all free to change between editions and an archive is
  frozen bytes that can never be re-emitted to match. The **identity** is what
  `ArchiDep.CourseSite.Archives.Mapping` matches against the current course, and
  it is recorded here — by the edition that assigned it — precisely so that
  nothing has to re-derive it from the path later.

  A manifest is written once, at the year-end rollover, by `mix
  archidep.course_site.archives`, and committed. It is generated rather than
  hand-written; the hand-written half of the mapping is
  `ArchiDep.CourseSite.Archives.Overrides`.
  """

  alias ArchiDep.CourseSite.PageRef
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Cheatsheet

  # The version this module writes and reads. A manifest that states another one
  # is refused rather than guessed at: an edition whose pages are identified by
  # something other than a kind and a slug is what a bump is for, and the
  # manifests written before it must go on being read by the clauses that
  # understood them.
  @manifest_version 1

  @enforce_keys [:edition, :pages]
  defstruct [:edition, :pages]

  @type page :: {String.t(), PageRef.identity()}

  @type t :: %__MODULE__{
          edition: String.t(),
          pages: [page()]
        }

  @type error ::
          {:unsupported_manifest_version, term()}
          | {:malformed_manifest, String.t()}
          | {:duplicate_page, String.t()}

  @doc """
  The manifest of an edition holding a given course: its home page, every
  chapter, the slides of the chapters that have them, and every cheatsheet, in
  reading order.
  """
  @spec of(String.t(), Structure.t()) :: t()
  def of(edition, %Structure{} = structure) when is_binary(edition) do
    pages =
      [:home] ++
        Enum.flat_map(Structure.chapters(structure), &chapter_pages/1) ++
        Enum.map(structure.cheatsheets, &Cheatsheet.page_ref/1)

    %__MODULE__{edition: edition, pages: Enum.map(pages, &page/1)}
  end

  @doc """
  The manifest a decoded `course/archives/<year>.json` names.

      iex> Manifest.from_json(%{
      ...>   "version" => 1,
      ...>   "edition" => "2025",
      ...>   "pages" => [
      ...>     %{"path" => "/", "kind" => "home"},
      ...>     %{"path" => "/cheatsheets/git/", "kind" => "cheatsheet", "slug" => "git"}
      ...>   ]
      ...> })
      {:ok,
       %Manifest{
         edition: "2025",
         pages: [{"/", :home}, {"/cheatsheets/git/", {:cheatsheet, "git"}}]
       }}

      iex> Manifest.from_json(%{"version" => 2, "edition" => "2025", "pages" => []})
      {:error, {:unsupported_manifest_version, 2}}

      iex> Manifest.from_json(%{"version" => 1, "edition" => "2025"})
      {:error, {:malformed_manifest, "no \\"pages\\" list"}}
  """
  @spec from_json(term()) :: {:ok, t()} | {:error, error()}
  def from_json(%{"version" => @manifest_version} = manifest) do
    with {:ok, edition} <- edition(manifest),
         {:ok, pages} <- pages(manifest) do
      {:ok, %__MODULE__{edition: edition, pages: pages}}
    end
  end

  def from_json(%{"version" => version}), do: {:error, {:unsupported_manifest_version, version}}

  def from_json(manifest) when is_map(manifest),
    do: {:error, {:malformed_manifest, ~s{no "version"}}}

  def from_json(manifest),
    do: {:error, {:malformed_manifest, "#{inspect(manifest)} is not a map"}}

  @doc """
  The manifest as the file it is committed as.

  The key order and the indentation are fixed, and the pages keep the order they
  are read in, so that a re-run of the rollover on unchanged content produces an
  unchanged file. That is what makes this one of the few places the subsystem
  encodes with `Jason` rather than decoding with `JSON`, which orders neither.
  """
  @spec to_json(t()) :: String.t()
  def to_json(%__MODULE__{edition: edition, pages: pages}),
    do:
      Jason.encode!(
        Jason.OrderedObject.new(
          version: @manifest_version,
          edition: edition,
          pages: Enum.map(pages, &page_json/1)
        ),
        pretty: true
      ) <> "\n"

  @doc """
  Describe what is wrong with an archive manifest.
  """
  @spec format_error(error()) :: String.t()
  def format_error({:unsupported_manifest_version, version}),
    do:
      "Archive manifest version #{inspect(version)} is not version #{@manifest_version}, the one this application reads"

  def format_error({:malformed_manifest, why}), do: "Archive manifest is malformed: #{why}"

  def format_error({:duplicate_page, path}),
    do: "Archive manifest lists #{inspect(path)} twice"

  defp chapter_pages(%Chapter{} = chapter) do
    slides = if Chapter.slides?(chapter), do: [{:document, chapter.slides}], else: []
    [Chapter.page_ref(chapter) | slides]
  end

  defp page(page), do: {PageRef.output_path(page), PageRef.identity(page)}

  defp edition(manifest) do
    case Map.fetch(manifest, "edition") do
      {:ok, edition} when is_binary(edition) -> {:ok, edition}
      {:ok, other} -> {:error, {:malformed_manifest, "#{inspect(other)} is not an edition"}}
      :error -> {:error, {:malformed_manifest, ~s{no "edition"}}}
    end
  end

  defp pages(manifest) do
    case Map.fetch(manifest, "pages") do
      {:ok, pages} when is_list(pages) -> decode_pages(pages)
      {:ok, _other} -> {:error, {:malformed_manifest, ~s{"pages" is not a list}}}
      :error -> {:error, {:malformed_manifest, ~s{no "pages" list}}}
    end
  end

  defp decode_pages(pages) do
    case Enum.reduce_while(pages, {[], MapSet.new()}, &decode_page/2) do
      {:error, _reason} = error -> error
      {decoded, _paths} -> {:ok, Enum.reverse(decoded)}
    end
  end

  defp decode_page(page, {decoded, paths}) do
    with {:ok, path} <- page_path(page),
         :ok <- unseen(path, paths),
         {:ok, identity} <- page_identity(page, path) do
      {:cont, {[{path, identity} | decoded], MapSet.put(paths, path)}}
    else
      {:error, _reason} = error -> {:halt, error}
    end
  end

  defp page_path(%{"path" => path}) when is_binary(path), do: {:ok, path}

  defp page_path(page),
    do: {:error, {:malformed_manifest, "#{inspect(page)} is published at no path"}}

  defp unseen(path, paths),
    do: if(MapSet.member?(paths, path), do: {:error, {:duplicate_page, path}}, else: :ok)

  defp page_identity(%{"kind" => "home"}, _path), do: {:ok, :home}

  defp page_identity(%{"kind" => "chapter", "num" => num, "slug" => slug}, _path)
       when is_integer(num) and num > 0 and is_binary(slug),
       do: {:ok, {:chapter, num, slug}}

  defp page_identity(%{"kind" => "chapter_slides", "num" => num, "slug" => slug}, _path)
       when is_integer(num) and num > 0 and is_binary(slug),
       do: {:ok, {:chapter_slides, num, slug}}

  defp page_identity(%{"kind" => "cheatsheet", "slug" => slug}, _path) when is_binary(slug),
    do: {:ok, {:cheatsheet, slug}}

  defp page_identity(page, path),
    do:
      {:error,
       {:malformed_manifest,
        "#{inspect(path)} is identified as #{inspect(Map.delete(page, "path"))}"}}

  defp page_json({path, :home}), do: Jason.OrderedObject.new(path: path, kind: "home")

  defp page_json({path, {:chapter, num, slug}}),
    do: Jason.OrderedObject.new(path: path, kind: "chapter", num: num, slug: slug)

  defp page_json({path, {:chapter_slides, num, slug}}),
    do: Jason.OrderedObject.new(path: path, kind: "chapter_slides", num: num, slug: slug)

  defp page_json({path, {:cheatsheet, slug}}),
    do: Jason.OrderedObject.new(path: path, kind: "cheatsheet", slug: slug)
end
