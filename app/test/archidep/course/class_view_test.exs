defmodule ArchiDep.Course.ClassViewTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.CourseFactory
  alias ArchiDep.Course.ClassView
  alias ArchiDep.Course.Events.ClassExpectedServerPropertiesUpdated
  alias ArchiDep.Course.Events.ClassUpdated
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Support.EventsFactory

  # A fixed instant keeps the persisted fixtures deterministic.
  @now ~U[2024-01-01 08:00:00.000000Z]

  # A later instant for the broadcast payloads a refresh applies, distinct from
  # the persisted fixtures' timestamps.
  @later ~U[2024-06-01 12:00:00.000000Z]

  describe "refresh!/3" do
    test "merges an incoming class-updated event one version ahead into the cached view" do
      class = insert(:class, now: @now)
      {:ok, aggregate} = Class.fetch_class(class.id)
      cached = ClassView.from(aggregate)

      # The event diverges from the persisted row on every asserted field and the
      # envelope carries the next version, so the assertion can only pass if the
      # in-memory merge ran: the catch-all fallback would re-fetch and return the
      # persisted values instead. The envelope's `occurred_at` becomes the
      # read-view's `updated_at`.
      event =
        ClassUpdated.new(%{
          aggregate
          | name: "Renamed class",
            start_date: ~D[2024-02-01],
            end_date: ~D[2024-11-30],
            active: not aggregate.active,
            servers_enabled: not aggregate.servers_enabled,
            teacher_ssh_public_keys: ["ssh-ed25519 AAAAsentinel comment"]
        })

      assert ClassView.refresh!(
               cached,
               event,
               EventsFactory.build(:event_reference,
                 version: cached.version + 1,
                 occurred_at: @later
               )
             ) == %{
               cached
               | name: "Renamed class",
                 start_date: ~D[2024-02-01],
                 end_date: ~D[2024-11-30],
                 active: not aggregate.active,
                 servers_enabled: not aggregate.servers_enabled,
                 teacher_ssh_public_keys: ["ssh-ed25519 AAAAsentinel comment"],
                 version: cached.version + 1,
                 updated_at: @later
             }
    end

    test "merges an incoming expected-server-properties event one version ahead" do
      class = insert(:class, now: @now)
      {:ok, aggregate} = Class.fetch_class(class.id)
      cached = ClassView.from(aggregate)

      event =
        ClassExpectedServerPropertiesUpdated.new(
          %{aggregate.expected_server_properties | hostname: "sentinel-host"},
          aggregate
        )

      assert ClassView.refresh!(
               cached,
               event,
               EventsFactory.build(:event_reference,
                 version: cached.version + 1,
                 occurred_at: @later
               )
             ) == %{
               cached
               | expected_server_properties: %{
                   cached.expected_server_properties
                   | hostname: "sentinel-host"
                 },
                 version: cached.version + 1,
                 updated_at: @later
             }
    end

    test "ignores a class event at or below the cached version" do
      class = insert(:class, now: @now)
      {:ok, aggregate} = Class.fetch_class(class.id)
      cached = ClassView.from(aggregate)

      event = ClassUpdated.new(%{aggregate | name: "Ignored"})

      assert ClassView.refresh!(
               cached,
               event,
               EventsFactory.build(:event_reference, version: cached.version, occurred_at: @later)
             ) == cached
    end

    test "re-fetches from the database when the incoming version skips ahead" do
      class = insert(:class, now: @now)
      {:ok, aggregate} = Class.fetch_class(class.id)
      cached = ClassView.from(aggregate)

      {1, nil} =
        Repo.update_all(
          from(c in Class, where: c.id == ^cached.id),
          set: [name: "Persisted rename", version: cached.version + 2, updated_at: @later]
        )

      {:ok, refreshed} = Class.fetch_class(cached.id)
      fresh = ClassView.from(refreshed)
      refute fresh == cached

      event = ClassUpdated.new(%{aggregate | name: "Ignored"})

      assert ClassView.refresh!(
               cached,
               event,
               EventsFactory.build(:event_reference,
                 version: cached.version + 2,
                 occurred_at: @later
               )
             ) == fresh
    end
  end
end
