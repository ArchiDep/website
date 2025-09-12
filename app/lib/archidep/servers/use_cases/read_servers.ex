defmodule ArchiDep.Servers.UseCases.ReadServers do
  @moduledoc false

  use ArchiDep, :use_case

  alias ArchiDep.Servers.Policy
  alias ArchiDep.Servers.Schemas.Server

  @spec list_my_servers(Authentication.t()) :: list(Server.t())
  def list_my_servers(auth) do
    authorize!(auth, Policy, :servers, :list_my_servers, nil)

    principal_id = auth.principal_id

    Repo.all(
      from s in Server,
        join: o in assoc(s, :owner),
        left_join: ogm in assoc(o, :group_member),
        left_join: ogmg in assoc(ogm, :group),
        join: g in assoc(s, :group),
        join: gesp in assoc(g, :expected_server_properties),
        join: ep in assoc(s, :expected_properties),
        left_join: lkp in assoc(s, :last_known_properties),
        where: s.owner_id == ^principal_id,
        order_by: [s.name, s.username, s.ip_address],
        preload: [
          group: {g, expected_server_properties: gesp},
          expected_properties: ep,
          last_known_properties: lkp,
          owner: {o, group_member: {ogm, group: ogmg}}
        ]
    )
  end

  @spec list_my_active_servers(Authentication.t()) :: list(Server.t())
  def list_my_active_servers(auth) do
    authorize!(auth, Policy, :servers, :list_my_active_servers, nil)

    principal_id = auth.principal_id

    Repo.all(
      from s in Server,
        join: o in assoc(s, :owner),
        left_join: ogm in assoc(o, :group_member),
        left_join: ogmg in assoc(ogm, :group),
        join: g in assoc(s, :group),
        join: gesp in assoc(g, :expected_server_properties),
        join: ep in assoc(s, :expected_properties),
        left_join: lkp in assoc(s, :last_known_properties),
        where: s.owner_id == ^principal_id and s.active,
        order_by: [s.name, s.username, s.ip_address],
        preload: [
          group: {g, expected_server_properties: gesp},
          expected_properties: ep,
          last_known_properties: lkp,
          owner: {o, group_member: {ogm, group: ogmg}}
        ]
    )
  end

  @spec fetch_server(Authentication.t(), UUID.t()) ::
          {:ok, Server.t()} | {:error, :server_not_found}
  def fetch_server(auth, id) do
    with :ok <- validate_uuid(id, :server_not_found),
         {:ok, server} <- Server.fetch_server(id),
         :ok <- authorize(auth, Policy, :servers, :fetch_server, server) do
      {:ok, server}
    else
      {:error, :server_not_found} ->
        {:error, :server_not_found}

      {:error, {:access_denied, :servers, :fetch_server}} ->
        {:error, :server_not_found}
    end
  end
end
