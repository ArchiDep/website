defmodule ArchiDep.Course.UseCases.UpdateExpectedServerPropertiesForClass do
  @moduledoc false

  use ArchiDep, :use_case

  alias ArchiDep.Course.Events.ClassExpectedServerPropertiesUpdated
  alias ArchiDep.Course.Policy
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.ExpectedServerProperties
  alias ArchiDep.Course.Types

  @spec validate_expected_server_properties_for_class(
          Authentication.t(),
          UUID.t(),
          Types.expected_server_properties()
        ) ::
          {:ok, Changeset.t()}
          | {:error, :class_not_found}
  def validate_expected_server_properties_for_class(auth, id, data) do
    with :ok <- validate_uuid(id, :class_not_found),
         {:ok, class} <- Class.fetch_class(id) do
      authorize!(auth, Policy, :course, :update_expected_server_properties_for_class, class)

      class.expected_server_properties
      |> ExpectedServerProperties.update(data)
      |> ok()
    end
  end

  @spec update_expected_server_properties_for_class(
          Authentication.t(),
          UUID.t(),
          Types.expected_server_properties()
        ) ::
          {:ok, ExpectedServerProperties.t()}
          | {:error, Changeset.t()}
          | {:error, :class_not_found}
  def update_expected_server_properties_for_class(auth, id, data)
      when is_binary(id) and is_map(data) do
    with :ok <- validate_uuid(id, :class_not_found),
         {:ok, class} <- Class.fetch_class(id),
         :ok <-
           authorize(auth, Policy, :course, :update_expected_server_properties_for_class, class) do
      transaction(auth, class, data)
    else
      {:error, {:access_denied, :course, :update_expected_server_properties_for_class}} ->
        {:error, :class_not_found}
    end
  end

  defp transaction(auth, class, data) when is_struct(class, Class) and is_map(data) do
    case Multi.new()
         |> Multi.update(:class, Class.update_expected_server_properties(class, data))
         |> Multi.insert(
           :stored_event,
           &class_expected_properties_updated(auth, &1.class)
         )
         |> Repo.transaction() do
      {:ok, %{class: updated_class}} ->
        :ok = PubSub.publish_class_updated(updated_class)
        {:ok, updated_class.expected_server_properties}

      {:error, :class, changeset, _} ->
        {:error, Changeset.fetch_change!(changeset, :expected_server_properties)}
    end
  end

  defp class_expected_properties_updated(auth, class),
    do:
      class.expected_server_properties
      |> ClassExpectedServerPropertiesUpdated.new()
      |> new_event(auth, occurred_at: class.updated_at)
      |> add_to_stream(class)
      |> initiated_by(auth)
end
