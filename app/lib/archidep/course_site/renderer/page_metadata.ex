defmodule ArchiDep.CourseSite.Renderer.PageMetadata do
  @moduledoc """
  How a page introduces itself to something that is not reading it: a browser
  tab, a search engine, a chat client unfurling a link someone pasted.

  A page says the same three things to all of them — what it is called, what it
  is about, and where it really lives — so they are worked out once here and
  written out as the tags each of them looks for, rather than by every layout
  that happens to need them. That is what keeps a page from carrying two
  `<title>` elements that disagree.

  ## What a page is about

  A page's description is its own opening, as [the site shows
  it](`ArchiDep.CourseSite.Renderer.Excerpt`) with its markup taken back off.
  That is what makes the description of a chapter the sentence the chapter
  itself opens with rather than a line someone has to remember to keep in step
  with the page.

  Two things sit either side of that. A page may declare a `description` in its
  front matter, which wins: a page whose opening reads as a description only in
  place — a lead-in ending in a colon, a sentence that only means anything under
  the heading above it — has no other way to say so. And a **deck** has no
  opening at all, being handed to the browser whole rather than split, so it
  says that it is the slides of its chapter; the site's own description is what
  is left for a page with neither, and it is worth avoiding, since every page
  that falls back to it claims the same thing as all the others.

  ## Where a page really lives

  The canonical URL is the page on the **main site**, which is what stops the
  backup copy and the archived editions from competing with it in a search
  engine — they are the same pages at other addresses, and this is how they say
  so. A build that does not know where the main site is says nothing rather than
  guessing, since a canonical URL that is wrong is worse than none.

  ## What an archived page asks a search engine to do with it

  A past edition asks to be kept out of the results (`noindex`) so that a search
  sends a reader to the current edition rather than to a five-year-old page —
  and, in the same breath, to be *followed*, which is what actively points the
  crawler at the current edition: the way there is the link the page itself
  offers (`ArchiDep.CourseSite.Layout.Chrome.Banner`), and `nofollow` would keep
  the archive out of the results just as well while severing it.
  """

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Renderer.RenderContext
  alias ArchiDep.CourseSite.Urls
  alias ArchiDep.CourseSite.Urls.UrlContext

  # What the site is called and what it is about, for a page that has nothing of
  # its own to say. The application says the same of itself in its layout.
  @site_title "ArchiDep"
  @site_description "Media engineering architecture and deployment course"

  # The course is taught and written in English, and no build of it is anything
  # else.
  @locale "en_US"

  @title_separator " · "

  # The opening of a page is HTML, so what it says is written with entities;
  # escaping it again on the way out would describe a page as being about
  # `Q&amp;A`.
  @unescaped [{"&lt;", "<"}, {"&gt;", ">"}, {"&quot;", "\""}, {"&#39;", "'"}, {"&amp;", "&"}]
  @escaped [{"&", "&amp;"}, {"<", "&lt;"}, {">", "&gt;"}, {"\"", "&quot;"}]

  # Long enough that no opening of the course is cut, short enough that a page
  # whose opening is a whole section does not carry it twice.
  @description_max_words 200

  # What a page of a frozen edition asks of a crawler.
  @archive_robots "noindex, follow"

  @enforce_keys [:title, :page_title, :description, :canonical_url, :robots]
  defstruct [:title, :page_title, :description, :canonical_url, :robots]

  @typedoc """
  What a page says about itself: the title of its tab, its own title, what it is
  about, where it lives on the main site if the build knows, and what it asks a
  crawler to do with it if it has anything to ask.
  """
  @type t :: %__MODULE__{
          title: String.t(),
          page_title: String.t() | nil,
          description: String.t(),
          canonical_url: String.t() | nil,
          robots: String.t() | nil
        }

  @doc """
  Work out what a page says about itself, given the opening the site shows of
  it.

  Pass no opening for a page that has none, and for a slide deck, which is never
  split into one.
  """
  @spec of(RenderContext.t()) :: t()
  @spec of(RenderContext.t(), String.t() | nil) :: t()
  def of(%RenderContext{} = context, excerpt_html \\ nil) do
    page_title = page_title(context)

    %__MODULE__{
      title: title(page_title),
      page_title: page_title,
      description: description(context, page_title, excerpt_html),
      canonical_url: canonical_url(context),
      robots: robots(context)
    }
  end

  @doc """
  Write what a page says about itself as the tags a `<head>` carries.
  """
  @spec to_html(t()) :: String.t()
  def to_html(%__MODULE__{} = metadata) do
    [
      "<title>#{escape(metadata.title)}</title>",
      meta(name: "description", content: metadata.description),
      meta(name: "robots", content: metadata.robots),
      link(rel: "canonical", href: metadata.canonical_url),
      meta(property: "og:type", content: "website"),
      meta(property: "og:site_name", content: @site_title),
      meta(property: "og:locale", content: @locale),
      meta(property: "og:title", content: metadata.page_title),
      meta(property: "og:description", content: metadata.description),
      meta(property: "og:url", content: metadata.canonical_url),
      meta(name: "twitter:card", content: "summary")
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  @doc """
  What a page called this is called in a browser tab.

  Pass no title for a page that has none, and for a page whose own title is
  already the name of the site, which says it once rather than twice.

      iex> PageMetadata.title("Cloud Computing")
      "Cloud Computing · ArchiDep"

      iex> PageMetadata.title(nil)
      "ArchiDep"

      iex> PageMetadata.title("ArchiDep")
      "ArchiDep"
  """
  @spec title(String.t() | nil) :: String.t()
  def title(nil), do: @site_title
  def title(@site_title), do: @site_title
  def title(page_title), do: page_title <> @title_separator <> @site_title

  defp meta(attributes), do: element("meta", attributes)
  defp link(attributes), do: element("link", attributes)

  # A tag the build has no value for is left out rather than written empty: an
  # empty `content` is a claim that the page has no such thing to say, where
  # leaving the tag out says nothing at all.
  defp element(name, attributes) do
    if Enum.any?(attributes, fn {_attribute, value} -> is_nil(value) end) do
      nil
    else
      written =
        Enum.map_join(attributes, " ", fn {attribute, value} ->
          ~s(#{attribute}="#{escape(value)}")
        end)

      "<#{name} #{written} />"
    end
  end

  defp page_title(context) do
    case Map.get(RenderContext.page_variables(context), "title") do
      title when is_binary(title) and title != "" -> title
      _none -> nil
    end
  end

  defp description(context, page_title, excerpt_html) do
    declared(context) || from_excerpt(excerpt_html) || slides_description(context, page_title) ||
      @site_description
  end

  defp declared(context) do
    case Map.get(RenderContext.page_variables(context), "description") do
      declared when is_binary(declared) and declared != "" -> snippet(text_of(declared))
      _none -> nil
    end
  end

  defp from_excerpt(nil), do: nil

  defp from_excerpt(excerpt_html) do
    case excerpt_html |> text_of() |> snippet() do
      "" -> nil
      description -> description
    end
  end

  # A deck is the one page with nothing of its own to read, so what it says is
  # what it is: the slides of its chapter, which its title names.
  defp slides_description(%RenderContext{page: {:document, %DocumentRef{type: :slides}}}, title)
       when is_binary(title),
       do: "Slides for the #{title} chapter of the #{@site_title} course."

  defp slides_description(_context, _title), do: nil

  # The opening as it is read rather than as it is marked up: an image drops out
  # with the rest of the markup, so a heading decorated with an emoji describes
  # the page by what it says.
  defp text_of(html) do
    html
    |> String.replace(~r{<[^>]*>}s, "")
    |> unescape()
    |> String.split()
    |> Enum.join(" ")
  end

  defp snippet(text) do
    case String.split(text, " ") do
      words when length(words) <= @description_max_words ->
        text

      words ->
        cut = Enum.take(words, @description_max_words)
        Enum.join(cut, " ") <> "…"
    end
  end

  defp robots(%RenderContext{urls: %UrlContext{mode: :archive}}), do: @archive_robots
  defp robots(%RenderContext{}), do: nil

  defp canonical_url(%RenderContext{urls: urls, page: page}) do
    case Urls.resolve(urls, {:live_site, page}) do
      {:ok, url} -> url
      {:error, _reason} -> nil
    end
  end

  defp unescape(text),
    do:
      Enum.reduce(@unescaped, text, fn {entity, character}, text ->
        String.replace(text, entity, character)
      end)

  defp escape(text),
    do:
      Enum.reduce(@escaped, text, fn {character, entity}, text ->
        String.replace(text, character, entity)
      end)
end
