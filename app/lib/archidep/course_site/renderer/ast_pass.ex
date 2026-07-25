defmodule ArchiDep.CourseSite.Renderer.AstPass do
  @moduledoc """
  A rewrite of a Markdown document, applied between parsing and rendering.

  A pass runs over **every** document the build converts — a whole page and the
  body of every block tag alike — because a tag's body is converted on its own
  and would otherwise be invisible to it. Anything that must instead see the
  finished page, or the HTML a tag wrote around its body, is an
  `ArchiDep.CourseSite.Renderer.HtmlPass`.

  A pass returns errors rather than raising, because the things it does can
  legitimately fail on a fact about the content: digesting an image next to a
  page fails when the image is not there.
  """

  alias ArchiDep.CourseSite.Renderer.RenderContext
  alias ArchiDep.CourseSite.Renderer.RenderError

  @callback run(MDEx.Document.t(), RenderContext.t()) ::
              {MDEx.Document.t(), [RenderError.t()]}
end
