defmodule ArchiDepWeb.Admin.Classes.ClassesController do
  use ArchiDepWeb, :controller

  alias ArchiDep.Course

  @spec generate_class_ssh_exercise_vm_inventory(Conn.t(), map) :: Conn.t()
  def generate_class_ssh_exercise_vm_inventory(conn, %{"id" => id}) do
    auth = conn.assigns.auth

    with {:ok, class} <- Course.fetch_class(auth, id) do
      students = Course.list_students(auth, class)

      conn
      |> put_resp_header("content-type", "application/json; charset=utf-8")
      |> put_resp_header(
        "content-disposition",
        "attachment; filename=\"inventory.yml\""
      )
      |> send_resp(
        200,
        Jason.encode!(
          %{
            "students" =>
              Enum.map(
                students,
                &%{"username" => &1.username, "password" => &1.ssh_exercise_password}
              )
          },
          pretty: true
        )
      )
    else
      _anything ->
        send_resp(conn, 401, "Unauthorized")
    end
  end
end
