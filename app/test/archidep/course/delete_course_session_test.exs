defmodule ArchiDep.Course.DeleteCourseSessionTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox

  import ArchiDep.Support.PubSubTestHelpers,
    only: [collect_broadcasts: 1, received_broadcasts: 1]

  alias ArchiDep.Clock
  alias ArchiDep.Course.Behaviour
  alias ArchiDep.Course.Context
  alias ArchiDep.Course.Events.CourseSessionDeleted
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.CourseSession
  alias ArchiDep.Errors.UnauthorizedError
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Repo
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.Factory
  alias Ecto.UUID

  @now ~U[2026-10-09 09:00:00.000000Z]

  @affected_tables [CourseSession, StoredEvent]

  setup :verify_on_exit!

  setup do
    stub(Clock.Mock, :now, fn -> @now end)
    :ok
  end

  setup_all do
    %{delete_course_session: protect({Context, :delete_course_session, 2}, Behaviour)}
  end

  test "delete a session of the course", %{delete_course_session: delete_course_session} do
    broadcasts = subscribe_course_session_broadcasts()

    recorded = CourseFactory.insert(:course_session)
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert delete_course_session.(auth, recorded.id) == :ok

    event = assert_course_session_deleted_event(recorded, auth)

    assert_gone(event)
    assert_row_count_diff(previous_counts, %{CourseSession => -1, StoredEvent => 1})
    assert_course_session_deleted_broadcast(broadcasts, recorded, event)
  end

  test "a session of the course that does not exist cannot be deleted", %{
    delete_course_session: delete_course_session
  } do
    broadcasts = subscribe_course_session_broadcasts()

    recorded = CourseFactory.insert(:course_session)
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert delete_course_session.(auth, UUID.generate()) == {:error, :course_session_not_found}

    assert nothing_deleted(broadcasts, previous_counts, recorded)
  end

  test "a non-root user cannot delete a session of the course", %{
    delete_course_session: delete_course_session
  } do
    broadcasts = subscribe_course_session_broadcasts()

    recorded = CourseFactory.insert(:course_session)
    auth = Factory.build(:authentication, root: false)

    previous_counts = count_rows(@affected_tables)

    assert_raise UnauthorizedError, fn -> delete_course_session.(auth, recorded.id) end

    assert nothing_deleted(broadcasts, previous_counts, recorded)
  end

  defp assert_course_session_deleted_event(
         %CourseSession{id: id, date: date, title: title, version: version},
         auth
       ) do
    assert [%StoredEvent{id: event_id} = deleted_event] = fetch_new_stored_events()

    assert deleted_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "course:sessions:#{id}",
             version: version,
             schema_version: 1,
             type: "archidep/course/session-deleted",
             data: %{
               "id" => id,
               "date" => Date.to_iso8601(date),
               "title" => title
             },
             meta: %{},
             initiator: "accounts:user-accounts:#{auth.principal_id}",
             causation_id: event_id,
             correlation_id: event_id,
             occurred_at: @now,
             entity: nil
           }

    deleted_event
  end

  # The row the already-asserted audit event names is the one that has to be
  # gone, which is what makes this a check of the deletion rather than of the
  # fixture.
  defp assert_gone(%StoredEvent{data: %{"id" => id}}),
    do: assert(Repo.get(CourseSession, id) == nil)

  defp subscribe_course_session_broadcasts,
    do: %{global: collect_broadcasts(fn -> PubSub.subscribe_course_sessions() end)}

  defp assert_course_session_deleted_broadcast(
         broadcasts,
         %CourseSession{} = course_session,
         %StoredEvent{} = event
       ) do
    expected_message =
      {:course_session_deleted, CourseSessionDeleted.new(course_session),
       StoredEvent.to_reference(event)}

    assert received_broadcasts(broadcasts.global) == [expected_message]
  end

  defp nothing_deleted(broadcasts, previous_counts, %CourseSession{id: id} = recorded) do
    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
    assert received_broadcasts(broadcasts.global) == []
    assert Repo.get!(CourseSession, id) == recorded
    true
  end
end
