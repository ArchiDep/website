defmodule ArchiDep.Servers.ConfigureServerGroupMember do
  use ArchiDep, :use_case

  alias ArchiDep.Servers.Events.ServerGroupMemberConfigured
  alias ArchiDep.Servers.Policy
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.Types

  @spec validate_server_group_member_config(
          Authentication.t(),
          UUID.t(),
          Types.server_group_member_config()
        ) ::
          {:ok, Changeset.t()} | {:error, :server_group_member_not_found}
  def validate_server_group_member_config(auth, id, data) do
    with :ok <- validate_uuid(id, :server_group_member_not_found),
         owner = ServerOwner.fetch_authenticated(auth),
         {:ok, member} <- ServerGroupMember.fetch_server_group_member(id),
         :ok <- authorize(auth, Policy, :servers, :configure_server_group_member, {owner, member}) do
      {:ok, ServerGroupMember.configure_changeset(member, data)}
    else
      {:error, :server_group_member_not_found} ->
        {:error, :server_group_member_not_found}
    end
  end

  @spec configure_server_group_member(
          Authentication.t(),
          UUID.t(),
          Types.server_group_member_config()
        ) ::
          {:ok, ServerGroupMember.t()}
          | {:error, Changeset.t()}
          | {:error, :server_group_member_not_found}
  def configure_server_group_member(auth, id, data) do
    with :ok <- validate_uuid(id, :server_group_member_not_found),
         owner = ServerOwner.fetch_authenticated(auth),
         {:ok, member} <- ServerGroupMember.fetch_server_group_member(id),
         :ok <-
           authorize(auth, Policy, :servers, :configure_server_group_member, {owner, member}),
         {:ok, updated_member} <- transaction(auth, member, data) do
      :ok = PubSub.publish_server_group_member_updated(updated_member)
      {:ok, updated_member}
    else
      {:error, :server_group_member_not_found} ->
        {:error, :server_group_member_not_found}

      {:error, {:access_denied, :servers, :configure_server_group_member}} ->
        {:error, :server_group_member_not_found}

      {:error, %Changeset{} = changeset} ->
        {:error, changeset}
    end
  end

  defp transaction(auth, member, data) do
    case Multi.new()
         |> Multi.update(:member, ServerGroupMember.configure_changeset(member, data))
         |> Multi.insert(:stored_event, &server_group_member_configured(auth, &1.member))
         |> Repo.transaction() do
      {:ok, %{member: updated_member}} ->
        {:ok, updated_member}

      {:error, :member, changeset, _} ->
        {:error, changeset}
    end
  end

  defp server_group_member_configured(auth, member),
    do:
      ServerGroupMemberConfigured.new(member)
      |> new_event(auth, occurred_at: member.updated_at)
      |> add_to_stream(member)
      |> initiated_by(auth)
end
