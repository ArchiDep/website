defmodule ArchiDep.CourseSite.Renderer.HighlighterTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Renderer.Highlighter
  alias ArchiDep.CourseSite.Renderer.Markdown
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.Support.CourseSiteFactory

  @source_path "chapters/101-command-line/subject.md"

  describe "run/2" do
    test "colours the code of a fenced block" do
      context = context()
      {:ok, document} = Markdown.parse("```bash\npwd\n```\n", context)

      assert Highlighter.run(document, context) ==
               {%{
                  document
                  | nodes: [
                      html_block(
                        ~s(<pre class="lumis"><code class="language-bash" translate="no" ) <>
                          ~s(tabindex="0"><div class="l-line" data-line="1">) <>
                          ~s(<span class="l-function-builtin">pwd</span>\n</div></code></pre>)
                      )
                    ]
                }, []}
    end

    test "highlights a block that names no language as plain text" do
      context = context()
      {:ok, document} = Markdown.parse("```\nplain\n```\n", context)

      assert Highlighter.run(document, context) ==
               {%{document | nodes: [html_block(plain_text("plain"))]}, []}
    end

    test "highlights a block naming a language nothing knows as plain text" do
      context = context()
      {:ok, document} = Markdown.parse("```klingon\nplain\n```\n", context)

      assert Highlighter.run(document, context) ==
               {%{document | nodes: [html_block(plain_text("plain"))]}, []}
    end

    test "marks the line a fence asks for" do
      context = context()
      {:ok, document} = Markdown.parse(~s(```text highlight_lines="2"\na\nb\n```\n), context)

      assert Highlighter.run(document, context) ==
               {%{
                  document
                  | nodes: [
                      html_block(
                        ~s(<pre class="lumis"><code class="language-plaintext" translate="no" ) <>
                          ~s(tabindex="0"><div class="l-line" data-line="1">a\n</div>) <>
                          ~s(<div class="l-line l-highlighted" data-line="2">b\n</div>) <>
                          ~s(</code></pre>)
                      )
                    ]
                }, []}
    end

    test "marks the lines and the ranges of lines a fence asks for" do
      context = context()

      {:ok, document} =
        Markdown.parse(~s(```text highlight_lines="1,3-4"\na\nb\nc\nd\n```\n), context)

      assert Highlighter.run(document, context) ==
               {%{
                  document
                  | nodes: [
                      html_block(
                        ~s(<pre class="lumis"><code class="language-plaintext" translate="no" ) <>
                          ~s(tabindex="0"><div class="l-line l-highlighted" data-line="1">a\n</div>) <>
                          ~s(<div class="l-line" data-line="2">b\n</div>) <>
                          ~s(<div class="l-line l-highlighted" data-line="3">c\n</div>) <>
                          ~s(<div class="l-line l-highlighted" data-line="4">d\n</div>) <>
                          ~s(</code></pre>)
                      )
                    ]
                }, []}
    end

    test "highlights the code blocks nested in the rest of the document" do
      context = context()
      {:ok, document} = Markdown.parse("> ```\n> plain\n> ```\n", context)
      [%MDEx.BlockQuote{} = quotation] = document.nodes

      assert Highlighter.run(document, context) ==
               {%{document | nodes: [%{quotation | nodes: [html_block(plain_text("plain"))]}]},
                []}
    end

    test "leaves a document with no code in it alone" do
      context = context()
      {:ok, document} = Markdown.parse("Prose with `code` in it.\n", context)

      assert Highlighter.run(document, context) == {document, []}
    end

    test "reports a decorator that does not exist, and colours the block anyway" do
      context = context(source_path: @source_path)
      {:ok, document} = Markdown.parse(~s(```text highlight_line="1"\nplain\n```\n), context)

      assert Highlighter.run(document, context) ==
               {%{document | nodes: [html_block(plain_text("plain"))]},
                [
                  RenderError.new(
                    {:invalid_code_fence, ~s(text highlight_line="1"),
                     ~s(there is no "highlight_line" decorator)},
                    @source_path
                  )
                ]}
    end

    test "reports a marked line that is not a line number" do
      context = context(source_path: @source_path)
      {:ok, document} = Markdown.parse(~s(```text highlight_lines="one"\nplain\n```\n), context)

      assert Highlighter.run(document, context) ==
               {%{document | nodes: [html_block(plain_text("plain"))]},
                [
                  RenderError.new(
                    {:invalid_code_fence, ~s(text highlight_lines="one"),
                     ~s("one" is not a line number)},
                    @source_path
                  )
                ]}
    end

    test "reports a marked range of lines that ends before it starts" do
      context = context(source_path: @source_path)
      {:ok, document} = Markdown.parse(~s(```text highlight_lines="3-1"\nplain\n```\n), context)

      assert Highlighter.run(document, context) ==
               {%{document | nodes: [html_block(plain_text("plain"))]},
                [
                  RenderError.new(
                    {:invalid_code_fence, ~s(text highlight_lines="3-1"),
                     "the range of lines 3-1 ends before it starts"},
                    @source_path
                  )
                ]}
    end

    test "reports a marked line that is neither a number nor a range" do
      context = context(source_path: @source_path)
      {:ok, document} = Markdown.parse(~s(```text highlight_lines="1-2-3"\nplain\n```\n), context)

      assert Highlighter.run(document, context) ==
               {%{document | nodes: [html_block(plain_text("plain"))]},
                [
                  RenderError.new(
                    {:invalid_code_fence, ~s(text highlight_lines="1-2-3"),
                     ~s("1-2-3" is neither a line number nor a range of them)},
                    @source_path
                  )
                ]}
    end

    test "reports what follows the language when it is not a list of decorators" do
      context = context(source_path: @source_path)
      {:ok, document} = Markdown.parse("```text mark line 1\nplain\n```\n", context)

      assert Highlighter.run(document, context) ==
               {%{document | nodes: [html_block(plain_text("plain"))]},
                [
                  RenderError.new(
                    {:invalid_code_fence, "text mark line 1",
                     ~s(expected `name="value"` decorators after the language)},
                    @source_path
                  )
                ]}
    end

    test "reports the problem of every fence, in the order the document writes them" do
      context = context(source_path: @source_path)

      {:ok, document} =
        Markdown.parse(
          ~s(```text highlight_lines="0"\nfirst\n```\n\n```text nope\nsecond\n```\n),
          context
        )

      assert Highlighter.run(document, context) ==
               {%{
                  document
                  | nodes: [
                      html_block(plain_text("first")),
                      html_block(plain_text("second"))
                    ]
                },
                [
                  RenderError.new(
                    {:invalid_code_fence, ~s(text highlight_lines="0"),
                     ~s("0" is not a line number)},
                    @source_path
                  ),
                  RenderError.new(
                    {:invalid_code_fence, "text nope",
                     ~s(expected `name="value"` decorators after the language)},
                    @source_path
                  )
                ]}
    end
  end

  defp context(attrs \\ []), do: CourseSiteFactory.build(:render_context, attrs)

  defp html_block(literal), do: %MDEx.HtmlBlock{literal: literal}

  defp plain_text(code),
    do:
      ~s(<pre class="lumis"><code class="language-plaintext" translate="no" tabindex="0">) <>
        ~s(<div class="l-line" data-line="1">#{code}\n</div></code></pre>)
end
