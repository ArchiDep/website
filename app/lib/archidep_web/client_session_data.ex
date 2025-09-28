defmodule ArchiDepWeb.ClientSessionData do
  @moduledoc """
  Data structure representing the session information sent to the frontend.
  """

  alias ArchiDep.Authentication
  alias Ecto.UUID

  @derive Jason.Encoder
  @enforce_keys [:username, :root, :impersonating, :sessionId, :sessionExpiresAt]
  defstruct [:username, :root, :impersonating, :sessionId, :sessionExpiresAt]

  @type t :: %__MODULE__{
          username: String.t(),
          root: boolean(),
          impersonating: boolean(),
          sessionId: UUID.t(),
          sessionExpiresAt: String.t()
        }

  @spec new(Authentication.t()) :: t()
  def new(%Authentication{
        username: username,
        root: root,
        session_id: session_id,
        session_expires_at: session_expires_at,
        impersonated_id: impersonated_id
      }),
      do: %__MODULE__{
        username: username,
        root: root,
        impersonating: impersonated_id != nil,
        sessionId: session_id,
        sessionExpiresAt: DateTime.to_iso8601(session_expires_at)
      }
end
