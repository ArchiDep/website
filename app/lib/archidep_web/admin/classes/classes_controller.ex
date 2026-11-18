defmodule ArchiDepWeb.Admin.Classes.ClassesController do
  use ArchiDepWeb, :controller

  alias ArchiDep.Clock
  alias ArchiDep.Course
  alias ArchiDep.Servers
  alias ArchiDepWeb.Admin.Classes.Export
  alias ArchiDepWeb.Admin.Classes.StudentFilters

  @doc """
  Downloads the students of a class matching the student filters given as query
  parameters, in one of the formats of `ArchiDepWeb.Admin.Classes.Export`.
  """
  @spec generate_class_export(Conn.t(), map) :: Conn.t()
  def generate_class_export(conn, %{"id" => id, "format" => format_id} = params) do
    auth = conn.assigns.auth

    with {:ok, format} <- Export.fetch_format(format_id),
         {:ok, class} <- Course.fetch_class(auth, id),
         students =
           params
           |> StudentFilters.from_params()
           |> StudentFilters.filter(Course.list_students(auth, class)),
         {:ok, servers} <- list_servers(auth, class.id, format) do
      export = Export.new(class, students, servers, Clock.now())

      conn
      |> put_resp_header("content-type", format.content_type())
      |> put_resp_header(
        "content-disposition",
        "attachment; filename=\"#{format.filename(class)}\""
      )
      |> send_resp(200, Export.render(export, format, false))
    else
      {:error, :format_not_found} -> send_resp(conn, 404, "Not Found")
      {:error, _reason} -> send_resp(conn, 401, "Unauthorized")
    end
  end

  defp list_servers(auth, class_id, format) do
    if format.needs_servers?(),
      do: Servers.list_active_servers_in_group(auth, class_id),
      else: {:ok, []}
  end
end
