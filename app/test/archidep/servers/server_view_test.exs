defmodule ArchiDep.Servers.ServerViewTest do
  use ArchiDep.Support.DataCase, async: true

  alias ArchiDep.Servers.Events.ServerFactsGathered
  alias ArchiDep.Servers.Events.ServerOpenPortsChecked
  alias ArchiDep.Servers.Events.ServerSetUp
  alias ArchiDep.Servers.Events.ServerUpdated
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDep.Servers.ServerView
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.ServersTestHelpers

  @now ~U[2024-03-15 10:30:00.000000Z]

  # A later instant for the broadcast payloads a refresh applies, distinct from
  # the persisted fixtures' timestamps.
  @later ~U[2024-06-01 12:00:00.000000Z]

  describe "refresh!/3" do
    test "merges a ServerUpdated event one version ahead into the cached view" do
      %{owner: owner, class: class} = ServersTestHelpers.register_group_member(@now)
      server = ServersTestHelpers.insert_server(owner.id, class.id)
      view = ServerView.from(server)

      new_ip_address = %Postgrex.INET{address: {203, 0, 113, 42}, netmask: nil}

      new_expected_properties = %{
        server.expected_properties
        | hostname: "renamed.example.com",
          cpus: 99
      }

      modified = %{
        server
        | name: "Renamed server",
          ip_address: new_ip_address,
          username: "renameduser",
          app_username: "renamedapp",
          ssh_port: 2222,
          ssh_host_key_fingerprints: "renamed fingerprints",
          active: not server.active,
          expected_properties: new_expected_properties
      }

      event = ServerUpdated.new(modified)

      # The event carries the next version and diverges from the persisted row
      # on every asserted field, so the assertion can only pass if the in-memory
      # merge ran: the catch-all fallback would re-fetch and return the
      # persisted values instead.
      reference =
        EventsFactory.build(:event_reference, version: view.version + 1, occurred_at: @later)

      assert ServerView.refresh!(view, event, reference) == %{
               view
               | name: "Renamed server",
                 ip_address: new_ip_address,
                 username: "renameduser",
                 app_username: "renamedapp",
                 ssh_port: 2222,
                 ssh_host_key_fingerprints: "renamed fingerprints",
                 active: modified.active,
                 expected_properties: new_expected_properties,
                 version: view.version + 1
             }
    end

    test "bumps only the version for a ServerFactsGathered event (unrendered on the view)" do
      %{owner: owner, class: class} = ServersTestHelpers.register_group_member(@now)
      server = ServersTestHelpers.insert_server(owner.id, class.id, last_known_properties: nil)
      view = ServerView.from(server)

      gathered_properties = %ServerProperties{
        id: Ecto.UUID.generate(),
        hostname: "gathered.example.com",
        machine_id: "gathered-machine",
        cpus: 4,
        cores: 8,
        vcpus: 16,
        memory: 2048,
        swap: 1024,
        system: "Linux",
        architecture: "x86_64",
        os_family: "Debian",
        distribution: "Ubuntu",
        distribution_release: "jammy",
        distribution_version: "22.04"
      }

      event = ServerFactsGathered.new(%{server | last_known_properties: gathered_properties})

      # Diverge the persisted row so a catch-all re-fetch would change `name`;
      # the view carries no last-known properties, so the merge must leave every
      # field but `version` untouched.
      {1, nil} =
        Repo.update_all(
          from(s in Server, where: s.id == ^server.id),
          set: [name: "Persisted rename", version: view.version + 1, updated_at: @later]
        )

      reference =
        EventsFactory.build(:event_reference, version: view.version + 1, occurred_at: @later)

      assert ServerView.refresh!(view, event, reference) == %{view | version: view.version + 1}
    end

    test "stamps set_up_at from a ServerSetUp event's timestamp" do
      %{owner: owner, class: class} = ServersTestHelpers.register_group_member(@now)
      server = ServersTestHelpers.insert_server(owner.id, class.id, set_up_at: @now)
      view = ServerView.from(server)

      event = ServerSetUp.new(server)

      reference =
        EventsFactory.build(:event_reference, version: view.version + 1, occurred_at: @later)

      assert ServerView.refresh!(view, event, reference) == %{
               view
               | set_up_at: @later,
                 version: view.version + 1
             }
    end

    test "bumps only the version for a ServerOpenPortsChecked event (unrendered on the view)" do
      %{owner: owner, class: class} = ServersTestHelpers.register_group_member(@now)

      server =
        ServersTestHelpers.insert_server(owner.id, class.id, open_ports_checked_at: @now)

      view = ServerView.from(server)

      event = ServerOpenPortsChecked.new(server, [22, 80, 443])

      {1, nil} =
        Repo.update_all(
          from(s in Server, where: s.id == ^server.id),
          set: [name: "Persisted rename", version: view.version + 1, updated_at: @later]
        )

      reference =
        EventsFactory.build(:event_reference, version: view.version + 1, occurred_at: @later)

      assert ServerView.refresh!(view, event, reference) == %{view | version: view.version + 1}
    end

    test "ignores an event at or below the cached version" do
      %{owner: owner, class: class} = ServersTestHelpers.register_group_member(@now)
      server = ServersTestHelpers.insert_server(owner.id, class.id)
      view = ServerView.from(server)

      event = ServerUpdated.new(%{server | name: "Ignored"})

      reference =
        EventsFactory.build(:event_reference, version: view.version, occurred_at: @later)

      assert ServerView.refresh!(view, event, reference) == view
    end

    test "re-fetches from the database when the incoming version skips ahead" do
      %{owner: owner, class: class} = ServersTestHelpers.register_group_member(@now)
      server = ServersTestHelpers.insert_server(owner.id, class.id)
      view = ServerView.from(server)

      {1, nil} =
        Repo.update_all(
          from(s in Server, where: s.id == ^server.id),
          set: [name: "Persisted rename", version: view.version + 2, updated_at: @later]
        )

      {:ok, fresh} = Server.fetch_server(server.id)
      fresh_view = ServerView.from(fresh)
      refute fresh_view == view

      event = ServerUpdated.new(%{server | name: "Ignored"})

      reference =
        EventsFactory.build(:event_reference, version: view.version + 2, occurred_at: @later)

      assert ServerView.refresh!(view, event, reference) == fresh_view
    end
  end
end
