defmodule ArchiDep.Servers.UseCases.CreateServer do
  use ArchiDep, :use_case

  import Authentication, only: [has_role?: 2]
  alias ArchiDep.Servers.Events.ServerCreated
  alias ArchiDep.Servers.Policy
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.Types

  @spec validate_server(Authentication.t(), Types.create_server_data()) :: Changeset.t()
  def validate_server(auth, data) do
    authorize!(auth, Policy, :servers, :validate_server, data)

    owner = ServerOwner.fetch_authenticated(auth)

    new_server(auth, data, owner)
  end

  @spec create_server(Authentication.t(), Types.create_server_data()) ::
          {:ok, Server.t()}
          | {:error, Changeset.t()}
          | {:error, {:server_limit_reached, pos_integer()}}
  def create_server(auth, data) do
    authorize!(auth, Policy, :servers, :create_server, data)

    owner = ServerOwner.fetch_authenticated(auth)

    case Multi.new()
         |> Multi.insert(:server, new_server(auth, data, owner))
         |> Multi.merge(&increase_active_server_count(owner, &1.server))
         |> Multi.insert(:stored_event, &server_created(auth, &1.server))
         |> Repo.transaction() do
      {:ok, %{server: server}} ->
        :ok = PubSub.publish_server_created(server)
        {:ok, server}

      {:error, :server, changeset, _} ->
        {:error, changeset}
    end
  end

  defp new_server(auth, data, owner) do
    if has_role?(auth, :root) do
      Server.new(data, owner)
    else
      Server.new_group_member_server(data, owner)
    end
  end

  defp increase_active_server_count(owner, %Server{active: true}),
    do:
      Multi.update(
        Multi.new(),
        :server_limit,
        ServerOwner.update_active_server_count(owner, 1)
      )

  defp increase_active_server_count(_owner, _server), do: Multi.new()

  defp server_created(auth, server),
    do:
      ServerCreated.new(server)
      |> new_event(auth, occurred_at: server.created_at)
      |> add_to_stream(server)
      |> initiated_by(auth)
end
