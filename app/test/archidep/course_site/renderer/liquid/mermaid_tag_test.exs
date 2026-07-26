defmodule ArchiDep.CourseSite.Renderer.Liquid.MermaidTagTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Renderer.Liquid
  alias ArchiDep.Support.CourseSiteFactory

  describe "render/1" do
    test "puts the description of a diagram on the page for the browser to draw" do
      assert render("""
             {% mermaid %}
             flowchart LR
               client --> server
             {% endmermaid %}\
             """) ==
               {:ok, ~s(<pre class="mermaid loading">\nflowchart LR\n  client --> server\n</pre>),
                []}
    end

    test "leaves a description that looks like Liquid exactly as it was written" do
      assert render("{% mermaid %}\nflowchart LR\n  a[\"{{ name }}\"]\n{% endmermaid %}") ==
               {:ok, ~s(<pre class="mermaid loading">\nflowchart LR\n  a["{{ name }}"]\n</pre>),
                []}
    end
  end

  defp render(text) do
    Liquid.render(
      CourseSiteFactory.build(:render_context,
        source: CourseSiteFactory.build(:source, text: text),
        source_path: "_course/104-ssh/slides/slides.md",
        page: {:document, DocumentRef.new(104, "ssh", :slides)},
        urls: CourseSiteFactory.build(:url_context, version: "2031", base_path: "")
      )
    )
  end
end
