defmodule ArchiDep.Servers.PubSub do
  use ArchiDep, :pub_sub

  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember

  @pubsub ArchiDep.PubSub

  # Server groups

  @spec publish_server_group_updated(ServerGroup.t()) :: :ok
  def publish_server_group_updated(group) do
    :ok = PubSub.broadcast(@pubsub, "server-groups:#{group.id}", {:server_group_updated, group})
  end

  @spec subscribe_server_group(UUID.t()) :: :ok
  def subscribe_server_group(group_id) do
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{group_id}")
  end

  @spec unsubscribe_server_group(UUID.t()) :: :ok
  def unsubscribe_server_group(group_id) do
    :ok = PubSub.unsubscribe(@pubsub, "server-groups:#{group_id}")
  end

  @spec subscribe_server_group_members(UUID.t()) :: :ok
  def subscribe_server_group_members(group_id) do
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{group_id}:members")
  end

  @spec subscribe_server_group_servers(UUID.t()) :: :ok
  def subscribe_server_group_servers(group_id) do
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{group_id}:servers")
  end

  @spec unsubscribe_server_group_servers(UUID.t()) :: :ok
  def unsubscribe_server_group_servers(group_id) do
    :ok = PubSub.unsubscribe(@pubsub, "server-groups:#{group_id}:servers")
  end

  # Server group members

  @spec subscribe_server_group_member(UUID.t()) :: :ok
  def subscribe_server_group_member(member_id) do
    :ok = PubSub.subscribe(@pubsub, "server-group-members:#{member_id}")
  end

  @spec publish_server_group_member_updated(ServerGroupMember.t()) :: :ok
  def publish_server_group_member_updated(member) do
    :ok =
      PubSub.broadcast(
        @pubsub,
        "server-group-members:#{member.id}",
        {:server_group_member_updated, member}
      )

    :ok =
      PubSub.broadcast(
        @pubsub,
        "server-groups:#{member.group_id}:members",
        {:server_group_member_updated, member}
      )
  end

  # Servers

  @spec publish_server_created(Server.t()) :: :ok
  def publish_server_created(server) do
    :ok = PubSub.broadcast(@pubsub, "servers:new", {:server_created, server})

    :ok =
      PubSub.broadcast(
        @pubsub,
        "server-groups:#{server.group_id}:servers",
        {:server_created, server}
      )
  end

  @spec subscribe_server_created() :: :ok
  def subscribe_server_created() do
    :ok = PubSub.subscribe(@pubsub, "servers:new")
  end

  @spec publish_server_updated(Server.t()) :: :ok
  def publish_server_updated(server) do
    :ok = PubSub.broadcast(@pubsub, "servers:#{server.id}", {:server_updated, server})

    :ok =
      PubSub.broadcast(
        @pubsub,
        "server-groups:#{server.group_id}:servers",
        {:server_updated, server}
      )
  end

  @spec publish_server_deleted(Server.t()) :: :ok
  def publish_server_deleted(server) do
    :ok = PubSub.broadcast(@pubsub, "servers:#{server.id}", {:server_deleted, server})

    :ok =
      PubSub.broadcast(
        @pubsub,
        "server-groups:#{server.group_id}:servers",
        {:server_deleted, server}
      )
  end

  @spec subscribe_server(UUID.t()) :: :ok
  def subscribe_server(server_id) do
    :ok = PubSub.subscribe(@pubsub, "servers:#{server_id}")
  end

  @spec unsubscribe_server(UUID.t()) :: :ok
  def unsubscribe_server(server_id) do
    :ok = PubSub.unsubscribe(@pubsub, "servers:#{server_id}")
  end
end
