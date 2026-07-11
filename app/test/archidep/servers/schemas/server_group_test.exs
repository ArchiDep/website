defmodule ArchiDep.Servers.Schemas.ServerGroupTest do
  use ArchiDep.Support.DataCase, async: true

  alias ArchiDep.Course.Events.ClassExpectedServerPropertiesUpdated
  alias ArchiDep.Course.Events.ClassUpdated
  alias ArchiDep.Events.Store.EventReference
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Support.CourseFactory
  alias Ecto.UUID

  @now ~U[2024-03-15 10:30:00.000000Z]

  # A later instant for the broadcast payloads a refresh applies, distinct from
  # the persisted fixtures' timestamps.
  @later ~U[2024-06-01 12:00:00.000000Z]

  describe "fetch_server_group/1" do
    test "fetches a server group with its expected server properties by id" do
      class = CourseFactory.insert(:class, now: @now)

      expected =
        ServerGroup
        |> Repo.get!(class.id)
        |> Repo.preload(:expected_server_properties)

      assert ServerGroup.fetch_server_group(class.id) == {:ok, expected}
    end

    test "returns an error when no server group has the given id" do
      assert ServerGroup.fetch_server_group(UUID.generate()) ==
               {:error, :server_group_not_found}
    end
  end

  describe "refresh!/3" do
    test "merges an incoming class-updated event one version ahead into the cached group" do
      class = CourseFactory.insert(:class, now: @now)
      {:ok, group} = ServerGroup.fetch_server_group(class.id)

      # The event diverges from the persisted row on every merged field and the
      # envelope carries the next version, so the assertion can only pass if the
      # in-memory merge ran: the catch-all fallback would re-fetch and return
      # the persisted values instead. The producer's `teacher_ssh_public_keys`
      # maps onto the read-view's `ssh_public_keys_to_install`.
      event =
        ClassUpdated.new(%{
          class
          | name: "Renamed group",
            start_date: ~D[2024-02-01],
            end_date: ~D[2024-11-30],
            active: not class.active,
            servers_enabled: not class.servers_enabled,
            teacher_ssh_public_keys: ["ssh-ed25519 AAAAsentinel comment"]
        })

      assert ServerGroup.refresh!(group, event, reference(group.version + 1, @later)) == %{
               group
               | name: "Renamed group",
                 start_date: ~D[2024-02-01],
                 end_date: ~D[2024-11-30],
                 active: not class.active,
                 servers_enabled: not class.servers_enabled,
                 ssh_public_keys_to_install: ["ssh-ed25519 AAAAsentinel comment"],
                 version: group.version + 1,
                 updated_at: @later
             }
    end

    test "merges an incoming expected-server-properties event one version ahead" do
      class = CourseFactory.insert(:class, now: @now)
      {:ok, group} = ServerGroup.fetch_server_group(class.id)

      props = group.expected_server_properties

      event = %ClassExpectedServerPropertiesUpdated{
        class: %{id: class.id, name: class.name},
        hostname: "sentinel-host",
        machine_id: props.machine_id,
        cpus: props.cpus,
        cores: props.cores,
        vcpus: props.vcpus,
        memory: props.memory,
        swap: props.swap,
        system: props.system,
        architecture: props.architecture,
        os_family: props.os_family,
        distribution: props.distribution,
        distribution_release: props.distribution_release,
        distribution_version: props.distribution_version
      }

      assert ServerGroup.refresh!(group, event, reference(group.version + 1, @later)) == %{
               group
               | expected_server_properties: %{props | hostname: "sentinel-host"},
                 version: group.version + 1,
                 updated_at: @later
             }
    end

    test "ignores a class event at or below the cached version" do
      class = CourseFactory.insert(:class, now: @now)
      {:ok, group} = ServerGroup.fetch_server_group(class.id)

      event = ClassUpdated.new(%{class | name: "Ignored"})

      assert ServerGroup.refresh!(group, event, reference(group.version, @later)) == group
    end

    test "re-fetches from the database when the incoming version skips ahead" do
      class = CourseFactory.insert(:class, now: @now)
      {:ok, group} = ServerGroup.fetch_server_group(class.id)

      {1, nil} =
        Repo.update_all(
          from(g in ServerGroup, where: g.id == ^group.id),
          set: [name: "Persisted rename", version: group.version + 2, updated_at: @later]
        )

      {:ok, fresh} = ServerGroup.fetch_server_group(group.id)
      refute fresh == group

      event = ClassUpdated.new(%{class | name: "Ignored"})

      assert ServerGroup.refresh!(group, event, reference(group.version + 2, @later)) == fresh
    end
  end

  defp reference(version, occurred_at),
    do: %EventReference{
      id: UUID.generate(),
      causation_id: UUID.generate(),
      correlation_id: UUID.generate(),
      version: version,
      occurred_at: occurred_at
    }
end
