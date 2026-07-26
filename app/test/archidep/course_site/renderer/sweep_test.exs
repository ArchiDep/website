defmodule ArchiDep.CourseSite.Renderer.SweepTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Renderer.Sweep

  doctest ArchiDep.CourseSite.Renderer.Sweep

  describe "split/2" do
    test "protects a code element and everything in it" do
      sweep = Sweep.compile([:code_markup])

      assert Sweep.split("Type <code>ls -la</code> to look.", sweep) == [
               {:text, "Type "},
               {:protected, "<code>ls -la</code>"},
               {:text, " to look."}
             ]
    end

    test "protects a preformatted element spanning several lines" do
      sweep = Sweep.compile([:code_markup])

      assert Sweep.split("Before\n<pre class=\"x\">one\ntwo</pre>\nAfter", sweep) == [
               {:text, "Before\n"},
               {:protected, "<pre class=\"x\">one\ntwo</pre>"},
               {:text, "\nAfter"}
             ]
    end

    test "protects a comment" do
      sweep = Sweep.compile([:comments])

      assert Sweep.split("Shown <!-- but not this --> again", sweep) == [
               {:text, "Shown "},
               {:protected, "<!-- but not this -->"},
               {:text, " again"}
             ]
    end

    test "protects every tag when the words are what is being swept" do
      sweep = Sweep.compile([:tags])

      assert Sweep.split(~s(<p class="lead">Deploy <em>now</em></p>), sweep) == [
               {:text, ""},
               {:protected, ~s(<p class="lead">)},
               {:text, "Deploy "},
               {:protected, "<em>"},
               {:text, "now"},
               {:protected, "</em>"},
               {:text, ""},
               {:protected, "</p>"},
               {:text, ""}
             ]
    end

    test "leaves the attributes of a tag alone when tags are not protected" do
      sweep = Sweep.compile([:code_markup, :comments])

      assert Sweep.split(~s(<img src="images/vm.png"><pre><img src="images/x.png"></pre>), sweep) ==
               [
                 {:text, ~s(<img src="images/vm.png">)},
                 {:protected, ~s(<pre><img src="images/x.png"></pre>)},
                 {:text, ""}
               ]
    end

    test "protects a fenced code block written with backticks, and its info string" do
      sweep = Sweep.compile([:fences])

      assert Sweep.split("Run:\n\n```bash\nssh root@host\n```\n\nDone.\n", sweep) == [
               {:text, "Run:\n\n"},
               {:protected, "```bash\nssh root@host\n```\n"},
               {:text, "\nDone.\n"}
             ]
    end

    test "protects a fenced code block written with tildes" do
      sweep = Sweep.compile([:fences])

      assert Sweep.split("~~~txt\n:tada:\n~~~\n", sweep) == [
               {:text, ""},
               {:protected, "~~~txt\n:tada:\n~~~\n"},
               {:text, ""}
             ]
    end

    test "protects a fence that is never closed to the end of the text" do
      sweep = Sweep.compile([:fences])

      assert Sweep.split("Prose.\n\n```\nff:aa:28\n", sweep) == [
               {:text, "Prose.\n\n"},
               {:protected, "```\nff:aa:28\n"},
               {:text, ""}
             ]
    end

    test "protects code written between backticks, single and doubled" do
      sweep = Sweep.compile([:inline_code])

      assert Sweep.split("Both `0123:4567` and ``a `b` c`` are code.", sweep) == [
               {:text, "Both "},
               {:protected, "`0123:4567`"},
               {:text, " and "},
               {:protected, "``a `b` c``"},
               {:text, " are code."}
             ]
    end

    test "protects a fence rather than the backticks that open it" do
      sweep = Sweep.compile([:fences, :inline_code])

      assert Sweep.split("```\n`ls`\n```\n", sweep) == [
               {:text, ""},
               {:protected, "```\n`ls`\n```\n"},
               {:text, ""}
             ]
    end

    test "protects what a deck writes code and markup with at once" do
      sweep = Sweep.compile([:fences, :code_markup, :comments, :inline_code, :tags])

      assert Sweep.split(
               "A `ff:28` host.\n\n```txt\n:coffee:\n```\n\n<div class=\"note\">:tada:</div>\n",
               sweep
             ) == [
               {:text, "A "},
               {:protected, "`ff:28`"},
               {:text, " host.\n\n"},
               {:protected, "```txt\n:coffee:\n```\n"},
               {:text, "\n"},
               {:protected, ~s(<div class="note">)},
               {:text, ":tada:"},
               {:protected, "</div>"},
               {:text, "\n"}
             ]
    end

    test "leaves text nothing protects in one piece" do
      assert Sweep.split("Nothing to protect here.", Sweep.compile([:tags, :fences])) == [
               {:text, "Nothing to protect here."}
             ]
    end
  end

  describe "text/1" do
    test "keeps only what may be rewritten" do
      sweep = Sweep.compile([:tags, :inline_code])

      assert Sweep.text(Sweep.split("Say <b>:books:</b> or `:books:`", sweep)) ==
               ["Say ", ":books:", " or ", ""]
    end
  end

  describe "map_text/2" do
    test "rewrites what may be rewritten and puts the rest back" do
      sweep = Sweep.compile([:fences, :tags])

      assert "loud <em>words</em>\n\n```\nquiet code\n```\n"
             |> Sweep.split(sweep)
             |> Sweep.map_text(&String.upcase/1) ==
               "LOUD <em>WORDS</em>\n\n```\nquiet code\n```\n"
    end
  end

  describe "compile/1" do
    test "refuses a region it does not know" do
      assert_raise ArgumentError, "No such region to protect: [:frontmatter]", fn ->
        Sweep.compile([:tags, :frontmatter])
      end
    end
  end
end
