defmodule ArchiDep.Servers.ServerTracking.ServerManagerClientBehaviour do
  @moduledoc """
  Behaviour of the client API of
  `ArchiDep.Servers.ServerTracking.ServerManager` that use cases rely on to send
  requests to a server's manager process.

  This is distinct from
  `ArchiDep.Servers.ServerTracking.ServerManagerBehaviour`, which describes the
  manager's internal state machine. It is implemented in production by the
  `ServerManager` GenServer and swapped for a mock in the test environment so
  that use cases can be tested in isolation.
  """

  alias ArchiDep.Authentication
  alias ArchiDep.Events.Store.EventReference
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookEvent
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Types
  alias Ecto.Changeset
  alias Ecto.UUID

  @callback online?(Server.t()) :: boolean()

  @callback ansible_facts_gathered(
              Server.t(),
              {:ok, Types.ansible_facts()} | {:error, term()}
            ) :: :ok

  @callback ansible_playbook_event(AnsiblePlaybookRun.t(), AnsiblePlaybookEvent.t()) :: :ok

  @callback ansible_playbook_completed(AnsiblePlaybookRun.t()) :: :ok

  @callback retry_connecting(Server.t() | UUID.t()) :: :ok

  @callback retry_ansible_playbook(Server.t(), String.t()) ::
              :ok | {:error, :server_not_connected} | {:error, :server_busy}

  @callback retry_checking_open_ports(Server.t()) ::
              :ok | {:error, :server_not_connected} | {:error, :server_busy}

  @callback update_server(Server.t(), Authentication.t(), Types.server_data()) ::
              {:ok, Server.t(), EventReference.t()}
              | {:error, Changeset.t()}
              | {:error, :server_busy}

  @callback delete_server(Server.t(), Authentication.t()) :: :ok | {:error, :server_busy}

  @callback notify_server_up(UUID.t(), EventReference.t()) :: :ok
end
