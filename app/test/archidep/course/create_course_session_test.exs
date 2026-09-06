defmodule ArchiDep.Course.CreateCourseSessionTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox

  import ArchiDep.Support.PubSubTestHelpers,
    only: [collect_broadcasts: 1, received_broadcasts: 1]

  alias ArchiDep.Clock
  alias ArchiDep.Course.Behaviour
  alias ArchiDep.Course.Context
  alias ArchiDep.Course.Events.CourseSessionCreated
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.CourseSession
  alias ArchiDep.Errors.UnauthorizedError
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Repo
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.Factory

  # Pinned instant returned by the injected clock for the duration of each test,
  # so that every timestamp produced by the use case can be asserted exactly
  # (see `docs/testing.md`).
  @now ~U[2026-09-18 10:30:00.000000Z]

  # Every table this use case can affect. Snapshot all of them with
  # `count_rows/1` before each call so the row-count diff catches a stray write
  # to any of them, not just the ones a given test happens to think about (see
  # `docs/testing.md`).
  @affected_tables [CourseSession, StoredEvent]

  setup :verify_on_exit!

  setup do
    stub(Clock.Mock, :now, fn -> @now end)
    :ok
  end

  setup_all do
    %{
      create_course_session: protect({Context, :create_course_session, 2}, Behaviour),
      validate_course_session: protect({Context, :validate_course_session, 2}, Behaviour)
    }
  end

  # The three creation tests below follow the create-testing strategy documented
  # in `docs/testing.md`: a random one (let the factory fill as much as
  # possible), a minimal one (only the required fields, every optional left
  # out), and a full one (every optional set).

  test "record a session of the course", %{create_course_session: create_course_session} do
    broadcasts = subscribe_course_session_broadcasts()

    data = CourseFactory.build(:course_session_data)
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, course_session} = create_course_session.(auth, data)

    event =
      course_session
      |> assert_created_course_session(data)
      |> assert_course_session_created_event(auth, data)

    assert_persisted_course_session(event)
    assert_row_count_diff(previous_counts, %{CourseSession => 1, StoredEvent => 1})
    assert_course_session_created_broadcast(broadcasts, course_session, event)
  end

  test "record a minimal session of the course", %{
    create_course_session: create_course_session
  } do
    broadcasts = subscribe_course_session_broadcasts()

    # Built by hand (rather than via the factory) so the minimal valid set is
    # explicit and does not drift: the day and the name, with the three
    # categories left empty, which is what a session that announced nothing
    # recorded.
    data = %{date: ~D[2026-09-18], title: "Welcome", done: [], due: [], next: []}
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, course_session} = create_course_session.(auth, data)

    event =
      course_session
      |> assert_created_course_session(data)
      |> assert_course_session_created_event(auth, data)

    assert_persisted_course_session(event)
    assert_row_count_diff(previous_counts, %{CourseSession => 1, StoredEvent => 1})
    assert_course_session_created_broadcast(broadcasts, course_session, event)
  end

  test "record a full session of the course", %{create_course_session: create_course_session} do
    broadcasts = subscribe_course_session_broadcasts()

    data = %{
      date: ~D[2026-10-02],
      title: "Basic Deployment",
      done: [410, 411, 500],
      due: [501, 504],
      next: [507, 508]
    }

    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, course_session} = create_course_session.(auth, data)

    event =
      course_session
      |> assert_created_course_session(data)
      |> assert_course_session_created_event(auth, data)

    assert_persisted_course_session(event)
    assert_row_count_diff(previous_counts, %{CourseSession => 1, StoredEvent => 1})
    assert_course_session_created_broadcast(broadcasts, course_session, event)
  end

  test "the numbers are stored sorted and de-duplicated", %{
    create_course_session: create_course_session
  } do
    broadcasts = subscribe_course_session_broadcasts()

    data = %{
      date: ~D[2026-10-02],
      title: "Unix Basics",
      done: [406, 402, 406, 405],
      due: [405, 405],
      next: [410]
    }

    auth = Factory.build(:authentication, root: true)

    assert {:ok, course_session} = create_course_session.(auth, data)

    sorted = %{data | done: [402, 405, 406], due: [405], next: [410]}

    event =
      course_session
      |> assert_created_course_session(sorted)
      |> assert_course_session_created_event(auth, sorted)

    assert_persisted_course_session(event)
    assert_course_session_created_broadcast(broadcasts, course_session, event)
  end

  test "a session that names a chapter the course no longer has is recorded all the same", %{
    create_course_session: create_course_session
  } do
    broadcasts = subscribe_course_session_broadcasts()

    # A stored number is a record of what a session said on the day, not a
    # reference into the course as it stands: the material is written as the
    # course runs, and a chapter that has not been taught yet may be renumbered
    # or dropped at any point.
    data = %{date: ~D[2026-10-02], title: "Gone", done: [99_999], due: [], next: []}
    auth = Factory.build(:authentication, root: true)

    assert {:ok, course_session} = create_course_session.(auth, data)

    event =
      course_session
      |> assert_created_course_session(data)
      |> assert_course_session_created_event(auth, data)

    assert_persisted_course_session(event)
    assert_course_session_created_broadcast(broadcasts, course_session, event)
  end

  test "a non-root user cannot record a session of the course", %{
    create_course_session: create_course_session
  } do
    broadcasts = subscribe_course_session_broadcasts()

    data = CourseFactory.build(:course_session_data)
    auth = Factory.build(:authentication, root: false)

    previous_counts = count_rows(@affected_tables)

    assert_raise UnauthorizedError, fn -> create_course_session.(auth, data) end

    assert_nothing_recorded(broadcasts, previous_counts)
  end

  test "a session of the course cannot be recorded without a day", %{
    create_course_session: create_course_session
  } do
    broadcasts = subscribe_course_session_broadcasts()

    data = CourseFactory.build(:course_session_data, date: nil)
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:error, changeset} = create_course_session.(auth, data)
    assert errors_on(changeset) == %{date: ["can't be blank"]}

    assert_nothing_recorded(broadcasts, previous_counts)
  end

  test "a session of the course cannot be recorded without a name", %{
    create_course_session: create_course_session
  } do
    broadcasts = subscribe_course_session_broadcasts()

    data = CourseFactory.build(:course_session_data, title: "   ")
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:error, changeset} = create_course_session.(auth, data)
    assert errors_on(changeset) == %{title: ["can't be blank"]}

    assert_nothing_recorded(broadcasts, previous_counts)
  end

  test "a session of the course cannot record a number that is not one", %{
    create_course_session: create_course_session
  } do
    broadcasts = subscribe_course_session_broadcasts()

    data = CourseFactory.build(:course_session_data, done: [0], due: [-1], next: [1])
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:error, changeset} = create_course_session.(auth, data)

    assert errors_on(changeset) == %{
             done: ["must contain only section or chapter numbers"],
             due: ["must contain only section or chapter numbers"]
           }

    assert_nothing_recorded(broadcasts, previous_counts)
  end

  test "validate valid session data without recording anything", %{
    validate_course_session: validate_course_session
  } do
    broadcasts = subscribe_course_session_broadcasts()

    data = CourseFactory.build(:course_session_data)
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert %Changeset{} = changeset = validate_course_session.(auth, data)
    assert errors_on(changeset) == %{}

    assert_nothing_recorded(broadcasts, previous_counts)
  end

  test "validate surfaces validation errors without recording anything", %{
    validate_course_session: validate_course_session
  } do
    broadcasts = subscribe_course_session_broadcasts()

    data = CourseFactory.build(:course_session_data, title: "")
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert %Changeset{} = changeset = validate_course_session.(auth, data)
    assert errors_on(changeset) == %{title: ["can't be blank"]}

    assert_nothing_recorded(broadcasts, previous_counts)
  end

  test "a non-root user cannot validate session data", %{
    validate_course_session: validate_course_session
  } do
    broadcasts = subscribe_course_session_broadcasts()

    data = CourseFactory.build(:course_session_data)
    auth = Factory.build(:authentication, root: false)

    previous_counts = count_rows(@affected_tables)

    assert_raise UnauthorizedError, fn -> validate_course_session.(auth, data) end

    assert_nothing_recorded(broadcasts, previous_counts)
  end

  defp assert_created_course_session(%CourseSession{} = course_session, data) do
    assert %CourseSession{id: id} = course_session

    assert course_session == %CourseSession{
             __meta__: loaded(CourseSession, "course_sessions"),
             id: id,
             date: data.date,
             title: data.title,
             done: data.done,
             due: data.due,
             next: data.next,
             version: 1,
             created_at: @now,
             updated_at: @now
           }

    course_session
  end

  defp assert_course_session_created_event(%CourseSession{id: id}, auth, data) do
    assert [%StoredEvent{id: event_id} = created_event] = fetch_new_stored_events()

    assert created_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "course:sessions:#{id}",
             version: 1,
             schema_version: 1,
             type: "archidep/course/session-created",
             data: %{
               "id" => id,
               "date" => Date.to_iso8601(data.date),
               "title" => data.title,
               "done" => data.done,
               "due" => data.due,
               "next" => data.next
             },
             meta: %{},
             initiator: "accounts:user-accounts:#{auth.principal_id}",
             causation_id: event_id,
             correlation_id: event_id,
             occurred_at: @now,
             entity: nil
           }

    created_event
  end

  # Reconstructs the expected persisted row entirely from the already-asserted
  # audit event: the fields it carries, plus what a "session recorded" event
  # implies — version 1 and `updated_at` equal to `created_at`. The event stores
  # the day as an ISO-8601 string, so it is parsed back to a `Date`.
  defp assert_persisted_course_session(%StoredEvent{
         data: %{
           "id" => id,
           "date" => date,
           "title" => title,
           "done" => done,
           "due" => due,
           "next" => next
         },
         occurred_at: created_at
       }) do
    assert Repo.get!(CourseSession, id) == %CourseSession{
             __meta__: loaded(CourseSession, "course_sessions"),
             id: id,
             date: Date.from_iso8601!(date),
             title: title,
             done: done,
             due: due,
             next: next,
             version: 1,
             created_at: created_at,
             updated_at: created_at
           }
  end

  defp subscribe_course_session_broadcasts,
    do: %{global: collect_broadcasts(fn -> PubSub.subscribe_course_sessions() end)}

  defp assert_course_session_created_broadcast(
         broadcasts,
         %CourseSession{} = course_session,
         %StoredEvent{} = event
       ) do
    expected_message =
      {:course_session_created, CourseSessionCreated.new(course_session),
       StoredEvent.to_reference(event)}

    assert received_broadcasts(broadcasts.global) == [expected_message]
  end

  defp assert_nothing_recorded(broadcasts, previous_counts) do
    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
    assert received_broadcasts(broadcasts.global) == []
  end
end
