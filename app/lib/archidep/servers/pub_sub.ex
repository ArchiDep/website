defmodule ArchiDep.Servers.PubSub do
  @moduledoc """
  Publication and subscription of events related to servers.
  """

  use ArchiDep, :pub_sub

  alias ArchiDep.Events.Store.EventReference
  alias ArchiDep.Servers.Events.ServerCreated
  alias ArchiDep.Servers.Events.ServerDeleted
  alias ArchiDep.Servers.Events.ServerFactsGathered
  alias ArchiDep.Servers.Events.ServerOpenPortsChecked
  alias ArchiDep.Servers.Events.ServerSetUp
  alias ArchiDep.Servers.Events.ServerUpdated

  @pubsub ArchiDep.PubSub

  # Server groups

  @spec subscribe_server_group_servers(UUID.t()) :: :ok
  def subscribe_server_group_servers(group_id) do
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{group_id}:servers")
  end

  @spec unsubscribe_server_group_servers(UUID.t()) :: :ok
  def unsubscribe_server_group_servers(group_id) do
    :ok = PubSub.unsubscribe(@pubsub, "server-groups:#{group_id}:servers")
  end

  # Server owners

  @spec subscribe_server_owner_servers(UUID.t()) :: :ok
  def subscribe_server_owner_servers(owner_id) do
    :ok = PubSub.subscribe(@pubsub, "server-owners:#{owner_id}:servers")
  end

  # Servers

  @spec publish_server_created(ServerCreated.t(), EventReference.t()) :: :ok
  def publish_server_created(event, reference) do
    message = {:server_created, event, reference}
    :ok = PubSub.broadcast(@pubsub, Scope.global_topic("servers:new"), message)
    :ok = PubSub.broadcast(@pubsub, "server-groups:#{event.group.id}:servers", message)
    :ok = PubSub.broadcast(@pubsub, "server-owners:#{event.owner.id}:servers", message)
  end

  @spec subscribe_server_created() :: :ok
  def subscribe_server_created do
    :ok = PubSub.subscribe(@pubsub, Scope.global_topic("servers:new"))
  end

  @spec publish_server_updated(
          ServerUpdated.t()
          | ServerFactsGathered.t()
          | ServerSetUp.t()
          | ServerOpenPortsChecked.t(),
          EventReference.t()
        ) :: :ok
  def publish_server_updated(event, reference) do
    message = {:server_updated, event, reference}
    :ok = PubSub.broadcast(@pubsub, "servers:#{event.id}", message)
    :ok = PubSub.broadcast(@pubsub, "server-groups:#{event.group.id}:servers", message)
    :ok = PubSub.broadcast(@pubsub, "server-owners:#{event.owner.id}:servers", message)
  end

  @spec publish_server_deleted(ServerDeleted.t(), EventReference.t()) :: :ok
  def publish_server_deleted(event, reference) do
    message = {:server_deleted, event, reference}
    :ok = PubSub.broadcast(@pubsub, "servers:#{event.id}", message)
    :ok = PubSub.broadcast(@pubsub, "server-groups:#{event.group.id}:servers", message)
    :ok = PubSub.broadcast(@pubsub, "server-owners:#{event.owner.id}:servers", message)
  end

  @spec subscribe_server(UUID.t()) :: :ok
  def subscribe_server(server_id) do
    :ok = PubSub.subscribe(@pubsub, "servers:#{server_id}")
  end

  @spec unsubscribe_server(UUID.t()) :: :ok
  def unsubscribe_server(server_id) do
    :ok = PubSub.unsubscribe(@pubsub, "servers:#{server_id}")
  end

  # Ansible pipeline

  @spec subscribe_ansible_playbook_runs() :: :ok
  def subscribe_ansible_playbook_runs do
    :ok = PubSub.subscribe(@pubsub, "tracker:" <> Scope.global_topic("ansible-queue"))
  end
end
