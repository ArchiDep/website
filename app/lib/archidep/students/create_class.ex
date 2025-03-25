defmodule ArchiDep.Students.CreateClass do
  use ArchiDep, :use_case

  alias ArchiDep.EventMetadata
  alias ArchiDep.Students.Events.ClassCreated
  alias ArchiDep.Students.Policy
  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Types

  @spec create_class(Authentication.t(), Types.class_data(), EventMetadata.t()) ::
          {:ok, Class.t()} | {:error, Changeset.t()}
  def create_class(auth, data, meta) do
    authorize!(auth, Policy, :students, :create_class, nil)

    user = Authentication.fetch_user_account(auth)

    Multi.new()
    |> Multi.insert(:class, Class.new(data))
    |> Multi.insert(:stored_event, fn %{class: class} ->
      ClassCreated.new(class)
      |> new_event(meta, occurred_at: class.created_at)
      |> add_to_stream(class)
      |> initiated_by(user)
    end)
    |> Repo.transaction()
  end
end
