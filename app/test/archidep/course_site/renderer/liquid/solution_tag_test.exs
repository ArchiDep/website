defmodule ArchiDep.CourseSite.Renderer.Liquid.SolutionTagTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Renderer.Liquid
  alias ArchiDep.Support.CourseSiteFactory

  describe "render/1" do
    test "collapses the answer to an exercise behind a title the reader clicks" do
      assert render("{% solution %}\nRun `ls -la`.\n{% endsolution %}") ==
               {:ok, solution(~s(<p>Run <code>ls -la</code>.</p>)), []}
    end

    test "expands the Liquid the answer contains before converting it" do
      assert render("""
             {% solution %}
             Read the [SFTP exercise]({% link _course/410-sftp-deployment/exercise.md %}).
             {% endsolution %}\
             """) ==
               {:ok,
                solution(
                  ~s(<p>Read the <a href="/2030/course/410-sftp-deployment/">SFTP exercise</a>.</p>)
                ), []}
    end
  end

  defp solution(content),
    do:
      ~s(<div class="solution collapse screen:collapse-arrow print:collapse-open ) <>
        ~s(border border-neutral hover:bg-primary/25">) <>
        ~s(<input type="checkbox" />) <>
        ~s(<div class="collapse-title font-semibold">) <>
        ~s(<div class="flex items-center gap-2">:key:<span>Solution</span></div>) <>
        ~s(</div>) <>
        ~s(<div class="collapse-content overflow-x-auto">#{content}</div>) <>
        ~s(</div>)

  defp render(text) do
    Liquid.render(
      CourseSiteFactory.build(:render_context,
        source: CourseSiteFactory.build(:source, text: text),
        source_path: "_course/205-php-todolist/exercise.md",
        page: {:document, DocumentRef.new(205, "php-todolist", :exercise)},
        urls: CourseSiteFactory.build(:url_context, version: "2030", base_path: "")
      )
    )
  end
end
