defmodule ArchiDep.CourseSite.Renderer.SourceTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias ArchiDep.CourseSite.Renderer.Source

  doctest ArchiDep.CourseSite.Renderer.Source

  describe "parse/1" do
    test "takes apart a document with front matter, a body and definitions" do
      assert Source.parse("""
             ---
             title: Domain Name System
             excerpt_separator: <!-- more -->
             ---

             Look it up with [dig][dig].

             [dig]: https://linux.die.net/man/1/dig
             """) ==
               {:ok,
                %Source{
                  front_matter: %{
                    "title" => "Domain Name System",
                    "excerpt_separator" => "<!-- more -->"
                  },
                  body: "Look it up with [dig][dig].\n\n[dig]: https://linux.die.net/man/1/dig\n",
                  body_line_offset: 5,
                  link_references: [{"dig", "https://linux.die.net/man/1/dig"}]
                }}
    end

    test "takes a document without front matter to be all body" do
      assert Source.parse("Just prose.\n") ==
               {:ok,
                %Source{
                  front_matter: %{},
                  body: "Just prose.\n",
                  body_line_offset: 0,
                  link_references: []
                }}
    end

    test "reads front matter values of every shape the course writes" do
      assert Source.parse("""
             ---
             title: Deploy a PHP application
             graded: true
             done: [100, 101]
             ---
             Body.
             """) ==
               {:ok,
                %Source{
                  front_matter: %{
                    "title" => "Deploy a PHP application",
                    "graded" => true,
                    "done" => [100, 101]
                  },
                  body: "Body.\n",
                  body_line_offset: 5,
                  link_references: []
                }}
    end

    test "takes empty front matter to be no front matter at all" do
      assert Source.parse("---\n---\nBody.\n") ==
               {:ok,
                %Source{
                  front_matter: %{},
                  body: "Body.\n",
                  body_line_offset: 2,
                  link_references: []
                }}
    end

    test "keeps a line of three dashes in the body, which is a slide separator" do
      assert Source.parse("---\ntitle: Slides\n---\n\nFirst slide.\n\n---\n\nSecond slide.\n") ==
               {:ok,
                %Source{
                  front_matter: %{"title" => "Slides"},
                  body: "First slide.\n\n---\n\nSecond slide.\n",
                  body_line_offset: 4,
                  link_references: []
                }}
    end

    test "collects every definition of the trailing block" do
      assert Source.parse("""
             Read [one][a] and [two][b].

             [a]: https://example.com/a
             [b]: https://example.com/b
             """) ==
               {:ok,
                %Source{
                  front_matter: %{},
                  body:
                    "Read [one][a] and [two][b].\n\n[a]: https://example.com/a\n[b]: https://example.com/b\n",
                  body_line_offset: 0,
                  link_references: [
                    {"a", "https://example.com/a"},
                    {"b", "https://example.com/b"}
                  ]
                }}
    end

    test "ignores a definition that is not part of the trailing block" do
      assert Source.parse("[a]: https://example.com/a\n\nProse in the way.\n") ==
               {:ok,
                %Source{
                  front_matter: %{},
                  body: "[a]: https://example.com/a\n\nProse in the way.\n",
                  body_line_offset: 0,
                  link_references: []
                }}
    end

    test "reports front matter that is never closed" do
      assert Source.parse("---\ntitle: Unfinished\n") == {:error, :unterminated_front_matter}
    end

    test "reports front matter that is not a mapping" do
      assert Source.parse("---\n- one\n- two\n---\nBody.\n") ==
               {:error, {:invalid_front_matter, "expected a mapping, got [\"one\", \"two\"]"}}
    end

    test "reports front matter that is not YAML" do
      assert Source.parse("---\ntitle: [unclosed\n---\nBody.\n") ==
               {:error,
                {:invalid_front_matter, "Unfinished flow collection (line: 1, column: 17)"}}
    end
  end

  describe "link_references/1" do
    test "reads the definitions written at the end" do
      assert Source.link_references("Text.\n\n[a]: https://example.com/a\n[b]: /b\n") ==
               [{"a", "https://example.com/a"}, {"b", "/b"}]
    end

    test "reads a definition whose destination is still Liquid" do
      assert Source.link_references("[cli]: {% link chapters/101-command-line/subject.md %}\n") ==
               [{"cli", "{% link chapters/101-command-line/subject.md %}"}]
    end

    test "leaves a definition that is not at the end to the Markdown renderer" do
      assert Source.link_references("[a]: https://example.com/a\n\nText.\n") == []
    end

    test "reads nothing from a document that defines nothing" do
      assert Source.link_references("Nothing to define.\n") == []
    end
  end

  describe "definitions/1" do
    test "writes the definitions back as Markdown" do
      assert Source.definitions([{"a", "https://example.com/a"}, {"b", "https://example.com/b"}]) ==
               "[a]: https://example.com/a\n[b]: https://example.com/b"
    end

    test "writes nothing for a document that defines nothing" do
      assert Source.definitions([]) == ""
    end
  end

  describe "substitute/2" do
    test "rewrites every reference link of a fragment" do
      references = [{"dig", "https://example.com/dig"}, {"ping", "https://example.com/ping"}]

      assert Source.substitute(
               references,
               "Use [dig][dig], then [ping][ping], then [dig][dig]."
             ) ==
               "Use [dig](https://example.com/dig), then [ping](https://example.com/ping), then [dig](https://example.com/dig)."
    end

    test "leaves a fragment alone when the document defines nothing" do
      assert Source.substitute([], "Use [dig][dig].") == "Use [dig][dig]."
    end
  end

  property "the body is the document minus the lines the offset counts" do
    check all(
            front_matter <- one_of([constant(""), constant("---\ntitle: Something\n---\n")]),
            blank_lines <- integer(0..3),
            body <- string(:alphanumeric, min_length: 1)
          ) do
      text = front_matter <> String.duplicate("\n", blank_lines) <> body <> "\n"
      {:ok, source} = Source.parse(text)

      assert Enum.drop(String.split(text, "\n"), source.body_line_offset) ==
               String.split(source.body, "\n")
    end
  end
end
