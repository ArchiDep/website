defmodule ArchiDep.Course.ReadCourseSessionsTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox
  alias ArchiDep.Course.Behaviour
  alias ArchiDep.Course.Context
  alias ArchiDep.Course.UseCases.ReadCourseSessions
  alias ArchiDep.CourseSite.Session

  @moduletag :tmp_dir

  setup :verify_on_exit!

  setup_all do
    %{course_sessions: protect({Context, :course_sessions, 0}, Behaviour)}
  end

  describe "course_sessions/0" do
    test "reads the file the application ships with its own code", %{
      course_sessions: course_sessions
    } do
      file = ReadCourseSessions.progress_file()

      assert file == Application.app_dir(:archidep, "priv/course/progress.json")
      assert course_sessions.() == ReadCourseSessions.course_sessions(file)

      assert_no_stored_events!()
    end
  end

  describe "course_sessions/1" do
    test "reads what each session of the course recorded, in the order the file lists them", %{
      tmp_dir: tmp_dir
    } do
      file = Path.join(tmp_dir, "progress.json")

      File.write!(file, """
      {
        "sessions": [
          {"date": "2025-09-19", "title": "CLI", "done": [100], "due": [101], "next": [102]},
          {"date": "2025-09-26", "title": "SSH", "done": [101], "due": [], "next": []}
        ]
      }
      """)

      assert ReadCourseSessions.course_sessions(file) == [
               Session.new(~D[2025-09-19], "CLI", [100], [101], [102]),
               Session.new(~D[2025-09-26], "SSH", [101], [], [])
             ]

      assert_no_stored_events!()
    end

    test "refuses to answer for a course whose progress cannot be read", %{tmp_dir: tmp_dir} do
      file = Path.join(tmp_dir, "progress.json")
      File.write!(file, ~s({"sessions": [{"title": "CLI"}]}))

      assert_raise RuntimeError,
                   """
                   The progress through the course could not be read:
                     Session 1 of the progress file is malformed: no "date"\
                   """,
                   fn -> ReadCourseSessions.course_sessions(file) end

      assert_no_stored_events!()
    end
  end
end
