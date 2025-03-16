defmodule ArchiDep.Accounts.Events.UserRegisteredWithSwitchEduId do
  @moduledoc """
  A new user account was registered based on a Switch edu-ID identity.
  """

  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias ArchiDep.Accounts.Schemas.UserAccount
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
    :username,
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
    :username,
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
          username: String.t(),
          session_id: UUID.t(),
          client_ip_address: String.t() | nil,
          client_user_agent: String.t() | nil
        }

  @spec new(SwitchEduId.t(), UserAccount.t(), UserSession.t()) :: t()
  def new(switch_edu_id, user_account, user_session) do
    %SwitchEduId{
      id: id,
      email: email,
      first_name: first_name,
      last_name: last_name,
      swiss_edu_person_unique_id: swiss_edu_person_unique_id
    } = switch_edu_id

    %UserAccount{
      id: user_account_id,
      username: username
    } = user_account

    %UserSession{
      id: session_id,
      client_ip_address: client_ip_address,
      client_user_agent: client_user_agent
    } = user_session

    %__MODULE__{
      switch_edu_id: id,
      email: email,
      first_name: first_name,
      last_name: last_name,
      swiss_edu_person_unique_id: swiss_edu_person_unique_id,
      user_account_id: user_account_id,
      username: username,
      session_id: session_id,
      client_ip_address: client_ip_address,
      client_user_agent: client_user_agent
    }
  end
end
