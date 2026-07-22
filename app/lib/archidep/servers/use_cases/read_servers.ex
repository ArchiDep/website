defmodule ArchiDep.Servers.UseCases.ReadServers do
  @moduledoc false

  use ArchiDep, :use_case

  alias ArchiDep.Clock
  alias ArchiDep.Events.Store.EventReference
  alias ArchiDep.Servers.Policy
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.ServerTracking.ServerTrackerClient
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

  # Subscribing to a member's server-owner topic grants no access beyond what
  # the initial active-server fetch already authorized, so this read-model
  # plumbing takes no authentication. The topic is keyed by the member's user
  # account, so an unlinked member (no account) owns no server and there is
  # nothing to subscribe to; the consumer re-calls this once an account is
  # linked.
  @spec subscribe_active_server_for_member(UUID.t() | nil) :: :ok
  def subscribe_active_server_for_member(nil), do: :ok

  def subscribe_active_server_for_member(owner_id),
    do: PubSub.subscribe_server_owner_servers(owner_id)

  @spec refresh_active_server_for_member(
          Authentication.t(),
          UUID.t(),
          ServerView.t() | nil,
          term()
        ) :: {:ok, ServerView.t() | nil} | :ignore
  def refresh_active_server_for_member(
        _auth,
        _member_id,
        %ServerView{id: id} = current,
        {:server_updated, %{id: id} = event, %EventReference{} = reference}
      ),
      do: {:ok, keep_if_active(ServerView.refresh!(current, event, reference))}

  def refresh_active_server_for_member(
        auth,
        member_id,
        _current,
        {server_event, %{}, %EventReference{}}
      )
      when server_event in [:server_created, :server_updated],
      do: {:ok, fetch_active_server_or_nil(auth, member_id)}

  def refresh_active_server_for_member(
        _auth,
        _member_id,
        %ServerView{id: id},
        {:server_deleted, %{id: id}, %EventReference{}}
      ),
      do: {:ok, nil}

  def refresh_active_server_for_member(
        _auth,
        _member_id,
        %ServerView{} = current,
        {member_event, event, %EventReference{} = reference}
      )
      when member_event in [:student_updated, :class_updated],
      do: {:ok, keep_if_active(ServerView.refresh!(current, event, reference))}

  def refresh_active_server_for_member(
        auth,
        member_id,
        nil,
        {member_event, _event, %EventReference{}}
      )
      when member_event in [:student_updated, :class_updated],
      do: {:ok, fetch_active_server_or_nil(auth, member_id)}

  def refresh_active_server_for_member(_auth, _member_id, _current, _message), do: :ignore

  defp keep_if_active(%ServerView{} = server),
    do: if(ServerView.active?(server, Clock.now()), do: server, else: nil)

  # Fetch through the public context boundary (authorized, and mockable) rather
  # than the local read, so the consuming LiveView sees an ordinary context read
  # — the same choice `refresh_my_servers/3` makes on first sighting.
  defp fetch_active_server_or_nil(auth, member_id) do
    case ArchiDep.Servers.fetch_active_server_for_group_member(auth, member_id) do
      {:ok, %ServerView{} = server} -> server
      {:error, :server_not_found} -> nil
    end
  end

  # Subscribing to the principal's own server topic grants no access beyond what
  # `list_my_servers/1` already authorized, so this read-model plumbing takes no
  # authentication check.
  @spec subscribe_my_servers(Authentication.t()) :: :ok
  def subscribe_my_servers(auth), do: PubSub.subscribe_server_owner_servers(auth.principal_id)

  @spec refresh_my_servers(Authentication.t(), list(ServerView.t()), term()) ::
          {:ok, list(ServerView.t())} | :ignore
  def refresh_my_servers(
        auth,
        servers,
        {:server_created, %{id: id}, %EventReference{}}
      )
      when is_list(servers) do
    # The created broadcast carries only the curated event, so fetch the full
    # read-view on first sighting. This goes through the public context boundary
    # rather than the local read so the consuming LiveView sees it as an
    # ordinary context read (authorized, and mockable) like every other server
    # fetch.
    case ArchiDep.Servers.fetch_server(auth, id) do
      {:ok, %ServerView{} = created_server} -> {:ok, sort_my_servers([created_server | servers])}
      {:error, :server_not_found} -> {:ok, servers}
    end
  end

  def refresh_my_servers(
        _auth,
        servers,
        {:server_updated, %{id: id} = event, %EventReference{} = reference}
      )
      when is_list(servers),
      do:
        {:ok,
         servers
         |> Enum.map(fn
           %ServerView{id: ^id} = server -> ServerView.refresh!(server, event, reference)
           server -> server
         end)
         |> sort_my_servers()}

  def refresh_my_servers(
        _auth,
        servers,
        {:server_deleted, %{id: id}, %EventReference{}}
      )
      when is_list(servers),
      do: {:ok, Enum.reject(servers, &(&1.id == id))}

  def refresh_my_servers(_auth, _servers, _message), do: :ignore

  @spec refresh_server_state_map(
          %{optional(UUID.t()) => ServerRealTimeState.t() | nil},
          term()
        ) :: {:ok, %{optional(UUID.t()) => ServerRealTimeState.t() | nil}} | :ignore
  def refresh_server_state_map(map, {:server_state, _id, _state} = update) when is_map(map),
    do: {:ok, ServerTrackerClient.update_server_state_map(map, update)}

  def refresh_server_state_map(_map, _message), do: :ignore

  defp sort_my_servers(servers),
    do: Enum.sort_by(servers, &{&1.name, &1.username, :inet.ntoa(&1.ip_address.address)})
end
