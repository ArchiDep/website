defmodule ArchiDep.CourseSite.Renderer.Liquid.NoteTagTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Renderer
  alias ArchiDep.CourseSite.Renderer.Liquid
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.Support.CourseSiteFactory

  @source_path "chapters/406-unix-processes/subject.md"

  describe "render/1" do
    test "shows an aside of every kind under its own icon and title" do
      assert Map.new(
               ["advanced", "info", "more", "tip", "troubleshooting", "warning"],
               &{&1, render("{% note type: #{&1} %}\nRead this.\n{% endnote %}")}
             ) == %{
               "advanced" => {:ok, note("advanced", ":space_invader:", "Advanced"), []},
               "info" => {:ok, note("info", icon("info-circle"), "Note"), []},
               "more" => {:ok, note("more", ":books:", "More information"), []},
               "tip" => {:ok, note("tip", ":gem:", "Tip"), []},
               "troubleshooting" =>
                 {:ok, note("troubleshooting", ":boom:", "Troubleshooting"), []},
               "warning" => {:ok, note("warning", icon("exclamation-triangle"), "Warning"), []}
             }
    end

    test "takes an aside with no kind at all to be a plain note" do
      assert render("{% note %}\nRead this.\n{% endnote %}") ==
               {:ok, note("info", icon("info-circle"), "Note"), []}
    end

    test "says what the author wrote instead of the title of the kind" do
      assert render(~s({% note type: advanced, title: "Challenge" %}\nRead this.\n{% endnote %})) ==
               {:ok, note("advanced", ":space_invader:", "Challenge"), []}
    end

    test "shows an aside of a kind the site has none of as a plain note, and reports the kind" do
      assert render("{% note type: helpful %}\nRead this.\n{% endnote %}") ==
               {:ok, note("info", icon("info-circle"), "Note"),
                [
                  RenderError.new(
                    {:invalid_tag, "note", ~s(Unknown type "helpful")},
                    @source_path,
                    %{line: 1, column: 1}
                  )
                ]}
    end

    test "expands the Liquid its prose contains before converting it" do
      assert render("""
             {% note type: tip %}
             See the [SFTP exercise]({% link chapters/410-sftp-deployment/exercise.md %}).
             {% endnote %}\
             """) ==
               {:ok,
                note(
                  "tip",
                  ":gem:",
                  "Tip",
                  ~s(<p>See the <a href="/2027/course/410-sftp-deployment/">SFTP exercise</a>.</p>)
                ), []}
    end

    test "reports the icon of a kind whose partial the build was never given" do
      assert render("{% note type: warning %}\nRead this.\n{% endnote %}", includes: %{}) ==
               {:ok, note("warning", "", "Warning"),
                [
                  RenderError.new(
                    {:unknown_include, "icons/exclamation-triangle.html"},
                    @source_path,
                    %{line: 1, column: 1}
                  )
                ]}
    end
  end

  defp note(type, icon, title, content \\ "<p>Read this.</p>"),
    do:
      ~s(<div class="note note-#{type}">) <>
        ~s(<div class="title">#{icon}<span>#{title}</span></div>) <>
        ~s(<div class="content">#{content}</div>) <>
        ~s(</div>)

  defp icon(name), do: ~s(<svg class="size-6">#{name}</svg>)

  defp icons do
    {:ok, includes} =
      Renderer.compile_includes(
        Map.new(
          ["info-circle", "exclamation-triangle"],
          &{"icons/#{&1}.html", ~s(<svg class="{{ include.class }}">#{&1}</svg>\n)}
        )
      )

    includes
  end

  defp render(text, attrs \\ []) do
    Liquid.render(
      CourseSiteFactory.build(
        :render_context,
        Keyword.merge(
          [
            source: CourseSiteFactory.build(:source, text: text),
            source_path: @source_path,
            page: {:document, DocumentRef.new(406, "unix-processes", :subject)},
            urls: CourseSiteFactory.build(:url_context, version: "2027", base_path: ""),
            includes: icons()
          ],
          attrs
        )
      )
    )
  end
end
