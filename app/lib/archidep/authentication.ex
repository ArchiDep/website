defmodule ArchiDep.Authentication do
  @moduledoc """
  Authentication context containing the user session and logged user.
  """

  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Errors.AuthenticatedUserNotFoundError
  alias ArchiDep.Repo

  @spec is_authentication(term) :: Macro.t()
  defguard is_authentication(value) when is_struct(value, __MODULE__)

  @enforce_keys [:session, :principal, :metadata]
  defstruct [:session, :principal, :metadata]

  @opaque t :: %__MODULE__{
            session: UserSession.t(),
            principal: UserAccount.t(),
            metadata: map
          }

  @doc """
  Creates an authentication context for the specified user session.
  """
  @spec for_user_session(UserSession.t(), map) :: __MODULE__.t()
  def for_user_session(session, metadata),
    do: %__MODULE__{
      session: session,
      principal: session.user_account,
      metadata: metadata
    }

  @doc """
  Returns the username of the currently authenticated user.
  """
  @spec username(__MODULE__.t()) :: String.t()
  def username(%__MODULE__{principal: %UserAccount{username: username}}), do: username

  @doc """
  Returns the ID of the authenticated user account.
  """
  @spec user_account_id(__MODULE__.t()) :: String.t()
  def user_account_id(%__MODULE__{principal: %UserAccount{id: id}}), do: id

  @doc """
  Returns the token identifying the current session.
  """
  @spec session_token(__MODULE__.t()) :: String.t()
  def session_token(%__MODULE__{session: %UserSession{token: token}}) when is_binary(token),
    do: token

  @doc """
  Indicates whether the specified session is the same as the current one.
  """
  @spec current_session?(__MODULE__.t(), UserSession.t()) :: boolean
  def current_session?(%__MODULE__{session: %UserSession{id: id}}, %UserSession{id: id}),
    do: true

  def current_session?(%__MODULE__{}, %UserSession{}), do: false

  @doc """
  Returns the metadata associated with the authenticated user.
  """
  @spec metadata(__MODULE__.t()) :: map
  def metadata(%__MODULE__{metadata: metadata}), do: metadata

  @doc """
  Returns a fresh version of the authenticated user account.
  """
  @spec fetch_user_account(__MODULE__.t()) :: UserAccount.t()
  def fetch_user_account(%__MODULE__{principal: %UserAccount{id: id}}) do
    UserAccount
    |> Repo.get(id)
    |> tap(fn user_account ->
      unless user_account, do: raise(AuthenticatedUserNotFoundError)
    end)
  end
end
