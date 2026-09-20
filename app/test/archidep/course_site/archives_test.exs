defmodule ArchiDep.CourseSite.ArchivesTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Archives
  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Material
  alias ArchiDep.CourseSite.PageRef
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Cheatsheet

  # `course/archives` holds one manifest per edition, and the two are read
  # differently here. 2026 is the edition being taught: its manifest is written
  # again whenever the material moves, so it records the course exactly as it
  # stands and every page of it answers for itself. 2025 is finished, so its
  # manifest is the course written back into the shape it had then —
  # @path_in_2025 says where a page was published, and pages_of_2025/0 puts them
  # in the order that manifest lists them.
  @current_edition "2026"

  # Two of the pages 2025 published are published at another path now: "Shell
  # Scripting" was chapter 102 and is a cheatsheet, which moved the three
  # chapters that followed it up one number; and the graded exercise, which 2025
  # named after the application it had students deploy, is named for what it is.
  # Every other page is still published at the path 2025 knew it by.
  @shell_scripting {:cheatsheet, "shell-scripting"}
  @path_in_2025 %{
    "/cheatsheets/shell-scripting/" => "/course/102-shell-scripting/",
    "/course/102-hello-shell/" => "/course/103-hello-shell/",
    "/course/103-ssh/" => "/course/104-ssh/",
    "/course/103-ssh/slides/" => "/course/104-ssh/slides/",
    "/course/104-hello-ssh/" => "/course/105-hello-ssh/",
    "/course/603-graded-deployment/" => "/course/603-floodit-deployment/"
  }

  describe "mapping/0" do
    test "answers for every page every edition published, with the page that succeeded it" do
      assert Archives.mapping() ==
               Map.new(
                 for {edition, pages} <- published_pages(), {path, page} <- pages do
                   {PageRef.edition_path(edition, path), page}
                 end
               )
    end
  end

  describe "editions/0" do
    test "names every page a host must hold, for every edition" do
      assert Archives.editions() ==
               Map.new(published_pages(), fn {edition, pages} ->
                 {edition,
                  Enum.map(pages, fn {path, _page} ->
                    PageRef.edition_path(edition, path)
                  end)}
               end)
    end
  end

  describe "resolve/1" do
    test "sends an archived chapter to what the course now holds at its name" do
      assert Archives.resolve("/2025/course/402-run-virtual-server/") ==
               {:ok, {:document, DocumentRef.new(402, "run-virtual-server", :exercise)}}
    end

    test "sends an archived deck to the deck of its chapter" do
      assert Archives.resolve("/2025/course/101-command-line/slides/") ==
               {:ok, {:document, DocumentRef.new(101, "command-line", :slides)}}
    end

    test "sends an archived cheatsheet to the cheatsheet of the same name" do
      assert Archives.resolve("/2025/cheatsheets/sysadmin/") == {:ok, {:cheatsheet, "sysadmin"}}
    end

    test "sends an archived chapter that is now a cheatsheet where the course says it went" do
      assert Archives.resolve("/2025/course/102-shell-scripting/") ==
               {:ok, {:cheatsheet, "shell-scripting"}}
    end

    test "sends an archived chapter that was renumbered to the chapter of the same name" do
      assert Archives.resolve("/2025/course/104-ssh/") ==
               {:ok, {:document, DocumentRef.new(103, "ssh", :subject)}}
    end

    test "sends the archived home page to the home page" do
      assert Archives.resolve("/2025/") == {:ok, :home}
    end

    test "answers for no page of an edition that was never archived" do
      assert Archives.resolve("/1999/course/402-run-virtual-server/") == :error
    end

    test "answers for no page the archived edition never published" do
      assert Archives.resolve("/2025/course/999-nowhere/") == :error
    end

    test "answers for no page when asked for nothing" do
      assert Archives.resolve(nil) == :error
    end
  end

  describe "__mix_recompile__?/0" do
    test "is answered no by the archives directory the module was compiled from" do
      refute Archives.__mix_recompile__?()
    end
  end

  # What each edition's manifest lists, in its own order, paired with the page
  # of the course that answers for it.
  defp published_pages do
    [
      {@current_edition, Enum.map(current_pages(), &{PageRef.output_path(&1), &1})},
      {"2025", Enum.map(pages_of_2025(), &{path_in_2025(&1), &1})}
    ]
  end

  # A manifest lists the home page, then the chapters, then the cheatsheets.
  # 2025 published "Shell Scripting" as a chapter, so its manifest lists it
  # among them, right after the command line pages, rather than among the
  # cheatsheets where the course holds it now.
  defp pages_of_2025 do
    {command_line, rest} =
      current_pages()
      |> Enum.reject(&(&1 == @shell_scripting))
      |> Enum.split_while(&command_line_page?/1)

    command_line ++ [@shell_scripting] ++ rest
  end

  defp command_line_page?(:home), do: true
  defp command_line_page?({:document, %DocumentRef{slug: "command-line"}}), do: true
  defp command_line_page?(_page), do: false

  defp path_in_2025(page) do
    path = PageRef.output_path(page)
    Map.get(@path_in_2025, path, path)
  end

  defp current_pages do
    structure = Material.structure()

    [:home] ++
      Enum.flat_map(Structure.chapters(structure), &chapter_pages/1) ++
      Enum.map(structure.cheatsheets, &Cheatsheet.page_ref/1)
  end

  defp chapter_pages(%Chapter{} = chapter) do
    slides = if Chapter.slides?(chapter), do: [{:document, chapter.slides}], else: []
    [Chapter.page_ref(chapter) | slides]
  end
end
