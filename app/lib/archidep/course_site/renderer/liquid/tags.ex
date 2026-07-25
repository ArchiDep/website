defmodule ArchiDep.CourseSite.Renderer.Liquid.Tags do
  @moduledoc """
  The Liquid tags a course document may use.

  It is `Solid`'s own set, plus the ones this course writes, minus `render`:
  that one pulls in another template from a file system the renderer
  deliberately does not have, so leaving it in would turn a mistyped tag name
  into a confusing failure about templates instead of an unknown tag.
  """

  alias ArchiDep.CourseSite.Renderer.Liquid.IncludeTag
  alias ArchiDep.CourseSite.Renderer.Liquid.LinkTag

  @doc """
  The tag table of a build.
  """
  @spec default() :: %{String.t() => module()}
  def default do
    Solid.Tag.default_tags()
    |> Map.delete("render")
    |> Map.merge(%{"include" => IncludeTag, "link" => LinkTag})
  end
end
