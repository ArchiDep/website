defmodule ArchiDep.Accounts.Events.UserLoggedInWithSwitchEduId do
  @moduledoc """
  A user logged in with a Switch edu-ID identity linked to an existing user
  account.
  """

  alias ArchiDep.EventMetadata
  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [
    :id,
    :email,
    :first_name,
    :last_name,
    :swiss_edu_person_unique_id,
    :session_id,
    :client_ip_address,
    :client_user_agent
  ]
  defstruct [
    :id,
    :email,
    :first_name,
    :last_name,
    :swiss_edu_person_unique_id,
    :session_id,
    :client_ip_address,
    :client_user_agent
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          email: String.t(),
          first_name: String.t(),
          last_name: String.t() | nil,
          swiss_edu_person_unique_id: String.t(),
          session_id: UUID.t(),
          client_ip_address: String.t() | nil,
          client_user_agent: String.t() | nil
        }

  @doc """
  Creates a new Switch edu-ID login event.
  """
  @spec new(UUID.t(), SwitchEduId.t(), UUID.t(), EventMetadata.t()) :: __MODULE__.t()
  def new(id, switch_edu_id, session_id, meta) do
    %SwitchEduId{
      id: session_id,
      email: email,
      first_name: first_name,
      last_name: last_name,
      swiss_edu_person_unique_id: swiss_edu_person_unique_id
    } = switch_edu_id

    %__MODULE__{
      id: id,
      email: email,
      first_name: first_name,
      last_name: last_name,
      swiss_edu_person_unique_id: swiss_edu_person_unique_id,
      session_id: session_id,
      client_ip_address: meta[:client_ip_address],
      client_user_agent: meta[:client_user_agent]
    }
  end
end
