defmodule ArchiDep.Accounts.Events.UserLoggedInWithSwitchEduId do
  @moduledoc """
  A user logged in with a Switch edu-ID identity linked to an existing user
  account.
  """

  import ArchiDep.Helpers.PipeHelpers, only: [truthy_then: 2]
  alias ArchiDep.EventMetadata
  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias ArchiDep.Accounts.Schemas.UserSession
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [
    :id,
    :user_account_id,
    :session_id,
    :email,
    :first_name,
    :last_name,
    :swiss_edu_person_unique_id,
    :client_ip_address,
    :client_user_agent
  ]
  defstruct [
    :id,
    :user_account_id,
    :session_id,
    :email,
    :first_name,
    :last_name,
    :swiss_edu_person_unique_id,
    :client_ip_address,
    :client_user_agent
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          user_account_id: UUID.t(),
          session_id: UUID.t(),
          email: String.t(),
          first_name: String.t(),
          last_name: String.t() | nil,
          swiss_edu_person_unique_id: String.t(),
          client_ip_address: String.t() | nil,
          client_user_agent: String.t() | nil
        }

  @spec new(UserSession.t(), SwitchEduId.t(), EventMetadata.t()) :: t()
  def new(switch_edu_id, session, meta) do
    %SwitchEduId{
      id: id,
      email: email,
      first_name: first_name,
      last_name: last_name,
      swiss_edu_person_unique_id: swiss_edu_person_unique_id
    } = switch_edu_id

    %UserSession{
      id: session_id,
      user_account_id: user_account_id
    } = session

    %__MODULE__{
      id: id,
      user_account_id: user_account_id,
      session_id: session_id,
      email: email,
      first_name: first_name,
      last_name: last_name,
      swiss_edu_person_unique_id: swiss_edu_person_unique_id,
      client_ip_address:
        meta
        |> Map.get(:client_ip_address)
        |> truthy_then(&EventMetadata.serialize_ip_address/1),
      client_user_agent: meta[:client_user_agent]
    }
  end
end
