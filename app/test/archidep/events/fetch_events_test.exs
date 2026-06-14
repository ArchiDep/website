defmodule ArchiDep.Events.FetchEventsTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox
  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias ArchiDep.Accounts.Schemas.PreregisteredUser
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Errors.UnauthorizedError
  alias ArchiDep.Events.Behaviour
  alias ArchiDep.Events.Context
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Events.UseCases.FetchEvents
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.Factory
  alias ArchiDep.Support.ServersFactory
  alias Ecto.UUID

  # Distinct instants used to pin the ordering and cursor boundaries.
  @t10 ~U[2024-03-15 10:00:00.000000Z]
  @t11 ~U[2024-03-15 11:00:00.000000Z]
  @t12 ~U[2024-03-15 12:00:00.000000Z]

  # Fixed, lexicographically ordered IDs (a < b < c) for the tie-break cases,
  # where events share an `occurred_at` and the ID decides the order.
  @id_a "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
  @id_b "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
  @id_c "cccccccc-cccc-4ccc-8ccc-cccccccccccc"

  setup :verify_on_exit!

  setup_all do
    %{
      fetch_events: protect({Context, :fetch_events, 2}, Behaviour),
      fetch_event: protect({Context, :fetch_event, 2}, Behaviour)
    }
  end

  describe "fetch_events/2" do
    test "events are returned newest first by occurred-at", %{fetch_events: fetch_events} do
      old = EventsFactory.insert(:stored_event, occurred_at: @t10, stream: class_stream())
      newest = EventsFactory.insert(:stored_event, occurred_at: @t12, stream: class_stream())
      middle = EventsFactory.insert(:stored_event, occurred_at: @t11, stream: class_stream())

      auth = Factory.build(:authentication, root: true)

      assert fetch_events.(auth, limit: 10) == [newest, middle, old]
    end

    test "events sharing an occurred-at are ordered by ascending ID", %{
      fetch_events: fetch_events
    } do
      later =
        EventsFactory.insert(:stored_event, id: @id_b, occurred_at: @t11, stream: class_stream())

      earlier =
        EventsFactory.insert(:stored_event, id: @id_a, occurred_at: @t11, stream: class_stream())

      auth = Factory.build(:authentication, root: true)

      assert fetch_events.(auth, limit: 10) == [earlier, later]
    end

    test "the limit caps the number of returned events", %{fetch_events: fetch_events} do
      _old = EventsFactory.insert(:stored_event, occurred_at: @t10, stream: class_stream())
      newest = EventsFactory.insert(:stored_event, occurred_at: @t12, stream: class_stream())
      middle = EventsFactory.insert(:stored_event, occurred_at: @t11, stream: class_stream())

      auth = Factory.build(:authentication, root: true)

      assert fetch_events.(auth, limit: 2) == [newest, middle]
    end

    test "no events are returned when the store is empty", %{fetch_events: fetch_events} do
      auth = Factory.build(:authentication, root: true)

      assert fetch_events.(auth, limit: 10) == []
    end

    test "a limit outside the allowed range is rejected", %{fetch_events: fetch_events} do
      auth = Factory.build(:authentication, root: true)

      assert_raise FunctionClauseError, fn -> fetch_events.(auth, limit: 1001) end
    end

    test "the limit is required", %{fetch_events: fetch_events} do
      auth = Factory.build(:authentication, root: true)

      assert_raise KeyError, fn -> fetch_events.(auth, []) end
    end

    test "a non-root user cannot fetch events", %{fetch_events: fetch_events} do
      EventsFactory.insert(:stored_event, stream: class_stream())
      auth = Factory.build(:authentication, root: false)

      assert_raise UnauthorizedError, fn -> fetch_events.(auth, limit: 10) end
    end
  end

  # Keyset pagination orders by `occurred_at` descending then `id` ascending and
  # pages with a `{id, occurred_at}` cursor. The cases below walk the whole
  # boundary matrix: the cursor row itself is excluded; rows strictly
  # older/newer are included; rows that *share* the cursor's `occurred_at` are
  # split by ID in the cursor's direction (a greater ID is "older", a lesser ID
  # is "newer"); and `newer_than` + `older_than` together bound a window. The
  # fixtures deliberately give three events the same `@t11` so the tie-break is
  # actually exercised rather than only the strict-inequality path.
  describe "fetch_events/2 cursor pagination" do
    test "older_than returns strictly-older events and same-instant events with a greater ID",
         %{fetch_events: fetch_events} do
      low = EventsFactory.insert(:stored_event, occurred_at: @t10, stream: class_stream())
      # Same instant as the cursor, smaller ID: excluded (not strictly older).
      _mid_a =
        EventsFactory.insert(:stored_event, id: @id_a, occurred_at: @t11, stream: class_stream())

      mid_b =
        EventsFactory.insert(:stored_event, id: @id_b, occurred_at: @t11, stream: class_stream())

      # Same instant as the cursor, greater ID: included.
      mid_c =
        EventsFactory.insert(:stored_event, id: @id_c, occurred_at: @t11, stream: class_stream())

      # Newer than the cursor: excluded.
      _high = EventsFactory.insert(:stored_event, occurred_at: @t12, stream: class_stream())

      auth = Factory.build(:authentication, root: true)

      assert fetch_events.(auth, limit: 10, older_than: {mid_b.id, mid_b.occurred_at}) ==
               [mid_c, low]
    end

    test "newer_than returns strictly-newer events and same-instant events with a lesser ID", %{
      fetch_events: fetch_events
    } do
      # Older than the cursor: excluded.
      _low = EventsFactory.insert(:stored_event, occurred_at: @t10, stream: class_stream())
      # Same instant as the cursor, smaller ID: included.
      mid_a =
        EventsFactory.insert(:stored_event, id: @id_a, occurred_at: @t11, stream: class_stream())

      mid_b =
        EventsFactory.insert(:stored_event, id: @id_b, occurred_at: @t11, stream: class_stream())

      # Same instant as the cursor, greater ID: excluded.
      _mid_c =
        EventsFactory.insert(:stored_event, id: @id_c, occurred_at: @t11, stream: class_stream())

      high = EventsFactory.insert(:stored_event, occurred_at: @t12, stream: class_stream())

      auth = Factory.build(:authentication, root: true)

      assert fetch_events.(auth, limit: 10, newer_than: {mid_b.id, mid_b.occurred_at}) ==
               [high, mid_a]
    end

    test "newer_than and older_than together bound a window", %{fetch_events: fetch_events} do
      low = EventsFactory.insert(:stored_event, occurred_at: @t10, stream: class_stream())
      middle = EventsFactory.insert(:stored_event, occurred_at: @t11, stream: class_stream())
      high = EventsFactory.insert(:stored_event, occurred_at: @t12, stream: class_stream())

      auth = Factory.build(:authentication, root: true)

      assert fetch_events.(auth,
               limit: 10,
               newer_than: {low.id, low.occurred_at},
               older_than: {high.id, high.occurred_at}
             ) == [middle]
    end
  end

  # Each event carries an `entity` virtual field resolved from the stream's
  # context. The resolved struct must match the exact preloaded/loaded shape the
  # resolver builds (no preloads for classes/students/servers/switch-edu-id
  # identities; switch edu-ID + preregistered user for user accounts; group +
  # user account for preregistered users — see
  # ArchiDep.Events.UseCases.FetchEvents). Each expected entity is therefore
  # re-read here with the resolver's own query rather than assumed. Fixtures pin
  # the stream to a recognised type; the factory's random stream would otherwise
  # reach the resolver's stream parser.
  describe "fetch_events/2 entity enrichment" do
    test "a class event resolves its class", %{fetch_events: fetch_events} do
      class = CourseFactory.insert(:class)

      %StoredEvent{} =
        event =
        EventsFactory.insert(:stored_event,
          occurred_at: @t11,
          stream: "course:classes:#{class.id}"
        )

      auth = Factory.build(:authentication, root: true)

      assert fetch_events.(auth, limit: 10) == [%{event | entity: resolved_class(class.id)}]
    end

    test "a student event resolves its student", %{fetch_events: fetch_events} do
      student = CourseFactory.insert(:student, user: nil)

      %StoredEvent{} =
        event =
        EventsFactory.insert(:stored_event,
          occurred_at: @t11,
          stream: "course:students:#{student.id}"
        )

      auth = Factory.build(:authentication, root: true)

      assert fetch_events.(auth, limit: 10) ==
               [%{event | entity: resolved_student(student.id)}]
    end

    test "a user-account event resolves its account with its identity preloads", %{
      fetch_events: fetch_events
    } do
      # A root account satisfies the user-account check constraint (root accounts
      # always carry a username); the resolution shape is what matters here.
      account = AccountsFactory.insert(:user_account, root: true)

      %StoredEvent{} =
        event =
        EventsFactory.insert(:stored_event,
          occurred_at: @t11,
          stream: "accounts:user-accounts:#{account.id}"
        )

      auth = Factory.build(:authentication, root: true)

      assert fetch_events.(auth, limit: 10) ==
               [%{event | entity: resolved_user_account(account.id)}]
    end

    test "a switch edu-ID event resolves its identity", %{fetch_events: fetch_events} do
      switch_edu_id = AccountsFactory.insert(:switch_edu_id)

      %StoredEvent{} =
        event =
        EventsFactory.insert(:stored_event,
          occurred_at: @t11,
          stream: "accounts:switch-edu-id:#{switch_edu_id.id}"
        )

      auth = Factory.build(:authentication, root: true)

      assert fetch_events.(auth, limit: 10) ==
               [%{event | entity: resolved_switch_edu_id(switch_edu_id.id)}]
    end

    test "a preregistered-user event resolves it with its group and account preloads", %{
      fetch_events: fetch_events
    } do
      # A preregistered user is the accounts-context view of a student row (they
      # share the `students` table), so it is persisted through the course
      # factory; its group is the student's class.
      student = CourseFactory.insert(:student, user: nil)

      %StoredEvent{} =
        event =
        EventsFactory.insert(:stored_event,
          occurred_at: @t11,
          stream: "accounts:preregistered-users:#{student.id}"
        )

      auth = Factory.build(:authentication, root: true)

      assert fetch_events.(auth, limit: 10) ==
               [%{event | entity: resolved_preregistered_user(student.id)}]
    end

    test "a server event resolves its server", %{fetch_events: fetch_events} do
      # A server belongs to a server group (which shares the `classes` table) and
      # an owner account, and carries its two server-properties rows.
      owner = AccountsFactory.insert(:user_account, root: true)
      group = CourseFactory.insert(:class)
      expected_properties = ServersFactory.insert(:server_properties)
      last_known_properties = ServersFactory.insert(:server_properties)

      server =
        ServersFactory.insert(:server,
          group_id: group.id,
          owner_id: owner.id,
          expected_properties: expected_properties,
          last_known_properties: last_known_properties
        )

      %StoredEvent{} =
        event =
        EventsFactory.insert(:stored_event,
          occurred_at: @t11,
          stream: "servers:servers:#{server.id}"
        )

      auth = Factory.build(:authentication, root: true)

      assert fetch_events.(auth, limit: 10) ==
               [%{event | entity: resolved_server(server.id)}]
    end

    test "an event whose entity row no longer exists keeps a nil entity", %{
      fetch_events: fetch_events
    } do
      # Recognised stream type, but no matching class row exists.
      event =
        EventsFactory.insert(:stored_event,
          occurred_at: @t11,
          stream: "course:classes:#{UUID.generate()}"
        )

      auth = Factory.build(:authentication, root: true)

      assert fetch_events.(auth, limit: 10) == [event]
    end

    test "an event with an unrecognised stream type keeps a nil entity", %{
      fetch_events: fetch_events
    } do
      # The resolver only knows specific stream types; any other (here an
      # events-context stream) must be returned with a nil entity rather than
      # crashing the whole read.
      event =
        EventsFactory.insert(:stored_event,
          occurred_at: @t11,
          stream: "events:projections:#{UUID.generate()}"
        )

      auth = Factory.build(:authentication, root: true)

      assert fetch_events.(auth, limit: 10) == [event]
    end
  end

  describe "fetch_event/2" do
    test "fetch a stored event by ID", %{fetch_event: fetch_event} do
      event = EventsFactory.insert(:stored_event, occurred_at: @t11, stream: class_stream())
      auth = Factory.build(:authentication, root: true)

      # This path does not enrich the event, so the entity stays nil.
      assert fetch_event.(auth, event.id) == {:ok, event}
    end

    test "an unknown ID is reported as not found", %{fetch_event: fetch_event} do
      auth = Factory.build(:authentication, root: true)

      assert fetch_event.(auth, UUID.generate()) == {:error, :event_not_found}
    end

    test "a malformed ID is reported as not found" do
      auth = Factory.build(:authentication, root: true)

      # The `fetch_event/2` typespec requires a UUID, so the `Hammox`-protected
      # wrapper would reject a malformed string before the use case runs. This
      # exercises the use case's own defensive `validate_uuid` guard, so it
      # calls the implementation directly.
      assert FetchEvents.fetch_event(auth, "not-a-uuid") == {:error, :event_not_found}
    end

    test "a non-root user gets not found rather than access denied", %{fetch_event: fetch_event} do
      # The authorization failure is masked as `:event_not_found` so it does not
      # leak the existence of an event the caller may not see.
      event = EventsFactory.insert(:stored_event, occurred_at: @t11, stream: class_stream())
      auth = Factory.build(:authentication, root: false)

      assert fetch_event.(auth, event.id) == {:error, :event_not_found}
    end
  end

  defp class_stream, do: "course:classes:#{UUID.generate()}"

  defp resolved_class(id), do: Repo.get!(Class, id)

  defp resolved_switch_edu_id(id), do: Repo.get!(SwitchEduId, id)

  defp resolved_student(id), do: Repo.get!(Student, id)

  defp resolved_server(id), do: Repo.get!(Server, id)

  defp resolved_user_account(id),
    do:
      Repo.one!(
        from(ua in UserAccount,
          where: ua.id == ^id,
          left_join: sei in assoc(ua, :switch_edu_id),
          left_join: pu in assoc(ua, :preregistered_user),
          preload: [switch_edu_id: sei, preregistered_user: pu]
        )
      )

  defp resolved_preregistered_user(id),
    do:
      Repo.one!(
        from(pu in PreregisteredUser,
          where: pu.id == ^id,
          join: ug in assoc(pu, :group),
          left_join: ua in assoc(pu, :user_account),
          preload: [group: ug, user_account: ua]
        )
      )
end
