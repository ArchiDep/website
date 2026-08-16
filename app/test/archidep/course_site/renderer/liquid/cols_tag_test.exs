defmodule ArchiDep.CourseSite.Renderer.Liquid.ColsTagTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Renderer.Liquid
  alias ArchiDep.CourseSite.Renderer.Liquid.ColsTag
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.Support.CourseSiteFactory

  doctest ColsTag

  @source_path "chapters/302-git-branching/subject.md"

  describe "render/1" do
    test "lays two columns out side by side, which is what a row is by default" do
      assert render("""
             {% cols %}
             The left one.
             <!-- col -->
             The right one.
             {% endcols %}\
             """) ==
               {:ok,
                row(
                  "md:grid-cols-2",
                  ~s(<div><p>The left one.</p></div><div><p>The right one.</p></div>)
                ), []}
    end

    test "takes the text before the first marker to be the first column" do
      assert render("""
             {% cols columns: 3 %}
             <!-- col -->
             The only one.
             {% endcols %}\
             """) ==
               {:ok, row("md:grid-cols-3", ~s(<div><p>The only one.</p></div>)), []}
    end

    test "gives a column the classes its marker carries, so that it may span several" do
      assert render("""
             {% cols columns: 3 %}
             <!-- col md:col-span-2 -->
             The wide one.
             <!-- column text-center -->
             The narrow one.
             {% endcols %}\
             """) ==
               {:ok,
                row(
                  "md:grid-cols-3",
                  ~s(<div class="md:col-span-2"><p>The wide one.</p></div>) <>
                    ~s(<div class="text-center"><p>The narrow one.</p></div>)
                ), []}
    end

    test "lays a row of more columns than the grid has out in two, and reports the number" do
      assert render("{% cols columns: 13 %}\nThe only one.\n{% endcols %}") ==
               {:ok, row("md:grid-cols-2", ~s(<div><p>The only one.</p></div>)),
                [
                  RenderError.new(
                    {:invalid_tag, "cols",
                     "The number of columns must be between 2 and 12, got 13"},
                    @source_path,
                    %{line: 1, column: 1}
                  )
                ]}
    end

    test "expands the Liquid a column contains before converting it" do
      assert render("""
             {% cols %}
             Read the [SFTP exercise]({% link chapters/410-sftp-deployment/exercise.md %}).
             <!-- col -->
             Then come back.
             {% endcols %}\
             """) ==
               {:ok,
                row(
                  "md:grid-cols-2",
                  ~s(<div><p>Read the ) <>
                    ~s(<a href="/2029/course/410-sftp-deployment/">SFTP exercise</a>.</p></div>) <>
                    ~s(<div><p>Then come back.</p></div>)
                ), []}
    end
  end

  defp row(grid_class, columns),
    do: ~s(<div class="cols grid grid-cols-1 #{grid_class} gap-4">#{columns}</div>)

  defp render(text) do
    Liquid.render(
      CourseSiteFactory.build(:render_context,
        source: CourseSiteFactory.build(:source, text: text),
        source_path: @source_path,
        page: {:document, DocumentRef.new(302, "git-branching", :subject)},
        urls: CourseSiteFactory.build(:url_context, version: "2029", base_path: "")
      )
    )
  end
end
