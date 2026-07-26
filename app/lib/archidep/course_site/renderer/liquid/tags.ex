defmodule ArchiDep.CourseSite.Renderer.Liquid.Tags do
  @moduledoc """
  The Liquid tags a course document may use.

  It is `Solid`'s own set, plus the ones this course writes, minus `render`:
  that one pulls in another template from a file system the renderer
  deliberately does not have, so leaving it in would turn a mistyped tag name
  into a confusing failure about templates instead of an unknown tag.
  """

  alias ArchiDep.CourseSite.Renderer.Liquid.CalloutTag
  alias ArchiDep.CourseSite.Renderer.Liquid.ColsTag
  alias ArchiDep.CourseSite.Renderer.Liquid.IncludeTag
  alias ArchiDep.CourseSite.Renderer.Liquid.LinkTag
  alias ArchiDep.CourseSite.Renderer.Liquid.MarkdownTag
  alias ArchiDep.CourseSite.Renderer.Liquid.MermaidTag
  alias ArchiDep.CourseSite.Renderer.Liquid.NoteTag
  alias ArchiDep.CourseSite.Renderer.Liquid.SolutionTag

  @doc """
  The tag table of a build.
  """
  @spec default() :: %{String.t() => module()}
  def default do
    Solid.Tag.default_tags()
    |> Map.delete("render")
    |> Map.merge(%{
      "callout" => CalloutTag,
      "cols" => ColsTag,
      "include" => IncludeTag,
      "link" => LinkTag,
      "markdown" => MarkdownTag,
      "mermaid" => MermaidTag,
      "note" => NoteTag,
      "solution" => SolutionTag
    })
  end
end
