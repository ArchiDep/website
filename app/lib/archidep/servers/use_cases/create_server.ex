defmodule ArchiDep.Servers.UseCases.CreateServer do
  @moduledoc false

  use ArchiDep, :use_case

  import Authentication, only: [root?: 1]
  alias ArchiDep.Servers.Events.ServerCreated
  alias ArchiDep.Servers.Policy
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.Types

  @spec validate_server(Authentication.t(), UUID.t(), Types.server_data()) ::
          {:ok, Changeset.t()} | {:error, :server_group_not_found}
  def validate_server(auth, group_id, data) do
    with :ok <- validate_uuid(group_id, :server_group_not_found),
         {:ok, group} <- ServerGroup.fetch_server_group(group_id),
         owner = ServerOwner.fetch_authenticated(auth),
         :ok <- authorize(auth, Policy, :servers, :validate_server, {data, group, owner}) do
      {:ok, new_server(auth, data, group, owner)}
    else
      {:error, {:access_denied, :servers, :validate_server}} ->
        {:error, :server_group_not_found}

      {:error, :server_group_not_found} ->
        {:error, :server_group_not_found}
    end
  end

  @spec create_server(Authentication.t(), UUID.t(), Types.server_data()) ::
          {:ok, Server.t()}
          | {:error, Changeset.t()}
          | {:error, {:server_limit_reached, pos_integer()}}
          | {:error, :server_group_not_found}
  def create_server(auth, group_id, data) do
    with :ok <- validate_uuid(group_id, :server_group_not_found),
         {:ok, group} <- ServerGroup.fetch_server_group(group_id),
         owner = ServerOwner.fetch_authenticated(auth),
         :ok <- authorize(auth, Policy, :servers, :create_server, {data, group, owner}) do
      case Multi.new()
           |> Multi.insert(:server, new_server(auth, data, group, owner))
           |> Multi.update(:server_limit, ServerOwner.update_server_count(owner, 1))
           |> Multi.merge(&increase_active_server_count(&1.server_limit, &1.server))
           |> Multi.insert(:stored_event, &server_created(auth, &1.server))
           |> Repo.transaction() do
        {:ok, %{server: server}} ->
          :ok = PubSub.publish_server_created(server)
          {:ok, server}

        {:error, :server, changeset, _changes} ->
          {:error, changeset}
      end
    else
      {:error, {:access_denied, :servers, :validate_server}} ->
        {:error, :server_group_not_found}

      {:error, :server_group_not_found} ->
        {:error, :server_group_not_found}
    end
  end

  defp new_server(auth, data, group, owner) do
    if root?(auth) do
      Server.new(data, group, owner)
    else
      Server.new_group_member_server(data, owner)
    end
  end

  defp increase_active_server_count(owner, %Server{active: true}),
    do:
      Multi.update(
        Multi.new(),
        :active_server_limit,
        ServerOwner.update_active_server_count(owner, 1)
      )

  defp increase_active_server_count(_owner, _server), do: Multi.new()

  defp server_created(auth, server),
    do:
      server
      |> ServerCreated.new()
      |> new_event(auth, occurred_at: server.created_at)
      |> add_to_stream(server)
      |> initiated_by(auth)
end
