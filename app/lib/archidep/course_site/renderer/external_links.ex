defmodule ArchiDep.CourseSite.Renderer.ExternalLinks do
  @moduledoc """
  Opens the links that leave the site in a tab of their own.

  A chapter is something a reader works through with a terminal beside it, and
  it sends them to a manual page, a specification or a service's own
  documentation every few paragraphs. A link that navigated the tab away would
  lose the page they are working through, so anything pointing at another site
  gets `target="_blank"`, and `rel="noopener noreferrer"` with it: the page
  opened this way must not be able to reach back into the one that opened it.

  Whether a URL leaves the site is `ArchiDep.CourseSite.Urls.external?/2`'s to
  say rather than this pass's, because the answer depends on the build: the one
  printed to PDF writes the site's own links as absolute URLs, which nothing but
  the seam that wrote them can tell apart from a link to somewhere else.

  It sweeps the finished page rather than the document because 184 links of the
  course are written inside the body of a block tag, which is HTML by the time
  the page's document exists.

  ## What it leaves alone

  An anchor that already carries a `target` or a `rel` is left exactly as it is:
  the content writes a handful of anchors by hand, and one saying how it opens
  has already answered the question this pass asks.
  """

  @behaviour ArchiDep.CourseSite.Renderer.HtmlPass

  alias ArchiDep.CourseSite.Renderer.RenderContext
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.CourseSite.Urls

  @anchor ~r{<a\s[^>]*>}i
  @href ~r{\shref\s*=\s*(?|"([^"]*)"|'([^']*)')}i
  @spoken_for ~r{\s(?:target|rel)\s*=}i

  @opened_elsewhere ~s( target="_blank" rel="noopener noreferrer">)

  @doc """
  Open the links of a rendered page that leave the site elsewhere.
  """
  @impl ArchiDep.CourseSite.Renderer.HtmlPass
  @spec run(String.t(), RenderContext.t()) :: {String.t(), [RenderError.t()]}
  def run(html, %RenderContext{} = context) when is_binary(html),
    do: {Regex.replace(@anchor, html, &open(&1, context)), []}

  defp open(anchor, context) do
    if leaves_the_site?(anchor, context),
      do: String.replace_suffix(anchor, ">", @opened_elsewhere),
      else: anchor
  end

  defp leaves_the_site?(anchor, context) do
    if Regex.match?(@spoken_for, anchor) do
      false
    else
      case Regex.run(@href, anchor, capture: :all_but_first) do
        [href] -> Urls.external?(context.urls, href)
        nil -> false
      end
    end
  end
end
