defmodule ArchiDepWeb.Helpers.CourseMaterialHelpers do
  @moduledoc """
  Helper functions to link into the course material from the dashboard.

  `ArchiDep.CourseSite.Material` stores what a page of the course material *is*
  rather than where it is served from, so this is where the application turns
  one of those into a URL. It goes through `ArchiDep.CourseSite.Urls` like every
  other URL of the site, which is what keeps the mount point and the edition
  prefix out of both the compiled model and the templates.

  A reference the course material does not hold is a stale link the application
  wrote rather than a fact about the content, so this resolves with
  `ArchiDep.CourseSite.Urls.resolve!/2` and raises.
  """

  alias ArchiDep.CourseSite.HeadingRef
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Cheatsheet
  alias ArchiDep.CourseSite.Urls
  alias ArchiDep.CourseSite.Urls.UrlContext

  # The application resolves no reference that is named after a build, so there
  # is nothing meaningful to identify one with. It is a literal rather than the
  # Git revision because a checkout that cannot say what its revision is would
  # otherwise take every page of the dashboard down with it.
  @build_id "app"

  @doc """
  Where a page of the course material, or one of its headings, is served from.

  A chapter, a cheatsheet and a heading are named by the values the compiled
  model holds; anything else is taken to be a reference already and passed
  through, so the home page of the course material is `course_url(:home)`.

  There is deliberately no way to pass a heading as a string. An identifier is
  the renderer's to assign rather than the application's to know, so naming one
  goes through `ArchiDep.CourseSite.Material`, where a heading the course no
  longer has fails the build.
  """
  @spec course_url(Chapter.t() | Cheatsheet.t() | HeadingRef.t() | Urls.logical_reference()) ::
          String.t()
  def course_url(page), do: Urls.resolve!(url_context(), reference(page))

  @doc """
  How the dashboard addresses the course material site: where it is mounted and
  which edition of the course it holds.

  Built per call rather than memoized — it is a handful of guards and three
  empty manifests, against the fifty-odd references one page of the dashboard
  resolves.
  """
  @spec url_context() :: UrlContext.t()
  def url_context,
    do:
      :archidep
      |> Application.get_env(:course_site, [])
      |> Keyword.put(:build_id, @build_id)
      |> UrlContext.new()

  defp reference(%Chapter{} = chapter), do: Chapter.page_ref(chapter)
  defp reference(%Cheatsheet{} = cheatsheet), do: Cheatsheet.page_ref(cheatsheet)
  defp reference(%HeadingRef{page: page, id: id}), do: {:heading, page, id}
  defp reference(reference), do: reference
end
