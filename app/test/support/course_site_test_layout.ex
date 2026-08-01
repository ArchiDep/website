defmodule ArchiDep.Support.CourseSiteTestLayout do
  @moduledoc """
  Layouts that exist only to drive the course material build in tests.

  `ArchiDep.CourseSite.Layout` is the seam the site's own chrome plugs into.
  These are the smallest things that fit it, so that a test of what a build
  *plans* does not depend on what any particular layout happens to emit.
  """

  defmodule Wrapper do
    @moduledoc """
    A layout that writes down what it was given, in one line, so that a test
    asserting a whole file asserts what reached the layout rather than a page of
    markup.
    """

    @behaviour ArchiDep.CourseSite.Layout

    alias ArchiDep.CourseSite.Layout.LayoutContext
    alias ArchiDep.CourseSite.PageRef
    alias ArchiDep.CourseSite.Progress
    alias ArchiDep.CourseSite.Renderer.Page
    alias ArchiDep.CourseSite.Renderer.Slides
    alias ArchiDep.CourseSite.Session

    @impl ArchiDep.CourseSite.Layout
    def document(%LayoutContext{} = context) do
      {:ok,
       Enum.join(
         [
           PageRef.output_path(context.page),
           context.source_path,
           context.metadata.title,
           entry(context.entry),
           section(context.section),
           last_session(context.progress),
           body(context.content)
         ],
         "|"
       )}
    end

    defp entry(nil), do: ""
    defp entry(%{title: title}), do: title

    defp section(nil), do: ""
    defp section(%{title: title}), do: title

    # The last session the record kept, since that is the one it is kept for.
    defp last_session(%Progress{last: nil}), do: ""
    defp last_session(%Progress{last: %Session{title: title}}), do: title

    defp body(%Slides{markdown: markdown}), do: "deck:" <> markdown

    defp body(%Page{} = page),
      do:
        String.replace(
          "page:#{page.excerpt_html}:#{Enum.map_join(page.toc, ",", & &1.id)}:#{page.html}",
          "\n",
          " "
        )
  end

  defmodule Failing do
    @moduledoc """
    A layout that cannot resolve a reference of its own, which is how a build
    reports a page it rendered but could not lay out.
    """

    @behaviour ArchiDep.CourseSite.Layout

    alias ArchiDep.CourseSite.Layout.LayoutContext

    @impl ArchiDep.CourseSite.Layout
    def document(%LayoutContext{}), do: {:error, [{:unknown_asset, "/assets/missing.css"}]}
  end
end
