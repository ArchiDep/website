defmodule ArchiDep.Servers.UseCases.ReadServerGroups do
  @moduledoc """
  Use cases for reading server groups and their members.
  """

  use ArchiDep, :use_case

  alias ArchiDep.Servers.Policy
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember

  @spec list_server_groups(Authentication.t()) ::
          list(ServerGroup.t())
  def list_server_groups(auth) do
    authorize!(auth, Policy, :servers, :list_server_groups, nil)

    Repo.all(
      from g in ServerGroup,
        order_by: [desc: g.active, desc: g.end_date, desc: g.created_at, asc: g.name]
    )
  end

  @spec fetch_server_group(Authentication.t(), UUID.t()) ::
          {:ok, ServerGroup.t()} | {:error, :server_group_not_found}
  def fetch_server_group(auth, id) do
    with :ok <- validate_uuid(id, :server_group_not_found),
         {:ok, group} <- ServerGroup.fetch_server_group(id),
         :ok <- authorize(auth, Policy, :servers, :fetch_server_group, group) do
      {:ok, group}
    else
      {:error, :server_group_not_found} ->
        {:error, :server_group_not_found}

      {:error, {:access_denied, :servers, :fetch_server_group}} ->
        {:error, :server_group_not_found}
    end
  end

  @spec list_server_group_members(Authentication.t(), UUID.t()) ::
          {:ok, list(ServerGroupMember.t())} | {:error, :server_group_not_found}
  def list_server_group_members(auth, id) do
    with :ok <- validate_uuid(id, :server_group_not_found),
         {:ok, group} <- ServerGroup.fetch_server_group(id),
         :ok <- authorize(auth, Policy, :servers, :list_server_group_members, group) do
      {:ok, ServerGroupMember.list_members_in_server_group(id)}
    else
      {:error, :server_group_not_found} ->
        {:error, :server_group_not_found}

      {:error, {:access_denied, :servers, :list_server_group_members}} ->
        {:error, :server_group_not_found}
    end
  end

  @spec fetch_authenticated_server_group_member(Authentication.t()) ::
          {:ok, ServerGroupMember.t()} | {:error, :not_a_server_group_member}
  def fetch_authenticated_server_group_member(auth) do
    with {:ok, server_group_member} <-
           auth
           |> Authentication.principal_id()
           |> ServerGroupMember.fetch_server_group_member_for_user_account_id(),
         :ok <-
           authorize(
             auth,
             Policy,
             :servers,
             :fetch_authenticated_server_group_member,
             server_group_member
           ) do
      {:ok, server_group_member}
    else
      {:error, :server_group_member_not_found} ->
        {:error, :not_a_server_group_member}

      {:error, {:access_denied, :servers, :fetch_authenticated_server_group_member}} ->
        {:error, :not_a_server_group_member}
    end
  end

  @spec list_all_servers_in_group(Authentication.t(), UUID.t()) ::
          {:ok, list(Server.t())} | {:error, :server_group_not_found}
  def list_all_servers_in_group(auth, server_group_id) do
    with {:ok, group} <- ServerGroup.fetch_server_group(server_group_id),
         :ok <- authorize(auth, Policy, :servers, :list_all_servers_in_group, group) do
      {
        :ok,
        Repo.all(
          from s in Server,
            join: g in assoc(s, :group),
            join: o in assoc(s, :owner),
            where: s.group_id == ^server_group_id,
            order_by: [s.name, s.username, s.ip_address],
            preload: [group: g, owner: o]
        )
      }
    else
      {:error, :server_group_not_found} ->
        {:error, :server_group_not_found}

      {:error, {:access_denied, :servers, :list_all_servers_in_group}} ->
        {:error, :server_group_not_found}
    end
  end

  @spec watch_server_ids(Authentication.t(), ServerGroup.t()) ::
          {:ok, MapSet.t(UUID.t()), (MapSet.t(UUID.t()), {atom(), term()} -> list(UUID.t()))}
          | {:error, :unauthorized}
  def watch_server_ids(auth, group) do
    case authorize(auth, Policy, :servers, :watch_server_ids, group) do
      :ok ->
        :ok = PubSub.subscribe_server_group_servers(group.id)

        server_ids = group.id |> Server.list_server_ids_in_group() |> MapSet.new()

        reducer = fn
          ids, {event, %Server{id: id}} when event in [:server_created, :server_updated] ->
            MapSet.put(ids, id)

          ids, {:server_deleted, %Server{id: id}} ->
            MapSet.delete(ids, id)
        end

        {:ok, server_ids, reducer}

      {:error, {:access_denied, :servers, :watch_server_ids}} ->
        {:error, :unauthorized}
    end
  end
end
