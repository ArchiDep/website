defmodule ArchiDep.CourseSite.Build.SearchIndex do
  @moduledoc """
  What a build tells the search dialog about a page.

  The dialog searches *parts* of pages rather than pages, because a course page
  is long: a reader looking for how to add an SSH key wants the section that
  says so, not the chapter it is in. So a page is cut into one entry per
  top-level heading, each carrying the prose under it, and the page itself is
  the entry that comes before the first cut.

  ## What counts as a cut

  Only a **top-level** heading that carries an identifier, and only once the
  entry being filled holds something. A heading nested inside a block tag is
  part of what that tag says rather than a section of the page, and a heading
  with no identifier is one nothing can link to. Both are read as prose, which
  is what keeps their words findable under whichever entry is open.

  A heading is not repeated in the entry it opens: it is already that entry's
  title, and a result that showed it twice would waste the line it is shown on.

  ## Reading the page

  The page is read as the HTML that was rendered for it, before the site is laid
  out around it. Everything the chrome adds — the sidebar, the table of
  contents, the footer, the script in the body — is therefore absent rather than
  filtered out, and what is left is the document a reader came for.

  What that HTML says is read with `LazyHTML`, the same parser the build reads
  its finished pages with. The emoji of a heading are pictures by this point and
  contribute nothing to its text, which is what keeps a heading's title the
  words it is made of.
  """

  alias ArchiDep.CourseSite.Build.SearchIndex.Entry
  alias ArchiDep.CourseSite.PageRef
  alias ArchiDep.CourseSite.Urls
  alias ArchiDep.CourseSite.Urls.UrlContext

  @headings ~w(h1 h2 h3 h4 h5 h6)

  # The one thing the dialog can find that the course does not write: the
  # dashboard a student manages their account and their server from. It has no
  # document to be read off, so it is said here — beside the rule that governs
  # it, which is that a copy of the site holds no entry for an application that
  # is not running where that copy is read.
  @application [
    {"/app", "dashboard", "Dashboard", "User & server dashboard",
     "Manage your user account for the course and register a server for the exercises."}
  ]

  @doc """
  Cut one rendered page into the entries it contributes to the index.

  `entry` is what the page is as a whole — everything about it that is known
  before reading it, the identity the first entry keeps. The entries after it
  are its headings, named after the same page and shown under the same title.
  """
  @spec entries(UrlContext.t(), PageRef.t(), Entry.t(), String.t()) :: [Entry.t()]
  def entries(%UrlContext{} = urls, page, %Entry{} = entry, html) when is_binary(html) do
    # The page is walked once, carrying the entry being filled, the pieces of
    # text collected for it so far, and the entries already closed. `entry` is
    # both what the walk starts with and what every heading is named after, so
    # it is closed over rather than threaded through the accumulator.
    {current, texts, done} =
      html
      |> elements()
      |> Enum.reduce({entry, [], []}, &cut(&1, &2, urls, page, entry))

    # The last entry is closed here rather than in the walk, there being no
    # heading after it to close it — which is also why a page ending on a
    # heading contributes an entry with no text: the heading is a place to
    # arrive at whether or not anything was written under it.
    Enum.reverse([fill(current, texts) | done])
  end

  @doc """
  The entries a build contributes of its own, which the course writes no
  document for.

  A copy of the site has none: the application is not running beside it, so an
  entry pointing at it would be a result that goes nowhere.
  """
  @spec application_entries(UrlContext.t()) :: [Entry.t()]
  def application_entries(%UrlContext{mode: :live} = urls),
    do:
      Enum.map(@application, fn {path, type, title, subtitle, text} ->
        %Entry{
          id: path,
          type: type,
          url: Urls.resolve!(urls, {:app, String.trim_leading(path, "/")}),
          title: title,
          subtitle: subtitle,
          text: text
        }
      end)

  def application_entries(%UrlContext{}), do: []

  # The top-level elements of the page, in the order it shows them. A bare piece
  # of text between two of them belongs to neither and is left out, which is
  # what a document selector does and what this reproduces on a fragment.
  defp elements(html) do
    html
    |> LazyHTML.from_fragment()
    # Only the root nodes, and only those that are elements: `filter/2` keeps
    # the roots matching a selector, where `query/2` would descend into them and
    # hand back every heading of the page, nested ones included.
    |> LazyHTML.filter("*")
    |> Enum.map(fn element ->
      tag = element |> LazyHTML.tag() |> List.first()

      # Three things are asked of an element and nothing else is kept: whether
      # it is a heading, what it can be linked to by, and what it says. The text
      # is the whole of the element's, so a heading nested inside this one has
      # already been folded into it — which is what makes a nested heading
      # prose.
      {tag in @headings, element |> LazyHTML.attribute("id") |> List.first(),
       element |> LazyHTML.text() |> normalize()}
    end)
  end

  # One element of the page, against the entry being filled. It does two
  # separate things, in this order: it may close that entry and open another,
  # and it may add its own words to whichever entry is open afterwards.
  defp cut({heading?, id, text}, {current, texts, done}, urls, page, entry) do
    # A heading cuts only if it can be linked to and there is something to cut:
    # `texts == []` means nothing has been collected yet, so this heading is the
    # page's opening rather than a section of it, and cutting there would leave
    # an empty entry in front of the page's own.
    {current, texts, done} =
      if heading? and id != nil and texts != [] do
        {heading(entry, urls, page, id, text), [], [fill(current, texts) | done]}
      else
        {current, texts, done}
      end

    # Whatever is open now takes the element's words — except the heading that
    # just opened it, whose words are already its title. Comparing the two is
    # what expresses that: after a cut they are equal by construction, and
    # before one it catches a page opening with a heading that repeats its own
    # title.
    if heading? and text == current.title do
      {current, texts, done}
    else
      {current, [text | texts], done}
    end
  end

  # A heading is a place on the page it is on: it is named after that page's own
  # path, resolved through the seam like any other reference, and shown under
  # what the page is called rather than under what the previous heading was.
  # `entry` is therefore the *page's* entry throughout, never the one being
  # filled, which is why the walk carries it separately.
  defp heading(%Entry{} = entry, urls, page, id, text),
    do: %Entry{
      id: PageRef.output_path(page) <> "#" <> id,
      type: entry.type,
      url: Urls.resolve!(urls, {:heading, page, id}),
      title: text,
      subtitle: entry.title
    }

  # The words collected for an entry, back in the order the page says them. An
  # element that says nothing — a divider, a picture — is dropped rather than
  # joined, so that what is left reads as a sentence instead of as text with
  # holes in it.
  defp fill(%Entry{} = entry, texts),
    do: %Entry{
      entry
      | text: texts |> Enum.reverse() |> Enum.reject(&(&1 == "")) |> Enum.join(" ")
    }

  # An entry is words rather than layout, so how a document happened to be
  # wrapped is taken out of it. It is done per element rather than once over the
  # finished text so that a heading's title and the text it is compared against
  # are spaced the same way.
  defp normalize(text), do: text |> String.replace(~r/\s+/, " ") |> String.trim()
end
