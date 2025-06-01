defmodule ArchiDep.Students.DeleteClass do
  use ArchiDep, :use_case

  alias ArchiDep.Students.Events.ClassDeleted
  alias ArchiDep.Students.Policy
  alias ArchiDep.Students.Schemas.Class

  @spec delete_class(Authentication.t(), UUID.t()) ::
          :ok | {:error, :class_not_found}
  def delete_class(auth, id) do
    with {:ok, class} <- Class.fetch_class(id) do
      authorize!(auth, Policy, :students, :update_class, class)

      now = DateTime.utc_now()
      user = Authentication.fetch_user_account(auth)

      case Multi.new()
           |> Multi.delete(:class, class)
           |> Multi.insert(:stored_event, fn %{class: class} ->
             ClassDeleted.new(class)
             |> new_event(auth, occurred_at: now)
             |> add_to_stream(class)
             |> initiated_by(user)
           end)
           |> Repo.transaction() do
        {:ok, %{class: class}} ->
          {:ok, class}

        {:error, :class, changeset, _} ->
          {:error, changeset}
      end
    end
  end
end
