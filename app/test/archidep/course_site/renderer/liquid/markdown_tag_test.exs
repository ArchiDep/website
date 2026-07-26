defmodule ArchiDep.CourseSite.Renderer.Liquid.MarkdownTagTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Renderer.Liquid
  alias ArchiDep.Support.CourseSiteFactory

  describe "render/1" do
    test "converts a piece of the page the page itself would not convert" do
      assert render(
               "<figcaption>\n{% markdown %}\nThe **engine**.\n{% endmarkdown %}\n</figcaption>"
             ) ==
               {:ok,
                ~s(<figcaption>\n<div class="markdown">) <>
                  ~s(<p>The <strong>engine</strong>.</p></div>\n</figcaption>), []}
    end

    test "expands the Liquid it contains before converting it" do
      assert render("""
             {% markdown %}
             Read the [SFTP exercise]({% link _course/410-sftp-deployment/exercise.md %}).
             {% endmarkdown %}\
             """) ==
               {:ok,
                ~s(<div class="markdown"><p>Read the ) <>
                  ~s(<a href="/2032/course/410-sftp-deployment/">SFTP exercise</a>.</p></div>),
                []}
    end
  end

  defp render(text) do
    Liquid.render(
      CourseSiteFactory.build(:render_context,
        source: CourseSiteFactory.build(:source, text: text),
        source_path: "_course/601-databases/subject.md",
        page: {:document, DocumentRef.new(601, "databases", :subject)},
        urls: CourseSiteFactory.build(:url_context, version: "2032", base_path: "")
      )
    )
  end
end
