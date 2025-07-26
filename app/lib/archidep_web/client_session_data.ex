defmodule ArchiDepWeb.ClientSessionData do
  @moduledoc """
  Data structure representing the session information sent to the frontend.
  """

  alias ArchiDep.Authentication
  alias Ecto.UUID

  @derive Jason.Encoder
  @enforce_keys [:username, :roles, :impersonating, :sessionId, :sessionExpiresAt]
  defstruct [:username, :roles, :impersonating, :sessionId, :sessionExpiresAt]

  @type t :: %__MODULE__{
          username: String.t(),
          roles: [String.t()],
          impersonating: boolean(),
          sessionId: UUID.t(),
          sessionExpiresAt: String.t()
        }

  @spec new(Authentication.t()) :: t()
  def new(%Authentication{
        username: username,
        roles: roles,
        session_id: session_id,
        session_expires_at: session_expires_at,
        impersonated_id: impersonated_id
      }) do
    %__MODULE__{
      username: username,
      roles: Enum.map(roles, &Atom.to_string/1),
      impersonating: impersonated_id != nil,
      sessionId: session_id,
      sessionExpiresAt: DateTime.to_iso8601(session_expires_at)
    }
  end
end
