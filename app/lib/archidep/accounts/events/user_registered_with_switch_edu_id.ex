defmodule ArchiDep.Accounts.Events.UserRegisteredWithSwitchEduId do
  @moduledoc """
  A new user account was registered based on a Switch edu-ID identity.
  """

  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Students.Schemas.Student
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
    :student_id
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
    :student_id
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
          student_id: UUID.t() | nil
        }

  @spec new(SwitchEduId.t(), UserAccount.t(), UserSession.t(), Student.t() | nil) :: t()
  def new(switch_edu_id, user_account, user_session, student) do
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

    student_id =
      case student do
        %Student{id: student_id} -> student_id
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
      student_id: student_id
    }
  end
end
