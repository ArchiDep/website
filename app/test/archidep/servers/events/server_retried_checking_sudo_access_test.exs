defmodule ArchiDep.Servers.Events.ServerRetriedCheckingSudoAccessTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Servers.Events.ServerRetriedCheckingSudoAccess
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Support.ServersFactory

  describe "new/2" do
    test "builds the event for a server owned by a group member" do
      server =
        ServersFactory.build(:server,
          ip_address: %Postgrex.INET{address: {10, 0, 0, 7}, netmask: nil},
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

      assert ServerRetriedCheckingSudoAccess.new(server, "archidep") ==
               %ServerRetriedCheckingSudoAccess{
                 id: id,
                 name: name,
                 ip_address: "10.0.0.7",
                 username: username,
                 ssh_username: "archidep",
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
          ip_address: %Postgrex.INET{address: {172, 16, 4, 2}, netmask: nil},
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

      assert ServerRetriedCheckingSudoAccess.new(server, "jdoe") ==
               %ServerRetriedCheckingSudoAccess{
                 id: id,
                 name: name,
                 ip_address: "172.16.4.2",
                 username: username,
                 ssh_username: "jdoe",
                 ssh_port: ssh_port,
                 group: %{id: group_id, name: group_name},
                 owner: %{id: owner_id, username: owner_username, name: nil, root: true}
               }
    end
  end
end
