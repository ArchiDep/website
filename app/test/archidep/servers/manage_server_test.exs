defmodule ArchiDep.Servers.ManageServerTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDep.Servers.ServerTracking.ServerManagerClientMock
  alias ArchiDep.Servers.UseCases.ManageServer
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.Factory
  alias ArchiDep.Support.ServersTestHelpers
  alias Ecto.UUID

  @past ~U[2023-09-15 09:42:17.000000Z]

  @affected_tables [Server, ServerProperties, StoredEvent]

  setup :verify_on_exit!

  describe "retry_connecting/2" do
    test "retries connecting to a server" do
      {auth, server} = root_owner_and_server()
      previous_counts = count_rows(@affected_tables)

      expect(ServerManagerClientMock, :retry_connecting, fn ^server -> :ok end)

      assert ManageServer.retry_connecting(auth, server.id) == :ok

      assert_no_side_effects(previous_counts)
    end

    test "a non-root owner retries connecting to their own server" do
      {auth, server} = group_member_owner_and_server()
      previous_counts = count_rows(@affected_tables)

      expect(ServerManagerClientMock, :retry_connecting, fn ^server -> :ok end)

      assert ManageServer.retry_connecting(auth, server.id) == :ok

      assert_no_side_effects(previous_counts)
    end

    test "rejects a malformed server ID" do
      {auth, _server} = root_owner_and_server()
      previous_counts = count_rows(@affected_tables)

      assert ManageServer.retry_connecting(auth, "not-a-uuid") == {:error, :server_not_found}

      assert_no_side_effects(previous_counts)
    end

    test "rejects an unknown server ID" do
      {auth, _server} = root_owner_and_server()
      previous_counts = count_rows(@affected_tables)

      assert ManageServer.retry_connecting(auth, UUID.generate()) == {:error, :server_not_found}

      assert_no_side_effects(previous_counts)
    end

    test "masks an unauthorized caller as a missing server" do
      {_auth, server} = root_owner_and_server()
      other = Factory.build(:authentication, principal_id: UUID.generate(), root: false)
      previous_counts = count_rows(@affected_tables)

      assert ManageServer.retry_connecting(other, server.id) == {:error, :server_not_found}

      assert_no_side_effects(previous_counts)
    end
  end

  describe "retry_ansible_playbook/3" do
    test "retries an Ansible playbook on a server" do
      {auth, server} = root_owner_and_server()
      previous_counts = count_rows(@affected_tables)

      expect(ServerManagerClientMock, :retry_ansible_playbook, fn ^server, "setup" -> :ok end)

      assert ManageServer.retry_ansible_playbook(auth, server.id, "setup") == :ok

      assert_no_side_effects(previous_counts)
    end

    test "passes through a server-not-connected error" do
      {auth, server} = root_owner_and_server()
      previous_counts = count_rows(@affected_tables)

      expect(ServerManagerClientMock, :retry_ansible_playbook, fn ^server, "setup" ->
        {:error, :server_not_connected}
      end)

      assert ManageServer.retry_ansible_playbook(auth, server.id, "setup") ==
               {:error, :server_not_connected}

      assert_no_side_effects(previous_counts)
    end

    test "passes through a server-busy error" do
      {auth, server} = root_owner_and_server()
      previous_counts = count_rows(@affected_tables)

      expect(ServerManagerClientMock, :retry_ansible_playbook, fn ^server, "setup" ->
        {:error, :server_busy}
      end)

      assert ManageServer.retry_ansible_playbook(auth, server.id, "setup") ==
               {:error, :server_busy}

      assert_no_side_effects(previous_counts)
    end

    test "rejects a malformed server ID" do
      {auth, _server} = root_owner_and_server()
      previous_counts = count_rows(@affected_tables)

      assert ManageServer.retry_ansible_playbook(auth, "not-a-uuid", "setup") ==
               {:error, :server_not_found}

      assert_no_side_effects(previous_counts)
    end

    test "masks an unauthorized caller as a missing server" do
      {_auth, server} = root_owner_and_server()
      other = Factory.build(:authentication, principal_id: UUID.generate(), root: false)
      previous_counts = count_rows(@affected_tables)

      assert ManageServer.retry_ansible_playbook(other, server.id, "setup") ==
               {:error, :server_not_found}

      assert_no_side_effects(previous_counts)
    end
  end

  describe "retry_checking_open_ports/2" do
    test "retries checking open ports on a server" do
      {auth, server} = root_owner_and_server()
      previous_counts = count_rows(@affected_tables)

      expect(ServerManagerClientMock, :retry_checking_open_ports, fn ^server -> :ok end)

      assert ManageServer.retry_checking_open_ports(auth, server.id) == :ok

      assert_no_side_effects(previous_counts)
    end

    test "a non-root owner retries checking open ports on their own server" do
      {auth, server} = group_member_owner_and_server()
      previous_counts = count_rows(@affected_tables)

      expect(ServerManagerClientMock, :retry_checking_open_ports, fn ^server -> :ok end)

      assert ManageServer.retry_checking_open_ports(auth, server.id) == :ok

      assert_no_side_effects(previous_counts)
    end

    test "passes through a server-not-connected error" do
      {auth, server} = root_owner_and_server()
      previous_counts = count_rows(@affected_tables)

      expect(ServerManagerClientMock, :retry_checking_open_ports, fn ^server ->
        {:error, :server_not_connected}
      end)

      assert ManageServer.retry_checking_open_ports(auth, server.id) ==
               {:error, :server_not_connected}

      assert_no_side_effects(previous_counts)
    end

    test "passes through a server-busy error" do
      {auth, server} = root_owner_and_server()
      previous_counts = count_rows(@affected_tables)

      expect(ServerManagerClientMock, :retry_checking_open_ports, fn ^server ->
        {:error, :server_busy}
      end)

      assert ManageServer.retry_checking_open_ports(auth, server.id) == {:error, :server_busy}

      assert_no_side_effects(previous_counts)
    end

    test "rejects a malformed server ID" do
      {auth, _server} = root_owner_and_server()
      previous_counts = count_rows(@affected_tables)

      assert ManageServer.retry_checking_open_ports(auth, "not-a-uuid") ==
               {:error, :server_not_found}

      assert_no_side_effects(previous_counts)
    end

    test "masks an unauthorized caller as a missing server" do
      {_auth, server} = root_owner_and_server()
      other = Factory.build(:authentication, principal_id: UUID.generate(), root: false)
      previous_counts = count_rows(@affected_tables)

      assert ManageServer.retry_checking_open_ports(other, server.id) ==
               {:error, :server_not_found}

      assert_no_side_effects(previous_counts)
    end
  end

  defp root_owner_and_server do
    {auth, account} = ServersTestHelpers.register_root(@past)
    group = CourseFactory.insert(:class, now: @past)
    server = ServersTestHelpers.insert_server(account.id, group.id, active: true)
    {auth, server}
  end

  defp group_member_owner_and_server do
    %{auth: auth, owner: owner, class: class} = ServersTestHelpers.register_group_member(@past)
    server = ServersTestHelpers.insert_server(owner.id, class.id, active: true)
    {auth, server}
  end

  defp assert_no_side_effects(previous_counts) do
    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
  end
end
