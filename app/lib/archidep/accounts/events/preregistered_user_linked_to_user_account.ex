defmodule ArchiDep.Accounts.Events.PreregisteredUserLinkedToUserAccount do
  @moduledoc """
  A preregistered user was linked to a user account, which happens the first
  time the corresponding person logs in and their account is created (or, for a
  Switch edu-ID login, when an existing account is linked to a new
  preregistration).
  """

  use ArchiDep, :event

  alias ArchiDep.Accounts.Schemas.PreregisteredUser
  alias ArchiDep.Accounts.Schemas.UserAccount

  @derive Jason.Encoder

  @enforce_keys [:preregistered_user_id, :user_account]
  defstruct [:preregistered_user_id, :user_account]

  @type t :: %__MODULE__{
          preregistered_user_id: UUID.t(),
          user_account: %{
            id: UUID.t(),
            username: String.t(),
            active: boolean(),
            version: pos_integer()
          }
        }

  @spec new(PreregisteredUser.t(), UserAccount.t()) :: t()
  def new(
        %PreregisteredUser{id: preregistered_user_id},
        %UserAccount{id: id, username: username, active: active, version: version}
      ),
      do: %__MODULE__{
        preregistered_user_id: preregistered_user_id,
        user_account: %{
          id: id,
          username: username,
          active: active,
          version: version
        }
      }

  defimpl Event do
    alias ArchiDep.Accounts.Events.PreregisteredUserLinkedToUserAccount

    @spec event_stream(PreregisteredUserLinkedToUserAccount.t()) :: String.t()
    def event_stream(%PreregisteredUserLinkedToUserAccount{
          preregistered_user_id: preregistered_user_id
        }),
        do: "accounts:preregistered-users:#{preregistered_user_id}"

    @spec event_type(PreregisteredUserLinkedToUserAccount.t()) :: atom()
    def event_type(_event), do: :"archidep/accounts/preregistered-user-linked-to-user-account"
  end
end
