defmodule ArchiDep.Accounts.Events.PreregisteredUserLoginLinkCreated do
  @moduledoc """
  A user deleted one of their sessions.
  """

  use ArchiDep, :event

  alias ArchiDep.Accounts.Schemas.LoginLink
  alias ArchiDep.Accounts.Schemas.PreregisteredUser

  @derive Jason.Encoder

  @enforce_keys [:id, :preregistered_user]
  defstruct [:id, :preregistered_user]

  @type t :: %__MODULE__{
          id: UUID.t(),
          preregistered_user: %{
            id: UUID.t(),
            name: String.t() | nil,
            email: String.t() | nil
          }
        }

  @spec new(LoginLink.t()) :: t()
  def new(%LoginLink{
        id: id,
        preregistered_user: preregistered_user
      }) do
    %PreregisteredUser{id: preregistered_user_id, name: name, email: email} = preregistered_user

    %__MODULE__{
      id: id,
      preregistered_user: %{id: preregistered_user_id, name: name, email: email}
    }
  end

  defimpl Event do
    alias ArchiDep.Accounts.Events.PreregisteredUserLoginLinkCreated

    @spec event_stream(PreregisteredUserLoginLinkCreated.t()) :: String.t()
    def event_stream(%PreregisteredUserLoginLinkCreated{
          preregistered_user: %{id: preregistered_user_id}
        }),
        do: "accounts:preregistered-users:#{preregistered_user_id}"

    @spec event_type(PreregisteredUserLoginLinkCreated.t()) :: atom()
    def event_type(_event), do: :"archidep/accounts/preregistered-user-login-link-created"
  end
end
