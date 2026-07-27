defmodule ArchiDep.CourseSite.Structure do
  @moduledoc """
  What the course is: its sections, the chapters of each, and its cheatsheets,
  in reading order.

  This is the *structure* of the course and nothing else. A chapter's progress —
  whether it is done, due, next or still to come — changes on every teaching
  session and is read from a source of its own at build time, so none of it is
  here: this value is a function of the content directory alone, which is what
  lets `ArchiDep.CourseSite.Material` compile it.

  ## What it is made of

  Three inputs, none of them a file: `plan/3` is handed the content directory as
  `ArchiDep.CourseSite.Build.ContentTree` has already sorted it, the front
  matter of every page of it, and the declarations — the sections of the course
  and the order of its cheatsheets, which nothing in the content directory
  states.

  The front matter arrives already parsed and keyed by
  `ArchiDep.CourseSite.PageRef`, because a build parses each source once and
  renders it too; what a page is called is the same reading either way.

  ## A chapter is the unit

  The material lists a chapter once, whatever documents it holds, and
  `ArchiDep.CourseSite.Structure.Chapter` is that entry: a page and, beside it,
  the deck the page presents. So there is no rule here that hides a chapter's
  deck when it also has a subject — the deck was never a second entry to be
  filtered back out. That rests on the rules
  `ArchiDep.CourseSite.Build.ContentTree` enforces over a chapter directory, and
  this module assumes a tree that passed them: it is handed the documents of a
  chapter, not the question of whether they may sit together.

  ## What it refuses

  A section is declared and a chapter names one with the first digit of its
  number, so the two can disagree; a title is prose an author may forget to
  write. Neither fails loudly on its own — an undeclared section is a chapter
  with no section title at all, a missing title an empty string in the
  navigation and in the name of a PDF — so each is refused here, with every
  offending document reported rather than the first. The declarations are the
  exception: nothing else can be trusted when the list of sections cannot be
  read, so those are reported alone.
  """

  alias ArchiDep.CourseSite.Build.ContentTree
  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.PageRef
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Cheatsheet
  alias ArchiDep.CourseSite.Structure.Section

  @enforce_keys [:sections, :cheatsheets]
  defstruct [:sections, :cheatsheets]

  @type front_matter :: %{String.t() => term()}

  @type t :: %__MODULE__{
          sections: [Section.t()],
          cheatsheets: [Cheatsheet.t()]
        }

  @type error ::
          {:malformed_declarations, String.t()}
          | {:duplicate_section_slug, String.t(), [String.t()]}
          | {:unknown_section, String.t(), pos_integer()}
          | {:empty_section, pos_integer(), String.t()}
          | {:missing_title, String.t()}
          | {:invalid_title, String.t(), term()}
          | {:invalid_graded, String.t(), term()}
          | {:graded_non_exercise, String.t()}
          | {:invalid_sidebar_title, String.t(), term()}
          | {:unlisted_cheatsheet, String.t()}
          | {:missing_cheatsheet, String.t()}

  @doc """
  Work out what the course is from what a build has read of it.

  The declarations are the decoded contents of the course's data file: a mapping
  with a `sections` list of titles, in order, and a `cheatsheets` list of slugs,
  also in order. They are validated here rather than by whatever read the file,
  so that `ArchiDep.CourseSite.Build` stays the one place that fetches bytes.

  The front matter must cover every document and cheatsheet of the tree. A page
  missing from it is the caller having read one thing and planned another, not a
  fact about the content, and raises `ArgumentError`.
  """
  @spec plan(ContentTree.t(), %{PageRef.t() => front_matter()}, term()) ::
          {:ok, t()} | {:error, nonempty_list(error())}
  def plan(%ContentTree{} = tree, front_matter, declarations) when is_map(front_matter) do
    case declared(declarations) do
      {:ok, {section_titles, cheatsheet_slugs}} ->
        build(tree, front_matter, section_titles, cheatsheet_slugs)

      {:error, errors} ->
        {:error, errors}
    end
  end

  @doc """
  Every chapter of the course, in reading order.
  """
  @spec chapters(t()) :: [Chapter.t()]
  def chapters(%__MODULE__{sections: sections}), do: Enum.flat_map(sections, & &1.chapters)

  @doc """
  Look up a section by its number.
  """
  @spec fetch_section(t(), pos_integer()) :: {:ok, Section.t()} | :error
  def fetch_section(%__MODULE__{sections: sections}, num) when is_integer(num),
    do: sections |> Enum.find(&(Section.num(&1) == num)) |> wrap()

  @doc """
  Look up a chapter by its number.
  """
  @spec fetch_chapter(t(), pos_integer()) :: {:ok, Chapter.t()} | :error
  def fetch_chapter(%__MODULE__{} = structure, num) when is_integer(num),
    do: structure |> chapters() |> Enum.find(&(Chapter.num(&1) == num)) |> wrap()

  @doc """
  Look up a chapter by its number and its slug.

  A chapter that has been renumbered or renamed is a different chapter, which is
  what makes this the form to name one from outside the course material: the
  application links to "chapter 402, run-virtual-server" and either half going
  stale is a link that no longer means what it said.

  The **type** of the chapter's page is deliberately not part of the lookup. A
  subject and an exercise are published at the same URL by design, so a chapter
  turned from one into the other is still the same chapter at the same address,
  and refusing it here would fail over a content change that cannot break a
  link.
  """
  @spec fetch_chapter(t(), pos_integer(), String.t()) :: {:ok, Chapter.t()} | :error
  def fetch_chapter(%__MODULE__{} = structure, num, slug)
      when is_integer(num) and is_binary(slug),
      do:
        structure
        |> chapters()
        |> Enum.find(&(Chapter.num(&1) == num and Chapter.slug(&1) == slug))
        |> wrap()

  @doc """
  Look up a chapter by its number and its slug, raising when the course has no
  such chapter.

  Use this where a missing chapter is a stale reference the application wrote
  rather than a fact about the content, the same distinction
  `ArchiDep.CourseSite.Urls.resolve!/3` draws.
  """
  @spec chapter!(t(), pos_integer(), String.t()) :: Chapter.t()
  def chapter!(%__MODULE__{} = structure, num, slug) do
    case fetch_chapter(structure, num, slug) do
      {:ok, chapter} -> chapter
      :error -> raise ArgumentError, "The course has no chapter #{num}-#{slug}"
    end
  end

  @doc """
  Look up a cheatsheet by its slug.
  """
  @spec fetch_cheatsheet(t(), String.t()) :: {:ok, Cheatsheet.t()} | :error
  def fetch_cheatsheet(%__MODULE__{cheatsheets: cheatsheets}, slug) when is_binary(slug),
    do: cheatsheets |> Enum.find(&(&1.slug == slug)) |> wrap()

  @doc """
  Look up a cheatsheet by its slug, raising when the course has no such
  cheatsheet.

  Use this where a missing cheatsheet is a stale reference rather than a fact
  about the content, as for `chapter!/3`.
  """
  @spec cheatsheet!(t(), String.t()) :: Cheatsheet.t()
  def cheatsheet!(%__MODULE__{} = structure, slug) do
    case fetch_cheatsheet(structure, slug) do
      {:ok, cheatsheet} -> cheatsheet
      :error -> raise ArgumentError, "The course has no #{slug} cheatsheet"
    end
  end

  @doc """
  Describe what is wrong with what a build read of the course.
  """
  @spec format_error(error()) :: String.t()
  def format_error({:malformed_declarations, why}),
    do: "The course declarations are invalid: #{why}"

  def format_error({:duplicate_section_slug, slug, titles}),
    do:
      "Sections #{Enum.map_join(titles, " and ", &inspect/1)} are both named #{inspect(slug)} in the navigation"

  def format_error({:unknown_section, chapter, section}),
    do: "Chapter #{inspect(chapter)} is in section #{section}, which is not declared"

  def format_error({:empty_section, index, title}),
    do: "Section #{index} (#{inspect(title)}) has no chapters"

  def format_error({:missing_title, source_path}),
    do: "Document #{inspect(source_path)} has no title"

  def format_error({:invalid_title, source_path, value}),
    do: "Document #{inspect(source_path)} has #{inspect(value)} as its title"

  def format_error({:invalid_graded, source_path, value}),
    do:
      "Document #{inspect(source_path)} declares #{inspect(value)} as graded rather than true or false"

  def format_error({:graded_non_exercise, source_path}),
    do: "Document #{inspect(source_path)} is graded, which only an exercise can be"

  def format_error({:invalid_sidebar_title, source_path, value}),
    do: "Document #{inspect(source_path)} has #{inspect(value)} as its title in a list"

  def format_error({:unlisted_cheatsheet, slug}),
    do: "Cheatsheet #{inspect(slug)} is not one of the declared cheatsheets"

  def format_error({:missing_cheatsheet, slug}),
    do:
      "Cheatsheet #{inspect(slug)} is declared but the content directory holds no such cheatsheet"

  defp wrap(nil), do: :error
  defp wrap(found), do: {:ok, found}

  defp build(tree, front_matter, section_titles, cheatsheet_slugs) do
    sections =
      section_titles
      |> Enum.with_index(1)
      |> Enum.map(fn {title, index} -> Section.new(index, title) end)

    errors =
      duplicate_section_slugs(sections) ++
        unknown_sections(tree, sections) ++
        empty_sections(tree, sections) ++
        page_errors(tree, front_matter) ++
        cheatsheet_list_errors(tree, cheatsheet_slugs)

    case errors do
      [] -> {:ok, assemble(tree, front_matter, sections, cheatsheet_slugs)}
      [_first | _rest] -> {:error, errors}
    end
  end

  defp assemble(tree, front_matter, sections, cheatsheet_slugs) do
    chapters = chapters_of(tree, front_matter)

    %__MODULE__{
      sections:
        Enum.map(sections, fn section ->
          %{section | chapters: Enum.filter(chapters, &(Chapter.section(&1) == section.index))}
        end),
      cheatsheets: Enum.map(cheatsheet_slugs, &cheatsheet_of(&1, front_matter))
    }
  end

  defp chapters_of(%ContentTree{documents: documents}, front_matter) do
    documents
    |> Map.keys()
    |> Enum.group_by(&DocumentRef.dir/1)
    |> Enum.map(fn {_chapter, refs} -> chapter_of(refs, front_matter) end)
    |> Enum.sort_by(&Chapter.num/1)
  end

  # The page of a chapter is its subject, its exercise or its deck, in that
  # order, and its deck is a second document only when the page is not the deck
  # itself. A chapter holding both a subject and an exercise would make that
  # order a choice; `ContentTree` refuses one, which is why there is no choice
  # to make here.
  defp chapter_of(refs, front_matter) do
    by_type = Map.new(refs, &{&1.type, &1})
    page = by_type[:subject] || by_type[:exercise] || by_type[:slides]
    slides = if page.type == :slides, do: nil, else: by_type[:slides]
    page_front_matter = Map.fetch!(front_matter, {:document, page})

    Chapter.new(page, Map.fetch!(page_front_matter, "title"),
      slides: slides,
      graded?: Map.get(page_front_matter, "graded", false)
    )
  end

  defp cheatsheet_of(slug, front_matter) do
    page_front_matter = Map.fetch!(front_matter, {:cheatsheet, slug})

    Cheatsheet.new(
      slug,
      Map.fetch!(page_front_matter, "title"),
      Map.get(page_front_matter, "sidebar_title")
    )
  end

  # Two sections whose titles slug alike are two `<input>` elements under one
  # identifier in the material's navigation, so folding one folds the other.
  defp duplicate_section_slugs(sections) do
    sections
    |> Enum.group_by(&Section.slug/1, & &1.title)
    |> Enum.filter(fn {_slug, titles} -> length(titles) > 1 end)
    |> Enum.sort()
    |> Enum.map(fn {slug, titles} -> {:duplicate_section_slug, slug, titles} end)
  end

  defp unknown_sections(tree, sections) do
    declared = length(sections)

    tree
    |> chapter_sections()
    |> Enum.filter(fn {_chapter, section} -> section > declared end)
    |> Enum.map(fn {chapter, section} -> {:unknown_section, chapter, section} end)
  end

  # A section is written down by hand, so one no chapter is numbered for is a
  # heading with nothing under it rather than a section of the course.
  defp empty_sections(tree, sections) do
    occupied = tree |> chapter_sections() |> MapSet.new(fn {_chapter, section} -> section end)

    sections
    |> Enum.reject(&MapSet.member?(occupied, &1.index))
    |> Enum.map(&{:empty_section, &1.index, &1.title})
  end

  defp chapter_sections(%ContentTree{documents: documents}) do
    documents
    |> Map.keys()
    |> Enum.map(&{DocumentRef.dir(&1), div(&1.num, 100)})
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp page_errors(tree, front_matter) do
    Enum.flat_map(pages(tree), fn {page, source_path} ->
      page_front_matter = front_matter!(front_matter, page, source_path)

      title_error(source_path, page_front_matter) ++
        graded_error(page, source_path, page_front_matter) ++
        sidebar_title_error(page, source_path, page_front_matter)
    end)
  end

  defp pages(%ContentTree{documents: documents, cheatsheets: cheatsheets}) do
    documents = Enum.map(documents, fn {ref, source_path} -> {{:document, ref}, source_path} end)

    cheatsheets =
      Enum.map(cheatsheets, fn {slug, source_path} -> {{:cheatsheet, slug}, source_path} end)

    Enum.sort_by(documents ++ cheatsheets, &elem(&1, 1))
  end

  defp title_error(source_path, front_matter) do
    case Map.fetch(front_matter, "title") do
      {:ok, title} when is_binary(title) ->
        blank_error(title, {:invalid_title, source_path, title})

      {:ok, other} ->
        [{:invalid_title, source_path, other}]

      :error ->
        [{:missing_title, source_path}]
    end
  end

  defp graded_error(page, source_path, front_matter) do
    case Map.fetch(front_matter, "graded") do
      {:ok, true} -> non_exercise_error(page, {:graded_non_exercise, source_path})
      {:ok, false} -> []
      {:ok, other} -> [{:invalid_graded, source_path, other}]
      :error -> []
    end
  end

  # A cheatsheet is the only thing the course gives a shorter name to, so it is
  # the only place a shorter name means anything.
  defp sidebar_title_error({:cheatsheet, _slug}, source_path, front_matter) do
    case Map.fetch(front_matter, "sidebar_title") do
      {:ok, title} when is_binary(title) ->
        blank_error(title, {:invalid_sidebar_title, source_path, title})

      {:ok, other} ->
        [{:invalid_sidebar_title, source_path, other}]

      :error ->
        []
    end
  end

  defp sidebar_title_error(_page, _source_path, _front_matter), do: []

  defp blank_error(title, error), do: if(String.trim(title) == "", do: [error], else: [])

  defp non_exercise_error({:document, %DocumentRef{type: :exercise}}, _error), do: []
  defp non_exercise_error(_page, error), do: [error]

  defp cheatsheet_list_errors(%ContentTree{cheatsheets: cheatsheets}, declared) do
    published = cheatsheets |> Map.keys() |> MapSet.new()
    listed = MapSet.new(declared)

    Enum.map(sorted_difference(published, listed), &{:unlisted_cheatsheet, &1}) ++
      Enum.map(sorted_difference(listed, published), &{:missing_cheatsheet, &1})
  end

  defp sorted_difference(left, right), do: left |> MapSet.difference(right) |> Enum.sort()

  defp front_matter!(front_matter, page, source_path) do
    case Map.fetch(front_matter, page) do
      {:ok, page_front_matter} when is_map(page_front_matter) ->
        page_front_matter

      {:ok, other} ->
        raise ArgumentError,
              "Front matter of #{inspect(source_path)} must be a map, got: #{inspect(other)}"

      :error ->
        raise ArgumentError, "No front matter was given for #{inspect(source_path)}"
    end
  end

  defp declared(declarations) when is_map(declarations) do
    sections = declared_sections(Map.get(declarations, "sections"))
    cheatsheets = declared_cheatsheets(Map.get(declarations, "cheatsheets"))

    case Enum.flat_map([sections, cheatsheets], &errors_of/1) do
      [] -> {:ok, {value_of(sections), value_of(cheatsheets)}}
      [_first | _rest] = errors -> {:error, errors}
    end
  end

  defp declared(other), do: malformed("expected a mapping, got: #{inspect(other)}")

  defp declared_sections(nil), do: malformed(~s{the "sections" key is missing})

  defp declared_sections(sections) when is_list(sections) do
    titles = Enum.map(sections, &section_title/1)

    if Enum.all?(titles, &(&1 != :error)),
      do: {:ok, titles},
      else:
        malformed(
          ~s{expected "sections" to be a list of mappings each with a non-empty title, got: #{inspect(sections)}}
        )
  end

  defp declared_sections(other),
    do: malformed(~s{expected "sections" to be a list, got: #{inspect(other)}})

  defp section_title(%{"title" => title}) when is_binary(title) do
    if String.trim(title) == "", do: :error, else: title
  end

  defp section_title(_section), do: :error

  defp declared_cheatsheets(nil), do: malformed(~s{the "cheatsheets" key is missing})

  defp declared_cheatsheets(slugs) when is_list(slugs) do
    cond do
      Enum.any?(slugs, &(not (is_binary(&1) and String.trim(&1) != ""))) ->
        malformed(
          ~s{expected "cheatsheets" to be a list of non-empty slugs, got: #{inspect(slugs)}}
        )

      length(Enum.uniq(slugs)) != length(slugs) ->
        malformed(~s{the "cheatsheets" key lists the same cheatsheet more than once})

      true ->
        {:ok, slugs}
    end
  end

  defp declared_cheatsheets(other),
    do: malformed(~s{expected "cheatsheets" to be a list, got: #{inspect(other)}})

  defp malformed(why), do: {:error, [{:malformed_declarations, why}]}

  defp errors_of({:error, errors}), do: errors
  defp errors_of({:ok, _value}), do: []

  defp value_of({:ok, value}), do: value
end
