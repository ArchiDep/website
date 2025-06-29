defmodule ArchiDep.Servers.ManageServer do
  use ArchiDep, :use_case

  alias ArchiDep.Servers.Policy
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerManager

  @spec retry_connecting(Authentication.t(), UUID.t()) ::
          :ok | {:error, :server_not_found}
  def retry_connecting(auth, server_id) do
    with :ok <- validate_uuid(server_id, :server_not_found),
         {:ok, server} <- Server.fetch_server(server_id),
         :ok <- authorize(auth, Policy, :servers, :retry_connecting, server) do
      ServerManager.retry_connecting(server)
    else
      {:error, {:access_denied, :servers, :retry_connecting}} ->
        {:error, :server_not_found}
    end
  end

  @spec retry_ansible_playbook(Authentication.t(), UUID.t(), String.t()) ::
          :ok | {:error, :server_not_found}
  def retry_ansible_playbook(auth, server_id, playbook) do
    with :ok <- validate_uuid(server_id, :server_not_found),
         {:ok, server} <- Server.fetch_server(server_id),
         :ok <- authorize(auth, Policy, :servers, :retry_ansible_playbook, {server, playbook}) do
      ServerManager.retry_ansible_playbook(server, playbook)
    else
      {:error, {:access_denied, :servers, :retry_ansible_playbook}} ->
        {:error, :server_not_found}
    end
  end
end
