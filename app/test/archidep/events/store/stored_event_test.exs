defmodule ArchiDep.Events.Store.StoredEventTest do
  use ArchiDep.Support.DataCase, async: true

  alias ArchiDep.Events.Store.EventReference
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Support.EventsFactory
  alias Ecto.Changeset
  alias Ecto.UUID

  # Pinned instant passed explicitly to `new/3` so every built event has a
  # deterministic `occurred_at`.
  @now ~U[2024-03-15 10:30:00.000000Z]

  describe "new/3" do
    test "build a root event from data, metadata and an explicit occurred-at" do
      data = %{"thing" => "happened", "count" => 3}
      meta = %{"actor" => "tester"}

      changeset = StoredEvent.new(data, meta, occurred_at: @now)

      assert %Changeset{valid?: true} = changeset

      event = Changeset.apply_changes(changeset)

      # A root event is its own cause: causation and correlation IDs both equal
      # the freshly generated event ID.
      assert %StoredEvent{id: id} = event
      assert id != nil
      assert event == expected_event(id, data: data, meta: meta)
    end

    test "a caused event inherits its cause's causation and correlation IDs" do
      data = %{"order" => "placed"}

      # A distinct correlation ID on the cause proves the correlation propagates
      # from the cause rather than defaulting to the new event's own ID.
      cause =
        EventsFactory.build(:stored_event,
          causation_id: UUID.generate(),
          correlation_id: UUID.generate()
        )

      event =
        data
        |> StoredEvent.new(%{}, occurred_at: @now, caused_by: cause)
        |> Changeset.apply_changes()

      assert %StoredEvent{id: id} = event
      assert id != cause.id

      assert event ==
               expected_event(id,
                 data: data,
                 causation_id: cause.id,
                 correlation_id: cause.correlation_id
               )
    end

    test "an event reference can be the cause" do
      data = %{"link" => "clicked"}
      cause = EventsFactory.build(:event_reference)

      event =
        data
        |> StoredEvent.new(%{}, occurred_at: @now, caused_by: cause)
        |> Changeset.apply_changes()

      assert %StoredEvent{id: id} = event

      assert event ==
               expected_event(id,
                 data: data,
                 causation_id: cause.id,
                 correlation_id: cause.correlation_id
               )
    end
  end

  describe "stream/4" do
    test "set the stream, version and type" do
      data = %{"class" => "created"}
      stream = "course:classes:#{UUID.generate()}"

      event =
        data
        |> StoredEvent.new(%{}, occurred_at: @now)
        |> StoredEvent.stream(stream, 3, "archidep/course/class-created")
        |> Changeset.apply_changes()

      assert %StoredEvent{id: id} = event

      assert event ==
               expected_event(id,
                 data: data,
                 stream: stream,
                 version: 3,
                 type: "archidep/course/class-created"
               )
    end

    test "the version must be greater than or equal to 1" do
      changeset =
        %{"class" => "created"}
        |> StoredEvent.new(%{}, occurred_at: @now)
        |> StoredEvent.stream(
          "course:classes:#{UUID.generate()}",
          0,
          "archidep/course/class-created"
        )

      assert errors_on(changeset) == %{version: ["must be greater than or equal to 1"]}
    end
  end

  describe "initiated_by/2" do
    test "set the initiator" do
      data = %{"logged" => "in"}
      initiator = "accounts:user-accounts:#{UUID.generate()}"

      event =
        data
        |> StoredEvent.new(%{}, occurred_at: @now)
        |> StoredEvent.initiated_by(initiator)
        |> Changeset.apply_changes()

      assert %StoredEvent{id: id} = event
      assert event == expected_event(id, data: data, initiator: initiator)
    end
  end

  describe "to_insert_data/1" do
    test "extract the database-insertable fields, dropping the virtual entity" do
      event = EventsFactory.build(:stored_event, entity: %{ignored: true})

      assert StoredEvent.to_insert_data(event) == %{
               id: event.id,
               stream: event.stream,
               version: event.version,
               type: event.type,
               data: event.data,
               meta: event.meta,
               initiator: event.initiator,
               causation_id: event.causation_id,
               correlation_id: event.correlation_id,
               occurred_at: event.occurred_at
             }
    end
  end

  describe "to_reference/1" do
    test "build an event reference carrying the causation chain IDs" do
      event = EventsFactory.build(:stored_event)

      assert StoredEvent.to_reference(event) == %EventReference{
               id: event.id,
               causation_id: event.causation_id,
               correlation_id: event.correlation_id
             }
    end
  end

  describe "fetch_event/1" do
    test "fetch a stored event by ID" do
      event = EventsFactory.insert(:stored_event, occurred_at: @now)

      assert StoredEvent.fetch_event(event.id) == {:ok, event}
    end

    test "an unknown ID is reported as not found" do
      assert StoredEvent.fetch_event(UUID.generate()) == {:error, :event_not_found}
    end
  end

  # The full `%StoredEvent{}` that `new/3` (plus optional `stream/4` /
  # `initiated_by/2`) is expected to produce, so every test asserts the whole
  # struct by equality rather than a subset of fields. Only the structurally
  # determined fields are defaulted: `id`/`causation_id`/`correlation_id` to the
  # generated event ID (a root event is its own cause) and `occurred_at` to the
  # pinned `@now`. Each test supplies its own `data` (and any other field it
  # exercises) through `overrides`, so no test is coupled to a shared payload.
  defp expected_event(id, overrides) do
    defaults = [
      id: id,
      stream: nil,
      version: nil,
      type: nil,
      data: %{},
      meta: %{},
      initiator: nil,
      causation_id: id,
      correlation_id: id,
      occurred_at: @now,
      entity: nil
    ]

    struct!(StoredEvent, Keyword.merge(defaults, overrides))
  end
end
