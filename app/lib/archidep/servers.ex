defmodule ArchiDep.Servers do
  @moduledoc """
  Servers context, which manages server groups and individual servers. This
  includes operations such as creating, updating, tracking, and deleting
  servers.
  """

  @behaviour ArchiDep.Servers.Behaviour

  use ArchiDep, :context

  alias ArchiDep.Events.Store.EventReference
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookEvent
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.Types

  @implementation Application.compile_env!(:archidep, __MODULE__)

  # Server groups

  @doc """
  Lists all server groups.
  """
  @spec list_server_groups(Authentication.t()) :: list(ServerGroup.t())
  defdelegate list_server_groups(auth), to: @implementation

  @doc """
  Fetches a server group.
  """
  @spec fetch_server_group(Authentication.t(), UUID.t()) ::
          {:ok, ServerGroup.t()} | {:error, :server_group_not_found}
  defdelegate fetch_server_group(auth, server_group_id), to: @implementation

  @doc """
  Watches the server IDs in a server group. Returns a tuple of the current set
  of server IDs and a function that can be used to update the set based on
  incoming messages.

  The subscriber will receive messages that are two-element tuples with the
  first element being `:server_created`, `:server_updated`, or
  `:server_deleted`, and the second element being the server that was created,
  updated or deleted.
  """
  @spec watch_server_ids(Authentication.t(), ServerGroup.t()) ::
          {:ok, MapSet.t(UUID.t()), (MapSet.t(UUID.t()), {atom(), term()} -> MapSet.t(UUID.t()))}
          | {:error, :unauthorized}
  defdelegate watch_server_ids(auth, server_group), to: @implementation

  @doc """
  Lists all servers in a server group.
  """
  @spec list_all_servers_in_group(Authentication.t(), UUID.t()) ::
          {:ok, list(Server.t())} | {:error, :server_group_not_found}
  defdelegate list_all_servers_in_group(auth, server_group_id), to: @implementation

  # Server group members

  @doc """
  Lists all members of a server group.
  """
  @spec list_server_group_members(Authentication.t(), UUID.t()) ::
          {:ok, list(ServerGroupMember.t())} | {:error, :server_group_not_found}
  defdelegate list_server_group_members(auth, server_group_id), to: @implementation

  @doc """
  Fetches the authenticated server group member.
  """
  @spec fetch_authenticated_server_group_member(Authentication.t()) ::
          {:ok, ServerGroupMember.t()} | {:error, :not_a_server_group_member}
  defdelegate fetch_authenticated_server_group_member(auth), to: @implementation

  @doc """
  Fetches the authenticated principal as a server owner.
  """
  @spec fetch_authenticated_server_owner(Authentication.t()) :: ServerOwner.t()
  defdelegate fetch_authenticated_server_owner(auth), to: @implementation

  # Servers

  @doc """
  Validates the data to create a new server.
  """
  @spec validate_server(Authentication.t(), UUID.t(), Types.server_data()) ::
          {:ok, Changeset.t()} | {:error, :server_group_not_found}
  defdelegate validate_server(auth, group_id, data), to: @implementation

  @doc """
  Creates a new server.
  """
  @spec create_server(Authentication.t(), UUID.t(), Types.server_data()) ::
          {:ok, Server.t()}
          | {:error, Changeset.t()}
          | {:error, {:server_limit_reached, pos_integer()}}
          | {:error, :server_group_not_found}
  defdelegate create_server(auth, group_id, data), to: @implementation

  @doc """
  Lists all servers owned by the authenticated user.
  """
  @spec list_my_servers(Authentication.t()) :: list(Server.t())
  defdelegate list_my_servers(auth), to: @implementation

  @doc """
  Fetches a server.
  """
  @spec fetch_server(Authentication.t(), UUID.t()) ::
          {:ok, Server.t()} | {:error, :server_not_found}
  defdelegate fetch_server(auth, server_id), to: @implementation

  @doc """
  Fetches the currently active server of a server group member, if any.
  """
  @spec fetch_active_server_for_group_member(Authentication.t(), UUID.t()) ::
          {:ok, Server.t()} | {:error, :server_not_found}
  defdelegate fetch_active_server_for_group_member(auth, group_member_id), to: @implementation

  @doc """
  Validates the data to update an existing server.
  """
  @spec validate_existing_server(Authentication.t(), UUID.t(), Types.server_data()) ::
          {:ok, Changeset.t()} | {:error, :server_not_found}
  defdelegate validate_existing_server(auth, server_id, data), to: @implementation

  @doc """
  Updates a server. The operation will fail if the server is busy.
  """
  @spec update_server(Authentication.t(), UUID.t(), Types.server_data()) ::
          {:ok, Server.t(), EventReference.t()}
          | {:error, Changeset.t()}
          | {:error, :server_busy}
          | {:error, :server_not_found}
  defdelegate update_server(auth, server_id, data), to: @implementation

  @doc """
  Deletes a server. The operation will fail if the server is busy.
  """
  @spec delete_server(Authentication.t(), UUID.t()) ::
          :ok | {:error, :server_busy} | {:error, :server_not_found}
  defdelegate delete_server(auth, server_id), to: @implementation

  # Connected servers

  @doc """
  Retry opening the connection to a server.
  """
  @spec retry_connecting(Authentication.t(), UUID.t()) ::
          :ok | {:error, :server_not_found}
  defdelegate retry_connecting(auth, server_id), to: @implementation

  @doc """
  Retry running an Ansible playbook on a server.
  """
  @spec retry_ansible_playbook(Authentication.t(), UUID.t(), String.t()) ::
          :ok
          | {:error, :server_not_found}
          | {:error, :server_not_connected}
          | {:error, :server_busy}
  defdelegate retry_ansible_playbook(auth, server_id, playbook), to: @implementation

  @doc """
  Retry checking the open ports on a server.
  """
  @spec retry_checking_open_ports(Authentication.t(), UUID.t()) ::
          :ok
          | {:error, :server_not_found}
          | {:error, :server_not_connected}
          | {:error, :server_busy}
  defdelegate retry_checking_open_ports(auth, server_id), to: @implementation

  @doc """
  Receive a notification that a server is up. This is used to automatically
  attempt to connect to a server as soon as it boots.
  """
  @spec notify_server_up(UUID.t(), binary()) ::
          :ok | {:error, :server_not_found}
  defdelegate notify_server_up(server_id, token), to: @implementation

  # Ansible

  @doc """
  Fetches all Ansible playbook runs.
  """
  @spec fetch_ansible_playbook_runs(Authentication.t()) :: list(AnsiblePlaybookRun.t())
  defdelegate fetch_ansible_playbook_runs(auth), to: @implementation

  @doc """
  Fetches an Ansible playbook run.
  """
  @spec fetch_ansible_playbook_run(Authentication.t(), UUID.t()) ::
          {:ok, AnsiblePlaybookRun.t()} | {:error, :ansible_playbook_run_not_found}
  defdelegate fetch_ansible_playbook_run(auth, run_id), to: @implementation

  @doc """
  Fetches the events of an Ansible playbook run.
  """
  @spec fetch_ansible_playbook_events_for_run(Authentication.t(), UUID.t()) ::
          {:ok, list(AnsiblePlaybookEvent.t())} | {:error, :ansible_playbook_run_not_found}
  defdelegate fetch_ansible_playbook_events_for_run(auth, run_id), to: @implementation
end
