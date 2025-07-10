defmodule ArchiDep.Students.UpdateClass do
  use ArchiDep, :use_case

  alias ArchiDep.Students.Events.ClassUpdated
  alias ArchiDep.Students.Policy
  alias ArchiDep.Students.PubSub
  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Types

  @spec validate_existing_class(Authentication.t(), UUID.t(), Types.class_data()) ::
          {:ok, Changeset.t()} | {:error, :class_not_found}
  def validate_existing_class(auth, id, data) do
    with :ok <- validate_uuid(id, :class_not_found),
         {:ok, class} <- Class.fetch_class(id) do
      authorize!(auth, Policy, :students, :validate_existing_class, class)
      {:ok, Class.update(class, data)}
    end
  end

  @spec update_class(Authentication.t(), UUID.t(), Types.class_data()) ::
          {:ok, Class.t()} | {:error, Changeset.t()} | {:error, :class_not_found}
  def update_class(auth, id, data) do
    with :ok <- validate_uuid(id, :class_not_found),
         {:ok, class} <- Class.fetch_class(id) do
      authorize!(auth, Policy, :students, :update_class, class)

      case Multi.new()
           |> Multi.update(:class, Class.update(class, data))
           |> Multi.insert(:stored_event, fn %{class: class} ->
             ClassUpdated.new(class)
             |> new_event(auth, occurred_at: class.updated_at)
             |> add_to_stream(class)
             |> initiated_by(auth)
           end)
           |> Repo.transaction() do
        {:ok, %{class: updated_class}} ->
          :ok = PubSub.publish_class(updated_class)
          {:ok, updated_class}

        {:error, :class, changeset, _} ->
          {:error, changeset}
      end
    end
  end
end
