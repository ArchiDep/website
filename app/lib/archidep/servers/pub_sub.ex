defmodule ArchiDep.Servers.PubSub do
  use ArchiDep, :pub_sub

  alias ArchiDep.Servers.Schemas.Server

  @pubsub ArchiDep.PubSub

  @spec publish_new_server(Server.t()) :: :ok
  def publish_new_server(server),
    do: PubSub.broadcast(@pubsub, "servers:new", {:server_created, server})

  @spec subscribe_new_server() :: :ok
  def subscribe_new_server() do
    :ok = PubSub.subscribe(@pubsub, "servers:new")
  end

  @spec publish_server(Server.t()) :: :ok
  def publish_server(server),
    do: PubSub.broadcast(@pubsub, "servers:#{server.id}", {:server_updated, server})

  @spec subscribe_server(UUID.t()) :: :ok | {:error, :server_not_found}
  def subscribe_server(server_id) do
    with {:ok, _server} <- Server.fetch_server(server_id) do
      :ok = PubSub.subscribe(@pubsub, "servers:#{server_id}")
    end
  end
end
