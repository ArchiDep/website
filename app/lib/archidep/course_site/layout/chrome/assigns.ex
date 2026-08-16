defmodule ArchiDep.CourseSite.Layout.Chrome.Assigns do
  @moduledoc """
  Everything one page is drawn from, worked out before a byte of it is drawn.

  Not only the chrome, despite the name it sits under: the page's own content is
  in here beside the navigation and the links, because what the chrome does with
  a page is place it, and something placing a page needs the page. Whatever
  draws one is handed this and nothing else, which is why the components take it
  as `page` rather than as a bag of chrome.

  A layout owes the build every reference it could not resolve, not the first
  one (`ArchiDep.CourseSite.Layout` says why). A template cannot do that: HEEx
  evaluates what is interpolated into it as it goes, so the first stylesheet
  that is not in the manifest would have to raise or be swallowed, and neither
  is reporting. So nothing is resolved inside a template. Everything is resolved
  here, into this, and what is left for the templates is strings.

  That is what makes drawing the chrome a step that cannot fail — which is worth
  more than it sounds: it means a page missing from the output is always a page
  the build refused, never a page something threw half way through.

  ## Which failures are fatal

  Reading `ArchiDep.CourseSite.Urls`, only three kinds of reference the chrome
  writes can fail at all: a global asset that is not in the manifest, a file at
  the mount point the build does not publish, and a page whose PDF has not been
  published. Everything else — the home page, a document, a cheatsheet, an
  external link, the page the banner offers in a build that is not the live site
  — is total, and asking for one is a programmer error rather than a fact about
  the build.

  So the split a layout has to make is exactly the split between those:

  - A **stylesheet, script or picture** that does not resolve is a build
    publishing pages nobody can read properly, so it is collected and the page
    is refused. A mark at the mount point the build does not carry
    (`ArchiDep.CourseSite.Urls.RootFileManifest`) is one of those.
  - A **PDF** that does not resolve is a page whose slides have not been printed
    yet, which is ordinary, so the download link is left out and the page is
    published.

  ## Why the navigation is flattened

  The sidebar is handed
  [sections](`ArchiDep.CourseSite.Layout.Chrome.MenuSection`) and
  [entries](`ArchiDep.CourseSite.Layout.Chrome.MenuEntry`) rather than the
  course's own `ArchiDep.CourseSite.Structure`, for the same reason: a chapter's
  URL and the picture beside it are both resolved references, and a template
  that resolved them would be a template that could fail. The home page's
  [cards](`ArchiDep.CourseSite.Layout.Chrome.HomeCard`) are the same lines drawn
  somewhere else, so they are the same value: a chapter is named and linked to
  the one way wherever the site lists it.

  ## What is not in `links`

  A link the build cannot offer is **absent** from the map rather than present
  and `nil`: the page has no PDF, the checkout has no revision to point at, the
  build *is* the live site and so has nowhere else to send anybody. What draws
  it asks whether it is there, which is one question instead of two.
  """

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Layout.Chrome.Footer
  alias ArchiDep.CourseSite.Layout.Chrome.HomeCard
  alias ArchiDep.CourseSite.Layout.Chrome.MenuEntry
  alias ArchiDep.CourseSite.Layout.Chrome.MenuSection
  alias ArchiDep.CourseSite.Layout.Chrome.Policy
  alias ArchiDep.CourseSite.Layout.LayoutContext
  alias ArchiDep.CourseSite.PageRef
  alias ArchiDep.CourseSite.Progress
  alias ArchiDep.CourseSite.Renderer.Page
  alias ArchiDep.CourseSite.Renderer.PageMetadata
  alias ArchiDep.CourseSite.Renderer.Slides
  alias ArchiDep.CourseSite.Renderer.Toc.Entry
  alias ArchiDep.CourseSite.SiteInfo
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Cheatsheet
  alias ArchiDep.CourseSite.Structure.Section
  alias ArchiDep.CourseSite.Urls
  alias ArchiDep.CourseSite.Urls.UrlContext
  alias ArchiDep.Emoji

  @enforce_keys [
    :ref,
    :kind,
    :title,
    :graded?,
    :content,
    :toc,
    :metadata_html,
    :policy,
    :banner,
    :site,
    :commit,
    :sections,
    :cheatsheets,
    :cards,
    :standalone?,
    :legend_emoji,
    :search_emoji,
    :page_class,
    :cloud_server,
    :pdf_tooltip,
    :links
  ]
  defstruct [
    :ref,
    :kind,
    :title,
    :graded?,
    :content,
    :toc,
    :metadata_html,
    :policy,
    :banner,
    :site,
    :commit,
    :sections,
    :cheatsheets,
    :cards,
    :standalone?,
    :legend_emoji,
    :search_emoji,
    :page_class,
    :cloud_server,
    :pdf_tooltip,
    :links
  ]

  @typedoc """
  Which of the site's layouts a page is drawn with.
  """
  @type kind :: :home | :subject | :exercise | :cheatsheet | :deck

  @typedoc """
  Which copy of the site this build is, for a build that is not the current one
  and has to say so — see `ArchiDep.CourseSite.Layout.Chrome.Banner`. The live
  site says nothing, and is `nil`.
  """
  @type banner :: :backup | :archive | nil

  @typedoc """
  What one page is drawn from: which page it is and how it is laid out, what the
  page itself says, the course beside it, the build around it, and every URL it
  writes.
  """
  @type t :: %__MODULE__{
          ref: PageRef.t(),
          kind: kind(),
          title: String.t() | nil,
          graded?: boolean(),
          content: Page.t() | Slides.t(),
          toc: [Entry.t()],
          metadata_html: String.t(),
          policy: Policy.t(),
          banner: banner(),
          site: SiteInfo.t(),
          commit: String.t() | nil,
          sections: [MenuSection.t()],
          cheatsheets: [MenuEntry.t()],
          cards: [HomeCard.t()],
          standalone?: boolean(),
          legend_emoji: %{String.t() => String.t()},
          search_emoji: %{String.t() => String.t()},
          page_class: String.t(),
          cloud_server: String.t() | nil,
          pdf_tooltip: String.t(),
          links: %{atom() => String.t()}
        }

  # Where the course is written. This is not a fact about a build the way the
  # revision it was made from is: there is one repository, and a build that
  # could claim to have come from another would be a build that could lie about
  # where its own pages are.
  @repository "https://github.com/ArchiDep/website"

  # Where the course sits in that repository. Every page is under it at the path
  # the build read it from, the home page included, so a source link is that
  # prefix and nothing else.
  @course_subdirectory "course"

  # The pictures the navigation draws, which are the same ones the dashboard
  # draws beside the same chapters. They are resolved up front like every other
  # reference, so that a build with no emoji published says so once instead of
  # once per chapter.
  @menu_emoji %{
    emoji_slides: {"clapper", "Slides"},
    emoji_graded_exercise: {"trophy", "Graded exercise"},
    emoji_exercise: {"hammer_and_wrench", "Exercise"},
    emoji_subject: {"book", "Subject"},
    emoji_cheatsheet: {"memo", "Cheatsheet"}
  }

  # Which of the course's own categories each of the home page's cards lists,
  # in the order the page shows them. What each is called and how it is drawn
  # belongs to `ArchiDep.CourseSite.Layout.Chrome.Home`; which lines it holds is
  # settled here, like every other list the chrome draws.
  @cards [previously: :done, due_next: :due, next_time: :next]

  # What the navigation draws a picture at, which is small enough to read as
  # punctuation beside the title rather than as an illustration of it.
  @menu_emoji_class "size-4"

  # The pictures an exercise's legend explains, drawn at the size the prose
  # around them is drawn at rather than sized here: in the legend they are read
  # as words, not as icons. They are keyed by the name the course itself writes
  # them under, which is what the legend reads them back by.
  @legend_emoji %{
    legend_trophy: "trophy",
    legend_scroll: "scroll",
    legend_exclamation: "exclamation",
    legend_question: "question",
    legend_space_invader: "space_invader",
    legend_checkered_flag: "checkered_flag",
    legend_classical_building: "classical_building",
    legend_boom: "boom"
  }

  # The pictures the search dialog draws. It is the one part of the site drawn
  # by a script rather than by a page, so it cannot know what an emoji looks
  # like: the page carries the pictures and the script puts them where its own
  # markup says. `course/src/assets/course/search.ts` is what asks for them,
  # under these names.
  @search_emoji %{
    search_book: "book",
    search_clapper: "clapper",
    search_hammer_and_wrench: "hammer_and_wrench",
    search_house: "house",
    search_memo: "memo",
    search_shrug: "shrug",
    search_trophy: "trophy"
  }

  # The identifiers of the headings the chrome draws. They are named here rather
  # than in the templates because the navigation and the heading must agree, and
  # the two are drawn in different places.
  @presentation_id "presentation"
  @graded_id "graded-exercise"
  @legend_id "legend"

  # Every size the browsers and the operating systems ask the site's mark for.
  @favicons %{
    favicon_16: "favicons/archidep-rocket-16.png",
    favicon_32: "favicons/archidep-rocket-32.png",
    favicon_48: "favicons/archidep-rocket-48.png",
    favicon_96: "favicons/archidep-rocket-96.png",
    favicon_180: "favicons/archidep-rocket-180.png",
    favicon_192: "favicons/archidep-rocket-192.png"
  }

  @doc """
  Resolve everything the chrome of a page needs, or say what it could not
  resolve.

  Every reference is attempted before the first failure is reported, so a build
  missing two files names both rather than taking one run per file. They come
  back sorted and without repeats, so that the same build reports the same thing
  twice running and one missing file is one problem: which reference the chrome
  happened to ask for first, and how many places it draws the same picture, are
  not things anybody reading the list should have to know.
  """
  @spec build(LayoutContext.t()) :: {:ok, t()} | {:error, nonempty_list(Urls.error())}
  def build(%LayoutContext{} = context) do
    resolved = links(context)

    case resolved.errors |> Enum.sort() |> Enum.uniq() do
      [] -> {:ok, assigns(context, resolved.links)}
      [_first | _rest] = errors -> {:error, errors}
    end
  end

  @doc """
  Which of the site's layouts a page is drawn with.

  A deck is decided by what was rendered rather than by what the chapter holds,
  because a chapter whose only document is its deck is laid out as a deck and
  not as a chapter with one.
  """
  @spec kind(LayoutContext.t()) :: kind()
  def kind(%LayoutContext{content: %Slides{}}), do: :deck
  def kind(%LayoutContext{page: :home}), do: :home
  def kind(%LayoutContext{page: {:cheatsheet, _slug}}), do: :cheatsheet

  def kind(%LayoutContext{entry: %Chapter{page: %DocumentRef{type: :subject}}}), do: :subject
  def kind(%LayoutContext{entry: %Chapter{page: %DocumentRef{type: :exercise}}}), do: :exercise

  @doc """
  The identifier of a heading the chrome draws.

  The navigation and the heading itself are drawn in different places and have
  to agree, and neither is in the document, so the identifiers are named here
  and read from here.
  """
  @spec heading_id(:presentation | :graded | :legend) :: String.t()
  def heading_id(:presentation), do: @presentation_id
  def heading_id(:graded), do: @graded_id
  def heading_id(:legend), do: @legend_id

  defp assigns(%LayoutContext{} = context, links) do
    policy = Policy.of(context.urls)

    %__MODULE__{
      ref: context.page,
      kind: kind(context),
      title: context.metadata.page_title,
      graded?: graded?(context),
      content: context.content,
      toc: toc(context, links),
      metadata_html: PageMetadata.to_html(context.metadata),
      policy: policy,
      banner: banner(context),
      site: context.site,
      commit: Footer.commit(context.site),
      sections: sections(context, links),
      cheatsheets: cheatsheets(context, links),
      cards: cards(context, policy, links),
      standalone?: context.urls.mode != :live,
      legend_emoji: legend_emoji(links),
      search_emoji: search_emoji(links),
      page_class: page_class(context),
      cloud_server: front_matter(context, "cloud_server"),
      pdf_tooltip: pdf_tooltip(kind(context)),
      links: links
    }
  end

  defp links(%LayoutContext{} = context) do
    %{urls: context.urls, page: context.page, links: %{}, errors: []}
    |> stylesheets_and_scripts(context)
    |> required(:home, :home)
    |> required(:favicon, {:root_file, "favicon.ico"})
    |> required(:heig_logo, {:root_file, "favicons/heig.png"})
    |> required(:logo, {:root_file, "favicons/archidep-512-flat.png"})
    |> required(:coffee_logo, {:root_file, "favicons/archidep-coffee.png"})
    |> favicons()
    |> menu_emoji()
    |> emoji(@legend_emoji)
    |> emoji(@search_emoji)
    |> put(:repository, @repository)
    |> put(:branch, branch_url(context.site))
    |> put(:source, source_url(context))
    |> deck(context)
    |> banner_link(context)
    |> optional(:page_pdf, {:pdf, context.page})
  end

  # Which copy of the site a build is, which is the whole of what the banner
  # says: the live site is the current one and says nothing.
  defp banner(%LayoutContext{urls: %UrlContext{mode: :live}}), do: nil
  defp banner(%LayoutContext{urls: %UrlContext{mode: mode}}), do: mode

  # Every page of a copy of the site offers *itself* elsewhere: the backup copy
  # the same page on the live site, an archived page whatever supersedes it.
  # Neither can fail the way a stylesheet can — a build that could not say where
  # the live site is, or an archive with no edition, is not representable
  # (`ArchiDep.CourseSite.Urls.UrlContext`).
  defp banner_link(resolved, %LayoutContext{urls: %UrlContext{mode: :live}}), do: resolved

  defp banner_link(resolved, %LayoutContext{} = context),
    do: put(resolved, :banner, Urls.resolve!(context.urls, banner_reference(context)))

  defp banner_reference(%LayoutContext{urls: %UrlContext{mode: :backup}, page: page}),
    do: {:live_site, page}

  defp banner_reference(%LayoutContext{urls: %UrlContext{mode: :archive}, page: page}),
    do: {:current_edition, page}

  # A page and a deck load nothing in common: one is the site, the other is a
  # presentation the site happens to publish. Each build asks only for what the
  # page it is drawing will actually load, so a missing deck stylesheet cannot
  # fail a chapter that has no deck.
  defp stylesheets_and_scripts(resolved, %LayoutContext{content: %Slides{}}) do
    resolved
    |> required(:slides_css, {:asset, "/assets/course/slides.css"})
    |> required(:theme_slides_css, {:asset, "/assets/theme/slides.css"})
    |> required(:slides_js, {:asset, "/assets/course/slides.js"})
    |> required(:slides_mermaid_js, {:asset, "/assets/course/slides-mermaid.js"})
  end

  # The search index is asked for by name rather than by digest, and the name is
  # the one `ArchiDep.CourseSite.Build.Site` writes it under. It carries the
  # build's identifier because it cannot carry its own: it is read off the pages
  # whose `<head>` this is.
  defp stylesheets_and_scripts(resolved, %LayoutContext{}) do
    resolved
    |> required(:theme_css, {:asset, "/assets/theme/theme.css"})
    |> required(:course_js, {:asset, "/assets/course/course.js"})
    |> required(:search_data, {:build_file, "search.json"})
  end

  defp favicons(resolved) do
    Enum.reduce(@favicons, resolved, fn {key, path}, resolved ->
      required(resolved, key, {:root_file, path})
    end)
  end

  defp menu_emoji(resolved) do
    emoji(resolved, Map.new(@menu_emoji, fn {key, {name, _alt}} -> {key, name} end))
  end

  defp emoji(resolved, names) do
    Enum.reduce(names, resolved, fn {key, name}, resolved ->
      required(resolved, key, {:asset, Emoji.asset_path(Emoji.fetch!(name))})
    end)
  end

  # The legend reads its pictures back by the name the course writes them under,
  # so what it is handed is keyed by that rather than by the key they were
  # resolved under.
  defp legend_emoji(links) do
    Map.new(@legend_emoji, fn {key, name} ->
      {name, Emoji.img(Emoji.fetch!(name), Map.fetch!(links, key))}
    end)
  end

  # The search dialog asks for a picture by the name the registry keeps it
  # under, the same way the legend does, because that is the name its own code
  # writes.
  defp search_emoji(links) do
    Map.new(@search_emoji, fn {key, name} ->
      {name, Emoji.img(Emoji.fetch!(name), Map.fetch!(links, key))}
    end)
  end

  # A chapter that was presented links to its deck twice: to the deck itself,
  # which always resolves, and to the deck printed as a PDF, which resolves only
  # once somebody has printed it.
  defp deck(resolved, %LayoutContext{entry: %Chapter{slides: %DocumentRef{} = deck}}) do
    resolved
    |> required(:deck, {:document, deck})
    |> optional(:deck_pdf, {:pdf, {:document, deck}})
  end

  defp deck(resolved, %LayoutContext{}), do: resolved

  defp graded?(%LayoutContext{entry: %Chapter{graded?: graded?}}), do: graded?
  defp graded?(%LayoutContext{}), do: false

  defp required(resolved, key, reference) do
    case Urls.resolve(resolved.urls, reference, resolved.page) do
      {:ok, url} -> %{resolved | links: Map.put(resolved.links, key, url)}
      {:error, error} -> %{resolved | errors: [error | resolved.errors]}
    end
  end

  defp optional(resolved, key, reference) do
    case Urls.resolve(resolved.urls, reference, resolved.page) do
      {:ok, url} -> %{resolved | links: Map.put(resolved.links, key, url)}
      {:error, _unpublished} -> resolved
    end
  end

  defp put(resolved, _key, nil), do: resolved
  defp put(resolved, key, url), do: %{resolved | links: Map.put(resolved.links, key, url)}

  defp sections(%LayoutContext{} = context, links) do
    Enum.map(context.structure.sections, fn %Section{} = section ->
      %MenuSection{
        title: section.title,
        slug: Section.slug(section),
        status: status(context, Section.num(section)),
        open?: Progress.section_open?(context.statuses, section),
        entries: Enum.map(section.chapters, &chapter_entry(&1, context, links))
      }
    end)
  end

  defp cheatsheets(%LayoutContext{} = context, links),
    do: Enum.map(context.structure.cheatsheets, &cheatsheet_entry(&1, context, links))

  # The home page's three cards, which are the one thing the chrome draws from a
  # single session rather than from the whole progression — see
  # `ArchiDep.CourseSite.Progress.last_recorded/3`. Every other page is handed
  # none: working out what the course did last time for a page that does not say
  # so would be fifty-five answers nobody reads. Whether a build says where the
  # course has got to at all is the policy's to answer, not the progress
  # source's.
  defp cards(%LayoutContext{}, %Policy{progress_cards?: false}, _links), do: []

  defp cards(%LayoutContext{} = context, %Policy{progress_cards?: true}, links) do
    case kind(context) do
      :home -> Enum.flat_map(@cards, &card(&1, context, links))
      _other -> []
    end
  end

  defp card({kind, category}, %LayoutContext{} = context, links) do
    case Progress.last_recorded(context.progress, context.structure, category) do
      [] ->
        []

      [_first | _rest] = chapters ->
        [%HomeCard{kind: kind, entries: entries(chapters, context, links)}]
    end
  end

  defp entries(chapters, context, links),
    do: Enum.map(chapters, &chapter_entry(&1, context, links))

  defp chapter_entry(%Chapter{} = chapter, %LayoutContext{} = context, links) do
    page = Chapter.page_ref(chapter)

    %MenuEntry{
      url: Urls.resolve!(context.urls, page),
      title: chapter.title,
      emoji_html: emoji_html(links, chapter_emoji(chapter)),
      deck_emoji_html: if(Chapter.slides?(chapter), do: emoji_html(links, :emoji_slides)),
      status: status(context, Chapter.num(chapter)),
      current?: page == context.page,
      deck?: chapter.page.type == :slides
    }
  end

  defp cheatsheet_entry(%Cheatsheet{} = cheatsheet, %LayoutContext{} = context, links) do
    page = Cheatsheet.page_ref(cheatsheet)

    %MenuEntry{
      url: Urls.resolve!(context.urls, page),
      title: Cheatsheet.sidebar_title(cheatsheet),
      emoji_html: emoji_html(links, :emoji_cheatsheet),
      deck_emoji_html: nil,
      status: nil,
      current?: page == context.page,
      deck?: false
    }
  end

  defp chapter_emoji(%Chapter{page: %DocumentRef{type: :slides}}), do: :emoji_slides

  defp chapter_emoji(%Chapter{page: %DocumentRef{type: :exercise}, graded?: true}),
    do: :emoji_graded_exercise

  defp chapter_emoji(%Chapter{page: %DocumentRef{type: :exercise}}), do: :emoji_exercise
  defp chapter_emoji(%Chapter{page: %DocumentRef{type: :subject}}), do: :emoji_subject

  defp emoji_html(links, key) do
    {name, alt} = Map.fetch!(@menu_emoji, key)

    Emoji.img(Emoji.fetch!(name), Map.fetch!(links, key), alt: alt, class: @menu_emoji_class)
  end

  defp status(%LayoutContext{statuses: statuses}, num), do: Map.get(statuses, num, :future)

  # The navigation of a page opens with the headings the *chrome* draws — a
  # chapter's presentation, an exercise's legend — because the reader sees those
  # first. The renderer never sees them: they are not in the document, so
  # nothing but this can put them in front of the document's own.
  defp toc(%LayoutContext{content: %Slides{}}, _links), do: []

  defp toc(%LayoutContext{content: %Page{toc: entries}} = context, links),
    do: chrome_headings(context, links) ++ entries

  defp chrome_headings(%LayoutContext{entry: %Chapter{slides: %DocumentRef{}}} = context, _links) do
    case kind(context) do
      :subject -> [heading(@presentation_id, "Presentation")]
      _other -> []
    end
  end

  defp chrome_headings(%LayoutContext{} = context, links) do
    case kind(context) do
      :exercise -> exercise_headings(context, links)
      _other -> []
    end
  end

  # An entry says what the heading it points at says, pictures included, which
  # is why these are drawn here rather than named: the two are read as one line.
  defp exercise_headings(%LayoutContext{entry: %Chapter{graded?: true}}, links),
    do: [
      heading(@graded_id, decorated(links, "trophy", "Graded exercise")),
      heading(@legend_id, decorated(links, "scroll", "Legend"))
    ]

  defp exercise_headings(%LayoutContext{}, links),
    do: [heading(@legend_id, decorated(links, "scroll", "Legend"))]

  defp decorated(links, name, label), do: "#{Map.fetch!(legend_emoji(links), name)} #{label}"

  defp heading(id, label), do: %Entry{id: id, level: 2, label_html: label, entries: []}

  # What the page is called in the stylesheets: which of the site's layouts drew
  # it, and whatever else the document asked for.
  defp page_class(%LayoutContext{} = context),
    do:
      [kind_class(context), front_matter(context, "custom_page_class")]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")

  defp kind_class(%LayoutContext{} = context), do: "course-#{kind(context)}"

  defp pdf_tooltip(:home), do: "Home PDF"
  defp pdf_tooltip(:subject), do: "Subject PDF"
  defp pdf_tooltip(:exercise), do: "Exercise PDF"
  defp pdf_tooltip(:cheatsheet), do: "Cheatsheet PDF"
  defp pdf_tooltip(:deck), do: "Slides PDF"

  defp front_matter(%LayoutContext{front_matter: front_matter}, key) do
    case Map.get(front_matter, key) do
      value when is_binary(value) and value != "" -> value
      _none -> nil
    end
  end

  # Where this page is written, as a link into the repository. Every page of the
  # course lives one directory deeper than the page introducing it, which is the
  # whole of the difference between the two.
  defp source_url(%LayoutContext{site: %SiteInfo{git_revision: nil}}), do: nil

  defp source_url(%LayoutContext{site: %SiteInfo{git_revision: revision}} = context),
    do: "#{@repository}/blob/#{revision}/#{@course_subdirectory}/#{context.source_path}"

  defp branch_url(%SiteInfo{git_branch: nil}), do: nil
  defp branch_url(%SiteInfo{git_branch: branch}), do: "#{@repository}/tree/#{branch}"
end
