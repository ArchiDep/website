defmodule ArchiDep.Accounts.Events.UserLoggedInWithSwitchEduId do
  @moduledoc """
  A user logged in with a Switch edu-ID identity linked to an existing user
  account.
  """

  alias ArchiDep.EventMetadata
  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias ArchiDep.Accounts.Schemas.UserSession
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

  @spec new(SwitchEduId.t(), UserSession.t(), EventMetadata.t()) :: t()
  def new(switch_edu_id, session, meta) do
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

    client_ip_address = EventMetadata.client_ip_address(meta)

    serialized_client_ip_address =
      if client_ip_address, do: EventMetadata.serialize_ip_address(client_ip_address), else: nil

    %__MODULE__{
      switch_edu_id: switch_edu_id_id,
      email: email,
      first_name: first_name,
      last_name: last_name,
      swiss_edu_person_unique_id: swiss_edu_person_unique_id,
      user_account_id: user_account_id,
      session_id: session_id,
      client_ip_address: serialized_client_ip_address,
      client_user_agent: EventMetadata.client_user_agent(meta)
    }
  end
end
