defmodule ArchiDep.CourseSite.Layout.Chrome.Toc do
  @moduledoc """
  The list of a page's headings, as "On this page".

  It is drawn twice on every page — folded above the text on a narrow screen,
  and beside the text on a wide one — which is why it is a component rather than
  markup written where it appears: two copies of the same list would be two
  places to change it.

  An entry keeps its heading's own markup rather than the heading's text, so a
  heading that shows a picture or a piece of code shows the same here as it does
  in the page. It also carries the level it was written at, because
  `theme/src/toc.css` sizes an entry by how deep the heading is and not by how
  deep the list is.

  The list carries no identifier of its own. It cannot: the same page draws it
  twice, and the two would be one identifier used for two elements. Nothing
  selects it by one — the stylesheet reaches it through the `aside` or the `nav`
  around it, which is what tells the two copies apart in the first place.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.Rendered

  # What the chrome writes is a file of a build rather than something a
  # developer is reading in a browser, so it carries neither the comments nor
  # the attributes saying where a component was called from.
  @debug_heex_annotations false
  @debug_attributes false

  attr :entries, :list, required: true, doc: "the headings to list, as Toc.Entry values"

  @doc """
  The headings of a page, nested as they are written.
  """
  @spec toc(map()) :: Rendered.t()
  def toc(assigns) do
    ~H"""
    <ul class="section-nav">
      <li :for={entry <- @entries} class={"toc-entry toc-h#{entry.level}"}>
        <a href={"##{entry.id}"}>{Phoenix.HTML.raw(entry.label_html)}</a>
        <.toc :if={entry.entries != []} entries={entry.entries} />
      </li>
    </ul>
    """
  end
end
