defmodule ArchiDep.CourseSite.Archives.Mapping do
  @moduledoc """
  What every page of every archived edition has become in the current one.

  This is the whole of the `/latest` resolver: a map from an archived page's own
  path — the value its banner hands over — to the page of the current course
  that superseded it, or to `:gone`. It is built once, while the application
  compiles, from the [manifests](`ArchiDep.CourseSite.Archives.Manifest`) of the
  finished editions, the [overrides](`ArchiDep.CourseSite.Archives.Overrides`)
  the course declares, and the current `ArchiDep.CourseSite.Structure`.

  Building it is where the guarantee lives: **an archived page that resolves to
  nothing fails the build**, listing every offender rather than the first. An
  archive is frozen and its banner cannot be re-pointed, so a rename that breaks
  the correspondence has to be caught here, by whoever made it, rather than by a
  reader clicking a link years later.

  ## How a page is matched

  An **override wins** wherever one is declared, because it is the course saying
  outright where a page went and there is no reading under which the answer
  worked out from a slug should beat it. Otherwise a page is matched
  automatically, on the *kind and slug* of the identity its edition recorded —
  never on its number, so renumbering a chapter that kept its name costs no
  entry at all. That automatic rule is what keeps the yearly cost of this
  mechanism to the diff.

  A slug the current edition uses twice is refused rather than guessed at: two
  chapters answering to one name make the automatic match a coin toss, so such a
  page is reported and an override has to say which one it is.

  ## Why nothing here validates the value it is given

  A `to` value arrives from a query string and is therefore untrusted, but it is
  only ever a key looked up in this map — never a path joined onto anything,
  never a redirect target. Every key is one this application generated, of the
  shape `/<year>/<page path>`; a value that is not one of them simply misses. So
  there is nothing to sanitise, and a check that a value is not off-site or not
  `..` would be a rule to maintain in place of a guarantee already held by
  construction.
  """

  alias ArchiDep.CourseSite.Archives.Manifest
  alias ArchiDep.CourseSite.Archives.Overrides
  alias ArchiDep.CourseSite.PageRef
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Cheatsheet

  @enforce_keys [:entries]
  defstruct [:entries]

  @type entry :: PageRef.t() | :gone

  @type t :: %__MODULE__{
          entries: %{String.t() => entry()}
        }

  @type error ::
          {:duplicate_manifest, String.t()}
          | {:unresolved, String.t(), String.t()}
          | {:ambiguous, String.t(), String.t(), PageRef.identity()}
          | {:unknown_override_edition, String.t()}
          | {:unknown_override_source, String.t(), String.t()}
          | {:unknown_override_target, String.t(), String.t(), String.t()}

  @doc """
  Work out what every page of every archived edition has become, refusing the
  archives outright if any page of them resolves to nothing.
  """
  @spec build([Manifest.t()], Overrides.t(), Structure.t()) ::
          {:ok, t()} | {:error, nonempty_list(error())}
  def build(manifests, %Overrides{} = overrides, %Structure{} = structure)
      when is_list(manifests) do
    current = current_pages(structure)

    with :ok <- one_manifest_per_edition(manifests),
         :ok <- overrides_of_archived_editions(manifests, overrides),
         {:ok, entries} <- resolve_pages(manifests, overrides, current) do
      {:ok, %__MODULE__{entries: entries}}
    end
  end

  @doc """
  What the current edition holds in place of the archived page a reader arrived
  with, if it is a page of an archived edition at all.

  The path returned alongside `:gone` is the key that matched — this
  application's own — so that a page saying there is no equivalent can still
  link back to the archive without ever echoing what it was given.
  """
  @spec fetch(t(), term()) :: {:ok, PageRef.t()} | {:gone, String.t()} | :error
  def fetch(%__MODULE__{entries: entries}, to) when is_binary(to) do
    case Map.fetch(entries, to) do
      {:ok, :gone} -> {:gone, to}
      {:ok, page} -> {:ok, page}
      :error -> :error
    end
  end

  def fetch(%__MODULE__{}, _to), do: :error

  @doc """
  The mapping as plain data, keyed by each archived page's own path.

  It is a map rather than a set of function clauses so that a build can emit it
  as it stands, and a static resolver reading `location.search` against it can
  answer these URLs once this application is gone.
  """
  @spec entries(t()) :: %{String.t() => entry()}
  def entries(%__MODULE__{entries: entries}), do: entries

  @doc """
  Describe an archived page the current edition cannot account for.
  """
  @spec format_error(error()) :: String.t()
  def format_error({:duplicate_manifest, edition}),
    do: "Edition #{edition} is archived twice"

  def format_error({:unresolved, edition, path}),
    do:
      "Edition #{edition} published #{inspect(path)}, which the course no longer holds; say where it went in course/archives.yml, or declare it gone"

  def format_error({:ambiguous, edition, path, identity}),
    do:
      "Edition #{edition} published #{inspect(path)}, and the course now holds more than one #{describe(identity)}; say which one it is in course/archives.yml"

  def format_error({:unknown_override_edition, edition}),
    do: "course/archives.yml declares edition #{edition}, which is not archived"

  def format_error({:unknown_override_source, edition, path}),
    do: "course/archives.yml sends #{inspect(path)}, which edition #{edition} never published"

  def format_error({:unknown_override_target, edition, path, target}),
    do:
      "course/archives.yml sends edition #{edition}'s #{inspect(path)} to #{inspect(target)}, which the course does not hold"

  defp current_pages(%Structure{} = structure) do
    pages =
      [:home] ++
        Enum.flat_map(Structure.chapters(structure), &chapter_pages/1) ++
        Enum.map(structure.cheatsheets, &Cheatsheet.page_ref/1)

    %{
      by_match: Enum.reduce(pages, %{}, &index_by_match/2),
      by_path: Map.new(pages, &{PageRef.output_path(&1), &1})
    }
  end

  defp chapter_pages(%Chapter{} = chapter) do
    slides = if Chapter.slides?(chapter), do: [{:document, chapter.slides}], else: []
    [Chapter.page_ref(chapter) | slides]
  end

  defp index_by_match(page, index) do
    key = page |> PageRef.identity() |> match_key()
    Map.update(index, key, page, fn _already_there -> :ambiguous end)
  end

  # The number a chapter carries is deliberately not part of the key. A chapter
  # renumbered but not renamed is the same chapter at a new address, which is
  # exactly the correspondence this resolver exists to keep, and matching on the
  # number would make every reordering of the course a page of overrides.
  defp match_key(:home), do: :home
  defp match_key({:chapter, _num, slug}), do: {:chapter, slug}
  defp match_key({:chapter_slides, _num, slug}), do: {:chapter_slides, slug}
  defp match_key({:cheatsheet, slug}), do: {:cheatsheet, slug}

  defp one_manifest_per_edition(manifests) do
    manifests
    |> Enum.frequencies_by(& &1.edition)
    |> Enum.filter(fn {_edition, count} -> count > 1 end)
    |> Enum.sort()
    |> Enum.map(fn {edition, _count} -> {:duplicate_manifest, edition} end)
    |> none()
  end

  defp overrides_of_archived_editions(manifests, overrides) do
    archived = MapSet.new(manifests, & &1.edition)

    overrides
    |> Overrides.editions()
    |> Enum.reject(&MapSet.member?(archived, &1))
    |> Enum.map(&{:unknown_override_edition, &1})
    |> none()
  end

  defp resolve_pages(manifests, overrides, current) do
    {entries, errors} =
      Enum.reduce(manifests, {%{}, []}, &resolve_manifest(&1, overrides, current, &2))

    case Enum.reverse(errors) do
      [] -> {:ok, entries}
      [_first | _rest] = errors -> {:error, errors}
    end
  end

  defp resolve_manifest(%Manifest{edition: edition, pages: pages}, overrides, current, acc) do
    declared = Overrides.entries(overrides, edition)

    acc = Enum.reduce(pages, acc, &resolve_page(edition, &1, declared, current, &2))

    {entries, errors} = acc
    published = MapSet.new(pages, fn {path, _identity} -> path end)
    {entries, dangling(declared, published, edition) ++ errors}
  end

  # An override for a page its edition never published is dead weight that will
  # never be read, and most often a typo in the path it was meant to send.
  defp dangling(declared, published, edition),
    do:
      declared
      |> Map.keys()
      |> Enum.reject(&MapSet.member?(published, &1))
      |> Enum.sort(:desc)
      |> Enum.map(&{:unknown_override_source, edition, &1})

  defp resolve_page(edition, {path, identity}, declared, current, {entries, errors}) do
    key = PageRef.edition_path(edition, path)

    case resolution(edition, path, identity, declared, current) do
      {:ok, entry} -> {Map.put(entries, key, entry), errors}
      {:error, error} -> {entries, [error | errors]}
    end
  end

  defp resolution(edition, path, identity, declared, current) do
    case Map.fetch(declared, path) do
      {:ok, :gone} -> {:ok, :gone}
      {:ok, {:page, target}} -> declared_page(edition, path, target, current)
      :error -> matched_page(edition, path, identity, current)
    end
  end

  defp declared_page(edition, path, target, %{by_path: by_path}) do
    case Map.fetch(by_path, target) do
      {:ok, page} -> {:ok, page}
      :error -> {:error, {:unknown_override_target, edition, path, target}}
    end
  end

  defp matched_page(edition, path, identity, %{by_match: by_match}) do
    case Map.fetch(by_match, match_key(identity)) do
      {:ok, :ambiguous} -> {:error, {:ambiguous, edition, path, identity}}
      {:ok, page} -> {:ok, page}
      :error -> {:error, {:unresolved, edition, path}}
    end
  end

  defp describe(:home), do: "home page"
  defp describe({:chapter, _num, slug}), do: "#{inspect(slug)} chapter"
  defp describe({:chapter_slides, _num, slug}), do: "#{inspect(slug)} slide deck"
  defp describe({:cheatsheet, slug}), do: "#{inspect(slug)} cheatsheet"

  defp none([]), do: :ok
  defp none([_first | _rest] = errors), do: {:error, errors}
end
