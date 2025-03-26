defmodule ArchiDep.Accounts.Events.UserLoggedInWithSwitchEduId do
  @moduledoc """
  A user logged in with a Switch edu-ID identity linked to an existing user
  account.
  """

  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.ClientMetadata
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [
    :switch_edu_id,
    :email,
    :first_name,
    :last_name,
    :swiss_edu_person_unique_id,
    :user_account_id,
    :session_id,
    :client_ip_address,
    :client_user_agent
  ]
  defstruct [
    :switch_edu_id,
    :email,
    :first_name,
    :last_name,
    :swiss_edu_person_unique_id,
    :user_account_id,
    :session_id,
    :client_ip_address,
    :client_user_agent
  ]

  @type t :: %__MODULE__{
          switch_edu_id: UUID.t(),
          email: String.t(),
          first_name: String.t(),
          last_name: String.t() | nil,
          swiss_edu_person_unique_id: String.t(),
          user_account_id: UUID.t(),
          session_id: UUID.t(),
          client_ip_address: String.t() | nil,
          client_user_agent: String.t() | nil
        }

  @spec new(SwitchEduId.t(), UserSession.t(), ClientMetadata.t()) :: t()
  def new(switch_edu_id, session, client_metadata) do
    %SwitchEduId{
      id: switch_edu_id_id,
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
      switch_edu_id: switch_edu_id_id,
      email: email,
      first_name: first_name,
      last_name: last_name,
      swiss_edu_person_unique_id: swiss_edu_person_unique_id,
      user_account_id: user_account_id,
      session_id: session_id,
      client_ip_address: client_metadata.ip_address,
      client_user_agent: client_metadata.user_agent
    }
  end
end
