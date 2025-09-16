defmodule ArchiDep.Accounts.UseCases.LogInOrRegisterWithLink do
  @moduledoc """
  User account management use case for a user to log in, creating a valid
  authentication object that can be used for authorization in other use cases.
  """

  use ArchiDep, :use_case

  alias ArchiDep.Accounts.Events.UserLoggedInWithLink
  alias ArchiDep.Accounts.Events.UserRegisteredWithLink
  alias ArchiDep.Accounts.PubSub
  alias ArchiDep.Accounts.Schemas.LoginLink
  alias ArchiDep.Accounts.Schemas.PreregisteredUser
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.ClientMetadata

  @spec log_in_or_register_with_link(
          binary(),
          ClientMetadata.t()
        ) ::
          {:ok, Authentication.t()}
          | {:error, :invalid_link}
  def log_in_or_register_with_link(
        link_token,
        client_metadata
      ) do
    case log_in_or_register(link_token, client_metadata) do
      {:ok,
       %{
         user_account: user_account,
         user_session: session,
         linked_preregistered_user: preregistered_user
       }} ->
        if preregistered_user != nil do
          :ok = PubSub.publish_preregistered_user_updated(preregistered_user)
        end

        enriched_session = %UserSession{
          session
          | user_account: user_account,
            impersonated_user_account: nil
        }

        :telemetry.execute([:archidep, :accounts, :auth, :login], %{}, %{
          method: :link,
          principal_id: user_account.id
        })

        {:ok, UserSession.authentication(enriched_session)}

      {:error, _operation, :invalid_link, _changes} ->
        {:error, :invalid_link}
    end
  end

  defp log_in_or_register(link_token, client_metadata),
    do:
      Multi.new()
      |> Multi.run(
        :valid_login_link,
        fn _repo, %{} -> LoginLink.fetch_valid_link_by_token(link_token) end
      )
      |> Multi.merge(fn
        %{
          valid_login_link:
            %LoginLink{preregistered_user: %PreregisteredUser{} = preregistered_user} = link
        } ->
          log_in_or_register_preregistered_user(link, preregistered_user, client_metadata)

        %{valid_login_link: %LoginLink{user_account: %UserAccount{} = user_account} = link} ->
          log_in_or_register_user_account(link, user_account, client_metadata)
      end)
      |> Repo.transaction()

  defp log_in_or_register_preregistered_user(
         link,
         %PreregisteredUser{user_account: %UserAccount{active: true} = user_account} =
           preregistered_user,
         client_metadata
       ) do
    now = DateTime.utc_now()

    if PreregisteredUser.active?(preregistered_user, now) do
      Multi.new()
      |> Multi.put(:user_account, user_account)
      |> Multi.put(:linked_preregistered_user, nil)
      |> Multi.insert(:user_session, &UserSession.new_session(&1.user_account, client_metadata))
      |> Multi.update(
        :used_login_link,
        LoginLink.mark_as_used_changeset(link)
      )
      |> Multi.insert(
        :stored_event,
        &user_logged_in_with_link(link, &1.user_session, client_metadata)
      )
    else
      Multi.run(Multi.new(), :invalid_link, fn _repo, _changes -> {:error, :invalid_link} end)
    end
  end

  defp log_in_or_register_preregistered_user(
         link,
         %PreregisteredUser{user_account: nil} = preregistered_user,
         client_metadata
       ) do
    now = DateTime.utc_now()

    if PreregisteredUser.active?(preregistered_user, now) do
      Multi.new()
      |> Multi.insert(:user_account, UserAccount.new_preregistered_account(preregistered_user))
      |> Multi.update(
        :linked_preregistered_user,
        &PreregisteredUser.link_to_user_account(
          preregistered_user,
          &1.user_account,
          DateTime.utc_now()
        )
      )
      |> Multi.insert(:user_session, &UserSession.new_session(&1.user_account, client_metadata))
      |> Multi.update(
        :used_login_link,
        LoginLink.mark_as_used_changeset(link)
      )
      |> Multi.insert(
        :stored_event,
        &user_registered_with_link(link, &1.user_session, preregistered_user)
      )
    else
      Multi.run(Multi.new(), :invalid_link, fn _repo, _changes -> {:error, :invalid_link} end)
    end
  end

  defp log_in_or_register_preregistered_user(
         _link,
         %PreregisteredUser{},
         _client_metadata
       ) do
    Multi.run(Multi.new(), :invalid_link, fn _repo, _changes -> {:error, :invalid_link} end)
  end

  defp log_in_or_register_user_account(_link_token, _user_account, _client_metadata) do
    Multi.run(Multi.new(), :invalid_link, fn _repo, _changes -> {:error, :invalid_link} end)
  end

  defp user_registered_with_link(
         login_link,
         session,
         preregistered_user
       ),
       do:
         login_link
         |> UserRegisteredWithLink.new(
           session,
           preregistered_user
         )
         |> new_event(%{}, occurred_at: session.user_account.created_at)
         |> add_to_stream(session.user_account)
         |> initiated_by(session.user_account)

  defp user_logged_in_with_link(
         login_link,
         session,
         client_metadata
       ),
       do:
         login_link
         |> UserLoggedInWithLink.new(session, client_metadata)
         |> new_event(%{}, occurred_at: session.created_at)
         |> add_to_stream(session.user_account)
         |> initiated_by(session.user_account)
end
