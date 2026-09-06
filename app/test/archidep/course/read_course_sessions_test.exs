defmodule ArchiDep.Course.ReadCourseSessionsTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox
  alias ArchiDep.Course.Behaviour
  alias ArchiDep.Course.Context
  alias ArchiDep.Course.Events.CourseSessionCreated
  alias ArchiDep.Course.Events.CourseSessionDeleted
  alias ArchiDep.Course.Events.CourseSessionUpdated
  alias ArchiDep.Course.Schemas.CourseSession
  alias ArchiDep.CourseSite.Session
  alias ArchiDep.Errors.UnauthorizedError
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.Factory
  alias Ecto.UUID

  setup :verify_on_exit!

  setup_all do
    %{
      course_sessions: protect({Context, :course_sessions, 0}, Behaviour),
      list_course_sessions: protect({Context, :list_course_sessions, 1}, Behaviour),
      refresh_course_sessions: protect({Context, :refresh_course_sessions, 3}, Behaviour)
    }
  end

  describe "course_sessions/0" do
    test "answers with what each session recorded, in the order they were taught", %{
      course_sessions: course_sessions
    } do
      # Recorded out of order, and two of them sharing a day, which is what the
      # two halves of the order have to get right: the day they were taught, and
      # — for the two sharing a day — the order they were entered in.
      git =
        CourseFactory.insert(:course_session,
          date: ~D[2026-09-25],
          title: "Git",
          done: [200],
          due: [201],
          next: [],
          created_at: ~U[2026-09-25 14:00:00.000000Z],
          version: 1
        )

      cli =
        CourseFactory.insert(:course_session,
          date: ~D[2026-09-18],
          title: "CLI",
          done: [100, 101],
          due: [102],
          next: [103],
          created_at: ~U[2026-09-18 10:00:00.000000Z],
          version: 1
        )

      ssh =
        CourseFactory.insert(:course_session,
          date: ~D[2026-09-25],
          title: "SSH",
          done: [102, 103],
          due: [],
          next: [200],
          created_at: ~U[2026-09-25 10:00:00.000000Z],
          version: 1
        )

      assert course_sessions.() == [
               Session.new(~D[2026-09-18], "CLI", [100, 101], [102], [103]),
               Session.new(~D[2026-09-25], "SSH", [102, 103], [], [200]),
               Session.new(~D[2026-09-25], "Git", [200], [201], [])
             ]

      assert_no_stored_events!()
      assert persisted_course_sessions() == [cli, ssh, git]
    end

    test "answers with nothing for a course nobody has taught yet", %{
      course_sessions: course_sessions
    } do
      assert course_sessions.() == []

      assert_no_stored_events!()
    end
  end

  describe "list_course_sessions/1" do
    test "answers with the records themselves, in the order they were taught", %{
      list_course_sessions: list_course_sessions
    } do
      docker =
        CourseFactory.insert(:course_session,
          date: ~D[2026-10-16],
          title: "Docker",
          done: [500],
          due: [501],
          next: [502],
          created_at: ~U[2026-10-16 10:00:00.000000Z],
          version: 1
        )

      deployment =
        CourseFactory.insert(:course_session,
          date: ~D[2026-10-02],
          title: "Deployment",
          done: [],
          due: [],
          next: [300],
          created_at: ~U[2026-10-02 10:00:00.000000Z],
          version: 1
        )

      auth = Factory.build(:authentication, root: true)

      assert list_course_sessions.(auth) == [deployment, docker]

      assert_no_stored_events!()
    end

    test "a non-root user cannot list the sessions of the course", %{
      list_course_sessions: list_course_sessions
    } do
      dns =
        CourseFactory.insert(:course_session,
          date: ~D[2026-10-09],
          title: "DNS",
          done: [400],
          due: [401],
          next: [402],
          created_at: ~U[2026-10-09 10:00:00.000000Z],
          version: 1
        )

      auth = Factory.build(:authentication, root: false)

      assert_raise UnauthorizedError, fn -> list_course_sessions.(auth) end

      assert_no_stored_events!()
      assert persisted_course_sessions() == [dns]
    end
  end

  describe "refresh_course_sessions/3" do
    test "re-reads the list for a message about a session", %{
      refresh_course_sessions: refresh_course_sessions
    } do
      auth = Factory.build(:authentication, root: true)
      reference = EventsFactory.build(:event_reference)
      answer = [CourseFactory.build(:course_session, date: ~D[2026-11-06], title: "TLS")]

      created = %CourseSessionCreated{
        id: UUID.generate(),
        date: ~D[2026-11-06],
        title: "TLS",
        done: [600],
        due: [601],
        next: [602]
      }

      updated = %CourseSessionUpdated{
        id: UUID.generate(),
        date: ~D[2026-11-13],
        title: "Reverse proxying",
        done: [603],
        due: [604],
        next: [605]
      }

      deleted = %CourseSessionDeleted{
        id: UUID.generate(),
        date: ~D[2026-11-20],
        title: "Automated deployment"
      }

      # The re-read goes through the public boundary so the consuming LiveView
      # sees it as an ordinary context read, which in a test is the mock.
      expect(ArchiDep.Course.ContextMock, :list_course_sessions, 3, fn ^auth -> answer end)

      for message <- [
            {:course_session_created, created, reference},
            {:course_session_updated, updated, reference},
            {:course_session_deleted, deleted, reference}
          ] do
        assert refresh_course_sessions.(auth, [], message) == {:ok, answer}
      end

      assert_no_stored_events!()
    end

    test "declines a message about anything else", %{
      refresh_course_sessions: refresh_course_sessions
    } do
      auth = Factory.build(:authentication, root: true)

      assert refresh_course_sessions.(auth, [], {:class_created, :an_event, :a_reference}) ==
               :ignore

      assert_no_stored_events!()
    end
  end

  defp persisted_course_sessions,
    do: Repo.all(from cs in CourseSession, order_by: [asc: cs.date, asc: cs.created_at])
end
