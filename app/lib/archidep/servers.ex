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
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.ServerView
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
  Subscribes the calling process to every topic that keeps the set of server IDs
  in the given server group live, returning the current set. Reconcile the set
  from each incoming message with `refresh_server_ids/2`.
  """
  @spec subscribe_server_group_servers(Authentication.t(), ServerGroup.t()) ::
          {:ok, MapSet.t(UUID.t())} | {:error, :unauthorized}
  defdelegate subscribe_server_group_servers(auth, server_group), to: @implementation

  @doc """
  Reconciles the set of server IDs in a server group from a PubSub message
  broadcast on one of the topics of `subscribe_server_group_servers/2`,
  returning the updated set or `:ignore` for a message that does not concern it.
  """
  @spec refresh_server_ids(MapSet.t(UUID.t()), term()) ::
          {:ok, MapSet.t(UUID.t())} | :ignore
  defdelegate refresh_server_ids(server_ids, message), to: @implementation

  @doc """
  Lists all servers in a server group.
  """
  @spec list_all_servers_in_group(Authentication.t(), UUID.t()) ::
          {:ok, list(ServerView.t())} | {:error, :server_group_not_found}
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
  @spec list_my_servers(Authentication.t()) :: list(ServerView.t())
  defdelegate list_my_servers(auth), to: @implementation

  @doc """
  Subscribes the calling process to the topic that keeps the authenticated
  principal's own servers live (their creation, update and deletion).
  """
  @spec subscribe_my_servers(Authentication.t()) :: :ok
  defdelegate subscribe_my_servers(auth), to: @implementation

  @doc """
  Reconciles the authenticated principal's server list from a PubSub message
  broadcast on the topic of `subscribe_my_servers/1`, returning the list with
  the referenced server created, refreshed or deleted, or `:ignore` for a
  message it does not reconcile.
  """
  @spec refresh_my_servers(Authentication.t(), list(ServerView.t()), term()) ::
          {:ok, list(ServerView.t())} | :ignore
  defdelegate refresh_my_servers(auth, servers, message), to: @implementation

  @doc """
  Reconciles a map of server real-time states from a message pushed by the
  server tracker, returning the updated map, or `:ignore` for a message that
  does not concern it.
  """
  @spec refresh_server_state_map(
          %{optional(UUID.t()) => ServerRealTimeState.t() | nil},
          term()
        ) :: {:ok, %{optional(UUID.t()) => ServerRealTimeState.t() | nil}} | :ignore
  defdelegate refresh_server_state_map(server_state_map, message), to: @implementation

  @doc """
  Fetches a server.
  """
  @spec fetch_server(Authentication.t(), UUID.t()) ::
          {:ok, ServerView.t()} | {:error, :server_not_found}
  defdelegate fetch_server(auth, server_id), to: @implementation

  @doc """
  Fetches the currently active server of a server group member, if any.
  """
  @spec fetch_active_server_for_group_member(Authentication.t(), UUID.t()) ::
          {:ok, ServerView.t()} | {:error, :server_not_found}
  defdelegate fetch_active_server_for_group_member(auth, group_member_id), to: @implementation

  @doc """
  Subscribes the calling process to every topic that keeps the given server's
  read-model live.
  """
  @spec subscribe_server(ServerView.t()) :: :ok
  defdelegate subscribe_server(server), to: @implementation

  @doc """
  Reconciles a server read-model from a PubSub message broadcast on one of the
  topics of `subscribe_server/1`, returning the updated server or `:ignore` for
  a message that does not concern it.
  """
  @spec refresh_server(ServerView.t() | nil, term()) ::
          {:ok, ServerView.t()} | :ignore
  defdelegate refresh_server(server, message), to: @implementation

  @doc """
  Subscribes the calling process to the server events of a group member's
  account (given its user-account id, or `nil` for an unlinked member), which
  keep that member's active server live.
  """
  @spec subscribe_active_server_for_member(UUID.t() | nil) :: :ok
  defdelegate subscribe_active_server_for_member(owner_id), to: @implementation

  @doc """
  Reconciles a group member's active-server read-model (a single `ServerView` or
  `nil`, identified by the member id) from a PubSub message, returning the
  updated value or `:ignore` for a message that does not concern it.
  """
  @spec refresh_active_server_for_member(
          Authentication.t(),
          UUID.t(),
          ServerView.t() | nil,
          term()
        ) :: {:ok, ServerView.t() | nil} | :ignore
  defdelegate refresh_active_server_for_member(auth, member_id, current, message),
    to: @implementation

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

  @doc """
  Subscribes the calling process to the `ArchiDep.Tracker` presence topic that
  keeps the Ansible playbook run list live with the running playbooks'
  real-time progress.
  """
  @spec subscribe_ansible_playbook_runs() :: :ok
  defdelegate subscribe_ansible_playbook_runs(), to: @implementation

  @doc """
  Returns the real-time progress of the currently running Ansible playbooks,
  keyed by playbook run id, as reported by the `ArchiDep.Tracker` presence topic
  of `subscribe_ansible_playbook_runs/0`.
  """
  @spec tracked_ansible_playbook_runs() :: %{optional(String.t()) => map()}
  defdelegate tracked_ansible_playbook_runs(), to: @implementation

  @doc """
  Reconciles the Ansible playbook run list and the running playbooks' real-time
  progress from a message broadcast on the topic of
  `subscribe_ansible_playbook_runs/0`, returning the updated list and progress
  map, or `:ignore` for a message that does not concern them.
  """
  @spec refresh_ansible_playbook_runs(
          Authentication.t(),
          list(AnsiblePlaybookRun.t()),
          %{optional(String.t()) => map()},
          term()
        ) ::
          {:ok, list(AnsiblePlaybookRun.t()), %{optional(String.t()) => map()}} | :ignore
  defdelegate refresh_ansible_playbook_runs(auth, playbook_runs, tracked_playbooks, message),
    to: @implementation
end
