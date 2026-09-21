defmodule ArchiDep.CourseSite.Build.LlmsTxt do
  @moduledoc """
  The index of the course an AI agent reads, following the
  [`/llms.txt`](https://llmstxt.org) convention: every section of the edition
  being taught with what it teaches, every chapter with what it is and where it
  is, and the tutor notes of those that have some.

  ## Who reads it, and what that decides

  It is read by a tutor agent a student installed, which has been told where it
  is and nothing about the course. So the index **describes itself**: how
  chapters are numbered, where the class's progress is published and what its
  numbers mean. It says so as description rather than as instructions, since an
  agent treats text it fetched from the web as data; how to tutor is the
  business of the instructions the student installed.

  Only the live build writes one (`ArchiDep.CourseSite.Build.Site`), and its
  links always point at the main site, `llms_site_url` in
  `ArchiDep.CourseSite.Build.Site.Options`: the agent's instructions name one
  address, and an index on a copy of the site would send it to pages that may
  not be the ones being taught.

  ## What it leaves out

  How far the class has got is not in it. That changes at every session without
  the material changing, and the application already publishes it, so the index
  points there instead and only needs rebuilding when the material changes.

  Nor does it say when it was built. A build is a function of its inputs and
  reads no clock; the revision it was built from identifies it just as well.

  ## Tutor notes

  A chapter's tutor notes are a `tutor.md` beside its page, published as any
  other file of a page, digested name included (see
  `ArchiDep.CourseSite.Build.ContentTree`). This index is the only thing that
  links to them, so the digest never has to be guessed.
  """

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.PageRef
  alias ArchiDep.CourseSite.SiteInfo
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Cheatsheet
  alias ArchiDep.CourseSite.Structure.Section
  alias ArchiDep.CourseSite.Urls
  alias ArchiDep.CourseSite.Urls.UrlContext

  @tutor_notes "tutor.md"
  @progress_path "api/progress"
  @summary_max_words 40
  @line_width 80

  @doc """
  Write the index of a build's course.

  `summaries` holds what each page says of itself
  (`ArchiDep.CourseSite.Renderer.PageMetadata.summary/2`), and `nil` for a page
  that says nothing. `urls` must carry the build's page asset manifest, which is
  what says whether a chapter has tutor notes and what they are called.
  """
  @spec text(
          Structure.t(),
          %{PageRef.t() => String.t() | nil},
          UrlContext.t(),
          String.t(),
          SiteInfo.t()
        ) :: String.t()
  def text(
        %Structure{} = structure,
        summaries,
        %UrlContext{} = urls,
        site_url,
        %SiteInfo{} = site
      )
      when is_map(summaries) and is_binary(site_url) do
    # Content links are absolutized against the main site by the seam itself,
    # the same way the PDF export's are; files of a page and pages of the
    # application stay relative, and are resolved against the page or the site.
    urls = %UrlContext{urls | absolute_base_url: site_url}

    Enum.join(
      [
        header(urls, site_url, site)
        | Enum.map(structure.sections, &section(&1, summaries, urls))
      ] ++ cheatsheets(structure.cheatsheets, urls),
      "\n"
    )
  end

  defp header(urls, site_url, site) do
    paragraphs = [
      wrap(
        "The course material of ArchiDep, the media engineering architecture and " <>
          "deployment course, #{site.years} edition.",
        "> "
      ),
      wrap("Home page: #{Urls.resolve!(urls, :home)}"),
      wrap(
        "This index lists the chapters of the edition being taught. Past editions " <>
          "stay published under their own year and are not listed here."
      ),
      wrap(
        "A chapter is identified by its number: the number of its section, a " <>
          "multiple of 100, plus its place in that section (402 is the second " <>
          "chapter of section 400). How far the class has got is published at " <>
          "#{progress_url(urls, site_url)} as a list of sessions, each recording " <>
          "the section and chapter numbers it finished (`done`), set work on " <>
          "(`due`) and announced for next time (`next`). A number is the first of " <>
          "done, due and next that any session lists it as; a number no session " <>
          "lists has not been reached yet. A session is recorded on the day it is " <>
          "taught, but what it covered may only be filled in at the end of that " <>
          "day. Chapters not reached yet are still being written: they may be " <>
          "renumbered, renamed, rewritten or removed before they are taught, so " <>
          "only what has been taught is final."
      ),
      wrap(
        "In the course pages, `jde` stands for the student's own username and " <>
          "`W.X.Y.Z` for the IP address of their server. An exercise's " <>
          "\"Requirements\" section, when it has one, names the earlier exercises " <>
          "whose results it builds on. Some values, such as the details of a " <>
          "student's server, are only shown in the browser of a logged-in student."
      ),
      wrap(
        "Some chapters have tutor notes, written for an AI tutor helping a student " <>
          "through the chapter: what it teaches, where students usually get stuck, " <>
          "hints, and the questions worth asking at its key steps. They are linked " <>
          "from the chapter's entry."
      )
    ]

    Enum.join(["# ArchiDep\n" | paragraphs] ++ revision(site), "\n")
  end

  defp revision(%SiteInfo{git_revision: nil}), do: []
  defp revision(%SiteInfo{git_revision: revision}), do: [wrap("Built from revision #{revision}.")]

  # The index is Markdown to be read by an agent and reviewed by a human, so its
  # prose is wrapped like the rest of the repository's. A word longer than a line,
  # such as a URL, stays whole on a line of its own.
  defp wrap(text, prefix \\ "") do
    text
    |> String.split(" ", trim: true)
    |> Enum.reduce([], fn
      word, [] ->
        [prefix <> word]

      word, [line | lines] ->
        if String.length(line) + 1 + String.length(word) <= @line_width,
          do: [line <> " " <> word | lines],
          else: [prefix <> word, line | lines]
    end)
    |> Enum.reverse()
    |> Enum.map_join(&(&1 <> "\n"))
  end

  defp progress_url(urls, site_url),
    do: site_url |> URI.merge(Urls.resolve!(urls, {:app, @progress_path})) |> URI.to_string()

  defp section(%Section{} = section, summaries, urls) do
    """
    ## #{Section.num(section)} #{section.title}

    #{section_description(section)}#{Enum.map_join(section.chapters, &chapter(&1, summaries, urls))}\
    """
  end

  # What a section teaches is what tells the reader how deep its chapters go, so
  # it is given whole rather than cut down like a chapter's summary.
  defp section_description(%Section{description: nil}), do: ""
  defp section_description(%Section{description: description}), do: wrap(description) <> "\n"

  defp chapter(%Chapter{} = chapter, summaries, urls) do
    page = Chapter.page_ref(chapter)
    page_url = Urls.resolve!(urls, page)

    IO.iodata_to_binary([
      "- [#{Chapter.num(chapter)} #{chapter.title}](#{page_url}): #{kind(chapter)}.\n",
      summary(Map.get(summaries, page)),
      slides(chapter, urls),
      tutor_notes(page, page_url, urls)
    ])
  end

  defp kind(%Chapter{page: %DocumentRef{type: :exercise}, graded?: true}), do: "graded exercise"
  defp kind(%Chapter{page: %DocumentRef{type: type}}), do: Atom.to_string(type)

  defp summary(nil), do: ""
  # Indented, so that the wrapped summary continues the chapter's list item.
  defp summary(summary), do: summary |> first_sentence() |> cut() |> wrap("  ")

  # The index is read at the start of every conversation, and a page's opening
  # can run to a paragraph of what to install and read first; its first sentence
  # is what says what the chapter is. A sentence ends before a capital letter or
  # at the end, so that "e.g." does not end one.
  defp first_sentence(summary) do
    case Regex.run(~r/\A.*?[.!?](?=\s+[[:upper:]])/su, summary) do
      [sentence] -> sentence
      nil -> summary
    end
  end

  defp cut(sentence) do
    case String.split(sentence, " ") do
      words when length(words) <= @summary_max_words -> sentence
      words -> Enum.join(Enum.take(words, @summary_max_words), " ") <> "…"
    end
  end

  defp slides(%Chapter{slides: nil}, _urls), do: ""

  defp slides(%Chapter{slides: %DocumentRef{} = deck}, urls),
    do: ["  - Slides: ", Urls.resolve!(urls, {:document, deck}), "\n"]

  # A chapter has tutor notes exactly when the build publishes a `tutor.md`
  # beside its page, which is the question the page asset manifest answers.
  defp tutor_notes(page, page_url, urls) do
    case Urls.resolve(urls, {:page_asset, page, @tutor_notes}) do
      {:ok, relative} ->
        ["  - Tutor notes: ", page_url |> URI.merge(relative) |> URI.to_string(), "\n"]

      {:error, {:unknown_page_asset, _page, _path, _output_path}} ->
        ""
    end
  end

  defp cheatsheets([], _urls), do: []

  defp cheatsheets(cheatsheets, urls) do
    [
      """
      ## Cheatsheets

      #{Enum.map_join(cheatsheets, &cheatsheet(&1, urls))}\
      """
    ]
  end

  defp cheatsheet(%Cheatsheet{} = cheatsheet, urls),
    do: "- [#{cheatsheet.title}](#{Urls.resolve!(urls, Cheatsheet.page_ref(cheatsheet))})\n"
end
