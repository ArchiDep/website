defmodule ArchiDep.Servers.Events.ServerDisconnectedTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Servers.Events.ServerDisconnected
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Support.ServersFactory

  describe "new/4" do
    test "builds the event for a server owned by a group member with a textual reason" do
      server =
        ServersFactory.build(:server,
          ip_address: %Postgrex.INET{address: {192, 168, 1, 10}, netmask: nil},
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

      assert ServerDisconnected.new(server, "root", 3600, "connection reset") ==
               %ServerDisconnected{
                 id: id,
                 name: name,
                 ip_address: "192.168.1.10",
                 username: username,
                 ssh_username: "root",
                 ssh_port: ssh_port,
                 uptime: 3600,
                 reason: "connection reset",
                 group: %{id: group_id, name: group_name},
                 owner: %{
                   id: owner_id,
                   username: owner_username,
                   name: owner_name,
                   root: owner_root
                 }
               }
    end

    test "builds the event for a server owned by a root account with no reason" do
      server =
        ServersFactory.build(:server,
          ip_address: %Postgrex.INET{address: {192, 168, 1, 10}, netmask: nil},
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

      assert ServerDisconnected.new(server, "root", 0, nil) == %ServerDisconnected{
               id: id,
               name: name,
               ip_address: "192.168.1.10",
               username: username,
               ssh_username: "root",
               ssh_port: ssh_port,
               uptime: 0,
               reason: nil,
               group: %{id: group_id, name: group_name},
               owner: %{id: owner_id, username: owner_username, name: nil, root: true}
             }
    end

    test "serializes a non-textual reason with inspect/1" do
      server =
        ServersFactory.build(:server,
          ip_address: %Postgrex.INET{address: {192, 168, 1, 10}, netmask: nil},
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

      assert ServerDisconnected.new(server, "root", 42, {:error, :closed}) ==
               %ServerDisconnected{
                 id: id,
                 name: name,
                 ip_address: "192.168.1.10",
                 username: username,
                 ssh_username: "root",
                 ssh_port: ssh_port,
                 uptime: 42,
                 reason: "{:error, :closed}",
                 group: %{id: group_id, name: group_name},
                 owner: %{
                   id: owner_id,
                   username: owner_username,
                   name: owner_name,
                   root: owner_root
                 }
               }
    end
  end
end
