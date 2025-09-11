defmodule ArchiDep.Course.UseCases.UpdateClass do
  @moduledoc false

  use ArchiDep, :use_case

  alias ArchiDep.Course.Events.ClassUpdated
  alias ArchiDep.Course.Policy
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Types

  @spec validate_existing_class(Authentication.t(), UUID.t(), Types.class_data()) ::
          {:ok, Changeset.t()} | {:error, :class_not_found}
  def validate_existing_class(auth, id, data) do
    with :ok <- validate_uuid(id, :class_not_found),
         {:ok, class} <- Class.fetch_class(id) do
      authorize!(auth, Policy, :course, :validate_existing_class, class)
      {:ok, Class.update(class, data)}
    end
  end

  @spec update_class(Authentication.t(), UUID.t(), Types.class_data()) ::
          {:ok, Class.t()} | {:error, Changeset.t()} | {:error, :class_not_found}
  def update_class(auth, id, data) do
    with :ok <- validate_uuid(id, :class_not_found),
         {:ok, class} <- Class.fetch_class(id) do
      authorize!(auth, Policy, :course, :update_class, class)

      case Multi.new()
           |> Multi.update(:class, Class.update(class, data))
           |> Multi.insert(:stored_event, &class_updated(auth, &1.class))
           |> Repo.transaction() do
        {:ok, %{class: updated_class, stored_event: event}} ->
          :ok = PubSub.publish_class_updated(updated_class, event)
          {:ok, updated_class}

        {:error, :class, changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  defp class_updated(auth, class),
    do:
      class
      |> ClassUpdated.new()
      |> new_event(auth, occurred_at: class.updated_at)
      |> add_to_stream(class)
      |> initiated_by(auth)
end
