defmodule ArchiDep.Servers.Events.ServerSetupResetTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Servers.Events.ServerSetupReset
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Support.ServersFactory

  describe "new/1" do
    test "builds the event for a server owned by a group member" do
      server =
        ServersFactory.build(:server,
          ip_address: %Postgrex.INET{address: {10, 0, 0, 9}, netmask: nil},
          app_username: "archidep",
          group: ServersFactory.build(:server_group),
          owner: ServersFactory.build(:server_owner, root: false)
        )

      %Server{
        id: id,
        name: name,
        username: username,
        ssh_port: ssh_port,
        group: %ServerGroup{id: group_id, name: group_name},
        owner: %ServerOwner{
          id: owner_id,
          username: owner_username,
          root: owner_root,
          group_member: %ServerGroupMember{name: owner_name}
        }
      } = server

      assert ServerSetupReset.new(server) ==
               %ServerSetupReset{
                 id: id,
                 name: name,
                 ip_address: "10.0.0.9",
                 username: username,
                 app_username: "archidep",
                 ssh_port: ssh_port,
                 group: %{id: group_id, name: group_name},
                 owner: %{
                   id: owner_id,
                   username: owner_username,
                   name: owner_name,
                   root: owner_root
                 }
               }
    end

    test "builds the event for a server owned by a root account with no group member" do
      server =
        ServersFactory.build(:server,
          ip_address: %Postgrex.INET{address: {192, 168, 7, 3}, netmask: nil},
          app_username: "deployer",
          group: ServersFactory.build(:server_group),
          owner: ServersFactory.build(:server_owner, root: true)
        )

      %Server{
        id: id,
        name: name,
        username: username,
        ssh_port: ssh_port,
        group: %ServerGroup{id: group_id, name: group_name},
        owner: %ServerOwner{id: owner_id, username: owner_username, root: true, group_member: nil}
      } = server

      assert ServerSetupReset.new(server) ==
               %ServerSetupReset{
                 id: id,
                 name: name,
                 ip_address: "192.168.7.3",
                 username: username,
                 app_username: "deployer",
                 ssh_port: ssh_port,
                 group: %{id: group_id, name: group_name},
                 owner: %{id: owner_id, username: owner_username, name: nil, root: true}
               }
    end
  end
end
