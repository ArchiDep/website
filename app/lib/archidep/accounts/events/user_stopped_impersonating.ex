defmodule ArchiDep.Accounts.Events.UserStoppedImpersonating do
  @moduledoc """
  An administrator stopped impersonating another user account, returning the
  session to its original user.
  """

  use ArchiDep, :event

  alias ArchiDep.Accounts.Events.UserImpersonated
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession

  @derive Jason.Encoder

  @enforce_keys [:session_id, :user_account, :impersonated_user_account]
  defstruct [:session_id, :user_account, :impersonated_user_account]

  @type t :: %__MODULE__{
          session_id: UUID.t(),
          user_account: UserImpersonated.account(),
          impersonated_user_account: UserImpersonated.account()
        }

  @spec new(UserSession.t()) :: t()
  def new(%UserSession{
        id: session_id,
        user_account: %UserAccount{} = user_account,
        impersonated_user_account: %UserAccount{} = impersonated_user_account
      }),
      # The same account representation as `UserImpersonated`, so both ends of
      # an impersonation are described identically in the audit log.
      do: %__MODULE__{
        session_id: session_id,
        user_account: UserImpersonated.account(user_account),
        impersonated_user_account: UserImpersonated.account(impersonated_user_account)
      }

  defimpl Event do
    alias ArchiDep.Accounts.Events.UserStoppedImpersonating

    @spec event_stream(UserStoppedImpersonating.t()) :: String.t()
    def event_stream(%UserStoppedImpersonating{user_account: %{id: user_account_id}}),
      do: "accounts:user-accounts:#{user_account_id}"

    @spec event_type(UserStoppedImpersonating.t()) :: atom()
    def event_type(_event), do: :"archidep/accounts/user-stopped-impersonating"
  end
end
