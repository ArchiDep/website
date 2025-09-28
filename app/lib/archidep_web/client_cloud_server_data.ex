defmodule ArchiDepWeb.ClientCloudServerData do
  @moduledoc """
  Data structure representing the information sent to the frontend about the
  user's active server.
  """

  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Servers.Schemas.Server

  @derive Jason.Encoder
  @enforce_keys [:student, :server, :serversEnabled]
  defstruct [:student, :server, :serversEnabled]

  @type t :: %__MODULE__{
          student:
            %{
              username: String.t(),
              usernameConfirmed: boolean(),
              domain: String.t()
            }
            | nil,
          server:
            %{
              name: String.t() | nil,
              username: String.t(),
              ipAddress: String.t(),
              url: String.t()
            }
            | nil,
          serversEnabled: boolean()
        }

  @spec new(Student.t(), {Server.t(), String.t()} | nil) :: t()
  def new(student, server),
    do: %__MODULE__{
      student: dump_student(student),
      server: dump_server(server),
      serversEnabled: servers_enabled?(student)
    }

  defp dump_server(nil), do: nil

  defp dump_server(
         {%Server{
            name: name,
            username: server_username,
            ip_address: ip_address
          }, server_url}
       ),
       do: %{
         name: name,
         username: server_username,
         ipAddress: ip_address.address |> :inet.ntoa() |> to_string(),
         url: server_url
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

  defp servers_enabled?(nil), do: false

  defp servers_enabled?(%Student{
         servers_enabled: student_servers_enabled,
         class: %Class{servers_enabled: class_servers_enabled}
       }),
       do: class_servers_enabled or student_servers_enabled
end
