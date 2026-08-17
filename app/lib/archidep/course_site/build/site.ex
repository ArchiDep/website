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

  ## Where a file goes

  A build writes into the directory its **mount point** names, so an edition's
  own files — its pages, the two it makes of itself — go under
  `ArchiDep.CourseSite.Urls.UrlContext.edition_prefix/1` and the files anchored
  at the mount point go beside it, which is exactly the split
  `ArchiDep.CourseSite.Urls` emits URLs for. A build that names no edition puts
  the two in the same place, and nothing else about it changes.

  The home page is the one page that may be written **twice**: while its edition
  is being taught it answers at the mount point as well as under the edition,
  and only an archived edition keeps it under its own prefix alone. The same
  bytes serve both, which holds because a page's own URLs are the seam's and the
  home page has no file sitting next to it to address relatively.

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
  alias ArchiDep.CourseSite.Build.NotFound
  alias ArchiDep.CourseSite.Build.PdfNames
  alias ArchiDep.CourseSite.Build.SearchIndex
  alias ArchiDep.CourseSite.Build.SearchIndex.Entry
  alias ArchiDep.CourseSite.Build.Site.Inputs
  alias ArchiDep.CourseSite.Build.Site.Options
  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Layout.LayoutContext
  alias ArchiDep.CourseSite.PageRef
  alias ArchiDep.CourseSite.Progress
  alias ArchiDep.CourseSite.Renderer
  alias ArchiDep.CourseSite.Renderer.Markdown
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
  alias ArchiDep.CourseSite.Urls.UrlContext
  alias ArchiDep.CourseSite.Urls.UrlPath

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

  # What the search dialog searches. It is named after the build rather than
  # after its own contents, which it cannot be: it is read off the pages whose
  # `<head>` has to name it.
  @search_file "/search.json"

  # What a static host shows for a path the build never wrote. Alone among the
  # files a build makes of itself it belongs at the mount point rather than
  # under the edition, a host offering one at all offering exactly one — see
  # `ArchiDep.CourseSite.Build.NotFound`.
  @not_found_file "/404.html"

  @enforce_keys [:files, :pages]
  defstruct [:files, :pages]

  @type t :: %__MODULE__{
          files: %{String.t() => binary()},
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
          {:ok, files, pages, entries} -> {[{files, pages, entries} | planned], errors}
          {:error, page_errors} -> {planned, Enum.reverse(page_errors) ++ errors}
        end
      end)

    collect(planned, errors, build_files(inputs, options, statuses), options)
  end

  @doc """
  Describe what a build could not turn into a file.
  """
  @spec format_error(error()) :: String.t()
  def format_error({:unrenderable_document, source_path, error}),
    do: "Document #{source_path} could not be rendered: #{RenderError.message(error)}"

  def format_error({:unlayoutable_page, page, error}),
    do: "Page #{PageRef.output_path(page)} could not be laid out: #{Urls.format_error(error)}"

  # The index goes in over the pages rather than under them, being derived from
  # what they say: a page is a directory holding an `index.html`, so there is no
  # path it could take from one.
  defp collect(planned, [], build, options) do
    {files, pages, entries} =
      planned |> Enum.reverse() |> Enum.reduce({build, [], []}, &merge/2)

    indexed = entries ++ SearchIndex.application_entries(UrlContext.local(options.urls))

    {:ok,
     %__MODULE__{
       files: Map.put(files, search_path(options.urls), search_json(indexed)),
       pages: pages
     }}
  end

  defp collect(_planned, [_first | _rest] = errors, _build, _options),
    do: {:error, Enum.sort(Enum.reverse(errors))}

  defp merge({page_files, page_pages, page_entries}, {files, pages, entries}),
    do: {Map.merge(files, page_files), pages ++ page_pages, entries ++ page_entries}

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
         {:ok, html} <- lay_out(page, content, context, entry, section, inputs, options, statuses),
         {:ok, entries} <- index(page, entry, content, context, options) do
      {:ok, page_files(page, options.urls, html), link_check_pages(page, content, html), entries}
    end
  end

  defp page_files(:home, urls, html) do
    path = PageRef.output_path(:home) <> @page_file
    home = %{(UrlContext.edition_prefix(urls) <> path) => html}

    if UrlContext.home_at_base?(urls), do: Map.put(home, path, html), else: home
  end

  defp page_files(page, urls, html),
    do: %{(UrlContext.edition_prefix(urls) <> PageRef.output_path(page) <> @page_file) => html}

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

  # A page is indexed as the document it is rather than as the page it was laid
  # out into. The chrome says the same words around every page of the site, so a
  # search that read them would answer every query with the whole course.
  #
  # A result is somewhere to go in the copy of the site the dialog is open in,
  # which is why its URLs are the build's own
  # (`ArchiDep.CourseSite.Urls.UrlContext.local/1`) whatever its pages link to —
  # the same reason `archidep.json` describes the copy beside it.
  defp index(page, entry, content, context, options) do
    urls = UrlContext.local(options.urls)

    with {:ok, body} <- indexable(content, context) do
      {:ok, SearchIndex.entries(urls, page, indexed_as(page, entry, context, urls), body)}
    end
  end

  # The site shows a page's opening above its table of contents and the rest of
  # it below, and both halves are the document a reader came for.
  defp indexable(%Page{html: html, excerpt_html: nil}, _context), do: {:ok, html}
  defp indexable(%Page{html: html, excerpt_html: excerpt}, _context), do: {:ok, excerpt <> html}

  # A deck stays Markdown all the way to the browser, so the only HTML there is
  # of one is converted here, to be read and thrown away.
  #
  # It is converted by the Markdown library directly rather than by the
  # renderer, which would do two things to a deck that a deck is not written
  # for: run the rewrites that have already run over it while it was rendered,
  # and hand its code fences to the site's highlighter — and a deck's fences are
  # reveal.js's own, saying which lines to reveal when, which the site's
  # highlighter reads as a malformed decorator and refuses. What is wanted here
  # is neither of those, only the words and the identifiers of the headings
  # between them.
  defp indexable(%Slides{markdown: markdown}, %RenderContext{} = context) do
    case MDEx.to_html(markdown, Markdown.options()) do
      {:ok, html} ->
        {:ok, html}

      {:error, error} ->
        {:error,
         [
           {:unrenderable_document, context.source_path,
            RenderError.new({:markdown, Exception.message(error)}, context.source_path)}
         ]}
    end
  end

  # What a page is in the index before it is read. `search_subtitle` and
  # `search_extra_text` are the two things a page may say about how it is found
  # rather than about what it is: what to show it under, and words to find it by
  # that it does not show.
  defp indexed_as(page, entry, context, urls) do
    front_matter = context.source.front_matter
    title = title(context)

    %Entry{
      id: PageRef.output_path(page),
      type: indexed_type(page, entry),
      url: Urls.resolve!(urls, page),
      title: title,
      subtitle: Map.get(front_matter, "search_subtitle", title),
      extra_text: Map.get(front_matter, "search_extra_text", "")
    }
  end

  # Every document and cheatsheet is named by `ArchiDep.CourseSite.Structure`,
  # which refuses one that is not. The home page is outside the content tree and
  # so outside that rule, and a page with no name of its own is called after the
  # site.
  defp title(context) do
    case Map.get(RenderContext.page_variables(context), "title") do
      title when is_binary(title) and title != "" -> title
      _none -> PageMetadata.title(nil)
    end
  end

  defp indexed_type(:home, _entry), do: "home"
  defp indexed_type({:cheatsheet, _slug}, _entry), do: "cheatsheet"

  defp indexed_type({:document, %DocumentRef{type: :exercise}}, %Chapter{graded?: true}),
    do: "graded-exercise"

  defp indexed_type({:document, %DocumentRef{type: type}}, _entry), do: Atom.to_string(type)

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

  # The files anchored at the mount point go in *under* the three a build makes
  # of itself, so that a course directory holding a `version.json` of its own
  # cannot take the place of the one saying what produced the build.
  defp build_files(inputs, options, statuses) do
    edition = UrlContext.edition_prefix(options.urls)

    Map.merge(inputs.root_files, %{
      (edition <> @course_file) =>
        course_json(inputs.structure, UrlContext.local(options.urls), statuses),
      (edition <> @version_file) => version_json(options.site),
      @not_found_file => NotFound.html(options.urls)
    })
  end

  # The three files below are objects whose keys are written in the order they
  # are stated, for the reason `ArchiDep.CourseSite.Archives.Manifest.to_json/1`
  # gives: a build is a function of its inputs, and a file whose keys come out
  # in the order the atoms of one run happened to be created in is not.
  #
  # The name of a PDF is asked of `PdfNames` rather than read out of the URL
  # context's manifest, which is empty in a build that publishes none — and a
  # build that publishes none is exactly the one this file is printed from.
  #
  # For the same reason the URLs are the build's own
  # (`ArchiDep.CourseSite.Urls.UrlContext.local/1`) whatever its pages say: this
  # describes the copy the consumer is about to walk, so a build printing links
  # to the main site would otherwise send that consumer there too.
  defp course_json(%Structure{} = structure, urls, statuses),
    do:
      encode_json(
        object(
          home: object(home_json(urls)),
          sections: Enum.map(structure.sections, &object(section_json(&1, urls, statuses))),
          cheatsheets: Enum.map(structure.cheatsheets, &object(cheatsheet_json(&1, urls)))
        )
      )

  defp home_json(urls),
    do: [
      url: Urls.resolve!(urls, :home),
      pdf: PdfNames.name(:home)
    ]

  defp section_json(%Section{} = section, urls, statuses),
    do: [
      title: section.title,
      slug: Section.slug(section),
      num: Section.num(section),
      progress: status(statuses, Section.num(section)),
      open: Progress.section_open?(statuses, section),
      docs: Enum.map(section.chapters, &object(chapter_json(&1, urls, statuses)))
    ]

  defp chapter_json(%Chapter{page: %DocumentRef{} = document} = chapter, urls, statuses),
    do: [
      title: chapter.title,
      num: Chapter.num(chapter),
      course_type: Atom.to_string(document.type),
      graded: chapter.graded?,
      course_slug: Chapter.slug(chapter),
      section: Chapter.section(chapter),
      section_chapter: Chapter.section_chapter(chapter),
      progress: status(statuses, Chapter.num(chapter)),
      slides: Chapter.slides?(chapter),
      url: Urls.resolve!(urls, Chapter.page_ref(chapter)),
      pdf: PdfNames.name(Chapter.page_ref(chapter)),
      slides_pdf: slides_pdf(chapter)
    ]

  defp slides_pdf(%Chapter{slides: nil}), do: nil
  defp slides_pdf(%Chapter{slides: %DocumentRef{} = deck}), do: PdfNames.name({:document, deck})

  defp cheatsheet_json(%Cheatsheet{} = cheatsheet, urls),
    do: [
      title: cheatsheet.title,
      sidebar_title: Cheatsheet.sidebar_title(cheatsheet),
      slug: cheatsheet.slug,
      url: Urls.resolve!(urls, Cheatsheet.page_ref(cheatsheet)),
      pdf: PdfNames.name(Cheatsheet.page_ref(cheatsheet))
    ]

  defp search_path(urls),
    do: UrlContext.edition_prefix(urls) <> UrlPath.insert_suffix(@search_file, urls.build_id)

  # `extraText` is written the way the client spells it: this file is a message
  # to a script rather than a record of the build.
  defp search_json(entries),
    do:
      encode_json(
        Enum.map(entries, fn %Entry{} = entry ->
          object(
            id: entry.id,
            type: entry.type,
            url: entry.url,
            title: entry.title,
            subtitle: entry.subtitle,
            text: entry.text,
            extraText: entry.extra_text
          )
        end)
      )

  defp version_json(%SiteInfo{} = site),
    do:
      encode_json(
        object(
          version: site.version,
          git: object(branch: site.git_branch, revision: site.git_revision)
        )
      )

  defp object(pairs), do: Jason.OrderedObject.new(pairs)

  defp encode_json(term), do: Jason.encode!(term) <> "\n"

  defp status(statuses, num), do: statuses |> Map.get(num, :future) |> Atom.to_string()
end
