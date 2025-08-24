defmodule ArchiDep.Servers.ServerTracking.ServerManagerBehaviour do
  @moduledoc """
  Specification of the behaviour of a
  `ArchiDep.Servers.ServerTracking.ServerManager`.
  """

  alias ArchiDep.Authentication
  alias ArchiDep.Servers.Ansible.Pipeline
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Servers.Types
  alias Ecto.Changeset
  alias Ecto.UUID

  @type t :: __MODULE__
  @type state :: ServerManagerState.t()

  @callback init(UUID.t(), Pipeline.t()) :: state()
  @callback online?(state()) :: boolean()
  @callback connection_idle(state(), pid()) :: state()
  @callback retry_connecting(state(), boolean()) :: state()
  @callback handle_task_result(state(), reference(), result) :: state() when result: term()
  @callback ansible_playbook_event(state(), UUID.t(), String.t() | nil) :: state()
  @callback ansible_playbook_completed(state(), UUID.t()) :: state()
  @callback retry_ansible_playbook(state(), String.t()) ::
              {state(), :ok | {:error, :server_not_connected} | {:error, :server_busy}}
  @callback retry_checking_open_ports(state()) ::
              {state(), :ok | {:error, :server_not_connected} | {:error, :server_busy}}
  @callback group_updated(state(), map()) :: state()
  @callback connection_crashed(state(), pid(), reason) :: state() when reason: term()
  @callback update_server(state(), Authentication.t(), Types.update_server_data()) ::
              {state(), {:ok, Server.t()} | {:error, Changeset.t()} | {:error, :server_busy}}
  @callback delete_server(state(), Authentication.t()) :: {state(), :ok | {:error, :server_busy}}
  @callback on_message(state(), term()) :: state()
end
