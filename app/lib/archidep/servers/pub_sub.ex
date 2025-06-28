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

  @spec publish_server_deleted(Server.t()) :: :ok
  def publish_server_deleted(server),
    do: PubSub.broadcast(@pubsub, "servers:#{server.id}", {:server_deleted, server})

  @spec subscribe_server(UUID.t()) :: :ok
  def subscribe_server(server_id) do
    :ok = PubSub.subscribe(@pubsub, "servers:#{server_id}")
  end

  @spec unsubscribe_server(UUID.t()) :: :ok
  def unsubscribe_server(server_id) do
    :ok = PubSub.unsubscribe(@pubsub, "servers:#{server_id}")
  end
end
