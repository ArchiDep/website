defmodule ArchiDep.Accounts.Events.UserLoggedOut do
  @moduledoc """
  A user logged out of one session.
  """

  use ArchiDep, :event

  alias ArchiDep.Accounts.Schemas.UserSession
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [:user_account_id, :session_id]
  defstruct [:user_account_id, :session_id]

  @type t :: %__MODULE__{
          user_account_id: UUID.t(),
          session_id: UUID.t()
        }

  @doc """
  Creates a new logout event for the specified session.
  """
  @spec new(UserSession.t()) :: t()
  def new(%UserSession{id: session_id, user_account: %{id: user_account_id}}) do
    %__MODULE__{user_account_id: user_account_id, session_id: session_id}
  end

  defimpl Event do
    alias ArchiDep.Accounts.Events.UserLoggedOut

    @spec event_stream(UserLoggedOut.t()) :: String.t()
    def event_stream(%UserLoggedOut{user_account_id: user_account_id}),
      do: "user-accounts:#{user_account_id}"

    @spec event_type(UserLoggedOut.t()) :: atom()
    def event_type(_event), do: :"archidep/accounts/user-logged-out"
  end
end
