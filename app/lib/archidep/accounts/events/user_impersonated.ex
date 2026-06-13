defmodule ArchiDep.Accounts.Events.UserImpersonated do
  @moduledoc """
  An administrator started impersonating another user account through one of
  their sessions.
  """

  use ArchiDep, :event

  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias ArchiDep.Accounts.Schemas.PreregisteredUser
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession

  @derive Jason.Encoder

  @enforce_keys [:session_id, :user_account, :impersonated_user_account]
  defstruct [:session_id, :user_account, :impersonated_user_account]

  @typedoc """
  How a user account is described in an impersonation event: enough to display
  either a root user (by username or Switch edu-ID name) or a student (by
  preregistered name/email), matching how other account events represent
  accounts.
  """
  @type account :: %{
          id: UUID.t(),
          username: String.t() | nil,
          root: boolean(),
          switch_edu_id:
            %{id: UUID.t(), first_name: String.t() | nil, last_name: String.t() | nil} | nil,
          preregistered_user:
            %{id: UUID.t(), name: String.t() | nil, email: String.t() | nil} | nil
        }

  @type t :: %__MODULE__{
          session_id: UUID.t(),
          user_account: account(),
          impersonated_user_account: account()
        }

  @spec new(UserSession.t(), UserAccount.t()) :: t()
  def new(
        %UserSession{id: session_id, user_account: %UserAccount{} = user_account},
        impersonated
      ),
      do: %__MODULE__{
        session_id: session_id,
        user_account: account(user_account),
        impersonated_user_account: account(impersonated)
      }

  @spec account(UserAccount.t()) :: account()
  def account(%UserAccount{
        id: id,
        username: username,
        root: root,
        switch_edu_id: switch_edu_id,
        preregistered_user: preregistered_user
      }),
      do: %{
        id: id,
        username: username,
        root: root,
        switch_edu_id:
          case switch_edu_id do
            %SwitchEduId{id: sei_id, first_name: first_name, last_name: last_name} ->
              %{id: sei_id, first_name: first_name, last_name: last_name}

            nil ->
              nil
          end,
        preregistered_user:
          case preregistered_user do
            %PreregisteredUser{id: pu_id, name: name, email: email} ->
              %{id: pu_id, name: name, email: email}

            nil ->
              nil
          end
      }

  defimpl Event do
    alias ArchiDep.Accounts.Events.UserImpersonated

    @spec event_stream(UserImpersonated.t()) :: String.t()
    def event_stream(%UserImpersonated{user_account: %{id: user_account_id}}),
      do: "accounts:user-accounts:#{user_account_id}"

    @spec event_type(UserImpersonated.t()) :: atom()
    def event_type(_event), do: :"archidep/accounts/user-impersonated"
  end
end
