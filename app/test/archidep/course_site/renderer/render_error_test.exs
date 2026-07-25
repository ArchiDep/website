defmodule ArchiDep.CourseSite.Renderer.RenderErrorTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Renderer.RenderError

  doctest ArchiDep.CourseSite.Renderer.RenderError

  describe "message/1" do
    test "says what is wrong and where, for every kind of problem" do
      assert Enum.map(
               [
                 {:invalid_front_matter, "expected a mapping, got []"},
                 :unterminated_front_matter,
                 {:liquid, "Unexpected tag 'note:'"},
                 {:markdown, "invalid document"},
                 {:url,
                  {:unknown_pdf, {:document, DocumentRef.new(101, "command-line", :slides)}}},
                 {:invalid_document, "_course/507-dns/notes.md"},
                 {:missing_excerpt_separator, "<!-- more -->"},
                 {:unknown_include, "icons/nope.html"},
                 {:invalid_tag, "cols", "columns must be between 2 and 12"}
               ],
               &Exception.message(RenderError.new(&1, "_course/507-dns/subject.md"))
             ) == [
               "Invalid front matter (expected a mapping, got []) in _course/507-dns/subject.md",
               "The front matter is never closed by a line of three dashes in _course/507-dns/subject.md",
               "Unexpected tag 'note:' in _course/507-dns/subject.md",
               "Invalid Markdown (invalid document) in _course/507-dns/subject.md",
               "No PDF has been published for page 101-command-line (slides) in _course/507-dns/subject.md",
               "\"_course/507-dns/notes.md\" is not the path of a course document in _course/507-dns/subject.md",
               "The front matter declares the excerpt separator \"<!-- more -->\", which the document never writes in _course/507-dns/subject.md",
               "There is no include named \"icons/nope.html\" in _course/507-dns/subject.md",
               "Invalid {% cols %} tag (columns must be between 2 and 12) in _course/507-dns/subject.md"
             ]
    end

    test "says where in the file the problem is when it knows" do
      error =
        RenderError.new({:liquid, "Boom"}, "_course/507-dns/subject.md", %{line: 12, column: 3})

      assert Exception.message(error) == "Boom in _course/507-dns/subject.md at line 12, column 3"
    end
  end

  describe "new/3" do
    test "takes a location however the thing that reported it expressed one" do
      assert RenderError.new(
               {:liquid, "Boom"},
               "_course/507-dns/subject.md",
               %Solid.Parser.Loc{line: 4, column: 9}
             ) == %RenderError{
               reason: {:liquid, "Boom"},
               source_path: "_course/507-dns/subject.md",
               loc: %{line: 4, column: 9}
             }
    end
  end

  describe "shift/2" do
    test "leaves an error that is not anywhere in particular alone" do
      error = RenderError.new({:liquid, "Boom"}, "_course/507-dns/subject.md")

      assert RenderError.shift(error, 4) == error
    end
  end
end
