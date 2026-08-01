defmodule ArchiDep.CourseSite.Layout.Chrome.PresentationTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.CourseSiteChrome, only: [icon: 2, render: 2]

  alias ArchiDep.CourseSite.Layout.Chrome.Presentation

  @url "/course/507-dns/slides/"

  describe "presentation/1" do
    test "shows a chapter's deck in place, and offers it both ways" do
      assert render(&Presentation.presentation/1, %{url: @url}) == expected(@url)
    end

    test "asks for the deck where the build published it" do
      assert render(&Presentation.presentation/1, %{url: "/2025/course/507-dns/slides/"}) ==
               expected("/2025/course/507-dns/slides/")
    end
  end

  defp expected(url) do
    String.trim_trailing("""
    <div class="not-prose print:hidden">
      <div class="mt-4 mb-2 flex justify-between items-end gap-x-2">
        <h2 id="presentation" class="text-4xl font-bold">Presentation</h2>
        <div class="flex items-center gap-2">
          <a href="#{url}?show-notes=true" target="_blank" rel="noopener noreferrer" class="flex items-center gap-x-2 opacity-75 hover:opacity-100 tooltip" data-tip="Open with speaker notes">
            #{icon(:document_text, "size-8")}
          </a>
          <a href="#{url}" target="_blank" rel="noopener noreferrer" class="flex items-center gap-x-2 opacity-75 hover:opacity-100 tooltip" data-tip="Open">
            #{icon(:presentation_chart_line, "size-8")}
          </a>
        </div>
      </div>

      <iframe class="w-full aspect-video dark:opacity-85" src="#{url}?view=scroll" title="Slides"></iframe>
    </div>
    """)
  end
end
