defmodule ArchiDep.CourseSite.Renderer.MarkdownTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias ArchiDep.CourseSite.Renderer.Markdown
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.CourseSite.Renderer.Source
  alias ArchiDep.Support.CourseSiteFactory
  alias ArchiDep.Support.CourseSiteRendererTestTags.FailingPass
  alias ArchiDep.Support.CourseSiteRendererTestTags.ShoutingPass

  describe "to_html/2" do
    test "converts Markdown" do
      assert Markdown.to_html("A *paragraph* with `code`.\n", context()) ==
               {"<p>A <em>paragraph</em> with <code>code</code>.</p>", []}
    end

    test "highlights the code of a fenced block" do
      assert Markdown.to_html("```bash\npwd\n```\n", context()) ==
               {~s(<pre class="lumis"><code class="language-bash" translate="no" tabindex="0">) <>
                  ~s(<div class="l-line" data-line="1">) <>
                  ~s(<span class="l-function-builtin">pwd</span>\n</div></code></pre>), []}
    end

    test "keeps the raw HTML the course writes in its Markdown" do
      assert Markdown.to_html("<div class='w80'><span>Zone file</span></div>\n", context()) ==
               {"<div class='w80'><span>Zone file</span></div>", []}
    end

    test "turns quotes into their typographic characters" do
      assert Markdown.to_html("It's the server's name.\n", context()) ==
               {"<p>It’s the server’s name.</p>", []}
    end

    test "gives every heading an identifier slugged from its text" do
      assert Markdown.to_html("## Create your server\n", context()) ==
               {~s(<h2 id="create-your-server">Create your server) <>
                  ~s(<a href="#create-your-server" ) <>
                  ~s(aria-label="Link to heading 'Create your server'" ) <>
                  ~s(data-heading-content="Create your server" class="anchor"></a></h2>), []}
    end

    test "leaves the emoji a heading is decorated with out of its identifier" do
      assert Markdown.to_html("## :exclamation: Register your server\n", context()) ==
               {~s(<h2 id="register-your-server">:exclamation: Register your server) <>
                  ~s(<a href="#register-your-server" ) <>
                  ~s(aria-label="Link to heading 'Register your server'" ) <>
                  ~s(data-heading-content="Register your server" class="anchor"></a></h2>), []}
    end

    test "converts the GitHub flavour the course writes" do
      assert Markdown.to_html(
               """
               | Command | Effect |
               | ------- | ------ |
               | `ls`    | Lists  |

               - [x] Done
               - [ ] Not done

               ~~Struck~~ and [a link](https://example.com)
               """,
               context()
             ) ==
               {String.trim_trailing("""
                <table>
                <thead>
                <tr>
                <th>Command</th>
                <th>Effect</th>
                </tr>
                </thead>
                <tbody>
                <tr>
                <td><code>ls</code></td>
                <td>Lists</td>
                </tr>
                </tbody>
                </table>
                <ul>
                <li><input type="checkbox" checked="" disabled="" /> Done</li>
                <li><input type="checkbox" disabled="" /> Not done</li>
                </ul>
                <p><del>Struck</del> and <a href="https://example.com">a link</a></p>
                """), []}
    end

    test "leaves a URL written in prose as the text it is written as" do
      assert Markdown.to_html("Visit http://todolist.jde.archidep.ch now.\n", context()) ==
               {"<p>Visit http://todolist.jde.archidep.ch now.</p>", []}
    end

    test "reads a reference link whose text is a URL as the link it looks like" do
      {:ok, source} = Source.parse("Prose.\n\n[todolist]: https://todolist.archidep.ch\n")

      assert Markdown.to_html(
               "See [https://todolist.archidep.ch][todolist].",
               context(source: source)
             ) ==
               {~s(<p>See <a href="https://todolist.archidep.ch">https://todolist.archidep.ch</a>.</p>),
                []}
    end

    test "resolves a reference link against the definitions of the document it comes from" do
      {:ok, source} = Source.parse("Prose.\n\n[owasp]: https://owasp.org/about\n")

      assert Markdown.to_html("Read the [OWASP][owasp] guide.", context(source: source)) ==
               {~s(<p>Read the <a href="https://owasp.org/about">OWASP</a> guide.</p>), []}
    end

    test "runs the build's passes over what it converts" do
      context =
        context(options: CourseSiteFactory.build(:render_options, ast_passes: [ShoutingPass]))

      assert Markdown.to_html("A *quiet* paragraph.\n", context) ==
               {"<p>A <em>QUIET</em> PARAGRAPH.</p>", []}
    end

    test "reports what a pass could not do, and still renders the page" do
      context =
        context(
          source_path: "_course/507-dns/subject.md",
          options: CourseSiteFactory.build(:render_options, ast_passes: [FailingPass])
        )

      assert Markdown.to_html("Prose.\n", context) ==
               {"<p>Prose.</p>",
                [
                  RenderError.new(
                    {:invalid_tag, "pass", "this pass always fails"},
                    "_course/507-dns/subject.md"
                  )
                ]}
    end
  end

  describe "parse/2 and render/2" do
    test "produce what converting the Markdown directly produces" do
      context = context()
      markdown = "# Title\n\nProse with a [link](https://example.com).\n\n> A quotation.\n"

      {:ok, document} = Markdown.parse(markdown, context)

      assert Markdown.render(document, context) == Markdown.to_html(markdown, context)
    end
  end

  property "converting a parsed document is converting the Markdown" do
    check all(paragraphs <- list_of(string(:alphanumeric, min_length: 1), min_length: 1)) do
      context = context()
      markdown = Enum.join(paragraphs, "\n\n") <> "\n"
      {:ok, document} = Markdown.parse(markdown, context)

      assert Markdown.render(document, context) == Markdown.to_html(markdown, context)
    end
  end

  defp context(attrs \\ []), do: CourseSiteFactory.build(:render_context, attrs)
end
