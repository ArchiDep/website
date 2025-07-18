defmodule ArchiDep.Accounts.PubSub do
  @moduledoc """
  Publication and subscription of events related to user account management.
  """

  alias ArchiDep.Accounts.Schemas.PreregisteredUser
  alias Ecto.UUID
  alias Phoenix.PubSub

  @pubsub ArchiDep.PubSub

  @spec subscribe_user_group_preregistered_users(UUID.t()) :: :ok
  def subscribe_user_group_preregistered_users(group_id) do
    :ok = PubSub.subscribe(@pubsub, "accounts:user-groups:#{group_id}:preregistered-users")
  end

  @spec subscribe_preregistered_user(UUID.t()) :: :ok
  def subscribe_preregistered_user(preregistered_user_id) do
    :ok = PubSub.subscribe(@pubsub, "accounts:preregistered-users:#{preregistered_user_id}")
  end

  @spec publish_preregistered_user_updated(PreregisteredUser.t()) :: :ok
  def publish_preregistered_user_updated(preregistered_user) do
    :ok =
      PubSub.broadcast(
        @pubsub,
        "accounts:preregistered-users:#{preregistered_user.id}",
        {:preregistered_user_updated, preregistered_user}
      )

    :ok =
      PubSub.broadcast(
        @pubsub,
        "accounts:user-groups:#{preregistered_user.group_id}:preregistered-users",
        {:preregistered_user_updated, preregistered_user}
      )
  end
end
