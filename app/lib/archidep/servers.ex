defmodule ArchiDep.Servers do
  @moduledoc """
  Servers context, which manages server groups and individual servers. This
  includes operations such as creating, updating, tracking, and deleting
  servers.
  """

  @behaviour ArchiDep.Servers.Behaviour

  use ArchiDep, :context

  alias ArchiDep.Servers.Behaviour

  @implementation Application.compile_env!(:archidep, __MODULE__)

  # Server groups
  delegate(&Behaviour.list_server_groups/1)
  delegate(&Behaviour.fetch_server_group/2)
  delegate(&Behaviour.watch_server_ids/2)

  # Server group members
  delegate(&Behaviour.list_server_group_members/2)
  delegate(&Behaviour.fetch_authenticated_server_group_member/1)

  # Servers
  delegate(&Behaviour.validate_server/2)
  delegate(&Behaviour.create_server/2)
  delegate(&Behaviour.list_my_servers/1)
  delegate(&Behaviour.fetch_server/2)
  delegate(&Behaviour.validate_existing_server/3)
  delegate(&Behaviour.update_server/3)
  delegate(&Behaviour.delete_server/2)

  # Connected servers
  delegate(&Behaviour.retry_connecting/2)
  delegate(&Behaviour.retry_ansible_playbook/3)
  delegate(&Behaviour.notify_server_up/2)
end
