defmodule ArchiDep.Accounts.Events.UserRegisteredWithSwitchEduId do
  @moduledoc """
  A new user account was registered based on a Switch edu-ID identity.
  """

  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [:id, :switch_edu_id, :session_id, :client_ip_address, :client_user_agent]
  defstruct [:id, :switch_edu_id, :session_id, :client_ip_address, :client_user_agent]

  @type t :: %__MODULE__{
          id: UUID.t(),
          switch_edu_id: UUID.t(),
          session_id: UUID.t(),
          client_ip_address: String.t() | nil,
          client_user_agent: String.t() | nil
        }
end
