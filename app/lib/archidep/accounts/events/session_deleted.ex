defmodule ArchiDep.Accounts.Events.SessionDeleted do
  @moduledoc """
  A user deleted one of their sessions.
  """

  use ArchiDep, :event

  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession

  @derive Jason.Encoder

  @enforce_keys [:user_account_id, :session_id]
  defstruct [:user_account_id, :session_id]

  @type t :: %__MODULE__{user_account_id: UUID.t(), session_id: UUID.t()}

  @spec new(UserSession.t()) :: t()
  def new(%UserSession{id: session_id, user_account: %UserAccount{id: user_account_id}}) do
    %__MODULE__{user_account_id: user_account_id, session_id: session_id}
  end

  defimpl Event do
    alias ArchiDep.Accounts.Events.SessionDeleted

    @spec event_stream(SessionDeleted.t()) :: String.t()
    def event_stream(%SessionDeleted{user_account_id: user_account_id}),
      do: "user-accounts:#{user_account_id}"

    @spec event_type(SessionDeleted.t()) :: atom()
    def event_type(_event), do: :"archidep/accounts/session-deleted"
  end
end
