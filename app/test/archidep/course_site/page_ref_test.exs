defmodule ArchiDep.CourseSite.PageRefTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.PageRef
  alias ArchiDep.Support.CourseSiteFactory

  doctest ArchiDep.CourseSite.PageRef

  describe "parse_source_path/1" do
    test "parses a document of a chapter" do
      assert PageRef.parse_source_path("chapters/104-ssh/subject.md") ==
               {:ok, {:document, %DocumentRef{num: 104, slug: "ssh", type: :subject}}}
    end

    test "parses a cheatsheet" do
      assert PageRef.parse_source_path("cheatsheets/git/cheatsheet.md") ==
               {:ok, {:cheatsheet, "git"}}
    end

    test "rejects another document of a cheatsheet's directory" do
      assert PageRef.parse_source_path("cheatsheets/git/notes.md") ==
               {:error, {:invalid_source_path, "cheatsheets/git/notes.md"}}
    end

    test "rejects a cheatsheet nested deeper than its directory" do
      assert PageRef.parse_source_path("cheatsheets/git/parts/cheatsheet.md") ==
               {:error, {:invalid_source_path, "cheatsheets/git/parts/cheatsheet.md"}}
    end

    test "rejects the home page, which is written outside the content tree" do
      assert PageRef.parse_source_path("index.md") ==
               {:error, {:invalid_source_path, "index.md"}}
    end
  end

  describe "output_path/1" do
    test "returns the path of a subject" do
      subject = DocumentRef.new(507, "dns", :subject)

      assert PageRef.output_path({:document, subject}) == "/course/507-dns/"
    end

    test "returns the path of an exercise" do
      exercise = DocumentRef.new(514, "certbot-deployment", :exercise)

      assert PageRef.output_path({:document, exercise}) == "/course/514-certbot-deployment/"
    end

    test "returns the path of slides, one segment below the chapter" do
      slides = DocumentRef.new(203, "git-collaboration", :slides)

      assert PageRef.output_path({:document, slides}) == "/course/203-git-collaboration/slides/"
    end
  end

  describe "identity/1" do
    test "returns the identity of the home page" do
      assert PageRef.identity(:home) == :home
    end

    test "returns the identity of a cheatsheet" do
      assert PageRef.identity({:cheatsheet, "command-line"}) == {:cheatsheet, "command-line"}
    end
  end

  describe "edition_path/2" do
    test "returns the path of a subject within its edition" do
      subject = DocumentRef.new(507, "dns", :subject)

      assert PageRef.edition_path("2025", PageRef.output_path({:document, subject})) ==
               "/2025/course/507-dns/"
    end

    test "returns the path of slides within their edition" do
      slides = DocumentRef.new(203, "git-collaboration", :slides)

      assert PageRef.edition_path("1985", PageRef.output_path({:document, slides})) ==
               "/1985/course/203-git-collaboration/slides/"
    end

    property "prefixes any page of an edition with that edition" do
      check all page <- CourseSiteFactory.page_ref_generator() do
        path = PageRef.output_path(page)

        assert PageRef.edition_path("1955", path) == "/1955" <> path
      end
    end
  end
end
