defmodule ArchiDep.CourseSite.Renderer.HtmlPass do
  @moduledoc """
  A rewrite of the finished HTML of a page, applied once at the end.

  Two things force this to exist alongside
  `ArchiDep.CourseSite.Renderer.AstPass`. A block tag converts its body to HTML
  while Liquid is still running, so by the time the page's Markdown document
  exists that body is one opaque node — a rewrite of links or text inside a note
  or a callout can only happen here. And a tag writes text of its own around
  that body, which was never Markdown at all.

  Emoji shortcodes are the case that shows why: a tag writes them in the wrapper
  it puts around its body, which was never Markdown at all, so a sweep of the
  document would leave those alone. The identifiers of the page are no argument
  either way — `ArchiDep.CourseSite.Renderer.HeadingIdentifiers` keeps the
  shortcodes of a heading out of them before the page is rendered.
  """

  alias ArchiDep.CourseSite.Renderer.RenderContext
  alias ArchiDep.CourseSite.Renderer.RenderError

  @callback run(String.t(), RenderContext.t()) :: {String.t(), [RenderError.t()]}
end
