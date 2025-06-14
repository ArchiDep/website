defmodule ArchiDep.Students.PubSub do
  use ArchiDep, :pub_sub

  alias ArchiDep.Students.Schemas.Class

  @pubsub ArchiDep.PubSub

  @spec publish_class(Class.t()) :: :ok
  def publish_class(class),
    do: PubSub.broadcast(@pubsub, "classes:#{class.id}", {:class_updated, class})

  @spec subscribe_class(UUID.t()) :: :ok | {:error, :class_not_found}
  def subscribe_class(class_id) do
    with {:ok, _class} <- Class.fetch_class(class_id) do
      :ok = PubSub.subscribe(@pubsub, "classes:#{class_id}")
    end
  end
end
