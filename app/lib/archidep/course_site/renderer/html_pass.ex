defmodule ArchiDep.CourseSite.Renderer.HtmlPass do
  @moduledoc """
  A rewrite of the finished HTML of a page, applied once at the end.

  Two things force this to exist alongside
  `ArchiDep.CourseSite.Renderer.AstPass`. A block tag converts its body to HTML
  while Liquid is still running, so by the time the page's Markdown document
  exists that body is one opaque node — a rewrite of links or text inside a note
  or a callout can only happen here. And a tag writes text of its own around
  that body, which was never Markdown at all.

  There is a second, sharper reason for emoji shortcodes specifically: heading
  identifiers are slugged from the heading's text as it is rendered, and the
  course links to headings such as `#exclamation-create-your-server`. Replacing
  `:exclamation:` with the character before rendering would silently move every
  one of those anchors.
  """

  alias ArchiDep.CourseSite.Renderer.RenderContext
  alias ArchiDep.CourseSite.Renderer.RenderError

  @callback run(String.t(), RenderContext.t()) :: {String.t(), [RenderError.t()]}
end
