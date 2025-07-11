defmodule ArchiDep.Servers.Behaviour do
  use ArchiDep, :behaviour

  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Types

  # Server groups

  @callback list_server_groups(Authentication.t()) :: list(ServerGroup.t())

  @callback fetch_server_group(Authentication.t(), UUID.t()) ::
              {:ok, ServerGroup.t()} | {:error, :server_group_not_found}

  # Servers

  @callback validate_server(Authentication.t(), Types.create_server_data()) :: Changeset.t()

  @callback create_server(Authentication.t(), Types.create_server_data()) ::
              {:ok, Server.t()} | {:error, Changeset.t()}

  @callback list_my_servers(Authentication.t()) :: list(Server.t())

  @callback fetch_server(Authentication.t(), UUID.t()) ::
              {:ok, Server.t()} | {:error, :server_not_found}

  @callback validate_existing_server(Authentication.t(), UUID.t(), Types.update_server_data()) ::
              {:ok, Changeset.t()} | {:error, :server_not_found}

  @callback update_server(Authentication.t(), UUID.t(), Types.update_server_data()) ::
              {:ok, Server.t()}
              | {:error, Changeset.t()}
              | {:error, :server_busy}
              | {:error, :server_not_found}

  @callback delete_server(Authentication.t(), UUID.t()) ::
              :ok | {:error, :server_busy} | {:error, :server_not_found}

  # Connected servers

  @callback retry_connecting(Authentication.t(), UUID.t()) ::
              :ok | {:error, :server_not_found}

  @callback retry_ansible_playbook(Authentication.t(), UUID.t(), String.t()) ::
              :ok | {:error, :server_not_found}

  @callback notify_server_up(UUID.t(), binary()) ::
              :ok | {:error, :server_not_found}
end
