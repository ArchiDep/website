defmodule ArchiDep.Accounts.Events.UserLoggedInWithSwitchEduId do
  @moduledoc """
  A user logged in with a Switch edu-ID identity linked to an existing user
  account.
  """

  use ArchiDep, :event

  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias ArchiDep.Accounts.Schemas.PreregisteredUser
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.ClientMetadata
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

  @spec new(SwitchEduId.t(), UserSession.t(), ClientMetadata.t()) :: t()
  def new(switch_edu_id, session, client_metadata) do
    %SwitchEduId{
      id: switch_edu_id_id,
      first_name: first_name,
      last_name: last_name,
      swiss_edu_person_unique_id: swiss_edu_person_unique_id
    } = switch_edu_id

    %UserSession{
      id: session_id,
      user_account: user_account
    } = session

    %UserAccount{
      id: user_account_id,
      username: username,
      root: root,
      preregistered_user: preregistered_user
    } = user_account

    client_ip_address =
      if client_metadata.ip_address,
        do: ClientMetadata.serialize_ip_address(client_metadata.ip_address),
        else: nil

    %__MODULE__{
      switch_edu_id: %{
        id: switch_edu_id_id,
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
      client_user_agent: client_metadata.user_agent,
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
    alias ArchiDep.Accounts.Events.UserLoggedInWithSwitchEduId

    @spec event_stream(UserLoggedInWithSwitchEduId.t()) :: String.t()
    def event_stream(%UserLoggedInWithSwitchEduId{user_account: %{id: user_account_id}}),
      do: "accounts:user-accounts:#{user_account_id}"

    @spec event_type(UserLoggedInWithSwitchEduId.t()) :: atom()
    def event_type(_event), do: :"archidep/accounts/user-logged-in-with-switch-edu-id"
  end
end
