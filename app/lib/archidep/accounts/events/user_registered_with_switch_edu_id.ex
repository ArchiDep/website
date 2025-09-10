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
    :user_account,
    :session_id,
    :client_ip_address,
    :client_user_agent,
    :preregistered_user
  ]
  defstruct [
    :switch_edu_id,
    :user_account,
    :session_id,
    :client_ip_address,
    :client_user_agent,
    :preregistered_user
  ]

  @type t :: %__MODULE__{
          switch_edu_id: %{
            id: UUID.t(),
            first_name: String.t() | nil,
            last_name: String.t() | nil,
            swiss_edu_person_unique_id: String.t()
          },
          user_account: %{
            id: UUID.t(),
            username: String.t() | nil,
            root: boolean()
          },
          session_id: UUID.t(),
          client_ip_address: String.t() | nil,
          client_user_agent: String.t() | nil,
          preregistered_user:
            %{
              id: UUID.t(),
              name: String.t(),
              email: String.t()
            }
            | nil
        }

  @spec new(SwitchEduId.t(), UserSession.t(), PreregisteredUser.t() | nil) :: t()
  def new(switch_edu_id, user_session, preregistered_user) do
    %SwitchEduId{
      id: id,
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
      username: username,
      root: root
    } = user_account

    %__MODULE__{
      switch_edu_id: %{
        id: id,
        first_name: first_name,
        last_name: last_name,
        swiss_edu_person_unique_id: swiss_edu_person_unique_id
      },
      user_account: %{
        id: user_account_id,
        username: username,
        root: root
      },
      session_id: session_id,
      client_ip_address: client_ip_address,
      client_user_agent: client_user_agent,
      preregistered_user:
        case preregistered_user do
          %PreregisteredUser{
            id: preregistered_user_id,
            name: preregistered_user_name,
            email: preregistered_user_email
          } ->
            %{
              id: preregistered_user_id,
              name: preregistered_user_name,
              email: preregistered_user_email
            }

          nil ->
            nil
        end
    }
  end

  defimpl Event do
    alias ArchiDep.Accounts.Events.UserRegisteredWithSwitchEduId

    @spec event_stream(UserRegisteredWithSwitchEduId.t()) :: String.t()
    def event_stream(%UserRegisteredWithSwitchEduId{user_account: %{id: user_account_id}}),
      do: "accounts:user-accounts:#{user_account_id}"

    @spec event_type(UserRegisteredWithSwitchEduId.t()) :: atom()
    def event_type(_event), do: :"archidep/accounts/user-registered-with-switch-edu-id"
  end
end
