defmodule ArchiDepWeb.Admin.CourseSessions.CourseSessionGrid do
  @moduledoc """
  The rows the form of a session of the course offers, and the numbers it holds
  that the course no longer uses.

  ## Correcting a session shows everything

  The rows are the course as it stands **plus** whatever the session recorded
  that is no longer part of it. The course material is written as the course
  runs, so a chapter that has not been taught yet may be added, removed or
  renumbered at any point, and a number recorded in September may name nothing
  in November. A grid built from the course alone would render no box for such a
  number, the form would send nothing for it, and the next edit of the session —
  a corrected title, say — would drop it without a word. So it gets a row of its
  own, checked, and removing it stays something somebody decided to do.

  They are gathered in one trailing group rather than filed under the section
  their number suggests: what section a number belonged to is exactly what is no
  longer knowable.

  ## Recording a session shows what is left

  A session is recorded to move the course forward, so `unfinished_rows/1`
  leaves out what earlier sessions have already marked as done: what the form
  offers is what a session can still be about. Correcting one goes on offering
  every row — the whole point of a correction is to reach what a session got
  wrong, which is as likely to be something it marked done as something it
  missed.
  """

  alias ArchiDep.Course.Schemas.CourseSession
  alias ArchiDep.CourseSite.Material
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Section

  @typedoc """
  One row of the grid: a section of the course, a chapter under it, or a number
  the course no longer uses and only the session still names.
  """
  @type row :: %{
          kind: :section | :chapter | :orphan,
          num: pos_integer(),
          title: String.t() | nil
        }

  # The course as a row per section paired with the rows of the chapters under
  # it, so that a section's heading can be kept or dropped along with them.
  @course_groups Enum.map(Material.sections(), fn %Section{chapters: chapters} = section ->
                   {%{kind: :section, num: Section.num(section), title: section.title},
                    Enum.map(chapters, &%{kind: :chapter, num: Chapter.num(&1), title: &1.title})}
                 end)

  @course_rows Enum.flat_map(@course_groups, fn {section, chapters} -> [section | chapters] end)

  @course_numbers Enum.map(@course_rows, & &1.num)

  @doc """
  Every number the course uses, in reading order.
  """
  @spec course_numbers() :: [pos_integer()]
  def course_numbers, do: @course_numbers

  @doc """
  The rows the form of the given session offers, in reading order, with the
  numbers it holds that the course no longer uses last.
  """
  @spec rows(CourseSession.t()) :: [row()]
  def rows(%CourseSession{} = course_session),
    do:
      @course_rows ++
        Enum.map(orphans(course_session), &%{kind: :orphan, num: &1, title: nil})

  @doc """
  The rows the form of a session about to be recorded offers, in reading order:
  the course as it stands, less what the given sessions have already marked as
  done.

  A section's own row stays as long as any chapter under it is left, so that
  what remains keeps the heading it belongs to; a section whose every chapter is
  done goes with them, as does one still to be marked done itself.
  """
  @spec unfinished_rows([CourseSession.t()]) :: [row()]
  def unfinished_rows(course_sessions) do
    done = course_sessions |> Enum.flat_map(& &1.done) |> MapSet.new()

    Enum.flat_map(@course_groups, &rows_left(&1, done))
  end

  defp rows_left({section, chapters}, done) do
    case Enum.reject(chapters, &MapSet.member?(done, &1.num)) do
      [] -> if MapSet.member?(done, section.num), do: [], else: [section]
      left -> [section | left]
    end
  end

  @doc """
  The numbers the given session holds that name no section or chapter of the
  course as it stands, sorted.
  """
  @spec orphans(CourseSession.t()) :: [pos_integer()]
  def orphans(%CourseSession{done: done, due: due, next: next}),
    do:
      (done ++ due ++ next)
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.reject(&(&1 in @course_numbers))

  @doc """
  Whether the compiled course still names the given number.
  """
  @spec in_course?(pos_integer()) :: boolean()
  def in_course?(num), do: num in @course_numbers
end
