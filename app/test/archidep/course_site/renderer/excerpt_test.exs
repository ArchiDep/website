defmodule ArchiDep.CourseSite.Renderer.ExcerptTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Renderer.Excerpt
  alias ArchiDep.CourseSite.Renderer.Markdown

  doctest ArchiDep.CourseSite.Renderer.Excerpt

  describe "split/2" do
    test "cuts a document at its separator" do
      assert split(
               """
               Learn to deploy on a platform.

               <!-- more -->

               ## Deploying

               The rest of the page.
               """,
               "<!-- more -->"
             ) ==
               {:ok, "<p>Learn to deploy on a platform.</p>",
                ~s(<h2 id="deploying">Deploying<a href="#deploying" ) <>
                  ~s(aria-label="Link to heading 'Deploying'" data-heading-content="Deploying" ) <>
                  ~s(class="anchor"></a></h2>\n<p>The rest of the page.</p>)}
    end

    test "cuts a document that declares no separator after its first block" do
      assert split("An opening paragraph.\n\nThe rest of it.\n\nAnd more.\n", nil) ==
               {:ok, "<p>An opening paragraph.</p>", "<p>The rest of it.</p>\n<p>And more.</p>"}
    end

    test "reports a document that declares a separator it never writes, cutting it anyway" do
      assert split("An opening paragraph.\n\nThe rest of it.\n", "<!-- more -->") ==
               {:missing_separator, "<p>An opening paragraph.</p>", "<p>The rest of it.</p>"}
    end

    test "reports a single-block document that declares a separator it never writes" do
      assert split("The only paragraph.\n", "<!-- more -->") ==
               {:missing_separator, nil, "<p>The only paragraph.</p>"}
    end

    test "leaves a separator written inside a code block alone" do
      assert split(
               "An opening paragraph.\n\n```html\n<!-- more -->\n```\n\nThe rest of it.\n",
               "<!-- more -->"
             ) ==
               {:missing_separator, "<p>An opening paragraph.</p>",
                "<pre><code class=\"language-html\">&lt;!-- more --&gt;\n</code></pre>\n<p>The rest of it.</p>"}
    end

    test "gives a document of a single block nothing to introduce it" do
      assert split("The only paragraph.\n", nil) == {:ok, nil, "<p>The only paragraph.</p>"}
    end

    test "gives an empty document nothing at all" do
      assert split("", nil) == {:ok, nil, ""}
    end
  end

  defp split(markdown, separator) do
    {result, excerpt, body} =
      markdown
      |> MDEx.parse_document!(Markdown.options())
      |> Excerpt.split(separator)

    {result, html(excerpt), html(body)}
  end

  defp html(nil), do: nil
  defp html(document), do: MDEx.to_html!(document, Markdown.options())
end
