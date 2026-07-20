defmodule ArchiDep.Course.ReadClassesTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox
  alias ArchiDep.Clock
  alias ArchiDep.Course.Behaviour
  alias ArchiDep.Course.Context
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
      refresh_classes: protect({Context, :refresh_classes, 2}, Behaviour)
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

      assert list_classes.(auth) == [
               nil_end,
               late_end,
               mid_end_newer,
               mid_end_older_a,
               mid_end_older_b,
               inactive
             ]

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

      assert list_active_classes.(auth) == [both_nil, wide, starts_today, ends_today]

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

      assert fetch_class.(auth, class.id) == {:ok, class}

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
      :ok = PubSub.publish_class_created(created)

      assert_receive {:class_created, ^created}

      assert_no_stored_events!()
    end
  end

  describe "refresh_classes/2" do
    test "adds a created class and re-sorts the list", %{refresh_classes: refresh_classes} do
      existing =
        CourseFactory.build(:class, active: true, start_date: nil, end_date: ~D[2026-06-30])

      created =
        CourseFactory.build(:class, active: true, start_date: nil, end_date: ~D[2026-12-31])

      assert refresh_classes.([existing], {:class_created, created}) == {:ok, [created, existing]}

      assert_no_stored_events!()
    end

    test "reconciles only the matching class from a class-updated message", %{
      refresh_classes: refresh_classes
    } do
      %Class{} =
        target =
        CourseFactory.build(:class, active: true, start_date: nil, end_date: ~D[2026-06-30])

      %Class{} =
        other =
        CourseFactory.build(:class, active: true, start_date: nil, end_date: ~D[2026-12-31])

      updated = %Class{target | name: "Renamed", version: target.version + 1}
      event = ClassUpdated.new(updated)
      reference = EventsFactory.build(:event_reference, version: updated.version)

      # `other` keeps its later end date, so it sorts ahead of the refreshed
      # target and must pass through unchanged.
      assert refresh_classes.([target, other], {:class_updated, event, reference}) ==
               {:ok, [other, Class.refresh!(target, event, reference)]}

      assert_no_stored_events!()
    end

    test "reconciles only the matching class from an expected-server-properties message", %{
      refresh_classes: refresh_classes
    } do
      %Class{} =
        target =
        CourseFactory.build(:class, active: true, start_date: nil, end_date: ~D[2026-06-30])

      %Class{} =
        other =
        CourseFactory.build(:class, active: true, start_date: nil, end_date: ~D[2026-12-31])

      updated = %Class{target | version: target.version + 1}
      event = ClassExpectedServerPropertiesUpdated.new(target.expected_server_properties, updated)
      reference = EventsFactory.build(:event_reference, version: updated.version)

      assert refresh_classes.([target, other], {:class_updated, event, reference}) ==
               {:ok, [other, Class.refresh!(target, event, reference)]}

      assert_no_stored_events!()
    end

    test "removes a deleted class and re-sorts the list", %{refresh_classes: refresh_classes} do
      keeper =
        CourseFactory.build(:class, active: true, start_date: nil, end_date: ~D[2026-06-30])

      victim =
        CourseFactory.build(:class, active: true, start_date: nil, end_date: ~D[2026-12-31])

      assert refresh_classes.([victim, keeper], {:class_deleted, victim}) == {:ok, [keeper]}

      assert_no_stored_events!()
    end

    test "ignores a message it does not handle", %{refresh_classes: refresh_classes} do
      %Class{} = class = CourseFactory.build(:class)

      assert refresh_classes.([class], {:students_imported, class}) == :ignore
      assert refresh_classes.([class], :unrelated) == :ignore

      assert_no_stored_events!()
    end
  end
end
