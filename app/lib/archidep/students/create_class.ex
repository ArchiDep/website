defmodule ArchiDep.Students.CreateClass do
  use ArchiDep, :use_case

  alias ArchiDep.Students.Events.ClassCreated
  alias ArchiDep.Students.Policy
  alias ArchiDep.Students.PubSub
  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Types

  @spec validate_class(Authentication.t(), Types.class_data()) :: Changeset.t()
  def validate_class(auth, data) do
    authorize!(auth, Policy, :students, :validate_class, nil)
    Class.new(data)
  end

  @spec create_class(Authentication.t(), Types.class_data()) ::
          {:ok, Class.t()} | {:error, Changeset.t()}
  def create_class(auth, data) do
    authorize!(auth, Policy, :students, :create_class, nil)

    user = Authentication.fetch_user_account(auth)

    case Multi.new()
         |> Multi.insert(:class, Class.new(data))
         |> Multi.insert(:stored_event, fn %{class: class} ->
           ClassCreated.new(class)
           |> new_event(auth, occurred_at: class.created_at)
           |> add_to_stream(class)
           |> initiated_by(user)
         end)
         |> Repo.transaction() do
      {:ok, %{class: class}} ->
        :ok = PubSub.publish_class_created(class)
        {:ok, class}

      {:error, :class, changeset, _} ->
        {:error, changeset}
    end
  end
end
