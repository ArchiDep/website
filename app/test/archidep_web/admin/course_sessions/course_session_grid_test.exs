defmodule ArchiDepWeb.Admin.CourseSessions.CourseSessionGridTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Material
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Section
  alias ArchiDep.Support.CourseFactory
  alias ArchiDepWeb.Admin.CourseSessions.CourseSessionGrid

  # Numbers the compiled course does not use, which a session recording them is
  # free to: the material is written as the course runs, so a chapter recorded
  # in September may have been renumbered or dropped by November.
  @orphan 99_998
  @other_orphan 99_999

  describe "course_numbers/0" do
    test "answers with the number of every section and chapter of the course, in reading order" do
      assert CourseSessionGrid.course_numbers() == Enum.map(course_rows(), & &1.num)
    end
  end

  describe "in_course?/1" do
    test "answers true for a number the course uses" do
      assert CourseSessionGrid.in_course?(hd(CourseSessionGrid.course_numbers()))
    end

    test "answers false for a number the course no longer uses" do
      refute CourseSessionGrid.in_course?(@orphan)
    end
  end

  describe "rows/1" do
    test "answers with a row per section and chapter of the course, in reading order" do
      recorded = session(done: [hd(CourseSessionGrid.course_numbers())])

      assert CourseSessionGrid.rows(recorded) == course_rows()
    end

    test "answers with a trailing row per number the course no longer uses" do
      recorded = session(done: [@other_orphan], due: [@orphan])

      assert CourseSessionGrid.rows(recorded) ==
               course_rows() ++
                 [
                   %{kind: :orphan, num: @orphan, title: nil},
                   %{kind: :orphan, num: @other_orphan, title: nil}
                 ]
    end
  end

  describe "orphans/1" do
    test "answers with nothing for a session naming only what the course has" do
      [first, second | _rest] = CourseSessionGrid.course_numbers()

      assert CourseSessionGrid.orphans(session(done: [first], next: [second])) == []
    end

    test "gathers the numbers of the three categories, sorted and without repeats" do
      recorded =
        session(
          done: [@other_orphan, hd(CourseSessionGrid.course_numbers())],
          due: [@orphan],
          next: [@other_orphan]
        )

      assert CourseSessionGrid.orphans(recorded) == [@orphan, @other_orphan]
    end
  end

  describe "unfinished_rows/1" do
    test "offers every row of the course when nothing has been recorded" do
      assert CourseSessionGrid.unfinished_rows([]) == course_rows()
    end

    test "leaves out a chapter an earlier session marked done" do
      {_section, [chapter | _rest]} = section_with_chapters()

      assert CourseSessionGrid.unfinished_rows([session(done: [chapter])]) ==
               without(course_rows(), [chapter])
    end

    test "leaves out a section along with the chapters under it once every one of them is done" do
      {section, chapters} = section_with_chapters()

      assert CourseSessionGrid.unfinished_rows([session(done: [section | chapters])]) ==
               without(course_rows(), [section | chapters])
    end

    test "keeps a section still to be marked done after the last chapter under it is" do
      {_section, chapters} = section_with_chapters()

      assert CourseSessionGrid.unfinished_rows([session(done: chapters)]) ==
               without(course_rows(), chapters)
    end

    test "keeps the heading of a section marked done that still has a chapter left" do
      {section, [chapter | _rest]} = section_with_chapters()

      assert CourseSessionGrid.unfinished_rows([session(done: [section, chapter])]) ==
               without(course_rows(), [chapter])
    end

    test "leaves out what every session marked done, taken together" do
      [first, second] = Enum.take(chapters_of_distinct_sections(), 2)

      sessions = [session(done: [first]), session(done: [second])]

      assert CourseSessionGrid.unfinished_rows(sessions) ==
               without(course_rows(), [first, second])
    end

    test "keeps what a session only set as work to hand in or announced for the next one" do
      {_section, [chapter, other_chapter | _rest]} = section_with_chapters()

      recorded = session(due: [chapter], next: [other_chapter])

      assert CourseSessionGrid.unfinished_rows([recorded]) == course_rows()
    end

    test "offers no row at all once every number of the course is done" do
      recorded = session(done: CourseSessionGrid.course_numbers())

      assert CourseSessionGrid.unfinished_rows([recorded]) == []
    end

    test "ignores a number the course no longer uses" do
      assert CourseSessionGrid.unfinished_rows([session(done: [@orphan])]) == course_rows()
    end
  end

  # Every category is pinned, empty unless the test says otherwise: what the
  # grid leaves out is a function of the whole of what a session recorded.
  defp session(overrides),
    do:
      CourseFactory.build(
        :course_session,
        Keyword.merge([done: [], due: [], next: []], overrides)
      )

  # The grid the course as it stands calls for. Built from the same compiled
  # course the module reads, so that a renumbered chapter is not a hardcoded
  # list to maintain; what a test pins is which of these rows survive.
  defp course_rows,
    do:
      Enum.flat_map(Material.sections(), fn %Section{chapters: chapters} = section ->
        [%{kind: :section, num: Section.num(section), title: section.title}] ++
          Enum.map(chapters, &%{kind: :chapter, num: Chapter.num(&1), title: &1.title})
      end)

  # A section of the course with more than one chapter under it, so that a test
  # can leave one of them done and another still to come.
  defp section_with_chapters do
    %Section{chapters: chapters} =
      section = Enum.find(Material.sections(), &(length(&1.chapters) > 1))

    {Section.num(section), Enum.map(chapters, &Chapter.num/1)}
  end

  # The first chapter of each section, so that marking one done never empties
  # the section it belongs to.
  defp chapters_of_distinct_sections,
    do:
      Enum.map(Material.sections(), fn %Section{chapters: [first | _rest]} ->
        Chapter.num(first)
      end)

  defp without(rows, numbers), do: Enum.reject(rows, &(&1.num in numbers))
end
