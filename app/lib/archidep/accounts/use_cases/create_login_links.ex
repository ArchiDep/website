defmodule ArchiDep.Accounts.UseCases.CreateLoginLinks do
  @moduledoc """
  User account management use case for creating login links for preregistered
  users. A login link allows a preregistered user to register or log in when
  Switch edu-ID login is not available.
  """

  use ArchiDep, :use_case

  alias ArchiDep.Accounts.Events.PreregisteredUserLoginLinkCreated
  alias ArchiDep.Accounts.Policy
  alias ArchiDep.Accounts.Schemas.LoginLink
  alias ArchiDep.Accounts.Schemas.PreregisteredUser

  @spec create_login_link_for_preregistered_user(Authentication.t(), UUID.t()) ::
          {:ok, LoginLink.t()} | {:error, :preregistered_user_not_found} | {:error, :unauthorized}
  def create_login_link_for_preregistered_user(auth, preregistered_user_id) do
    with :ok <- validate_uuid(preregistered_user_id, :preregistered_user_not_found),
         {:ok, preregistered_user} <-
           PreregisteredUser.fetch_preregistered_user(preregistered_user_id),
         :ok <-
           authorize(
             auth,
             Policy,
             :accounts,
             :create_login_link_for_preregistered_user,
             preregistered_user
           ) do
      do_create_login_link_for_preregistered_user(auth, preregistered_user)
    else
      {:error, :preregistered_user_not_found} ->
        {:error, :preregistered_user_not_found}

      {:error, {:access_denied, :accounts, :create_login_link_for_preregistered_user}} ->
        {:error, :unauthorized}
    end
  end

  defp do_create_login_link_for_preregistered_user(auth, preregistered_user) do
    case Multi.new()
         |> Multi.update_all(
           :deactivate_existing_links,
           from(ll in LoginLink,
             where: ll.preregistered_user_id == ^preregistered_user.id
           ),
           set: [active: false]
         )
         |> Multi.insert(
           :login_link,
           LoginLink.new_token_for_preregistered_user_changeset(preregistered_user)
         )
         |> Multi.insert(
           :stored_event,
           &preregistered_user_login_link_created(auth, &1.login_link)
         )
         |> transaction() do
      {:ok, %{login_link: login_link}} ->
        {:ok, login_link}
    end
  end

  defp preregistered_user_login_link_created(auth, login_link),
    do:
      login_link
      |> PreregisteredUserLoginLinkCreated.new()
      |> new_event(auth, occurred_at: login_link.created_at)
      |> add_to_stream(login_link.preregistered_user)
      |> initiated_by(auth)
end
