defmodule ArchiDep.CourseSite.ArchivesTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Archives
  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Material
  alias ArchiDep.CourseSite.PageRef
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Cheatsheet

  describe "mapping/0" do
    # The 2025 edition is archived *and* still the one being taught, so every
    # one of its pages is answered for by the page now at that same path. This
    # is the assertion to rewrite at the first rollover, when the two stop
    # coinciding.
    test "answers for every page the archived edition published, with the page now at its path" do
      assert Archives.mapping() ==
               Map.new(
                 current_pages(),
                 &{PageRef.edition_path("2025", PageRef.output_path(&1)), &1}
               )
    end
  end

  describe "editions/0" do
    # As above, the one archived edition is the one being taught, so the pages a
    # host must hold for it are the current ones under its prefix. This is the
    # other assertion to rewrite at the first rollover.
    test "names every page a host must hold, for every archived edition" do
      assert Archives.editions() ==
               %{
                 "2025" =>
                   Enum.map(
                     current_pages(),
                     &PageRef.edition_path("2025", PageRef.output_path(&1))
                   )
               }
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
