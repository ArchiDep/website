defmodule ArchiDep.Course.UpdateCourseSessionTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox

  import ArchiDep.Support.PubSubTestHelpers,
    only: [collect_broadcasts: 1, received_broadcasts: 1]

  alias ArchiDep.Clock
  alias ArchiDep.Course.Behaviour
  alias ArchiDep.Course.Context
  alias ArchiDep.Course.Events.CourseSessionUpdated
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.CourseSession
  alias ArchiDep.Errors.UnauthorizedError
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Repo
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.Factory
  alias Ecto.UUID

  @now ~U[2026-10-02 14:00:00.000000Z]

  @affected_tables [CourseSession, StoredEvent]

  setup :verify_on_exit!

  setup do
    stub(Clock.Mock, :now, fn -> @now end)
    :ok
  end

  setup_all do
    %{
      update_course_session: protect({Context, :update_course_session, 3}, Behaviour),
      validate_existing_course_session:
        protect({Context, :validate_existing_course_session, 3}, Behaviour)
    }
  end

  test "correct a session of the course", %{update_course_session: update_course_session} do
    broadcasts = subscribe_course_session_broadcasts()

    recorded = CourseFactory.insert(:course_session, version: 1)
    data = CourseFactory.build(:course_session_data)
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, course_session} = update_course_session.(auth, recorded.id, data)

    event =
      course_session
      |> assert_updated_course_session(recorded, data)
      |> assert_course_session_updated_event(recorded, auth, data)

    assert_persisted_course_session(event, recorded)
    assert_row_count_diff(previous_counts, %{StoredEvent => 1})
    assert_course_session_updated_broadcast(broadcasts, course_session, event)
  end

  test "empty a category of a session of the course", %{
    update_course_session: update_course_session
  } do
    broadcasts = subscribe_course_session_broadcasts()

    # The whole reason the form pairs every checkbox with a hidden `"false"`:
    # unchecking the last box of a category has to empty it rather than leave
    # what was there.
    recorded =
      CourseFactory.insert(:course_session, done: [100, 101], due: [102], next: [103], version: 1)

    data = %{
      date: recorded.date,
      title: recorded.title,
      done: [100, 101],
      due: [],
      next: [103]
    }

    auth = Factory.build(:authentication, root: true)

    assert {:ok, course_session} = update_course_session.(auth, recorded.id, data)

    event =
      course_session
      |> assert_updated_course_session(recorded, data)
      |> assert_course_session_updated_event(recorded, auth, data)

    assert_persisted_course_session(event, recorded)
    assert_course_session_updated_broadcast(broadcasts, course_session, event)
  end

  test "a session of the course that does not exist cannot be corrected", %{
    update_course_session: update_course_session
  } do
    broadcasts = subscribe_course_session_broadcasts()

    recorded = CourseFactory.insert(:course_session, version: 1)
    data = CourseFactory.build(:course_session_data)
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert update_course_session.(auth, UUID.generate(), data) ==
             {:error, :course_session_not_found}

    assert nothing_changed(broadcasts, previous_counts, recorded)
  end

  test "a non-root user cannot correct a session of the course", %{
    update_course_session: update_course_session
  } do
    broadcasts = subscribe_course_session_broadcasts()

    recorded = CourseFactory.insert(:course_session, version: 1)
    data = CourseFactory.build(:course_session_data)
    auth = Factory.build(:authentication, root: false)

    previous_counts = count_rows(@affected_tables)

    assert_raise UnauthorizedError, fn -> update_course_session.(auth, recorded.id, data) end

    assert nothing_changed(broadcasts, previous_counts, recorded)
  end

  test "a session of the course cannot be corrected into having no name", %{
    update_course_session: update_course_session
  } do
    broadcasts = subscribe_course_session_broadcasts()

    recorded = CourseFactory.insert(:course_session, version: 1)
    data = CourseFactory.build(:course_session_data, title: "")
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:error, changeset} = update_course_session.(auth, recorded.id, data)
    assert errors_on(changeset) == %{title: ["can't be blank"]}

    assert nothing_changed(broadcasts, previous_counts, recorded)
  end

  test "validate valid session data without correcting anything", %{
    validate_existing_course_session: validate_existing_course_session
  } do
    broadcasts = subscribe_course_session_broadcasts()

    recorded = CourseFactory.insert(:course_session, version: 1)
    data = CourseFactory.build(:course_session_data)
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, %Changeset{} = changeset} =
             validate_existing_course_session.(auth, recorded.id, data)

    assert errors_on(changeset) == %{}

    assert nothing_changed(broadcasts, previous_counts, recorded)
  end

  test "validate surfaces validation errors without correcting anything", %{
    validate_existing_course_session: validate_existing_course_session
  } do
    broadcasts = subscribe_course_session_broadcasts()

    recorded = CourseFactory.insert(:course_session, version: 1)
    data = CourseFactory.build(:course_session_data, title: "")
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, %Changeset{} = changeset} =
             validate_existing_course_session.(auth, recorded.id, data)

    assert errors_on(changeset) == %{title: ["can't be blank"]}

    assert nothing_changed(broadcasts, previous_counts, recorded)
  end

  test "a non-root user cannot validate the correction of a session of the course", %{
    validate_existing_course_session: validate_existing_course_session
  } do
    broadcasts = subscribe_course_session_broadcasts()

    recorded = CourseFactory.insert(:course_session, version: 1)
    data = CourseFactory.build(:course_session_data)
    auth = Factory.build(:authentication, root: false)

    previous_counts = count_rows(@affected_tables)

    assert_raise UnauthorizedError, fn ->
      validate_existing_course_session.(auth, recorded.id, data)
    end

    assert nothing_changed(broadcasts, previous_counts, recorded)
  end

  defp assert_updated_course_session(
         %CourseSession{} = course_session,
         %CourseSession{} = recorded,
         data
       ) do
    assert course_session == %CourseSession{
             __meta__: loaded(CourseSession, "course_sessions"),
             id: recorded.id,
             date: data.date,
             title: data.title,
             done: Enum.sort(data.done),
             due: Enum.sort(data.due),
             next: Enum.sort(data.next),
             version: recorded.version + 1,
             created_at: recorded.created_at,
             updated_at: @now
           }

    course_session
  end

  defp assert_course_session_updated_event(
         %CourseSession{},
         %CourseSession{id: id, version: version},
         auth,
         data
       ) do
    assert [%StoredEvent{id: event_id} = updated_event] = fetch_new_stored_events()

    assert updated_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "course:sessions:#{id}",
             version: version + 1,
             schema_version: 1,
             type: "archidep/course/session-updated",
             data: %{
               "id" => id,
               "date" => Date.to_iso8601(data.date),
               "title" => data.title,
               "done" => Enum.sort(data.done),
               "due" => Enum.sort(data.due),
               "next" => Enum.sort(data.next)
             },
             meta: %{},
             initiator: "accounts:user-accounts:#{auth.principal_id}",
             causation_id: event_id,
             correlation_id: event_id,
             occurred_at: @now,
             entity: nil
           }

    updated_event
  end

  # Reconstructs the expected persisted row from the already-asserted audit
  # event and the one thing a "session corrected" event does not carry: when the
  # session was first recorded, which a correction does not change.
  defp assert_persisted_course_session(
         %StoredEvent{
           data: %{
             "id" => id,
             "date" => date,
             "title" => title,
             "done" => done,
             "due" => due,
             "next" => next
           },
           version: version,
           occurred_at: updated_at
         },
         %CourseSession{created_at: created_at}
       ) do
    assert Repo.get!(CourseSession, id) == %CourseSession{
             __meta__: loaded(CourseSession, "course_sessions"),
             id: id,
             date: Date.from_iso8601!(date),
             title: title,
             done: done,
             due: due,
             next: next,
             version: version,
             created_at: created_at,
             updated_at: updated_at
           }
  end

  defp subscribe_course_session_broadcasts,
    do: %{global: collect_broadcasts(fn -> PubSub.subscribe_course_sessions() end)}

  defp assert_course_session_updated_broadcast(
         broadcasts,
         %CourseSession{} = course_session,
         %StoredEvent{} = event
       ) do
    expected_message =
      {:course_session_updated, CourseSessionUpdated.new(course_session),
       StoredEvent.to_reference(event)}

    assert received_broadcasts(broadcasts.global) == [expected_message]
  end

  defp nothing_changed(broadcasts, previous_counts, %CourseSession{id: id} = recorded) do
    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
    assert received_broadcasts(broadcasts.global) == []
    assert Repo.get!(CourseSession, id) == recorded
    true
  end
end
