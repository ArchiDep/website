defmodule ArchiDep.Authentication do
  @moduledoc """
  Represents an authenticated user session in the application.
  """

  alias ArchiDep.Events.Store.EventInitiator
  alias Ecto.UUID

  @spec is_authentication(term) :: Macro.t()
  defguard is_authentication(value) when is_struct(value, __MODULE__)

  @enforce_keys [
    :principal_id,
    :username,
    :root,
    :session_id,
    :session_token,
    :session_expires_at
  ]
  defstruct [
    :principal_id,
    :username,
    :root,
    :session_id,
    :session_token,
    :session_expires_at,
    impersonated_id: nil
  ]

  @type t :: %__MODULE__{
          principal_id: UUID.t(),
          username: String.t() | nil,
          root: boolean(),
          session_id: UUID.t(),
          session_token: binary() | nil,
          session_expires_at: DateTime.t(),
          impersonated_id: UUID.t() | nil
        }

  @spec username(t()) :: String.t() | nil
  def username(%__MODULE__{username: username}), do: username

  @spec root?(t()) :: boolean
  def root?(%__MODULE__{root: root}), do: root

  @spec principal_id(t()) :: String.t()
  def principal_id(%__MODULE__{principal_id: principal_id}), do: principal_id

  @spec session_id(t()) :: UUID.t()
  def session_id(%__MODULE__{session_id: session_id}), do: session_id

  @spec session_expires_at(t()) :: DateTime.t()
  def session_expires_at(%__MODULE__{session_expires_at: session_expires_at}),
    do: session_expires_at

  @doc """
  The session's token, as the caller presented it or as it was handed out when
  the session was created.

  It is absent from an authentication built from a session the caller did not
  present a token for, e.g. a channel connecting with a signed session ID rather
  than the token, because only the hash of the token is stored, and a hash
  cannot produce it. The guard is deliberate: nothing may quietly treat a
  missing token as a token.
  """
  @spec session_token(t()) :: binary()
  def session_token(%__MODULE__{session_token: session_token}) when is_binary(session_token),
    do: session_token

  @spec event_stream(t()) :: String.t()
  def event_stream(%__MODULE__{principal_id: principal_id}),
    do: "accounts:user-accounts:#{principal_id}"

  defimpl EventInitiator do
    alias ArchiDep.Authentication

    @spec event_initiator_stream(Authentication.t()) :: String.t()
    def event_initiator_stream(auth), do: Authentication.event_stream(auth)
  end
end
