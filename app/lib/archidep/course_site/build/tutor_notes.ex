defmodule ArchiDep.CourseSite.Build.TutorNotes do
  @moduledoc """
  What is published of a chapter's tutor notes: the notes as they are written,
  followed by a map of the chapter page's "Troubleshooting" section.

  ## Why the build adds to them

  The notes are what a tutor reads of a chapter in every conversation about it,
  because they are short enough to arrive whole where the page may only arrive
  as a summary. A page's troubleshooting entries are at the end of a long page,
  which is what a summary loses first, and an entry the tutor does not know
  exists is an entry it cannot ask for. So the notes carry the heading of every
  entry with its anchor, and the page stays the one place its fixes are written.

  The map is read off the rendered page rather than written by hand, so that it
  cannot drift from the page, and its entries are the page's own table of
  contents (`ArchiDep.CourseSite.Renderer.Toc`): the headings as the page shows
  them, under the identifiers the browser finds, Liquid and emoji already
  rendered. A section written as a list rather than as headings is linked as a
  whole. An exercise without the section says so, since knowing there is nothing
  to look for spares the tutor looking; any other page says nothing.

  ## Where it links to

  The section's link is absolute and points at the main site, like those of
  `ArchiDep.CourseSite.Build.LlmsTxt`, and for the same reason: the notes are
  read by an agent that fetched them from there, and which has no page to
  resolve a relative link against.
  """

  alias ArchiDep.CourseSite.Build.PageAssetDigest
  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.PageRef
  alias ArchiDep.CourseSite.Renderer.Page
  alias ArchiDep.CourseSite.Renderer.Slides
  alias ArchiDep.CourseSite.Renderer.Toc.Entry
  alias ArchiDep.CourseSite.Urls
  alias ArchiDep.CourseSite.Urls.UrlContext

  @file_name "tutor.md"

  # The heading the build writes, which is therefore one the written notes may
  # not use: the notes would otherwise hold two sections of that name, one of
  # them out of date.
  @map_heading "## Troubleshooting on the page"

  # The identifier of a page's troubleshooting section, which its decoration
  # does not change.
  @troubleshooting "troubleshooting"

  @type error :: {:reserved_tutor_notes_heading, String.t()}

  @doc """
  Where a chapter's notes are published before they are digested, given its
  directory.

      iex> TutorNotes.output_path("506-systemd-deployment")
      "/course/506-systemd-deployment/tutor.md"
  """
  @spec output_path(String.t()) :: String.t()
  def output_path(chapter) when is_binary(chapter), do: "/course/#{chapter}/#{@file_name}"

  @doc """
  The path from a chapter's page to its notes, which are at the root of the
  chapter's directory: a deck is published one segment deeper than that.

      iex> TutorNotes.reference({:document, DocumentRef.new(506, "systemd-deployment", :exercise)})
      "tutor.md"

      iex> TutorNotes.reference({:document, DocumentRef.new(202, "git-branching", :slides)})
      "../tutor.md"
  """
  @spec reference(PageRef.t()) :: String.t()
  def reference({:document, %DocumentRef{type: :slides}}), do: "../" <> @file_name
  def reference({:document, %DocumentRef{}}), do: @file_name

  @doc """
  The notes as they are published, given the notes as written and the rendered
  page of their chapter.

  `urls` is the build's, whose links are made absolute against `site_url`.
  """
  @spec text(String.t(), PageRef.t(), Page.t() | Slides.t(), UrlContext.t(), String.t()) ::
          {:ok, String.t()} | {:error, error()}
  def text(written, page, content, %UrlContext{} = urls, site_url)
      when is_binary(written) and is_binary(site_url) do
    if written |> String.split("\n") |> Enum.any?(&(String.trim_trailing(&1) == @map_heading)) do
      {:error, {:reserved_tutor_notes_heading, @map_heading}}
    else
      urls = %{urls | absolute_base_url: site_url}
      {:ok, append(written, map(page, content, urls))}
    end
  end

  @doc """
  Where published notes are written, named after their content like any file of
  a page.
  """
  @spec published_path(String.t(), String.t()) :: String.t()
  def published_path(output_path, text) when is_binary(output_path) and is_binary(text),
    do: PageAssetDigest.published_path(output_path, file_name(text))

  @doc """
  The name published notes are known by, as `published_path/2` writes them.
  """
  @spec file_name(String.t()) :: String.t()
  def file_name(text) when is_binary(text),
    do: PageAssetDigest.digested_name(@file_name, :crypto.hash(:md5, text))

  @doc """
  Describe what is wrong with a chapter's notes.
  """
  @spec format_error(error()) :: String.t()
  def format_error({:reserved_tutor_notes_heading, heading}),
    do: "Tutor notes must not write the heading #{inspect(heading)}, which the build adds"

  defp append(written, nil), do: written

  defp append(written, map),
    do: String.trim_trailing(written) <> "\n\n" <> @map_heading <> "\n\n" <> map

  defp map(page, %Page{toc: toc}, urls) do
    case find(toc) do
      %Entry{} = section ->
        "The page's \"Troubleshooting\" section: #{url(section, page, urls)}\n" <>
          entries(section.entries, page, urls)

      nil ->
        missing(page)
    end
  end

  defp map(page, %Slides{}, _urls), do: missing(page)

  defp find([]), do: nil
  defp find([%Entry{id: @troubleshooting} = entry | _rest]), do: entry
  defp find([%Entry{entries: under} | rest]), do: find(under) || find(rest)

  defp missing({:document, %DocumentRef{type: :exercise}}),
    do: "The page has no \"Troubleshooting\" section.\n"

  defp missing(_page), do: nil

  # A section may also be written as a list rather than as headings, which is a
  # section with nothing to map but itself.
  defp entries([], _page, _urls), do: ""

  defp entries(entries, page, urls),
    do:
      "\nIts entries, with their anchors on that page:\n\n" <>
        Enum.map_join(entries, &"- #{plain(&1.label_html)} (#{fragment(&1, page, urls)})\n")

  # An entry is given as a fragment of the section's page rather than as a URL
  # of its own: the page's address, repeated for every entry, would be most of
  # the map, and replacing the section's fragment is all it takes to link one.
  # The fragment is the page's own, where an agent could only guess at how a
  # heading is slugged, and a wrong guess lands on the top of the page.
  defp fragment(%Entry{id: id}, page, urls), do: Urls.resolve!(urls, {:heading, page, id}, page)

  defp url(%Entry{id: id}, page, urls), do: Urls.resolve!(urls, {:heading, page, id})

  # A heading is written with the same inline code and emoji as the rest of the
  # page. Its code is what an error message looks like, so it is kept as
  # Markdown; an emoji is a picture by now, and decoration.
  defp plain(label_html) do
    label_html
    |> LazyHTML.from_fragment()
    |> LazyHTML.to_tree()
    |> Enum.map_join(&node_text/1)
    |> String.split()
    |> Enum.join(" ")
  end

  defp node_text(text) when is_binary(text), do: text
  defp node_text({"img", _attributes, _children}), do: ""

  defp node_text({"code", _attributes, children}),
    do: "`" <> Enum.map_join(children, &node_text/1) <> "`"

  defp node_text({_tag, _attributes, children}), do: Enum.map_join(children, &node_text/1)
  defp node_text(_comment), do: ""
end
