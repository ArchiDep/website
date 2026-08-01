defmodule ArchiDep.CourseSite.Layout.Chrome do
  @moduledoc """
  The site's own chrome: what a reader of the course actually sees around a
  page.

  This is the `ArchiDep.CourseSite.Layout` a real build uses, where
  `ArchiDep.CourseSite.Layout.Minimal` is what a build uses when the chrome is
  not what is being checked.

  ## Resolve, then draw

  Laying a page out is two steps and they do not interleave.
  [`Chrome.Assigns`](`ArchiDep.CourseSite.Layout.Chrome.Assigns`) resolves every
  reference the chrome writes and reports the ones it could not; only if there
  were none is anything drawn, from a value in which nothing is left to work
  out. That is what lets the layout owe the build *every* failure rather than
  the first, which a template — evaluating as it goes — cannot do.

  ## One callback, and the table it hides

  The behaviour has a single callback, so choosing between the site's layouts is
  this module's business and never the build's. The choice is made once, into
  `ArchiDep.CourseSite.Layout.Chrome.Assigns` `kind`, and read from there: a
  deck is its own document, and everything else is a page of the site with the
  same bar, drawer and navigation around it, differing only in what it opens
  with.
  """

  @behaviour ArchiDep.CourseSite.Layout

  alias ArchiDep.CourseSite.Layout.Chrome.Assigns
  alias ArchiDep.CourseSite.Layout.Chrome.Deck
  alias ArchiDep.CourseSite.Layout.Chrome.Document
  alias ArchiDep.CourseSite.Layout.Chrome.Html
  alias ArchiDep.CourseSite.Layout.LayoutContext

  @impl ArchiDep.CourseSite.Layout
  def document(%LayoutContext{} = context) do
    with {:ok, page} <- Assigns.build(context) do
      {:ok, draw(page)}
    end
  end

  defp draw(%Assigns{kind: :deck} = page),
    do: %{page: page} |> Deck.deck() |> Html.render()

  defp draw(%Assigns{} = page),
    do: %{page: page} |> Document.document() |> Html.render()
end
