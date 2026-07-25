defmodule ArchiDep.CourseSite.Renderer.Slides do
  @moduledoc """
  A rendered slide deck, which is still Markdown.

  Slides are converted in the browser: the deck is handed to reveal.js as text
  and it splits it into slides and renders each one. So the renderer's job stops
  at expanding the Liquid — converting the Markdown here would produce a page of
  HTML where a deck was expected.
  """

  @enforce_keys [:markdown]
  defstruct [:markdown]

  @type t :: %__MODULE__{markdown: String.t()}
end
