defmodule ArchiDep.Servers.Schemas.ServerTest do
  use ArchiDep.Support.DataCase, async: true

  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Support.ServersFactory

  test "a server group member cannot create a server with the username 'archidep'" do
    data = ServersFactory.random_server_data(username: "archidep")
    owner = ServersFactory.build(:server_owner, root: false, active_server_count: 0)

    changeset = Server.new_group_member_server(data, owner)

    assert errors_on(changeset) == %{username: ["this username is reserved and cannot be used"]}
  end

  test "a server group member cannot update a server to have the username 'archidep'" do
    owner = ServersFactory.build(:server_owner, root: false, active_server_count: 1)
    server = ServersFactory.build(:server, active: true, username: "validusername", owner: owner)
    data = ServersFactory.random_server_data(username: "archidep")

    changeset = Server.update_group_member_server(server, data, owner)

    assert errors_on(changeset) == %{username: ["this username is reserved and cannot be used"]}
  end
end
