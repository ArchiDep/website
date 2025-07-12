defmodule ArchiDep.Students.DeleteClass do
  use ArchiDep, :use_case

  alias ArchiDep.Students.Events.ClassDeleted
  alias ArchiDep.Students.Policy
  alias ArchiDep.Students.PubSub
  alias ArchiDep.Students.Schemas.Class

  @spec delete_class(Authentication.t(), UUID.t()) ::
          :ok | {:error, :class_not_found} | {:error, :class_has_servers}
  def delete_class(auth, id) do
    with :ok <- validate_uuid(id, :class_not_found),
         {:ok, class} <- Class.fetch_class(id) do
      authorize!(auth, Policy, :students, :delete_class, class)

      now = DateTime.utc_now()

      case Multi.new()
           |> Multi.delete(:class, Class.delete(class))
           # Make sure to delete the expected server properties. This is
           # necessary because the foreign key is on the "classes" table, not
           # the "server_properties" table, so the properties would be orphaned.
           |> Multi.delete_all(:expected_server_properties, linked_server_properties(class))
           |> Multi.insert(:stored_event, &class_deleted(auth, &1.class, now))
           |> Repo.transaction() do
        {:ok, _} ->
          :ok = PubSub.publish_class_deleted(class)
          :ok

        {:error, :class, changeset, _} ->
          case Keyword.get(changeset.errors, :servers) do
            {"class has servers", _opts} ->
              {:error, :class_has_servers}
          end
      end
    end
  end

  # Build the query with the raw table name to avoid a code dependency on the
  # schemas in the Servers context (although the dependency still exists in the
  # database).
  defp linked_server_properties(class),
    do: from(sp in "server_properties", where: sp.id == ^UUID.dump!(class.id))

  defp class_deleted(auth, class, now),
    do:
      ClassDeleted.new(class)
      |> new_event(auth, occurred_at: now)
      |> add_to_stream(class)
      |> initiated_by(auth)
end
