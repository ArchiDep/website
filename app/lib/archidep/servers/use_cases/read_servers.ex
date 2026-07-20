defmodule ArchiDep.Servers.UseCases.ReadServers do
  @moduledoc false

  use ArchiDep, :use_case

  alias ArchiDep.Clock
  alias ArchiDep.Events.Store.EventReference
  alias ArchiDep.Servers.Policy
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerView

  @spec list_my_servers(Authentication.t()) :: list(ServerView.t())
  def list_my_servers(auth) do
    authorize!(auth, Policy, :servers, :list_my_servers, nil)

    principal_id = auth.principal_id

    servers =
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

    Enum.map(servers, &ServerView.from/1)
  end

  @spec fetch_server(Authentication.t(), UUID.t()) ::
          {:ok, ServerView.t()} | {:error, :server_not_found}
  def fetch_server(auth, id) do
    with :ok <- validate_uuid(id, :server_not_found),
         {:ok, server} <- Server.fetch_server(id),
         :ok <- authorize(auth, Policy, :servers, :fetch_server, server) do
      {:ok, ServerView.from(server)}
    else
      {:error, :server_not_found} ->
        {:error, :server_not_found}

      {:error, {:access_denied, :servers, :fetch_server}} ->
        {:error, :server_not_found}
    end
  end

  @spec fetch_active_server_for_group_member(Authentication.t(), UUID.t()) ::
          {:ok, ServerView.t()} | {:error, :server_not_found}
  def fetch_active_server_for_group_member(auth, group_member_id) do
    with :ok <-
           authorize(auth, Policy, :servers, :fetch_active_server_for_group_member, nil),
         {:ok, server} <-
           Server.find_active_server_for_group_member(group_member_id, Clock.now()) do
      {:ok, ServerView.from(server)}
    else
      {:error, {:access_denied, :servers, :fetch_active_server_for_group_member}} ->
        {:error, :server_not_found}

      {:error, :server_not_found} ->
        {:error, :server_not_found}

      {:error, {:multiple_servers_found, _ids}} ->
        {:error, :server_not_found}
    end
  end

  # Subscribing to the topic of a server the caller already holds grants no new
  # access, so this read-model plumbing takes no authentication and skips the
  # authorization the command use cases perform.
  @spec subscribe_server(ServerView.t()) :: :ok
  def subscribe_server(%ServerView{id: id}), do: PubSub.subscribe_server(id)

  @spec refresh_server(ServerView.t() | nil, term()) :: {:ok, ServerView.t()} | :ignore
  def refresh_server(
        %ServerView{id: id} = server,
        {:server_updated, %{id: id} = event, %EventReference{} = reference}
      ),
      do: {:ok, ServerView.refresh!(server, event, reference)}

  def refresh_server(_server, _message), do: :ignore
end
