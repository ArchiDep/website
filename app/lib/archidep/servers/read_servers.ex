defmodule ArchiDep.Servers.ReadServers do
  use ArchiDep, :use_case

  alias ArchiDep.Servers.Policy
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup

  @spec list_my_servers(Authentication.t()) :: list(Server.t())
  def list_my_servers(auth) do
    authorize!(auth, Policy, :servers, :list_my_servers, nil)

    principal_id = auth.principal.id

    Repo.all(
      from s in Server,
        join: o in assoc(s, :owner),
        where: s.owner_id == ^principal_id,
        order_by: [s.name, s.username, s.ip_address],
        preload: [owner: o]
    )
  end

  @spec list_server_groups(Authentication.t()) ::
          list(ServerGroup.t())
  def list_server_groups(auth) do
    authorize!(auth, Policy, :servers, :list_server_groups, nil)

    Repo.all(
      from g in ServerGroup,
        order_by: [desc: g.active, desc: g.end_date, desc: g.created_at, asc: g.name]
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
