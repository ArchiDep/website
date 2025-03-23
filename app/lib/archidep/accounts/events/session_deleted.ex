defmodule ArchiDep.Accounts.Events.SessionDeleted do
  @moduledoc """
  A user deleted one of their sessions.
  """

  alias Ecto.UUID
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession

  @derive Jason.Encoder

  @enforce_keys [:user_account_id, :session_id]
  defstruct [:user_account_id, :session_id]

  @type t :: %__MODULE__{user_account_id: UUID.t(), session_id: UUID.t()}

  @spec new(UserSession.t()) :: __MODULE__.t()
  def new(%UserSession{id: session_id, user_account: %UserAccount{id: user_account_id}}) do
    %__MODULE__{user_account_id: user_account_id, session_id: session_id}
  end
end
