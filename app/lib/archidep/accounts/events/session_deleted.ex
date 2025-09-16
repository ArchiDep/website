defmodule ArchiDep.Accounts.Events.SessionDeleted do
  @moduledoc """
  A user deleted one of their sessions.
  """

  use ArchiDep, :event

  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias ArchiDep.Accounts.Schemas.PreregisteredUser
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession

  @derive Jason.Encoder

  @enforce_keys [:user_account, :switch_edu_id, :preregistered_user, :session_id]
  defstruct [:user_account, :switch_edu_id, :preregistered_user, :session_id]

  @type t :: %__MODULE__{
          user_account: %{
            id: UUID.t(),
            username: String.t() | nil
          },
          switch_edu_id:
            %{
              id: UUID.t(),
              first_name: String.t() | nil,
              last_name: String.t() | nil
            }
            | nil,
          preregistered_user:
            %{
              id: UUID.t(),
              name: String.t() | nil,
              email: String.t() | nil
            }
            | nil,
          session_id: UUID.t()
        }

  @spec new(UserSession.t()) :: t()
  def new(%UserSession{
        id: session_id,
        user_account: %UserAccount{
          id: user_account_id,
          username: username,
          switch_edu_id: switch_edu_id,
          preregistered_user: preregistered_user
        }
      }) do
    %__MODULE__{
      user_account: %{id: user_account_id, username: username},
      switch_edu_id:
        case switch_edu_id do
          %SwitchEduId{id: switch_edu_id_id, first_name: first_name, last_name: last_name} ->
            %{id: switch_edu_id_id, first_name: first_name, last_name: last_name}

          nil ->
            nil
        end,
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
    alias ArchiDep.Accounts.Events.SessionDeleted

    @spec event_stream(SessionDeleted.t()) :: String.t()
    def event_stream(%SessionDeleted{user_account: %{id: user_account_id}}),
      do: "accounts:user-accounts:#{user_account_id}"

    @spec event_type(SessionDeleted.t()) :: atom()
    def event_type(_event), do: :"archidep/accounts/session-deleted"
  end
end
