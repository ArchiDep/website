defmodule ArchiDepWeb.Helpers.ClassHelpers do
  @moduledoc false

  # TODO: This helper exists only so the web layer can recover a class id from a
  # `:class_updated` broadcast payload. It can be removed once the owning Course
  # context owns the subscribe/reconcile dispatch and consumers no longer
  # inspect broadcast event shapes.

  alias ArchiDep.Course.Events.ClassExpectedServerPropertiesUpdated
  alias ArchiDep.Course.Events.ClassUpdated
  alias Ecto.UUID

  @doc """
  Returns the id of the class carried by a `:class_updated` broadcast payload,
  which may be either of the two class-update domain events.
  """
  @spec class_updated_id(ClassUpdated.t() | ClassExpectedServerPropertiesUpdated.t()) :: UUID.t()
  def class_updated_id(%ClassUpdated{id: id}), do: id
  def class_updated_id(%ClassExpectedServerPropertiesUpdated{class: %{id: id}}), do: id
end
