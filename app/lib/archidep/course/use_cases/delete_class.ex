defmodule ArchiDep.Course.UseCases.DeleteClass do
  @moduledoc false

  use ArchiDep, :use_case

  alias ArchiDep.Course.Events.ClassDeleted
  alias ArchiDep.Course.Policy
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.Class

  @spec delete_class(Authentication.t(), UUID.t()) ::
          :ok | {:error, :class_not_found} | {:error, :class_has_servers}
  def delete_class(auth, id) do
    with :ok <- validate_uuid(id, :class_not_found),
         {:ok, class} <- Class.fetch_class(id) do
      authorize!(auth, Policy, :course, :delete_class, class)

      now = DateTime.utc_now()

      case Multi.new()
           |> Multi.delete(:class, Class.delete(class))
           # Make sure to delete the expected server properties. This is
           # necessary because the foreign key is on the "classes" table, not
           # the "server_properties" table, so the properties would be orphaned.
           |> Multi.delete(:expected_server_properties, class.expected_server_properties)
           |> Multi.insert(:stored_event, &class_deleted(auth, &1.class, now))
           |> Repo.transaction() do
        {:ok, _changes} ->
          :ok = PubSub.publish_class_deleted(class)
          :ok

        {:error, :class, changeset, _changes} ->
          case Keyword.get(changeset.errors, :servers) do
            {"class has servers", _opts} ->
              {:error, :class_has_servers}
          end
      end
    end
  end

  defp class_deleted(auth, class, now),
    do:
      class
      |> ClassDeleted.new()
      |> new_event(auth, occurred_at: now)
      |> add_to_stream(class)
      |> initiated_by(auth)
end
