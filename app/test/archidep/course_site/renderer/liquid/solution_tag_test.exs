defmodule ArchiDep.CourseSite.Renderer.Liquid.SolutionTagTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Renderer.Liquid
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.Support.CourseSiteFactory

  @source_path "chapters/205-php-todolist/exercise.md"
  @page {:document, DocumentRef.new(205, "php-todolist", :exercise)}

  describe "render/1" do
    test "collapses the answer to an exercise behind a title the reader clicks" do
      assert render("{% solution %}\nRun `ls -la`.\n{% endsolution %}") ==
               {:ok, solution(~s(<p>Run <code>ls -la</code>.</p>)), []}
    end

    test "expands the Liquid the answer contains before converting it" do
      assert render("""
             {% solution %}
             Read the [SFTP exercise]({% link chapters/410-sftp-deployment/exercise.md %}).
             {% endsolution %}\
             """) ==
               {:ok,
                solution(
                  ~s(<p>Read the <a href="/2030/course/410-sftp-deployment/">SFTP exercise</a>.</p>)
                ), []}
    end

    test "leaves the answer out of a page the course has not covered yet" do
      assert render("{% solution %}\nRun `ls -la`.\n{% endsolution %}", solutions: :hidden) ==
               {:ok, "", []}
    end

    test "reports the file a withheld answer refers to and cannot find" do
      assert render("{% solution %}\n![Diagram](images/typo.png)\n{% endsolution %}",
               solutions: :hidden
             ) ==
               {:ok, "",
                [
                  RenderError.new(
                    {:url,
                     {:unknown_page_asset, @page, "images/typo.png",
                      "/course/205-php-todolist/images/typo.png"}},
                    @source_path,
                    nil
                  )
                ]}
    end

    test "labels the answer with its title" do
      assert render(
               ~s({% solution title: "Check your prediction" %}\nRun `ls -la`.\n{% endsolution %})
             ) ==
               {:ok, solution(~s(<p>Run <code>ls -la</code>.</p>), "Check your prediction"), []}
    end

    test "shows the answer with the emoji it names" do
      assert render("{% solution emoji: thinking %}\nRun `ls -la`.\n{% endsolution %}") ==
               {:ok, solution(~s(<p>Run <code>ls -la</code>.</p>), "Solution", ":thinking:"), []}
    end

    test "shows and reports an answer with an unknown emoji with the default one" do
      assert render("{% solution emoji: unicorn %}\nRun `ls -la`.\n{% endsolution %}") ==
               {:ok, solution(~s(<p>Run <code>ls -la</code>.</p>)),
                [
                  RenderError.new(
                    {:invalid_tag, "solution", ~s(Unknown emoji "unicorn")},
                    @source_path,
                    %{line: 1, column: 1}
                  )
                ]}
    end

    test "shows an answer to reveal always in a page the course has not covered yet" do
      assert render("{% solution reveal: always %}\nRun `ls -la`.\n{% endsolution %}",
               solutions: :hidden
             ) ==
               {:ok, solution(~s(<p>Run <code>ls -la</code>.</p>)), []}
    end

    test "withholds and reports an answer with an unknown reveal" do
      assert render("{% solution reveal: soon %}\nRun `ls -la`.\n{% endsolution %}",
               solutions: :hidden
             ) ==
               {:ok, "",
                [
                  RenderError.new(
                    {:invalid_tag, "solution",
                     ~s(Unknown reveal "soon", the only one is "always")},
                    @source_path,
                    %{line: 1, column: 1}
                  )
                ]}
    end

    test "refuses an answer to always reveal written on the home page" do
      assert render("{% solution reveal: always %}\nRun `ls -la`.\n{% endsolution %}",
               page: :home
             ) == {:ok, "", [outside_a_chapter()]}
    end

    test "refuses an answer written on the home page" do
      assert render("{% solution %}\nRun `ls -la`.\n{% endsolution %}", page: :home) ==
               {:ok, "", [outside_a_chapter()]}
    end

    test "refuses an answer written in a cheatsheet" do
      assert render("{% solution %}\nRun `ls -la`.\n{% endsolution %}",
               page: {:cheatsheet, "sysadmin"}
             ) == {:ok, "", [outside_a_chapter()]}
    end
  end

  defp outside_a_chapter,
    do:
      RenderError.new(
        {:invalid_tag, "solution", "only a chapter has an exercise for a solution to answer"},
        @source_path,
        %{line: 1, column: 1}
      )

  defp solution(content, title \\ "Solution", emoji \\ ":key:"),
    do:
      ~s(<div class="solution collapse screen:collapse-arrow print:collapse-open ) <>
        ~s(border border-neutral">) <>
        ~s(<input type="checkbox" class="peer" />) <>
        ~s(<div class="collapse-title font-semibold peer-hover:bg-primary/25">) <>
        ~s(<div class="flex items-center gap-2">#{emoji}<span>#{title}</span></div>) <>
        ~s(</div>) <>
        ~s(<div class="collapse-content overflow-x-auto">#{content}</div>) <>
        ~s(</div>)

  defp render(text, attrs \\ []) do
    Liquid.render(
      CourseSiteFactory.build(
        :render_context,
        Keyword.merge(
          [
            source: CourseSiteFactory.build(:source, text: text),
            source_path: @source_path,
            page: @page,
            urls: CourseSiteFactory.build(:url_context, version: "2030", base_path: "")
          ],
          attrs
        )
      )
    )
  end
end
