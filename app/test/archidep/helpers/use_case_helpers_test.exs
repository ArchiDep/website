defmodule ArchiDep.Helpers.UseCaseHelpersTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Course.Events.ClassCreated
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Helpers.UseCaseHelpers
  alias Ecto.Changeset
  alias Ecto.UUID

  # Pinned instant passed explicitly to `new/3` so every built event has a
  # deterministic `occurred_at`.
  @now ~U[2024-03-15 10:30:00.000000Z]

  describe "add_to_stream/2" do
    test "an event that declares no version is stamped with schema version 1" do
      id = UUID.generate()
      data = struct(ClassCreated, id: id)

      event =
        data
        |> StoredEvent.new(%{}, occurred_at: @now)
        |> UseCaseHelpers.add_to_stream(%{version: 4})
        |> Changeset.apply_changes()

      assert %StoredEvent{id: event_id} = event

      assert event ==
               expected_event(event_id,
                 data: data,
                 stream: "course:classes:#{id}",
                 version: 4,
                 schema_version: 1,
                 type: "archidep/course/class-created"
               )
    end
  end

  # The full `%StoredEvent{}` that `new/3 |> add_to_stream/2` is expected to
  # produce, so the test asserts the whole struct by equality rather than a
  # subset of fields. The causation and correlation IDs both default to the
  # generated event ID (a root event is its own cause) and `occurred_at` to the
  # pinned `@now`; the test supplies the fields it exercises through
  # `overrides`.
  defp expected_event(id, overrides) do
    defaults = [
      id: id,
      stream: nil,
      version: nil,
      schema_version: nil,
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
