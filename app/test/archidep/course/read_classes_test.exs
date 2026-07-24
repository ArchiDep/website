defmodule ArchiDep.Course.ReadClassesTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox
  alias ArchiDep.Clock
  alias ArchiDep.Course.Behaviour
  alias ArchiDep.Course.ClassView
  alias ArchiDep.Course.Context
  alias ArchiDep.Course.ContextMock
  alias ArchiDep.Course.Events.ClassCreated
  alias ArchiDep.Course.Events.ClassDeleted
  alias ArchiDep.Course.Events.ClassExpectedServerPropertiesUpdated
  alias ArchiDep.Course.Events.ClassUpdated
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Errors.UnauthorizedError
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.Factory

  # Pinned instant returned by the injected clock for the duration of each test.
  # `list_active_classes` derives "today" (2024-03-15) from it, so pinning it
  # makes the date-window filter deterministic (see docs/testing.md). Fixture
  # dates below are written as inline literals so each test's ordering and
  # windowing can be read against this instant locally.
  @now ~U[2024-03-15 10:30:00.000000Z]

  setup :verify_on_exit!

  setup do
    stub(Clock.Mock, :now, fn -> @now end)
    :ok
  end

  setup_all do
    %{
      list_classes: protect({Context, :list_classes, 1}, Behaviour),
      list_active_classes: protect({Context, :list_active_classes, 1}, Behaviour),
      fetch_class: protect({Context, :fetch_class, 2}, Behaviour),
      subscribe_classes: protect({Context, :subscribe_classes, 0}, Behaviour),
      refresh_classes: protect({Context, :refresh_classes, 3}, Behaviour),
      subscribe_class: protect({Context, :subscribe_class, 1}, Behaviour),
      refresh_class: protect({Context, :refresh_class, 2}, Behaviour)
    }
  end

  describe "list_classes/1" do
    test "list classes", %{
      list_classes: list_classes
    } do
      # `Class.list_classes/0` orders by `[desc: active, desc: end_date, desc:
      # created_at, asc: name]`. The fixtures below pin every one of those keys
      # so the expected order is unambiguous; they are inserted out of order to
      # prove the query sorts them rather than returning insertion order. Under
      # `desc`, PostgreSQL sorts NULLs first, so the active class with no end
      # date comes first. `created_at` is pinned (inline) only on the three
      # classes that tie on active+end date, where it decides the order; `name`
      # likewise only on the `mid_end_older_*` pair, which ties on every earlier
      # key. Everything else is left to the factory.
      inactive =
        CourseFactory.insert(:class, %{active: false, start_date: nil, end_date: ~D[2025-12-31]})

      mid_end_older_b =
        CourseFactory.insert(:class, %{
          name: "B",
          active: true,
          start_date: nil,
          end_date: ~D[2025-06-30],
          created_at: ~U[2023-01-01 00:00:00.000000Z]
        })

      nil_end =
        CourseFactory.insert(:class, %{active: true, start_date: nil, end_date: nil})

      mid_end_newer =
        CourseFactory.insert(:class, %{
          active: true,
          start_date: nil,
          end_date: ~D[2025-06-30],
          created_at: ~U[2023-06-01 00:00:00.000000Z]
        })

      late_end =
        CourseFactory.insert(:class, %{active: true, start_date: nil, end_date: ~D[2025-12-31]})

      mid_end_older_a =
        CourseFactory.insert(:class, %{
          name: "A",
          active: true,
          start_date: nil,
          end_date: ~D[2025-06-30],
          created_at: ~U[2023-01-01 00:00:00.000000Z]
        })

      auth = Factory.build(:authentication, root: true)

      assert list_classes.(auth) ==
               Enum.map(
                 [
                   nil_end,
                   late_end,
                   mid_end_newer,
                   mid_end_older_a,
                   mid_end_older_b,
                   inactive
                 ],
                 &ClassView.from/1
               )

      assert_no_stored_events!()
    end

    test "lists no classes", %{list_classes: list_classes} do
      auth = Factory.build(:authentication, root: true)

      assert list_classes.(auth) == []

      assert_no_stored_events!()
    end

    test "cannot list classes as a non-root user", %{list_classes: list_classes} do
      auth = Factory.build(:authentication, root: false)

      assert_raise UnauthorizedError, fn -> list_classes.(auth) end

      assert_no_stored_events!()
    end
  end

  describe "list_active_classes/1" do
    test "list currently active classes", %{
      list_active_classes: list_active_classes
    } do
      # A class is active when its `active` flag is set and today (`2024-03-15`,
      # derived from the pinned clock) falls within its `[start_date, end_date]`
      # window, with both bounds inclusive and a `nil` bound meaning "open". The
      # included classes are ordered by `[desc: end_date, desc: created_at, asc:
      # name]` (NULLs first under `desc`, so the open-ended class comes first).

      # Included. End dates are distinct, so they fix the order on their own
      # (names are auto-generated and irrelevant); the open-ended class sorts
      # first under `desc`.
      both_nil =
        CourseFactory.insert(:class, %{active: true, start_date: nil, end_date: nil})

      wide =
        CourseFactory.insert(:class, %{
          active: true,
          start_date: ~D[2024-01-01],
          end_date: ~D[2024-12-31]
        })

      starts_today =
        CourseFactory.insert(:class, %{
          active: true,
          start_date: ~D[2024-03-15],
          end_date: ~D[2024-06-30]
        })

      ends_today =
        CourseFactory.insert(:class, %{
          active: true,
          start_date: ~D[2024-02-01],
          end_date: ~D[2024-03-15]
        })

      # Excluded: inactive (in window), not yet started, and already ended.
      CourseFactory.insert(:class, %{
        active: false,
        start_date: ~D[2024-01-01],
        end_date: ~D[2024-12-31]
      })

      CourseFactory.insert(:class, %{
        active: true,
        start_date: ~D[2024-03-16],
        end_date: ~D[2024-12-31]
      })

      CourseFactory.insert(:class, %{
        active: true,
        start_date: ~D[2024-01-01],
        end_date: ~D[2024-03-14]
      })

      auth = Factory.build(:authentication, root: true)

      assert list_active_classes.(auth) ==
               Enum.map([both_nil, wide, starts_today, ends_today], &ClassView.from/1)

      assert_no_stored_events!()
    end

    test "a non-root user cannot list active classes", %{
      list_active_classes: list_active_classes
    } do
      auth = Factory.build(:authentication, root: false)

      assert_raise UnauthorizedError, fn -> list_active_classes.(auth) end

      assert_no_stored_events!()
    end
  end

  describe "fetch_class/2" do
    test "fetch a class", %{fetch_class: fetch_class} do
      class = CourseFactory.insert(:class)
      auth = Factory.build(:authentication, root: true)

      assert fetch_class.(auth, class.id) == {:ok, ClassView.from(class)}

      assert_no_stored_events!()
    end

    test "a class that does not exist is reported as not found", %{fetch_class: fetch_class} do
      auth = Factory.build(:authentication, root: true)

      assert fetch_class.(auth, Ecto.UUID.generate()) == {:error, :class_not_found}

      assert_no_stored_events!()
    end

    test "a non-root user gets not found rather than access denied for an existing class", %{
      fetch_class: fetch_class
    } do
      # `fetch_class` masks the authorization failure as `:class_not_found` so
      # that it does not leak the existence of a class the caller may not see —
      # a non-root caller cannot tell an existing class from a missing one.
      class = CourseFactory.insert(:class)
      auth = Factory.build(:authentication, root: false)

      assert fetch_class.(auth, class.id) == {:error, :class_not_found}

      assert_no_stored_events!()
    end
  end

  describe "subscribe_classes/0" do
    test "subscribes the calling process to the classes topic", %{
      subscribe_classes: subscribe_classes
    } do
      assert subscribe_classes.() == :ok

      %Class{} = created = CourseFactory.build(:class)
      event = ClassCreated.new(created)
      reference = EventsFactory.build(:event_reference, version: created.version)
      :ok = PubSub.publish_class_created(event, reference)

      assert_receive {:class_created, ^event, ^reference}

      assert_no_stored_events!()
    end
  end

  describe "refresh_classes/3" do
    test "fetches a created class and inserts it in sorted order", %{
      refresh_classes: refresh_classes
    } do
      auth = Factory.build(:authentication)

      existing =
        CourseFactory.build(:class_view, active: true, start_date: nil, end_date: ~D[2026-06-30])

      %Class{} =
        created_class =
        CourseFactory.build(:class, active: true, start_date: nil, end_date: ~D[2026-12-31])

      created = ClassView.from(created_class)
      created_id = created.id
      reference = EventsFactory.build(:event_reference)

      # The created broadcast carries only the curated event, so the read-model
      # fetches the full view through the context boundary on first sighting.
      expect(ContextMock, :fetch_class, fn ^auth, ^created_id -> {:ok, created} end)

      assert refresh_classes.(
               auth,
               [existing],
               {:class_created, ClassCreated.new(created_class), reference}
             ) == {:ok, [created, existing]}

      assert_no_stored_events!()
    end

    test "keeps the list unchanged when the created class can no longer be fetched", %{
      refresh_classes: refresh_classes
    } do
      auth = Factory.build(:authentication)

      existing =
        CourseFactory.build(:class_view, active: true, start_date: nil, end_date: ~D[2026-06-30])

      %Class{} =
        created_class =
        CourseFactory.build(:class, active: true, start_date: nil, end_date: ~D[2026-12-31])

      created_id = created_class.id
      reference = EventsFactory.build(:event_reference)

      expect(ContextMock, :fetch_class, fn ^auth, ^created_id -> {:error, :class_not_found} end)

      assert refresh_classes.(
               auth,
               [existing],
               {:class_created, ClassCreated.new(created_class), reference}
             ) == {:ok, [existing]}

      assert_no_stored_events!()
    end

    test "reconciles only the matching class from a class-updated message", %{
      refresh_classes: refresh_classes
    } do
      auth = Factory.build(:authentication)

      %Class{} =
        target_class =
        CourseFactory.build(:class, active: true, start_date: nil, end_date: ~D[2026-06-30])

      target = ClassView.from(target_class)

      other =
        CourseFactory.build(:class_view, active: true, start_date: nil, end_date: ~D[2026-12-31])

      updated = %Class{target_class | name: "Renamed", version: target_class.version + 1}
      event = ClassUpdated.new(updated)
      reference = EventsFactory.build(:event_reference, version: updated.version)

      # `other` keeps its later end date, so it sorts ahead of the refreshed
      # target and must pass through unchanged.
      assert refresh_classes.(auth, [target, other], {:class_updated, event, reference}) ==
               {:ok, [other, ClassView.refresh!(target, event, reference)]}

      assert_no_stored_events!()
    end

    test "reconciles only the matching class from an expected-server-properties message", %{
      refresh_classes: refresh_classes
    } do
      auth = Factory.build(:authentication)

      %Class{} =
        target_class =
        CourseFactory.build(:class, active: true, start_date: nil, end_date: ~D[2026-06-30])

      target = ClassView.from(target_class)

      other =
        CourseFactory.build(:class_view, active: true, start_date: nil, end_date: ~D[2026-12-31])

      updated = %Class{target_class | version: target_class.version + 1}

      event =
        ClassExpectedServerPropertiesUpdated.new(target_class.expected_server_properties, updated)

      reference = EventsFactory.build(:event_reference, version: updated.version)

      assert refresh_classes.(auth, [target, other], {:class_updated, event, reference}) ==
               {:ok, [other, ClassView.refresh!(target, event, reference)]}

      assert_no_stored_events!()
    end

    test "removes a deleted class and re-sorts the list", %{refresh_classes: refresh_classes} do
      auth = Factory.build(:authentication)

      keeper =
        CourseFactory.build(:class_view, active: true, start_date: nil, end_date: ~D[2026-06-30])

      %Class{} =
        victim_class =
        CourseFactory.build(:class, active: true, start_date: nil, end_date: ~D[2026-12-31])

      victim = ClassView.from(victim_class)
      reference = EventsFactory.build(:event_reference)

      # The deleted class arrives as the curated event on the broadcast; the
      # cached list holds its `ClassView`.
      assert refresh_classes.(
               auth,
               [victim, keeper],
               {:class_deleted, ClassDeleted.new(victim_class), reference}
             ) == {:ok, [keeper]}

      assert_no_stored_events!()
    end

    test "ignores a message it does not handle", %{refresh_classes: refresh_classes} do
      auth = Factory.build(:authentication)
      class = CourseFactory.build(:class_view)

      assert refresh_classes.(auth, [class], {:students_imported, class}) == :ignore
      assert refresh_classes.(auth, [class], :unrelated) == :ignore

      assert_no_stored_events!()
    end
  end

  describe "subscribe_class/1" do
    test "subscribes the calling process to the class's topic", %{
      subscribe_class: subscribe_class
    } do
      %Class{} = class_aggregate = CourseFactory.insert(:class, now: @now)
      class = ClassView.from(class_aggregate)

      assert subscribe_class.(class) == :ok

      updated = %Class{class_aggregate | name: "Renamed", version: class_aggregate.version + 1}
      event = ClassUpdated.new(updated)
      reference = EventsFactory.build(:event_reference, version: updated.version)
      :ok = PubSub.publish_class_updated(updated, event, reference)

      assert_receive {:class_updated, ^event, ^reference}

      assert_no_stored_events!()
    end
  end

  describe "refresh_class/2" do
    test "reconciles the class from a class-updated message", %{refresh_class: refresh_class} do
      %Class{} = class_aggregate = CourseFactory.build(:class)
      class = ClassView.from(class_aggregate)

      updated = %Class{class_aggregate | name: "Renamed", version: class_aggregate.version + 1}
      event = ClassUpdated.new(updated)
      reference = EventsFactory.build(:event_reference, version: updated.version)

      assert refresh_class.(class, {:class_updated, event, reference}) ==
               {:ok, ClassView.refresh!(class, event, reference)}

      assert_no_stored_events!()
    end

    test "reconciles the class from an expected-server-properties message", %{
      refresh_class: refresh_class
    } do
      %Class{} = class_aggregate = CourseFactory.build(:class)
      class = ClassView.from(class_aggregate)

      updated = %Class{class_aggregate | version: class_aggregate.version + 1}

      event =
        ClassExpectedServerPropertiesUpdated.new(
          class_aggregate.expected_server_properties,
          updated
        )

      reference = EventsFactory.build(:event_reference, version: updated.version)

      assert refresh_class.(class, {:class_updated, event, reference}) ==
               {:ok, ClassView.refresh!(class, event, reference)}

      assert_no_stored_events!()
    end

    test "ignores a class-updated message for another class", %{refresh_class: refresh_class} do
      class = CourseFactory.build(:class_view)
      %Class{} = other = CourseFactory.build(:class)

      event = ClassUpdated.new(%Class{other | version: other.version + 1})
      reference = EventsFactory.build(:event_reference, version: other.version + 1)

      assert refresh_class.(class, {:class_updated, event, reference}) == :ignore

      assert_no_stored_events!()
    end

    test "ignores a message it does not handle", %{refresh_class: refresh_class} do
      class = CourseFactory.build(:class_view)

      assert refresh_class.(class, {:class_deleted, class}) == :ignore
      assert refresh_class.(class, :unrelated) == :ignore

      assert_no_stored_events!()
    end
  end
end
