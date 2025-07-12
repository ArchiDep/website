defmodule ArchiDep.Accounts.Events.UserRegisteredWithSwitchEduId do
  @moduledoc """
  A new user account was registered based on a Switch edu-ID identity.
  """

  use ArchiDep, :event

  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias ArchiDep.Accounts.Schemas.PreregisteredUser
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
    :client_user_agent,
    :preregistered_user_id
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
    :client_user_agent,
    :preregistered_user_id
  ]

  @type t :: %__MODULE__{
          switch_edu_id: UUID.t(),
          email: String.t(),
          first_name: String.t() | nil,
          last_name: String.t() | nil,
          swiss_edu_person_unique_id: String.t(),
          user_account_id: UUID.t(),
          username: String.t(),
          session_id: UUID.t(),
          client_ip_address: String.t() | nil,
          client_user_agent: String.t() | nil,
          preregistered_user_id: UUID.t() | nil
        }

  @spec new(SwitchEduId.t(), UserSession.t(), PreregisteredUser.t() | nil) :: t()
  def new(switch_edu_id, user_session, preregistered_user) do
    %SwitchEduId{
      id: id,
      email: email,
      first_name: first_name,
      last_name: last_name,
      swiss_edu_person_unique_id: swiss_edu_person_unique_id
    } = switch_edu_id

    %UserSession{
      id: session_id,
      client_ip_address: client_ip_address,
      client_user_agent: client_user_agent,
      user_account: user_account
    } = user_session

    %UserAccount{
      id: user_account_id,
      username: username
    } = user_account

    preregistered_user_id =
      case preregistered_user do
        %PreregisteredUser{id: preregistered_user_id} -> preregistered_user_id
        nil -> nil
      end

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
      client_user_agent: client_user_agent,
      preregistered_user_id: preregistered_user_id
    }
  end

  defimpl Event do
    alias ArchiDep.Accounts.Events.UserRegisteredWithSwitchEduId

    def event_stream(%UserRegisteredWithSwitchEduId{user_account_id: user_account_id}),
      do: "user-accounts:#{user_account_id}"

    def event_type(_event), do: :"archidep/accounts/user-registered-with-switch-edu-id"
  end
end
