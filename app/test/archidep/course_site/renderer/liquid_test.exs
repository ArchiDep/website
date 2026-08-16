defmodule ArchiDep.CourseSite.Renderer.LiquidTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Renderer
  alias ArchiDep.CourseSite.Renderer.Liquid
  alias ArchiDep.CourseSite.Renderer.Liquid.Tags
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.CourseSite.Urls.PageAssetManifest
  alias ArchiDep.Support.CourseSiteFactory
  alias ArchiDep.Support.CourseSiteRendererTestTags

  describe "render/1" do
    test "renders a document that has no Liquid in it at all" do
      assert render("Just prose.\n") == {:ok, "Just prose.\n", []}
    end

    test "resolves a link to another document of the course" do
      assert render(
               "See the [SFTP exercise]({% link chapters/410-sftp-deployment/exercise.md %}).\n"
             ) ==
               {:ok, "See the [SFTP exercise](/2026/course/410-sftp-deployment/).\n", []}
    end

    test "resolves a link written across several lines, and its fragment" do
      assert render("""
             See the [exercise]({%
               link chapters/410-sftp-deployment/exercise.md %}#the-end).
             """) ==
               {:ok, "See the [exercise](/2026/course/410-sftp-deployment/#the-end).\n", []}
    end

    test "reports a link to a document that is not one, and leaves the link empty" do
      assert render("See the [notes]({% link chapters/507-dns/notes.md %}).\n") ==
               {:ok, "See the [notes]().\n",
                [
                  RenderError.new(
                    {:invalid_document, "chapters/507-dns/notes.md"},
                    "chapters/701-paas/subject.md",
                    %{line: 1, column: 17}
                  )
                ]}
    end

    test "reports every problem of a document rather than the first" do
      assert render("""
             {% boom %}

             Prose in between.

             {% boom %}
             """) ==
               {:ok, "\n\nProse in between.\n\n\n",
                [
                  boom_error(%{line: 1, column: 1}),
                  boom_error(%{line: 5, column: 1})
                ]}
    end

    test "puts a partial in the page, with the values it was given" do
      {:ok, includes} =
        Renderer.compile_includes(%{
          "icons/photo.html" => ~s(<svg class="{{ include.class }}"></svg>)
        })

      assert render(~s({% include icons/photo.html class="size-12 opacity-50" %}\n),
               includes: includes
             ) == {:ok, ~s(<svg class="size-12 opacity-50"></svg>\n), []}
    end

    test "reports a partial the build was never given" do
      assert render("{% include icons/nope.html %}\n") ==
               {:ok, "\n",
                [
                  RenderError.new(
                    {:unknown_include, "icons/nope.html"},
                    "chapters/701-paas/subject.md",
                    %{line: 1, column: 1}
                  )
                ]}
    end

    test "makes the front matter and the build's own values available to the page" do
      assert render(
               "---\ntitle: Platform-as-a-Service\n---\n{{ page.title }} is chapter {{ page.num }}.\n",
               page_variables: %{"num" => 701}
             ) == {:ok, "Platform-as-a-Service is chapter 701.\n", []}
    end

    test "reports a reference to a value the document was never given" do
      assert render("Written by {{ page.author }}.\n") ==
               {:error,
                [
                  RenderError.new(
                    {:liquid, "Undefined variable page.author"},
                    "chapters/701-paas/subject.md",
                    %{line: 1, column: 15}
                  )
                ]}
    end

    test "resolves the URL of a file sitting next to the page" do
      urls =
        CourseSiteFactory.build(:url_context,
          version: "2026",
          page_assets:
            PageAssetManifest.new(%{
              "/course/701-paas/images/render.png" => "render-4d5e6f.png"
            })
        )

      assert render(~s(<img src="{{ 'images/render.png' | relative_file_url }}">\n), urls: urls) ==
               {:ok, ~s(<img src="images/render-4d5e6f.png">\n), []}
    end

    test "reports a file that is not next to the page after all, and keeps what the author wrote" do
      assert render(~s(<img src="{{ 'images/missing.png' | relative_file_url }}">\n)) ==
               {:ok, ~s(<img src="images/missing.png">\n),
                [
                  RenderError.new(
                    {:url,
                     {:unknown_page_asset, {:document, DocumentRef.new(701, "paas", :subject)},
                      "images/missing.png", "/course/701-paas/images/missing.png"}},
                    "chapters/701-paas/subject.md"
                  )
                ]}
    end

    test "expands the Liquid of a block tag's body, then converts it" do
      assert render("""
             {% prose kind: tip %}
             See the [exercise]({% link chapters/410-sftp-deployment/exercise.md %}).
             {% endprose %}
             """) ==
               {:ok,
                ~s(<div class="prose-tip"><p>See the ) <>
                  ~s(<a href="/2026/course/410-sftp-deployment/">exercise</a>.</p></div>\n), []}
    end

    test "leaves the body of a code tag exactly as it was written" do
      assert render("""
             {% code %}
             - name: {{ ansible_hostname }}
             {% endcode %}
             """) == {:ok, "<pre>\n- name: {{ ansible_hostname }}\n</pre>\n", []}
    end

    test "reports a document that does not parse, and renders nothing of it" do
      assert render("{% note: type: tip %}\nA note.\n{% endnote %}\n") ==
               {:error,
                [
                  liquid_error("Unexpected tag 'note:'", %{line: 1, column: 1}),
                  liquid_error("Unexpected tag 'endnote'", %{line: 3, column: 1})
                ]}
    end

    test "refuses the render tag, which would need a file system" do
      assert render("{% render 'partial' %}\n") ==
               {:error, [liquid_error("Unexpected tag 'render'", %{line: 1, column: 1})]}
    end
  end

  describe "parse/3" do
    test "parses a partial" do
      source = ~s(<svg class="{{ include.class }}"></svg>)

      assert Liquid.parse(source, Tags.default(), "icons/photo.html") ==
               Solid.parse(source, tags: Tags.default())
    end

    test "reports a partial that does not parse" do
      assert Liquid.parse("{% nope %}", Tags.default(), "icons/broken.html") ==
               {:error,
                [
                  RenderError.new(
                    {:liquid, "Unexpected tag 'nope'"},
                    "icons/broken.html",
                    %{line: 1, column: 1}
                  )
                ]}
    end
  end

  defp boom_error(loc),
    do:
      RenderError.new(
        {:invalid_tag, "boom", "this tag always fails"},
        "chapters/701-paas/subject.md",
        loc
      )

  defp liquid_error(message, loc),
    do: RenderError.new({:liquid, message}, "chapters/701-paas/subject.md", loc)

  defp render(text, attrs \\ []) do
    Liquid.render(
      CourseSiteFactory.build(
        :render_context,
        Keyword.merge(
          [
            source: CourseSiteFactory.build(:source, text: text),
            source_path: "chapters/701-paas/subject.md",
            page: {:document, DocumentRef.new(701, "paas", :subject)},
            urls: CourseSiteFactory.build(:url_context, version: "2026", base_path: ""),
            options:
              CourseSiteFactory.build(:render_options, tags: CourseSiteRendererTestTags.tags())
          ],
          attrs
        )
      )
    )
  end
end
