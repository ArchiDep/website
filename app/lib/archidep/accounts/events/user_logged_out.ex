defmodule ArchiDep.Accounts.Events.UserLoggedOut do
  @moduledoc """
  A user logged out of one session.
  """

  use ArchiDep, :event

  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias ArchiDep.Accounts.Schemas.PreregisteredUser
  alias ArchiDep.Accounts.Schemas.UserSession
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [:user_account, :switch_edu_id, :preregistered_user, :session_id]
  defstruct [:user_account, :switch_edu_id, :preregistered_user, :session_id]

  @type t :: %__MODULE__{
          user_account: %{
            id: UUID.t(),
            username: String.t() | nil
          },
          switch_edu_id: %{
            id: UUID.t(),
            first_name: String.t() | nil,
            last_name: String.t() | nil
          },
          preregistered_user:
            %{
              id: UUID.t(),
              name: String.t() | nil,
              email: String.t() | nil
            }
            | nil,
          session_id: UUID.t()
        }

  @doc """
  Creates a new logout event for the specified session.
  """
  @spec new(UserSession.t()) :: t()
  def new(%UserSession{
        id: session_id,
        user_account: %{
          id: user_account_id,
          username: username,
          switch_edu_id: switch_edu_id,
          preregistered_user: preregistered_user
        }
      }) do
    %SwitchEduId{
      id: switch_edu_id,
      first_name: first_name,
      last_name: last_name
    } = switch_edu_id

    %__MODULE__{
      user_account: %{id: user_account_id, username: username},
      switch_edu_id: %{id: switch_edu_id, first_name: first_name, last_name: last_name},
      session_id: session_id,
      preregistered_user:
        case preregistered_user do
          %PreregisteredUser{id: preregistered_user_id, name: name, email: email} ->
            %{id: preregistered_user_id, name: name, email: email}

          nil ->
            nil
        end
    }
  end

  defimpl Event do
    alias ArchiDep.Accounts.Events.UserLoggedOut

    @spec event_stream(UserLoggedOut.t()) :: String.t()
    def event_stream(%UserLoggedOut{user_account: %{id: user_account_id}}),
      do: "accounts:user-accounts:#{user_account_id}"

    @spec event_type(UserLoggedOut.t()) :: atom()
    def event_type(_event), do: :"archidep/accounts/user-logged-out"
  end
end
