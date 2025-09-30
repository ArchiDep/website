defmodule ArchiDepWeb.ClientSessionData do
  @moduledoc """
  Data structure representing the session information sent to the frontend.
  """

  alias ArchiDep.Authentication
  alias ArchiDep.Course.Schemas.Student
  alias Ecto.UUID

  @derive Jason.Encoder
  @enforce_keys [:username, :root, :impersonating, :sessionId, :sessionExpiresAt, :student]
  defstruct [:username, :root, :impersonating, :sessionId, :sessionExpiresAt, :student]

  @type t :: %__MODULE__{
          username: String.t(),
          root: boolean(),
          impersonating: boolean(),
          sessionId: UUID.t(),
          sessionExpiresAt: String.t(),
          student:
            %{
              username: String.t(),
              usernameConfirmed: boolean(),
              domain: String.t()
            }
            | nil
        }

  @spec new(Authentication.t(), Student.t() | nil) :: t()
  def new(
        %Authentication{
          username: username,
          root: root,
          session_id: session_id,
          session_expires_at: session_expires_at,
          impersonated_id: impersonated_id
        },
        student
      ),
      do: %__MODULE__{
        username: username,
        root: root,
        impersonating: impersonated_id != nil,
        sessionId: session_id,
        sessionExpiresAt: DateTime.to_iso8601(session_expires_at),
        student: dump_student(student)
      }

  defp dump_student(nil), do: nil

  defp dump_student(%Student{
         username: username,
         username_confirmed: username_confirmed,
         domain: domain
       }),
       do: %{
         username: username,
         usernameConfirmed: username_confirmed,
         domain: domain
       }
end
