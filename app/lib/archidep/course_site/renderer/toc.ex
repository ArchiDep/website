defmodule ArchiDep.CourseSite.Renderer.Toc do
  @moduledoc """
  The "On this page" navigation of a page, read off the page's own HTML.

  It is read off the finished page rather than built from the document for two
  reasons, and both of them are about the entries naming the same identifiers
  the reader's browser will find:

  - The identifiers are assigned while the document is rendered, and a heading
    repeated on a page is numbered (`troubleshooting`, `troubleshooting-1`)
    according to what came before it. Working them out from the document again
    would mean writing a second slugger and keeping the two in agreement
    forever.
  - A label is the heading as the page shows it, so it has to be read after the
    passes over the finished page have had their say — the shortcodes of a
    heading are images by then, as they are in the heading itself.

  A heading introduces the headings that follow it and are deeper than it, which
  is what nests the navigation. A page that skips a level, or that starts deeper
  than it goes on, still produces a tree: each heading takes what is below it,
  whatever level that is.
  """

  alias ArchiDep.CourseSite.Renderer.Toc.Entry

  # A heading of the rendered page, as the Markdown renderer writes it: the
  # identifier is the first attribute and the anchor element it appends is the
  # last thing inside.
  @heading ~r|<h([1-6]) id="([^"]*)">(.*?)</h\1>|s
  @anchor ~r|<a [^>]*class="anchor"></a>\z|

  @doc """
  Read the headings of a rendered page, nested by level.
  """
  @spec extract(String.t()) :: [Entry.t()]
  def extract(html) when is_binary(html) do
    @heading
    |> Regex.scan(html)
    |> Enum.map(fn [_heading, level, id, content] ->
      %Entry{id: id, level: String.to_integer(level), label_html: label(content)}
    end)
    |> nest()
  end

  defp label(content), do: Regex.replace(@anchor, content, "")

  defp nest([]), do: []

  defp nest([%Entry{level: level} = entry | rest]) do
    {under, next} = Enum.split_while(rest, &(&1.level > level))
    [%Entry{entry | entries: nest(under)} | nest(next)]
  end
end
