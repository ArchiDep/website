defmodule ArchiDep.Servers.ServerTracking.ServersOrchestratorStoreTest do
  use ArchiDep.Support.DataCase, async: true

  alias ArchiDep.Servers.ServerTracking.ServersOrchestratorStore
  alias ArchiDep.Support.ServersTestHelpers
  alias Ecto.UUID

  setup do
    # The store decides activeness against wall-clock time, so the owner/class
    # active windows must cover the real current instant.
    %{owner: owner, class: class} = ServersTestHelpers.register_group_member(DateTime.utc_now())
    %{owner: owner, class: class}
  end

  describe "list_servers_to_track/0" do
    test "returns the active servers and excludes the inactive ones", %{
      owner: owner,
      class: class
    } do
      active1 = ServersTestHelpers.insert_server(owner.id, class.id, active: true)
      active2 = ServersTestHelpers.insert_server(owner.id, class.id, active: true)
      _inactive = ServersTestHelpers.insert_server(owner.id, class.id, active: false)

      # The active-server query is unordered (`distinct: true`, no `order_by`)
      # and loads a different association shape than `insert_server`, so the
      # store's contract here is *which* servers it selects; each server's full
      # content is pinned by the `Server.list_active_servers/1` tests.
      selected_ids = Enum.map(ServersOrchestratorStore.list_servers_to_track(), & &1.id)

      assert Enum.sort(selected_ids) == Enum.sort([active1.id, active2.id])
    end
  end

  describe "fetch_server_to_track/1" do
    test "returns an active server", %{owner: owner, class: class} do
      server = ServersTestHelpers.insert_server(owner.id, class.id, active: true)

      assert ServersOrchestratorStore.fetch_server_to_track(server.id) == {:ok, server}
    end

    test "does not return an inactive server", %{owner: owner, class: class} do
      server = ServersTestHelpers.insert_server(owner.id, class.id, active: false)

      assert ServersOrchestratorStore.fetch_server_to_track(server.id) == :not_tracked
    end

    test "does not return an unknown server" do
      assert ServersOrchestratorStore.fetch_server_to_track(UUID.generate()) == :not_tracked
    end
  end
end
