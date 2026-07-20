defmodule ArchiDep.Servers.Behaviour do
  @moduledoc false

  use ArchiDep, :context_behaviour

  alias ArchiDep.Servers.Schemas.AnsiblePlaybookEvent
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.ServerView
  alias ArchiDep.Servers.Types

  # Server groups
  # =============

  @doc """
  Lists all server groups.
  """
  @callback list_server_groups(Authentication.t()) :: list(ServerGroup.t())

  @doc """
  Fetches a server group.
  """
  @callback fetch_server_group(Authentication.t(), UUID.t()) ::
              {:ok, ServerGroup.t()} | {:error, :server_group_not_found}

  @doc """
  Watches the server IDs in a server group. Returns a tuple of the current set
  of server IDs and a function that can be used to update the set based on
  incoming messages.

  The subscriber will receive messages that are three-element tuples of the form
  `{event_name, event, reference}`, where `event_name` is `:server_created`,
  `:server_updated`, or `:server_deleted`, `event` is the corresponding curated
  domain event, and `reference` is its `EventReference`.
  """
  @callback watch_server_ids(Authentication.t(), ServerGroup.t()) ::
              {:ok, MapSet.t(UUID.t()),
               (MapSet.t(UUID.t()), {atom(), term()} -> MapSet.t(UUID.t()))}
              | {:error, :unauthorized}

  # Server group members
  # ====================

  @doc """
  Lists all members of a server group.
  """
  @callback list_server_group_members(Authentication.t(), UUID.t()) ::
              {:ok, list(ServerGroupMember.t())} | {:error, :server_group_not_found}

  @doc """
  Fetches the authenticated server group member.
  """
  @callback fetch_authenticated_server_group_member(Authentication.t()) ::
              {:ok, ServerGroupMember.t()} | {:error, :not_a_server_group_member}

  @doc """
  Fetches the authenticated principal as a server owner.
  """
  @callback fetch_authenticated_server_owner(Authentication.t()) :: ServerOwner.t()

  # Servers
  # =======

  @doc """
  Validates the data to create a new server.
  """
  @callback validate_server(Authentication.t(), UUID.t(), Types.server_data()) ::
              {:ok, Changeset.t()} | {:error, :server_group_not_found}

  @doc """
  Creates a new server.
  """
  @callback create_server(Authentication.t(), UUID.t(), Types.server_data()) ::
              {:ok, Server.t()}
              | {:error, Changeset.t()}
              | {:error, {:server_limit_reached, pos_integer()}}
              | {:error, :server_group_not_found}

  @doc """
  Lists all servers owned by the authenticated user.
  """
  @callback list_my_servers(Authentication.t()) :: list(ServerView.t())

  @doc """
  Subscribes the calling process to the topic that keeps the authenticated
  principal's own servers live (their creation, update and deletion).
  """
  @callback subscribe_my_servers(Authentication.t()) :: :ok

  @doc """
  Reconciles the authenticated principal's server list from a PubSub message
  broadcast on the topic of `subscribe_my_servers/1`, returning the list with
  the referenced server refreshed, or `:ignore` for a message it does not
  reconcile (such as a creation or deletion, which the caller applies alongside
  its server tracker).
  """
  @callback refresh_my_servers(list(ServerView.t()), term()) ::
              {:ok, list(ServerView.t())} | :ignore

  @doc """
  Lists all servers in a server group.
  """
  @callback list_all_servers_in_group(Authentication.t(), UUID.t()) ::
              {:ok, list(ServerView.t())} | {:error, :server_group_not_found}

  @doc """
  Fetches a server.
  """
  @callback fetch_server(Authentication.t(), UUID.t()) ::
              {:ok, ServerView.t()} | {:error, :server_not_found}

  @doc """
  Fetches the currently active server of a server group member, if any.
  """
  @callback fetch_active_server_for_group_member(Authentication.t(), UUID.t()) ::
              {:ok, ServerView.t()} | {:error, :server_not_found}

  @doc """
  Subscribes the calling process to every topic that keeps the given server's
  read-model live.
  """
  @callback subscribe_server(ServerView.t()) :: :ok

  @doc """
  Reconciles a server read-model from a PubSub message broadcast on one of the
  topics of `subscribe_server/1`, returning the updated server or `:ignore` for
  a message that does not concern it.
  """
  @callback refresh_server(ServerView.t() | nil, term()) ::
              {:ok, ServerView.t()} | :ignore

  @doc """
  Validates the data to update an existing server.
  """
  @callback validate_existing_server(Authentication.t(), UUID.t(), Types.server_data()) ::
              {:ok, Changeset.t()} | {:error, :server_not_found}

  @doc """
  Updates a server. The operation will fail if the server is busy.
  """
  @callback update_server(Authentication.t(), UUID.t(), Types.server_data()) ::
              {:ok, Server.t(), EventReference.t()}
              | {:error, Changeset.t()}
              | {:error, :server_busy}
              | {:error, :server_not_found}

  @doc """
  Deletes a server. The operation will fail if the server is busy.
  """
  @callback delete_server(Authentication.t(), UUID.t()) ::
              :ok | {:error, :server_busy} | {:error, :server_not_found}

  # Connected servers
  # =================

  @doc """
  Retry opening the connection to a server.
  """
  @callback retry_connecting(Authentication.t(), UUID.t()) ::
              :ok | {:error, :server_not_found}

  @doc """
  Retry running an Ansible playbook on a server.
  """
  @callback retry_ansible_playbook(Authentication.t(), UUID.t(), String.t()) ::
              :ok
              | {:error, :server_not_found}
              | {:error, :server_not_connected}
              | {:error, :server_busy}

  @doc """
  Retry checking the open ports on a server.
  """
  @callback retry_checking_open_ports(Authentication.t(), UUID.t()) ::
              :ok
              | {:error, :server_not_found}
              | {:error, :server_not_connected}
              | {:error, :server_busy}

  @doc """
  Receive a notification that a server is up. This is used to automatically
  attempt to connect to a server as soon as it boots.
  """
  @callback notify_server_up(UUID.t(), binary()) ::
              :ok | {:error, :server_not_found}

  # Ansible
  # =======

  @doc """
  Fetches all Ansible playbook runs.
  """
  @callback fetch_ansible_playbook_runs(Authentication.t()) :: list(AnsiblePlaybookRun.t())

  @doc """
  Fetches an Ansible playbook run.
  """
  @callback fetch_ansible_playbook_run(Authentication.t(), UUID.t()) ::
              {:ok, AnsiblePlaybookRun.t()} | {:error, :ansible_playbook_run_not_found}

  @doc """
  Fetches the events of an Ansible playbook run.
  """
  @callback fetch_ansible_playbook_events_for_run(Authentication.t(), UUID.t()) ::
              {:ok, list(AnsiblePlaybookEvent.t())} | {:error, :ansible_playbook_run_not_found}
end
