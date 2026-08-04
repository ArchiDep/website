defmodule ArchiDep.CourseSite.Build.PdfNamesTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias ArchiDep.CourseSite.Build.PdfNames
  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Cheatsheet
  alias ArchiDep.CourseSite.Structure.Section
  alias ArchiDep.CourseSite.Urls.PdfManifest
  alias ArchiDep.Support.CourseSiteFactory

  doctest ArchiDep.CourseSite.Build.PdfNames

  describe "name/1" do
    test "names the PDF of a document whose slug is not already a file name" do
      assert PdfNames.name({:document, DocumentRef.new(513, "TLS/SSL", :exercise)}) ==
               "archidep-513-tls-ssl-exercise.pdf"
    end

    test "names the PDF of a cheatsheet whose slug is not already a file name" do
      assert PdfNames.name({:cheatsheet, "Docker Compose!"}) == "archidep-999-docker-compose.pdf"
    end
  end

  describe "manifest/2" do
    test "names a PDF for every page of the site" do
      assert PdfNames.manifest(:site, course()) ==
               %PdfManifest{base: :site, entries: names()}
    end

    test "names the same PDFs wherever they are published" do
      assert PdfNames.manifest({:external, "https://example.com/pdf/2026"}, course()) ==
               %PdfManifest{
                 base: {:external, "https://example.com/pdf/2026"},
                 entries: names()
               }
    end

    test "names the PDF of the page introducing a course that has nothing else" do
      assert PdfNames.manifest(:site, %Structure{sections: [], cheatsheets: []}) ==
               %PdfManifest{base: :site, entries: %{home: "archidep-000-course.pdf"}}
    end

    property "names every page of a course differently" do
      check all {tree, front_matter, declarations} <- CourseSiteFactory.course_generator() do
        {:ok, structure} = Structure.plan(tree, front_matter, declarations)
        %PdfManifest{entries: entries} = PdfNames.manifest(:site, structure)
        names = Map.values(entries)

        assert Enum.sort(Enum.uniq(names)) == Enum.sort(names)
      end
    end
  end

  defp course do
    %Structure{
      sections: [
        Section.new(1, "Introduction", [
          Chapter.new(
            DocumentRef.new(101, "command-line", :subject),
            "Command Line",
            slides: DocumentRef.new(101, "command-line", :slides)
          )
        ]),
        Section.new(2, "Version Control", [
          Chapter.new(DocumentRef.new(202, "git-branching", :slides), "Git Branching"),
          Chapter.new(DocumentRef.new(205, "php-todolist", :exercise), "PHP Todolist")
        ])
      ],
      cheatsheets: [Cheatsheet.new("git", "Git Cheatsheet")]
    }
  end

  defp names do
    %{
      :home => "archidep-000-course.pdf",
      {:document, DocumentRef.new(101, "command-line", :subject)} =>
        "archidep-101-command-line-subject.pdf",
      {:document, DocumentRef.new(101, "command-line", :slides)} =>
        "archidep-101-command-line-slides.pdf",
      {:document, DocumentRef.new(202, "git-branching", :slides)} =>
        "archidep-202-git-branching-slides.pdf",
      {:document, DocumentRef.new(205, "php-todolist", :exercise)} =>
        "archidep-205-php-todolist-exercise.pdf",
      {:cheatsheet, "git"} => "archidep-999-git.pdf"
    }
  end
end
