defmodule ArchiDep.CourseSite.Layout.LayoutContext do
  @moduledoc """
  Everything a layout is given to wrap one rendered document in: the document
  itself, what the site knows about it, and what the site shows around it.

  It is the seam between what a page *says* and what the site *is*.
  `ArchiDep.CourseSite.Renderer` answers the first and stops there — a
  `ArchiDep.CourseSite.Renderer.Page` is the page's own prose and nothing else,
  and the headings the site shows around one belong to whatever lays it out. So
  everything the surrounding chrome reads is gathered here instead of each
  layout reaching for it, which is what keeps a layout a function of its
  argument.

  Two fields are `nil` for a page that is neither a chapter nor a cheatsheet.
  The home page is the only such page and it is the only one whose title,
  numbering and section come from nowhere: it is not part of the course's
  structure, it introduces it.

  ## Why the progression is here twice

  `statuses` is what the record says about every section and chapter of *this*
  course, which every page draws and which is therefore worked out once for the
  whole build rather than per page. `progress` is the record itself, which the
  home page asks a second question of: what the last session covered
  (`ArchiDep.CourseSite.Progress.last_recorded/3`), which is a question about
  one session rather than about the course.
  """

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.PageRef
  alias ArchiDep.CourseSite.Progress
  alias ArchiDep.CourseSite.Renderer.Page
  alias ArchiDep.CourseSite.Renderer.PageMetadata
  alias ArchiDep.CourseSite.Renderer.Slides
  alias ArchiDep.CourseSite.SiteInfo
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Cheatsheet
  alias ArchiDep.CourseSite.Structure.Section
  alias ArchiDep.CourseSite.Urls.UrlContext

  @enforce_keys [
    :page,
    :source_path,
    :content,
    :metadata,
    :front_matter,
    :structure,
    :progress,
    :statuses,
    :urls,
    :site
  ]
  defstruct [
    :page,
    :source_path,
    :content,
    :metadata,
    :front_matter,
    :structure,
    :progress,
    :statuses,
    :urls,
    :site,
    entry: nil,
    section: nil
  ]

  @typedoc """
  What was rendered: a page in the two pieces the site shows it in, or a deck
  that stays the Markdown a browser converts.
  """
  @type content :: Page.t() | Slides.t()

  @type t :: %__MODULE__{
          page: PageRef.t(),
          source_path: String.t(),
          content: content(),
          metadata: PageMetadata.t(),
          entry: Chapter.t() | Cheatsheet.t() | nil,
          section: Section.t() | nil,
          front_matter: %{String.t() => term()},
          structure: Structure.t(),
          progress: Progress.t(),
          statuses: %{pos_integer() => Progress.status()},
          urls: UrlContext.t(),
          site: SiteInfo.t()
        }

  @doc """
  Gather what a layout needs, raising an `ArgumentError` when a value is
  malformed.

  Options:

  - `:page` (required) — which page this is, as an
    `ArchiDep.CourseSite.PageRef`.
  - `:source_path` (required) — the file it was written in, e.g.
    `"_course/507-dns/subject.md"`. What the "Source code" link points at.
  - `:content` (required) — what the renderer produced.
  - `:metadata` (required) — what the page says about itself, for the `<head>`.
  - `:front_matter` (required) — what the author declared, for the keys only a
    layout reads.
  - `:structure` (required) — the course, for the navigation the site shows
    beside every page.
  - `:progress` (required) — how far the course has got, as the record itself,
    for what the home page says the last session covered.
  - `:statuses` (required) — how far the course has got, per chapter and
    section, for the navigation's colours.
  - `:urls` (required) — the build, as an `ArchiDep.CourseSite.Urls.UrlContext`.
    Also what says whether this build carries the dynamic chrome.
  - `:site` (required) — what the build was produced from, as an
    `ArchiDep.CourseSite.SiteInfo`.
  - `:entry` — the chapter or cheatsheet this page is, or `nil` when it is
    neither.
  - `:section` — the section it belongs to, or `nil` likewise. Carried rather
    than derived because a chapter's number gives only the section's number,
    while its title is prose only the `ArchiDep.CourseSite.Structure.Section`
    holds.
  """
  @spec new(keyword()) :: t()
  def new(opts) when is_list(opts) do
    %__MODULE__{
      page: page!(opts),
      source_path: source_path!(opts),
      content: content!(opts),
      metadata: metadata!(opts),
      front_matter: front_matter!(opts),
      structure: structure!(opts),
      progress: progress!(opts),
      statuses: statuses!(opts),
      urls: urls!(opts),
      site: site!(opts),
      entry: entry!(opts),
      section: section!(opts)
    }
  end

  defp page!(opts) do
    case Keyword.fetch!(opts, :page) do
      :home -> :home
      {:document, %DocumentRef{}} = page -> page
      {:cheatsheet, slug} = page when is_binary(slug) -> page
      other -> raise ArgumentError, "Page must be a page reference, got: #{inspect(other)}"
    end
  end

  defp source_path!(opts) do
    case Keyword.fetch!(opts, :source_path) do
      path when is_binary(path) and path != "" ->
        path

      other ->
        raise ArgumentError, "Source path must be a non-empty string, got: #{inspect(other)}"
    end
  end

  defp content!(opts) do
    case Keyword.fetch!(opts, :content) do
      %Page{} = page -> page
      %Slides{} = slides -> slides
      other -> raise ArgumentError, "Content must be a page or a deck, got: #{inspect(other)}"
    end
  end

  defp metadata!(opts) do
    case Keyword.fetch!(opts, :metadata) do
      %PageMetadata{} = metadata ->
        metadata

      other ->
        raise ArgumentError,
              "Metadata must be a #{inspect(PageMetadata)}, got: #{inspect(other)}"
    end
  end

  defp front_matter!(opts) do
    case Keyword.fetch!(opts, :front_matter) do
      matter when is_map(matter) ->
        named!(matter)

      other ->
        raise ArgumentError, "Front matter must be a map, got: #{inspect(other)}"
    end
  end

  defp named!(matter) do
    if Enum.all?(matter, fn {key, _value} -> is_binary(key) end) do
      matter
    else
      raise ArgumentError, "Front matter must be keyed by strings, got: #{inspect(matter)}"
    end
  end

  defp structure!(opts) do
    case Keyword.fetch!(opts, :structure) do
      %Structure{} = structure ->
        structure

      other ->
        raise ArgumentError, "Structure must be a #{inspect(Structure)}, got: #{inspect(other)}"
    end
  end

  defp progress!(opts) do
    case Keyword.fetch!(opts, :progress) do
      %Progress{} = progress ->
        progress

      other ->
        raise ArgumentError, "Progress must be a #{inspect(Progress)}, got: #{inspect(other)}"
    end
  end

  defp statuses!(opts) do
    case Keyword.fetch!(opts, :statuses) do
      statuses when is_map(statuses) ->
        numbered!(statuses)

      other ->
        raise ArgumentError, "Statuses must be a map, got: #{inspect(other)}"
    end
  end

  defp numbered!(statuses) do
    if Enum.all?(statuses, fn {num, status} ->
         is_integer(num) and num > 0 and status in [:done, :due, :next, :future]
       end) do
      statuses
    else
      raise ArgumentError,
            "Statuses must map chapter numbers to statuses, got: #{inspect(statuses)}"
    end
  end

  defp urls!(opts) do
    case Keyword.fetch!(opts, :urls) do
      %UrlContext{} = urls ->
        urls

      other ->
        raise ArgumentError,
              "URL context must be a #{inspect(UrlContext)}, got: #{inspect(other)}"
    end
  end

  defp site!(opts) do
    case Keyword.fetch!(opts, :site) do
      %SiteInfo{} = site ->
        site

      other ->
        raise ArgumentError, "Site info must be a #{inspect(SiteInfo)}, got: #{inspect(other)}"
    end
  end

  defp entry!(opts) do
    case Keyword.get(opts, :entry) do
      nil ->
        nil

      %Chapter{} = chapter ->
        chapter

      %Cheatsheet{} = cheatsheet ->
        cheatsheet

      other ->
        raise ArgumentError, "Entry must be a chapter or a cheatsheet, got: #{inspect(other)}"
    end
  end

  defp section!(opts) do
    case Keyword.get(opts, :section) do
      nil ->
        nil

      %Section{} = section ->
        section

      other ->
        raise ArgumentError, "Section must be a #{inspect(Section)}, got: #{inspect(other)}"
    end
  end
end
