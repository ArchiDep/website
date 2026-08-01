defmodule ArchiDep.CourseSite.Build.Site do
  @moduledoc """
  Every file a build writes, and what is in each of them.

  Rendering the whole site is a **function**: given the content, the course, how
  far it has got and where the build is published, the set of files and their
  contents follows. So it is worked out here, in one pure step between the reads
  and the writes, which is what makes "reading comes before writing" a shape
  rather than a rule to remember — a planner that cannot touch the filesystem
  cannot write half a build before discovering the rest is wrong.

  ## The order pages are planned in

  The site is walked in the order it is read: the home page, then each section's
  chapters, each chapter's page and the deck it presents, and the cheatsheets
  after them. A chapter is the unit, so a chapter with a subject and a deck is
  two files and one entry — there is no rule hiding a second listing, because
  there is no second listing.

  The home page is the one page belonging to no chapter and no section, and so
  the one laid out with neither. It introduces the course rather than being part
  of it, which is also why it is read from outside the content directory
  (`ArchiDep.CourseSite.Build.home_source/1`).

  ## What is handed to the link check

  A page is recorded as the HTML that was written for it, and a deck **also** as
  the Markdown it stays. The two are complementary rather than redundant: an
  HTML parser hands back the content of a `textarea` as text, so reading the
  written deck finds the URLs of the chrome around it and none of the deck's,
  while the Markdown scan finds the deck's and none of the chrome's. Recording
  only one of them would leave the other unchecked.
  """

  alias ArchiDep.CourseSite.Build.ContentTree
  alias ArchiDep.CourseSite.Build.LinkCheck
  alias ArchiDep.CourseSite.Build.Site.Inputs
  alias ArchiDep.CourseSite.Build.Site.Options
  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Layout.LayoutContext
  alias ArchiDep.CourseSite.PageRef
  alias ArchiDep.CourseSite.Progress
  alias ArchiDep.CourseSite.Renderer
  alias ArchiDep.CourseSite.Renderer.Page
  alias ArchiDep.CourseSite.Renderer.PageMetadata
  alias ArchiDep.CourseSite.Renderer.RenderContext
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.CourseSite.Renderer.Slides
  alias ArchiDep.CourseSite.SiteInfo
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Cheatsheet
  alias ArchiDep.CourseSite.Structure.Section
  alias ArchiDep.CourseSite.Urls

  # A page is published as a directory holding this, which is what a static
  # server answers a request for the directory with.
  @page_file "index.html"

  # What the course is, for the script that prints its slides to PDF — the one
  # consumer of a build that cannot reach into Elixir. It is a build *output*
  # rather than an input: nothing here reads it back.
  @course_file "/archidep.json"

  # What produced the build, for the footer of the site and anyone asking which
  # revision they are looking at.
  @version_file "/version.json"

  @enforce_keys [:files, :pages]
  defstruct [:files, :pages]

  @type t :: %__MODULE__{
          files: %{String.t() => String.t()},
          pages: [LinkCheck.page()]
        }

  @type error ::
          {:unrenderable_document, String.t(), RenderError.t()}
          | {:unlayoutable_page, PageRef.t(), Urls.error()}

  @doc """
  Work out every file a build writes.

  Every page is rendered and laid out before the first failure is reported, so a
  content directory takes one run to fix rather than one run per mistake.
  """
  @spec plan(Inputs.t(), Options.t()) :: {:ok, t()} | {:error, nonempty_list(error())}
  def plan(%Inputs{} = inputs, %Options{} = options) do
    statuses = Progress.statuses(inputs.progress, inputs.structure)

    {planned, errors} =
      inputs.structure
      |> pages()
      |> Enum.reduce({[], []}, fn planned_page, {planned, errors} ->
        case page(planned_page, inputs, options, statuses) do
          {:ok, files, pages} -> {[{files, pages} | planned], errors}
          {:error, page_errors} -> {planned, Enum.reverse(page_errors) ++ errors}
        end
      end)

    collect(planned, errors, build_files(inputs, options, statuses))
  end

  @doc """
  Describe what a build could not turn into a file.
  """
  @spec format_error(error()) :: String.t()
  def format_error({:unrenderable_document, source_path, error}),
    do: "Document #{source_path} could not be rendered: #{RenderError.message(error)}"

  def format_error({:unlayoutable_page, page, error}),
    do: "Page #{PageRef.output_path(page)} could not be laid out: #{Urls.format_error(error)}"

  defp collect(planned, [], build) do
    {files, pages} =
      planned
      |> Enum.reverse()
      |> Enum.reduce({build, []}, fn {page_files, page_pages}, {files, pages} ->
        {Map.merge(files, page_files), pages ++ page_pages}
      end)

    {:ok, %__MODULE__{files: files, pages: pages}}
  end

  defp collect(_planned, [_first | _rest] = errors, _build),
    do: {:error, Enum.sort(Enum.reverse(errors))}

  # Every page of the site, in the order the site is read: the home page, then a
  # chapter's own page and the deck it presents, section by section, and the
  # cheatsheets last. The home page comes first and belongs to neither a chapter
  # nor a section — it is not part of the course's structure, it introduces it,
  # which is why it is the one page carrying no entry.
  defp pages(%Structure{sections: sections, cheatsheets: cheatsheets}) do
    chapters =
      Enum.flat_map(sections, fn %Section{chapters: chapters} = section ->
        Enum.flat_map(chapters, &chapter_pages(&1, section))
      end)

    [{:home, nil, nil} | chapters] ++ Enum.map(cheatsheets, &{Cheatsheet.page_ref(&1), &1, nil})
  end

  defp chapter_pages(%Chapter{slides: nil} = chapter, section),
    do: [{Chapter.page_ref(chapter), chapter, section}]

  defp chapter_pages(%Chapter{slides: deck} = chapter, section),
    do: [{Chapter.page_ref(chapter), chapter, section}, {{:document, deck}, chapter, section}]

  defp page({page, entry, section}, inputs, options, statuses) do
    source = Map.fetch!(inputs.sources, page)
    source_path = source_path(inputs, page)

    context =
      RenderContext.new(
        source: source,
        source_path: source_path,
        urls: options.urls,
        page: page,
        includes: inputs.includes,
        options: options.render_options,
        solutions: Progress.solutions(inputs.progress, page)
      )

    with {:ok, content} <- render(page, context, source_path),
         {:ok, html} <- lay_out(page, content, context, entry, section, inputs, options, statuses) do
      {:ok, %{(PageRef.output_path(page) <> @page_file) => html},
       link_check_pages(page, content, html)}
    end
  end

  defp render(page, context, source_path) do
    result =
      case page do
        {:document, %DocumentRef{type: :slides}} -> Renderer.render_slides(context)
        _page -> Renderer.render_page(context)
      end

    case result do
      {:ok, content} -> {:ok, content}
      {:error, errors} -> {:error, Enum.map(errors, &{:unrenderable_document, source_path, &1})}
    end
  end

  defp lay_out(page, content, context, entry, section, inputs, options, statuses) do
    layout_context =
      LayoutContext.new(
        page: page,
        source_path: context.source_path,
        content: content,
        metadata: PageMetadata.of(context, excerpt(content)),
        entry: entry,
        section: section,
        front_matter: context.source.front_matter,
        structure: inputs.structure,
        progress: inputs.progress,
        statuses: statuses,
        urls: options.urls,
        site: options.site
      )

    case options.layout.document(layout_context) do
      {:ok, html} -> {:ok, html}
      {:error, errors} -> {:error, Enum.map(errors, &{:unlayoutable_page, page, &1})}
    end
  end

  defp excerpt(%Page{excerpt_html: html}), do: html
  defp excerpt(%Slides{}), do: nil

  defp link_check_pages(page, %Slides{markdown: markdown}, html),
    do: [{page, :markdown, markdown}, {page, :html, html}]

  defp link_check_pages(page, %Page{}, html), do: [{page, :html, html}]

  defp source_path(%Inputs{home_source_path: path}, :home), do: path

  defp source_path(%Inputs{tree: %ContentTree{documents: documents}}, {:document, ref}),
    do: Map.fetch!(documents, ref)

  defp source_path(%Inputs{tree: %ContentTree{cheatsheets: cheatsheets}}, {:cheatsheet, slug}),
    do: Map.fetch!(cheatsheets, slug)

  defp build_files(inputs, options, statuses),
    do: %{
      @course_file => course_json(inputs.structure, options.urls, statuses),
      @version_file => version_json(options.site)
    }

  # The key order and the indentation are Jekyll's, so that the file this
  # replaces stays diffable against the one it produced. Elixir's own `JSON`
  # does neither, which is why this is the one place the subsystem encodes with
  # `Jason` rather than decoding with `JSON`.
  defp course_json(%Structure{} = structure, urls, statuses),
    do:
      Jason.encode!(
        Jason.OrderedObject.new(
          sections: Enum.map(structure.sections, &section_json(&1, urls, statuses)),
          cheatsheets: Enum.map(structure.cheatsheets, &cheatsheet_json(&1, urls))
        ),
        pretty: true
      ) <> "\n"

  defp section_json(%Section{} = section, urls, statuses),
    do:
      Jason.OrderedObject.new(
        title: section.title,
        slug: Section.slug(section),
        num: Section.num(section),
        progress: status(statuses, Section.num(section)),
        open: Progress.section_open?(statuses, section),
        docs: Enum.map(section.chapters, &chapter_json(&1, urls, statuses))
      )

  defp chapter_json(%Chapter{page: %DocumentRef{} = document} = chapter, urls, statuses),
    do:
      Jason.OrderedObject.new(
        title: chapter.title,
        num: Chapter.num(chapter),
        course_type: Atom.to_string(document.type),
        graded: chapter.graded?,
        course_slug: Chapter.slug(chapter),
        section: Chapter.section(chapter),
        section_chapter: Chapter.section_chapter(chapter),
        progress: status(statuses, Chapter.num(chapter)),
        slides: Chapter.slides?(chapter),
        url: Urls.resolve!(urls, Chapter.page_ref(chapter))
      )

  defp cheatsheet_json(%Cheatsheet{} = cheatsheet, urls),
    do:
      Jason.OrderedObject.new(
        title: cheatsheet.title,
        sidebar_title: Cheatsheet.sidebar_title(cheatsheet),
        slug: cheatsheet.slug,
        url: Urls.resolve!(urls, Cheatsheet.page_ref(cheatsheet))
      )

  defp version_json(%SiteInfo{} = site) do
    Jason.encode!(
      Jason.OrderedObject.new(
        version: site.version,
        git:
          Jason.OrderedObject.new(
            branch: site.git_branch,
            revision: site.git_revision
          )
      ),
      pretty: true
    ) <> "\n"
  end

  defp status(statuses, num), do: statuses |> Map.get(num, :future) |> Atom.to_string()
end
