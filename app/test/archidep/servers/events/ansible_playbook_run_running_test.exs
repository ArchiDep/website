defmodule ArchiDep.Servers.Events.AnsiblePlaybookRunRunningTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Servers.Events.AnsiblePlaybookRunRunning
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Support.ServersFactory

  describe "new/1" do
    test "builds the event for a run whose server is owned by a group member" do
      run =
        ServersFactory.build(:ansible_playbook_run,
          server:
            ServersFactory.build(:server,
              group: ServersFactory.build(:server_group),
              owner: ServersFactory.build(:server_owner, root: false)
            ),
          host: %Postgrex.INET{address: {10, 0, 0, 5}, netmask: nil}
        )

      %AnsiblePlaybookRun{
        id: id,
        playbook: playbook,
        port: port,
        user: user,
        server: %Server{
          id: server_id,
          name: server_name,
          username: username,
          group: %ServerGroup{id: group_id, name: group_name},
          owner: %ServerOwner{
            id: owner_id,
            username: owner_username,
            root: owner_root,
            group_member: %ServerGroupMember{name: owner_name}
          }
        }
      } = run

      assert AnsiblePlaybookRunRunning.new(run) == %AnsiblePlaybookRunRunning{
               id: id,
               playbook: playbook,
               host: "10.0.0.5",
               port: port,
               user: user,
               server: %{id: server_id, name: server_name, username: username},
               group: %{id: group_id, name: group_name},
               owner: %{
                 id: owner_id,
                 username: owner_username,
                 name: owner_name,
                 root: owner_root
               }
             }
    end

    test "builds the event for a run whose server is owned by a root account" do
      run =
        ServersFactory.build(:ansible_playbook_run,
          server:
            ServersFactory.build(:server,
              group: ServersFactory.build(:server_group),
              owner: ServersFactory.build(:server_owner, root: true)
            ),
          host: %Postgrex.INET{address: {10, 0, 0, 5}, netmask: nil}
        )

      %AnsiblePlaybookRun{
        id: id,
        playbook: playbook,
        port: port,
        user: user,
        server: %Server{
          id: server_id,
          name: server_name,
          username: username,
          group: %ServerGroup{id: group_id, name: group_name},
          owner: %ServerOwner{
            id: owner_id,
            username: owner_username,
            root: true,
            group_member: nil
          }
        }
      } = run

      assert AnsiblePlaybookRunRunning.new(run) == %AnsiblePlaybookRunRunning{
               id: id,
               playbook: playbook,
               host: "10.0.0.5",
               port: port,
               user: user,
               server: %{id: server_id, name: server_name, username: username},
               group: %{id: group_id, name: group_name},
               owner: %{id: owner_id, username: owner_username, name: nil, root: true}
             }
    end
  end
end
