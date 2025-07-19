defmodule ArchiDep.Course.UseCases.CreateClass do
  @moduledoc false

  use ArchiDep, :use_case

  alias ArchiDep.Course.Events.ClassCreated
  alias ArchiDep.Course.Policy
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Types

  @spec validate_class(Authentication.t(), Types.class_data()) :: Changeset.t()
  def validate_class(auth, data) do
    authorize!(auth, Policy, :course, :validate_class, nil)
    Class.new(data)
  end

  @spec create_class(Authentication.t(), Types.class_data()) ::
          {:ok, Class.t()} | {:error, Changeset.t()}
  def create_class(auth, data) do
    authorize!(auth, Policy, :course, :create_class, nil)

    case Multi.new()
         |> Multi.insert(:class, Class.new(data))
         |> Multi.insert(:stored_event, &class_created(auth, &1.class))
         |> Repo.transaction() do
      {:ok, %{class: class}} ->
        :ok = PubSub.publish_class_created(class)
        {:ok, class}

      {:error, :class, changeset, _changes} ->
        {:error, changeset}
    end
  end

  defp class_created(auth, class),
    do:
      class
      |> ClassCreated.new()
      |> new_event(auth, occurred_at: class.created_at)
      |> add_to_stream(class)
      |> initiated_by(auth)
end
