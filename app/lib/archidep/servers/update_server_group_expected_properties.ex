defmodule ArchiDep.Servers.UpdateServerGroupExpectedProperties do
  use ArchiDep, :use_case

  alias ArchiDep.Servers.Events.ServerGroupExpectedPropertiesUpdated
  alias ArchiDep.Servers.Policy
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDep.Servers.Types

  @spec validate_server_group_expected_properties(
          Authentication.t(),
          UUID.t(),
          Types.server_properties_data()
        ) ::
          {:ok, Changeset.t()}
          | {:error, :server_group_not_found}
  def validate_server_group_expected_properties(auth, id, data) do
    with :ok <- validate_uuid(id, :server_group_not_found),
         {:ok, group} <- ServerGroup.fetch_server_group(id) do
      authorize!(auth, Policy, :servers, :validate_server_group_expected_properties, group)

      group
      |> ServerGroup.expected_server_properties()
      |> ServerProperties.update(data)
      |> ok()
    end
  end

  @spec update_server_group_expected_properties(
          Authentication.t(),
          UUID.t(),
          Types.server_properties_data()
        ) ::
          {:ok, ServerProperties.t()}
          | {:error, Changeset.t()}
          | {:error, :server_group_not_found}
  def update_server_group_expected_properties(auth, id, data)
      when is_binary(id) and is_map(data) do
    with :ok <- validate_uuid(id, :server_group_not_found),
         {:ok, group} <- ServerGroup.fetch_server_group(id),
         :ok <- authorize(auth, Policy, :servers, :update_server_group_expected_properties, group) do
      update_props(auth, group, data)
    else
      {:error, {:access_denied, :servers, :update_server_group_expected_properties}} ->
        {:error, :server_group_not_found}
    end
  end

  defp update_props(auth, group, data) when is_struct(group, ServerGroup) and is_map(data) do
    case Multi.new()
         |> Multi.update(:group, ServerGroup.update_expected_server_properties(group, data))
         |> Multi.insert(
           :stored_event,
           &server_group_expected_properties_updated(auth, &1.group)
         )
         |> Repo.transaction() do
      {:ok, %{group: updated_group}} ->
        PubSub.publish_server_group_updated(updated_group)
        {:ok, updated_group.expected_server_properties}

      {:error, :group, changeset, _} ->
        {:error, Changeset.fetch_change!(changeset, :expected_server_properties)}
    end
  end

  defp server_group_expected_properties_updated(auth, group),
    do:
      group.expected_server_properties
      |> ServerGroupExpectedPropertiesUpdated.new()
      |> new_event(auth, occurred_at: group.updated_at)
      |> add_to_stream(group)
      |> initiated_by(auth)
end
