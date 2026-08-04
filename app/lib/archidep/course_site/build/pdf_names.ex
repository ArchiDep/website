defmodule ArchiDep.CourseSite.Build.PdfNames do
  @moduledoc """
  What the generated PDF of a page is called.

  Every page of the site can be printed, and the file that comes out is named
  after the page rather than after what the page says:
  `archidep-<num>-<slug>-<type>.pdf` for a document, `archidep-999-<slug>.pdf`
  for a cheatsheet and `archidep-000-course.pdf` for the page introducing the
  course. A document's number and slug are the directory it is written in, so a
  chapter's PDFs are named after the chapter the way its URL already is.

  **A title contributes nothing.** A title is prose, reworded whenever it reads
  badly, and a published PDF that is renamed is a broken link from every
  archived edition that offered it — while a slug is the chapter's identity, the
  thing an archive freezes. Leaving titles out also leaves out the whole
  question of what a file name may contain: the section title is out for the
  same reason, so a chapter renumbered into another section keeps its PDF.

  What is left is a function of the page alone, which is what lets anything
  holding a reference say what a page's PDF is called without holding the course
  as well.

  **A deck is a deck wherever it comes from.** A chapter that presents a deck
  beside its subject and a chapter that *is* a deck both name that deck
  `archidep-<num>-<slug>-slides.pdf`, because both are a `:slides` document of
  the same chapter, and `ArchiDep.CourseSite.Build.ContentTree` allows a chapter
  no more than one.

  **`000` and `999` are sentinels.** A chapter's number never starts with a
  zero, and `999` is the number the course does not use. A document's name ends
  in its type and a cheatsheet's does not, so the two can only meet if a
  cheatsheet is slugged after a type — narrow enough to say here rather than to
  refuse.
  """

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.PageRef
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Urls.PdfManifest

  @prefix "archidep"
  @separator "-"
  @extension ".pdf"
  @home_name "000-course"
  @cheatsheet_num "999"
  @rejected ~r/[^a-z0-9]+/

  @doc """
  The name of the PDF of a page.

      iex> PdfNames.name(:home)
      "archidep-000-course.pdf"

      iex> PdfNames.name({:document, DocumentRef.new(202, "git-branching", :subject)})
      "archidep-202-git-branching-subject.pdf"

      iex> PdfNames.name({:document, DocumentRef.new(202, "git-branching", :slides)})
      "archidep-202-git-branching-slides.pdf"

      iex> PdfNames.name({:document, DocumentRef.new(205, "php-todolist", :exercise)})
      "archidep-205-php-todolist-exercise.pdf"

      iex> PdfNames.name({:cheatsheet, "git"})
      "archidep-999-git.pdf"
  """
  @spec name(PageRef.t()) :: String.t()
  def name(:home), do: file(@home_name)

  def name({:document, %DocumentRef{type: type} = document}),
    do: document |> DocumentRef.dir() |> file(Atom.to_string(type))

  def name({:cheatsheet, slug}) when is_binary(slug), do: file(@cheatsheet_num, slug)

  @doc """
  The manifest of the PDFs of a course published under the given base, naming
  one for every page of the site.

  The whole site rather than the whole course: the page introducing it is
  printed too, and it is `ArchiDep.CourseSite.Structure` that leaves it out.

  Every page gets an entry whether or not a PDF of it has been printed yet.
  Nothing here can know that, and a name is what the step that prints them needs
  in order to write the files under the names the pages already point at.
  """
  @spec manifest(PdfManifest.base(), Structure.t()) :: PdfManifest.t()
  def manifest(base, %Structure{} = structure),
    do:
      PdfManifest.new(
        base,
        Map.new([:home | Structure.pages(structure)], &{&1, name(&1)})
      )

  defp file(name, suffix), do: file(name <> @separator <> suffix)

  defp file(name), do: @prefix <> @separator <> slug(name) <> @extension

  # A slug already names a directory and a URL, so this changes nothing about
  # the names the course actually produces. It is what makes that a property of
  # this function rather than of the content.
  defp slug(name),
    do: name |> String.downcase() |> String.replace(@rejected, @separator) |> String.trim("-")
end
